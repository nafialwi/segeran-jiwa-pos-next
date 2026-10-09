#!/usr/bin/env node
/**
 * F22: read-only, fail-closed staging isolation preflight.
 *
 * This DOES NOT make API requests, create resources, verify live RLS, or authorize UAT.
 * A passing preflight only shows that local staging and preview project references
 * are distinct from the declared operational project and match each other.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const blocked = (reason) => {
  process.stdout.write(
    JSON.stringify({ status: 'BLOCKED', reason, uat_allowed: false }) + '\n',
  );
  process.exitCode = 2;
};

const options = {};
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i += 2) {
  const key = args[i];
  if (!key?.startsWith('--') || !args[i + 1] || args[i + 1].startsWith('--')) {
    blocked('INVALID_ARGUMENTS');
    process.exit();
  }
  options[key.slice(2)] = args[i + 1];
}

if (
  !options['staging-env'] ||
  !options['production-ref'] ||
  !options['preview-ref']
) {
  blocked('EXPLICIT_STAGING_ENV_PRODUCTION_REF_AND_PREVIEW_REF_REQUIRED');
  process.exit();
}

const refPattern = /^[a-z0-9]{20}$/;
const productionRef = options['production-ref'];
const previewRef = options['preview-ref'];

if (!refPattern.test(productionRef) || !refPattern.test(previewRef)) {
  blocked('PROJECT_REFERENCE_INVALID');
  process.exit();
}

let contents;
try {
  contents = readFileSync(resolve(options['staging-env']), 'utf8');
} catch {
  blocked('STAGING_ENV_NOT_READABLE');
  process.exit();
}

const env = {};
for (const entry of contents.split(/\r?\n/)) {
  const line = entry.trim();
  if (!line || line.startsWith('#')) continue;
  const match = line.match(
    /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/,
  );
  if (!match) continue;
  let value = match[2].trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  env[match[1]] = value;
}

const urlText = env.VITE_SUPABASE_URL;
const publishableKey = env.VITE_SUPABASE_PUBLISHABLE_KEY;
if (!urlText || !publishableKey) {
  blocked('STAGING_BROWSER_CONFIG_INCOMPLETE');
  process.exit();
}

if (
  publishableKey.startsWith('sb_secret_') ||
  publishableKey.startsWith('service_role')
) {
  blocked('SERVER_CREDENTIAL_IN_BROWSER_CONFIG');
  process.exit();
}

let stagingRef;
try {
  const url = new URL(urlText);
  const match = url.hostname.match(/^([a-z0-9]{20})\.supabase\.co$/);
  if (
    url.protocol !== 'https:' ||
    !match ||
    url.username ||
    url.password ||
    url.pathname !== '/' ||
    url.search ||
    url.hash
  ) {
    blocked('STAGING_URL_NOT_A_STANDARD_SUPABASE_ENDPOINT');
    process.exit();
  }
  stagingRef = match[1];
} catch {
  blocked('STAGING_URL_INVALID');
  process.exit();
}

if (stagingRef === productionRef) {
  blocked('STAGING_AND_OPERATIONAL_PROJECT_ARE_IDENTICAL');
  process.exit();
}
if (previewRef === productionRef) {
  blocked('PREVIEW_STILL_TARGETS_OPERATIONAL_PROJECT');
  process.exit();
}
if (previewRef !== stagingRef) {
  blocked('PREVIEW_AND_STAGING_PROJECT_DIFFER');
  process.exit();
}

process.stdout.write(
  JSON.stringify({
    status: 'CONFIG_DISTINCT_ONLY',
    staging_ref: stagingRef,
    preview_ref: previewRef,
    operational_ref: productionRef,
    uat_allowed: false,
    required_next:
      'VERIFY_SEPARATE_LIVE_PROJECT_RLS_SEED_AND_EXPLICIT_TEST_AUTHORIZATION',
  }) + '\n',
);
