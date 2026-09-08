import { describe, expect, it } from 'vitest';
import {
  normalizeUsername,
  toInternalAuthEmail,
  validateUsername,
} from '../src/auth/username';

describe('CS-03 username contract', () => {
  it('normalizes username deterministically', () => {
    expect(normalizeUsername('  Kasir_1  ')).toBe('kasir_1');
  });

  it('builds the reserved internal Auth email without exposing a real email', () => {
    expect(toInternalAuthEmail('Kasir_1')).toBe(
      'kasir_1@auth.segeranjiwa.invalid',
    );
  });

  it('accepts 3-32 ASCII username characters only', () => {
    expect(validateUsername('admin1').ok).toBe(true);
    expect(validateUsername('ka').ok).toBe(false);
    expect(validateUsername('kasir satu').ok).toBe(false);
    expect(validateUsername('kasir@1').ok).toBe(false);
  });

  it('rejects invalid usernames before building an internal Auth email', () => {
    expect(() => toInternalAuthEmail('ka')).toThrow('SJ_USERNAME_INVALID');
  });
});
