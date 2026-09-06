import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(
  readFileSync(new URL('../package.json', import.meta.url), 'utf8'),
);

describe('repository foundation', () => {
  it('pins the composite verify command', () => {
    expect(pkg.scripts.verify).toBe('node scripts/verify.mjs');
  });

  it('keeps Python tests inside the standard test surface', () => {
    expect(pkg.scripts['test:py']).toContain('unittest discover');
  });
});
