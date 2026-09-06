import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { findForbiddenTrackedPaths } from '../scripts/repo-guard.mjs';
import { canonicalCommands } from '../scripts/verify.mjs';

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

describe('repository guard', () => {
  it('rejects secret-like tracked paths while allowing .env.example', () => {
    const violations = findForbiddenTrackedPaths([
      '.env',
      '.env.local',
      '.env.example',
      'config/client-secret.json',
      'src/app.ts',
    ]);

    expect(violations).toEqual([
      '.env',
      '.env.local',
      'config/client-secret.json',
    ]);
  });

  it('contains every canonical quality phase in order', () => {
    expect(canonicalCommands.map(({ label }) => label)).toEqual([
      'node scripts/repo-guard.mjs',
      'npm run format:check',
      'npm run lint',
      'npm run typecheck',
      'npm run test:js',
      'npm run test:py',
      'npm run build',
      'git diff --check',
    ]);
  });
});
