import { normalizeUsername } from './username';

const DEVICE_KEY = 'sjpos.device_id.v1';
const DEVICE_KIND_KEY = 'sjpos.device_kind.v1';
const REMEMBERED_USERS_KEY = 'sjpos.remembered_users.v1';

export type DeviceKind = 'PERSONAL' | 'SHARED';

export function getOrCreateDeviceId(storage: Storage): string {
  const existing = storage.getItem(DEVICE_KEY);
  if (existing) return existing;
  const id = crypto.randomUUID();
  storage.setItem(DEVICE_KEY, id);
  return id;
}

export function getDeviceKind(storage: Storage): DeviceKind {
  return storage.getItem(DEVICE_KIND_KEY) === 'SHARED' ? 'SHARED' : 'PERSONAL';
}

export function setDeviceKind(storage: Storage, kind: DeviceKind): void {
  storage.setItem(DEVICE_KIND_KEY, kind);
}

export function rememberUsername(storage: Storage, username: string): void {
  const normalized = normalizeUsername(username);
  const current = getRememberedUsernames(storage);
  const next = [
    normalized,
    ...current.filter((item) => item !== normalized),
  ].slice(0, 8);
  storage.setItem(REMEMBERED_USERS_KEY, JSON.stringify(next));
}

export function getRememberedUsernames(storage: Storage): string[] {
  try {
    const parsed = JSON.parse(storage.getItem(REMEMBERED_USERS_KEY) ?? '[]');
    return Array.isArray(parsed)
      ? parsed
          .filter((item): item is string => typeof item === 'string')
          .slice(0, 8)
      : [];
  } catch {
    return [];
  }
}
