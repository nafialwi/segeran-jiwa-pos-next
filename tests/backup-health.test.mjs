import { createHash } from 'node:crypto';
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { validateBackupBundle } from '../scripts/backup-health.mjs';

const tempRoots = [];

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'sj-backup-health-'));
  tempRoots.push(root);

  const exportPath = join(root, 'data.sql');
  const retainedPath = join(root, 'retained-data.sql');

  writeFileSync(
    exportPath,
    "insert into public.businesses(id, code) values ('00000000-0000-0000-0000-000000000001', 'SJ');\n",
  );
  cpSync(exportPath, retainedPath);

  const digest = sha256(exportPath);

  writeFileSync(
    join(root, 'backup-manifest.json'),
    JSON.stringify({
      format_version: 1,
      project_ref: 'pkynjaqrxhhnnfuaxoqp',
      created_at: '2026-09-21T00:00:00.000Z',
      logical_export: {
        file: 'data.sql',
        sha256: digest,
      },
    }),
  );

  writeFileSync(
    join(root, 'restore-verification.json'),
    JSON.stringify({
      status: 'PASS',
      verified_at: '2026-09-21T00:10:00.000Z',
      backup_sha256: digest,
      method: 'isolated PostgreSQL restore',
    }),
  );

  return { root, exportPath, retainedPath, digest };
}

afterEach(() => {
  while (tempRoots.length > 0) {
    rmSync(tempRoots.pop(), { recursive: true, force: true });
  }
});

describe('P5C backup health gate', () => {
  it('accepts only a checksummed export with retained copy and PASS restore proof', () => {
    const { root, retainedPath, digest } = fixture();
    const result = validateBackupBundle(root, retainedPath);

    expect(result.healthy).toBe(true);
    expect(result.problems).toEqual([]);
    expect(result.backupSha256).toBe(digest);
  });

  it('fails closed when the logical export checksum changes', () => {
    const { root, exportPath, retainedPath } = fixture();
    writeFileSync(exportPath, 'tampered');

    const result = validateBackupBundle(root, retainedPath);

    expect(result.healthy).toBe(false);
    expect(result.problems.join('\n')).toContain('SHA-256 logical export');
  });

  it('fails closed when restore evidence is missing', () => {
    const { root, retainedPath } = fixture();
    rmSync(join(root, 'restore-verification.json'));

    const result = validateBackupBundle(root, retainedPath);

    expect(result.healthy).toBe(false);
    expect(result.problems.join('\n')).toContain('Bukti restore');
  });

  it('fails closed when retained copy is absent', () => {
    const { root } = fixture();

    const result = validateBackupBundle(root);

    expect(result.healthy).toBe(false);
    expect(result.problems.join('\n')).toContain('Retained copy');
  });

  it('rejects restore proof for a different backup checksum', () => {
    const { root, retainedPath } = fixture();
    const restorePath = join(root, 'restore-verification.json');
    const restore = JSON.parse(readFileSync(restorePath, 'utf8'));
    restore.backup_sha256 = '0'.repeat(64);
    writeFileSync(restorePath, JSON.stringify(restore));

    const result = validateBackupBundle(root, retainedPath);

    expect(result.healthy).toBe(false);
    expect(result.problems.join('\n')).toContain('tidak terikat');
  });
});
