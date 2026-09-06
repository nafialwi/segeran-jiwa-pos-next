import { describe, expect, it } from 'vitest';
import { findForbiddenTrackedPaths } from '../scripts/repo-guard.mjs';

describe('canonical source ZIP hygiene', () => {
  it('rejects root-level transit ZIP while allowing nested ZIP fixtures', () => {
    expect(
      findForbiddenTrackedPaths([
        'SEGERAN_JIWA_NEXT_VOL1_CS01_TASK3_SAFE_ZIP_VALIDATOR.zip',
        'tests/fixtures/archive.zip',
        'src/app.ts',
      ]),
    ).toEqual(['SEGERAN_JIWA_NEXT_VOL1_CS01_TASK3_SAFE_ZIP_VALIDATOR.zip']);
  });
});
