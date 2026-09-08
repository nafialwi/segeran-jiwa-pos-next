const BAD_CREDENTIAL_CODES = new Set([
  'SJ_USERNAME_INVALID',
  'SJ_LOGIN_INVALID',
]);

const SAFE_AUTHORITY_MESSAGES = new Set([
  'Akses perangkat ini telah dicabut oleh Owner.',
  'Akun tidak sedang aktif. Hubungi Owner.',
  'Tidak dapat memverifikasi akses. Sambungkan internet lalu coba lagi.',
]);

export function toLoginErrorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : '';

  if (BAD_CREDENTIAL_CODES.has(message)) {
    return 'Username atau password salah.';
  }

  if (SAFE_AUTHORITY_MESSAGES.has(message)) {
    return message;
  }

  return 'Tidak dapat masuk. Coba lagi.';
}
