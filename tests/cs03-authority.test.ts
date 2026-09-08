import { describe, expect, it } from 'vitest';
import {
  mapAuthorityError,
  parseAuthoritySnapshot,
} from '../src/auth/authority';

describe('CS-03 authority payload', () => {
  it('rejects an incomplete authority object', () => {
    expect(() => parseAuthoritySnapshot({ owner: false })).toThrow(
      'SJ_AUTHORITY_PAYLOAD_INVALID',
    );
  });

  it('accepts a complete active Kasir snapshot', () => {
    const result = parseAuthoritySnapshot({
      profile_id: 'p',
      business_id: 'b',
      username: 'kasir1',
      display_name: 'Kasir 1',
      status: 'ACTIVE',
      role_code: 'KASIR',
      owner: false,
      permissions: ['SALE_EXECUTE'],
      session_id: 's',
      device_id: 'd',
      device_kind: 'SHARED',
    });

    expect(result.username).toBe('kasir1');
    expect(result.device_kind).toBe('SHARED');
  });

  it('rejects invalid status and permission payload shapes', () => {
    expect(() =>
      parseAuthoritySnapshot({
        profile_id: 'p',
        business_id: 'b',
        username: 'kasir1',
        display_name: 'Kasir 1',
        status: 'UNKNOWN',
        role_code: 'KASIR',
        owner: false,
        permissions: ['SALE_EXECUTE'],
        session_id: 's',
        device_id: 'd',
        device_kind: 'PERSONAL',
      }),
    ).toThrow('SJ_AUTHORITY_PAYLOAD_INVALID');

    expect(() =>
      parseAuthoritySnapshot({
        profile_id: 'p',
        business_id: 'b',
        username: 'kasir1',
        display_name: 'Kasir 1',
        status: 'ACTIVE',
        role_code: 'KASIR',
        owner: false,
        permissions: [123],
        session_id: 's',
        device_id: 'd',
        device_kind: 'PERSONAL',
      }),
    ).toThrow('SJ_AUTHORITY_PAYLOAD_INVALID');
  });

  it('maps revoked devices to a safe Indonesian message', () => {
    expect(mapAuthorityError({ message: 'SJ_DEVICE_REVOKED' }).message).toBe(
      'Akses perangkat ini telah dicabut oleh Owner.',
    );
  });

  it('maps inactive accounts to a safe Indonesian message', () => {
    expect(
      mapAuthorityError({ message: 'SJ_ACCOUNT_NOT_ACTIVE' }).message,
    ).toBe('Akun tidak sedang aktif. Hubungi Owner.');
  });

  it('maps unknown/network failures without exposing raw backend text', () => {
    const result = mapAuthorityError({
      message: 'connection refused postgres://internal-secret',
    });

    expect(result.message).toBe(
      'Tidak dapat memverifikasi akses. Sambungkan internet lalu coba lagi.',
    );
    expect(result.message).not.toContain('postgres');
  });
});
