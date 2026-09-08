import { describe, expect, it } from 'vitest';
import {
  canAccessOwnerArea,
  canAccessRoute,
  hasPermission,
} from '../src/auth/permission';
import type { AuthoritySnapshot } from '../src/auth/types';

function authority(
  overrides: Partial<AuthoritySnapshot> = {},
): AuthoritySnapshot {
  return {
    profile_id: 'profile',
    business_id: 'business',
    username: 'kasir1',
    display_name: 'Kasir 1',
    status: 'ACTIVE',
    role_code: 'KASIR',
    owner: false,
    permissions: ['SALE_EXECUTE', 'SHIFT_OPEN_CLOSE', 'SHIFT_READ_OWN'],
    session_id: 'session',
    device_id: 'device',
    device_kind: 'PERSONAL',
    ...overrides,
  };
}

describe('CS-03 permission projection', () => {
  it('allows an active user only when the permission is in current authority', () => {
    const current = authority();
    expect(hasPermission(current, 'SALE_EXECUTE')).toBe(true);
    expect(hasPermission(current, 'INVENTORY_READ')).toBe(false);
  });

  it('denies permission projection for non-active status', () => {
    const onLeave = authority({ status: 'LEAVE' });
    expect(hasPermission(onLeave, 'SALE_EXECUTE')).toBe(false);
  });

  it('keeps Owner area behind the immutable Owner boundary', () => {
    const owner = authority({
      username: 'owner1',
      role_code: 'OWNER',
      owner: true,
    });
    expect(canAccessOwnerArea(owner)).toBe(true);
    expect(canAccessOwnerArea(authority())).toBe(false);
    expect(
      canAccessOwnerArea(
        owner && authority({ owner: true, status: 'DISABLED' }),
      ),
    ).toBe(false);
  });
});

describe('CS-03 route access policy', () => {
  it('projects the same authority into route access', () => {
    const kasir = authority();
    const owner = authority({
      username: 'owner1',
      role_code: 'OWNER',
      owner: true,
    });

    expect(canAccessRoute(kasir, '/jual')).toBe(true);
    expect(canAccessRoute(kasir, '/pengguna')).toBe(false);
    expect(canAccessRoute(owner, '/pengguna')).toBe(true);
    expect(canAccessRoute(kasir, '/keuangan')).toBe(false);
  });
});
