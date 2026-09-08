import { describe, expect, it } from 'vitest';

import { toLoginErrorMessage } from '../src/auth/login-error';

describe('CS-03 safe login error projection', () => {
  it('hides invalid username format behind generic credential text', () => {
    expect(toLoginErrorMessage(new Error('SJ_USERNAME_INVALID'))).toBe(
      'Username atau password salah.',
    );
  });

  it('hides rejected Supabase credentials behind the same generic text', () => {
    expect(toLoginErrorMessage(new Error('SJ_LOGIN_INVALID'))).toBe(
      'Username atau password salah.',
    );
  });

  it('preserves the approved revoked-device message', () => {
    const message = 'Akses perangkat ini telah dicabut oleh Owner.';
    expect(toLoginErrorMessage(new Error(message))).toBe(message);
  });

  it('preserves the approved inactive-account message', () => {
    const message = 'Akun tidak sedang aktif. Hubungi Owner.';
    expect(toLoginErrorMessage(new Error(message))).toBe(message);
  });

  it('does not expose unknown backend or technical text', () => {
    expect(
      toLoginErrorMessage(
        new Error('postgres raw error: relation private.foo does not exist'),
      ),
    ).toBe('Tidak dapat masuk. Coba lagi.');
  });
});
