import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const workerPath = new URL(
  '../.github/workflows/mobile-inbox-worker.yml',
  import.meta.url,
);

describe('mobile inbox canonical worker', () => {
  it('defines the guarded canonical intake contract', () => {
    const source = readFileSync(workerPath, 'utf8');

    const required = [
      'name: mobile-inbox-worker',
      'workflow_dispatch:',
      'transport_sha:',
      'group: mobile-inbox',
      'contents: write',
      'pull-requests: write',
      'statuses: write',
      'ref: main',
      'ref: mobile-inbox',
      'transport_guard.py',
      'mobile-inbox-trigger.yml',
      'package.zip',
      'intake.py validate',
      '--schema-version-current 0',
      'retry_safe',
      'base_commit',
      'npm ci',
      'npm run verify',
      'canonical-verify',
      'gh pr',
      'processed/',
      'reports/',
      'source_zip_sha256',
      'already_processed_same_content',
    ];

    for (const token of required) {
      expect(source).toContain(token);
    }

    expect(source).not.toContain('SUPABASE_');
    expect(source).not.toContain('CLOUDFLARE_');
  });
});
