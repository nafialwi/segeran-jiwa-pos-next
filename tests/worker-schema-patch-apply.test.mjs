import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const workflow = readFileSync(
  new URL('../.github/workflows/mobile-inbox-worker.yml', import.meta.url),
  'utf8',
);

const applyStart = workflow.indexOf('PHASE="apply_validated_patch"');
const verifyStart = workflow.indexOf('PHASE="canonical_verify"', applyStart);
const applyBlock = workflow.slice(
  applyStart,
  verifyStart === -1 ? undefined : verifyStart,
);

describe('mobile inbox schema_patch apply bridge', () => {
  it('isolates the actual apply_validated_patch block', () => {
    expect(applyStart).toBeGreaterThanOrEqual(0);
    expect(verifyStart).toBeGreaterThan(applyStart);
    expect(applyBlock).toContain('PHASE="apply_validated_patch"');
  });

  it('passes manifest package_type into protected-path checks for writes', () => {
    expect(applyBlock).toMatch(
      /is_protected_path\(\s*rel,\s*manifest\["package_type"\],\s*for_delete=False,?\s*\)/,
    );
  });

  it('keeps protected delete checks fail-closed', () => {
    expect(applyBlock).toMatch(
      /is_protected_path\(\s*rel,\s*manifest\["package_type"\],\s*for_delete=True,?\s*\)/,
    );
  });

  it('makes post-apply scope verification package-aware', () => {
    expect(applyBlock).toMatch(
      /is_protected_path\(\s*path,\s*manifest\["package_type"\],\s*for_delete=path in set\(manifest\["delete_paths"\]\),?\s*\)/,
    );
  });

  it('removes legacy unqualified protected-path checks from apply phase', () => {
    expect(applyBlock).not.toMatch(/is_protected_path\(rel\)/);
    expect(applyBlock).not.toMatch(/is_protected_path\(path\)/);
  });
});
