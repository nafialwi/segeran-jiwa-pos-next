#!/usr/bin/env node
/**
 * F23: read-only, fail-closed backup preflight for development UAT.
 * A passing evidence check never grants permission to mutate the database.
 * Evidence JSON is operator supplied; restored state needs independent validation.
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { validateBackupBundle } from './backup-health.mjs';

function block(reason) {
  process.stdout.write(
    JSON.stringify({
      status: 'BLOCKED',
      reason,
      uat_mutations_allowed: false,
    }) + '\n',
  );
  process.exitCode = 2;
}

const argv = process.argv.slice(2);
const opts = new Map();
for (let i = 0; i < argv.length; i += 2) {
  const key = argv[i];
  const value = argv[i + 1];
  if (!key?.startsWith('--') || !value || value.startsWith('--')) {
    block('INVALID_ARGUMENTS');
    process.exit();
  }
  opts.set(key.slice(2), value);
}

const bundle = opts.get('bundle-dir');
const retained = opts.get('retained-copy');
const baseline = opts.get('baseline-utc');
const projectRef = opts.get('project-ref');
if (!bundle || !retained || !baseline || !projectRef) {
  block('EXPLICIT_BUNDLE_RETAINED_COPY_BASELINE_AND_PROJECT_REQUIRED');
  process.exit();
}
if (projectRef !== 'pkynjaqrxhhnnfuaxoqp') {
  block('WRONG_PROJECT');
  process.exit();
}
const strictUTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/;
if (!strictUTC.test(baseline) || Number.isNaN(Date.parse(baseline))) {
  block('INVALID_BASELINE_UTC');
  process.exit();
}
const baseMs = Date.parse(baseline);
const result = validateBackupBundle(bundle, retained);
if (!result.healthy) {
  block('BACKUP_HEALTH_UNVERIFIED');
  process.exit();
}
const manifestFile = resolve(bundle, 'backup-manifest.json');
const restoreFile = resolve(bundle, 'restore-verification.json');
if (!existsSync(manifestFile) || !existsSync(restoreFile)) {
  block('EVIDENCE_NOT_READABLE');
  process.exit();
}
let manifest;
let restore;
try {
  manifest = JSON.parse(readFileSync(manifestFile, 'utf8'));
  restore = JSON.parse(readFileSync(restoreFile, 'utf8'));
} catch {
  block('EVIDENCE_INVALID');
  process.exit();
}
const createdMs = Date.parse(manifest.created_at);
const restoreMs = Date.parse(restore.verified_at);
if (
  !Number.isFinite(createdMs) ||
  !Number.isFinite(restoreMs) ||
  createdMs < baseMs
) {
  block('BACKUP_OLDER_THAN_BASELINE');
  process.exit();
}
if (restoreMs < createdMs) {
  block('RESTORE_EVIDENCE_PREDATES_BACKUP');
  process.exit();
}
if (createdMs > Date.now() + 300_000 || restoreMs > Date.now() + 300_000) {
  block('EVIDENCE_TIMESTAMP_IN_FUTURE');
  process.exit();
}
process.stdout.write(
  JSON.stringify({
    status: 'BACKUP_EVIDENCE_PRESENT_REVIEW_REQUIRED',
    project_ref: projectRef,
    created_at: manifest.created_at,
    verified_at: restore.verified_at,
    backup_sha256: result.backupSha256,
    uat_mutations_allowed: false,
    required_next: 'INDEPENDENT_RESTORE_CONFIRMATION_AND_OPERATOR_APPROVAL',
  }) + '\n',
);
