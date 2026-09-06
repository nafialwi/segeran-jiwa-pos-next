import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
const workflow = readFileSync(
  '.github/workflows/mobile-inbox-worker.yml',
  'utf8',
);
describe('mobile inbox retry_safe extraction', () => {
  it('accepts boolean false without jq -e false-status semantics', () => {
    expect(workflow).not.toContain("jq -er '.retry_safe | booleans'");
  });
});
