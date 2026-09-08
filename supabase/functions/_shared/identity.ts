import { SafeHttpError } from './http.ts';

const USERNAME_RE = /^[a-z0-9][a-z0-9_-]{2,31}$/;
const INTERNAL_AUTH_DOMAIN = 'auth.segeranjiwa.invalid';

export function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase();
}

export function toInternalAuthEmail(raw: string): string {
  const normalized = normalizeUsername(raw);
  if (!USERNAME_RE.test(normalized)) {
    throw new SafeHttpError(
      'SJ_USERNAME_INVALID',
      'Username tidak valid.',
      400,
    );
  }

  return `${normalized}@${INTERNAL_AUTH_DOMAIN}`;
}

export function validateStaffPassword(password: unknown): string {
  if (
    typeof password !== 'string' ||
    password.length < 8 ||
    password.length > 72
  ) {
    throw new SafeHttpError(
      'SJ_PASSWORD_INVALID',
      'Password harus 8–72 karakter.',
      400,
    );
  }

  return password;
}
