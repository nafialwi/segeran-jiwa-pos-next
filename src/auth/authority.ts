import type { DeviceKind } from './device';
import type { AuthoritySnapshot, ProfileStatus } from './types';

async function getSupabase() {
  const { supabase } = await import('../lib/supabase');
  return supabase;
}

type AuthorityErrorLike = {
  message?: unknown;
  code?: unknown;
};

const ACTIVE_STATUSES: ProfileStatus[] = ['ACTIVE', 'LEAVE', 'DISABLED'];
const DEVICE_KINDS: DeviceKind[] = ['PERSONAL', 'SHARED'];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0;
}

export function parseAuthoritySnapshot(value: unknown): AuthoritySnapshot {
  if (!isRecord(value)) {
    throw new Error('SJ_AUTHORITY_PAYLOAD_INVALID');
  }

  const permissions = value.permissions;
  const status = value.status;
  const deviceKind = value.device_kind;

  if (
    !isNonEmptyString(value.profile_id) ||
    !isNonEmptyString(value.business_id) ||
    !isNonEmptyString(value.username) ||
    !isNonEmptyString(value.display_name) ||
    !isNonEmptyString(value.role_code) ||
    typeof value.owner !== 'boolean' ||
    !Array.isArray(permissions) ||
    !permissions.every(isNonEmptyString) ||
    !isNonEmptyString(value.session_id) ||
    !isNonEmptyString(value.device_id) ||
    typeof status !== 'string' ||
    !ACTIVE_STATUSES.includes(status as ProfileStatus) ||
    typeof deviceKind !== 'string' ||
    !DEVICE_KINDS.includes(deviceKind as DeviceKind)
  ) {
    throw new Error('SJ_AUTHORITY_PAYLOAD_INVALID');
  }

  return {
    profile_id: value.profile_id,
    business_id: value.business_id,
    username: value.username,
    display_name: value.display_name,
    status: status as ProfileStatus,
    role_code: value.role_code,
    owner: value.owner,
    permissions: [...permissions],
    session_id: value.session_id,
    device_id: value.device_id,
    device_kind: deviceKind as DeviceKind,
  };
}

function authorityErrorToken(error: unknown): string {
  if (!isRecord(error)) return '';
  const candidate = error as AuthorityErrorLike;
  const message =
    typeof candidate.message === 'string' ? candidate.message : '';
  const code = typeof candidate.code === 'string' ? candidate.code : '';
  return `${code} ${message}`;
}

export function mapAuthorityError(error: unknown): Error {
  const token = authorityErrorToken(error);

  if (
    token.includes('SJ_ACCOUNT_NOT_ACTIVE') ||
    token.includes('SJ_PROFILE_NOT_BOUND')
  ) {
    return new Error('Akun tidak sedang aktif. Hubungi Owner.');
  }

  if (token.includes('SJ_DEVICE_REVOKED')) {
    return new Error('Akses perangkat ini telah dicabut oleh Owner.');
  }

  if (token.includes('SJ_DEVICE_RETIRED')) {
    return new Error('Perangkat ini sudah tidak aktif. Hubungi Owner.');
  }

  if (
    token.includes('SJ_AUTH_SESSION_INVALID') ||
    token.includes('SJ_AUTHORITY_DENIED')
  ) {
    return new Error('Sesi masuk sudah tidak berlaku. Silakan masuk kembali.');
  }

  return new Error(
    'Tidak dapat memverifikasi akses. Sambungkan internet lalu coba lagi.',
  );
}

export async function bootstrapAuthority(input: {
  deviceId: string;
  deviceKind: DeviceKind;
  friendlyName: string;
  platformLabel: string;
}): Promise<AuthoritySnapshot> {
  const supabase = await getSupabase();
  const { data, error } = await supabase.rpc('bootstrap_current_session', {
    p_device_id: input.deviceId,
    p_device_kind: input.deviceKind,
    p_friendly_name: input.friendlyName,
    p_platform_label: input.platformLabel,
  });

  if (error) throw mapAuthorityError(error);
  return parseAuthoritySnapshot(data);
}

export async function loadAuthority(): Promise<AuthoritySnapshot> {
  const supabase = await getSupabase();
  const { data, error } = await supabase.rpc('get_my_authority');

  if (error) throw mapAuthorityError(error);
  return parseAuthoritySnapshot(data);
}
