const USERNAME_RE = /^[a-z0-9][a-z0-9_-]{2,31}$/;
const INTERNAL_AUTH_DOMAIN = 'auth.segeranjiwa.invalid';

export type UsernameValidation =
  | { ok: true; normalized: string }
  | { ok: false; normalized: string; message: string };

export function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase();
}

export function validateUsername(raw: string): UsernameValidation {
  const normalized = normalizeUsername(raw);
  if (!USERNAME_RE.test(normalized)) {
    return {
      ok: false,
      normalized,
      message:
        'Username harus 3–32 karakter dan hanya memakai huruf, angka, _ atau -.',
    };
  }
  return { ok: true, normalized };
}

export function toInternalAuthEmail(raw: string): string {
  const result = validateUsername(raw);
  if (!result.ok) throw new Error('SJ_USERNAME_INVALID');
  return `${result.normalized}@${INTERNAL_AUTH_DOMAIN}`;
}
