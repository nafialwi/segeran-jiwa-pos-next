import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const workflow = readFileSync(
  new URL('../.github/workflows/mobile-inbox-worker.yml', import.meta.url),
  'utf8',
);

describe('mobile inbox schema authority bridge', () => {
  it('derives current schema version from canonical release manifest', () => {
    expect(workflow).toContain(
      '$CANONICAL/docs/checkpoints/RELEASE_MANIFEST.json',
    );
    expect(workflow).toContain('schema_version');
    expect(workflow).toContain('SCHEMA_VERSION_CURRENT');
  });

  it('does not hard-code schema version zero into intake validation', () => {
    expect(workflow).not.toMatch(/--schema-version-current\s+0\b/);
    expect(workflow).toContain(
      '--schema-version-current "$SCHEMA_VERSION_CURRENT"',
    );
  });

  it('fails closed when schema authority is absent or invalid', () => {
    expect(workflow).toContain('schema authority unreadable');
    expect(workflow).toContain('schema authority invalid');
  });
});
