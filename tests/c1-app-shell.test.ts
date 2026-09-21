import { describe, expect, it } from 'vitest';
import type { AuthoritySnapshot } from '../src/auth/types';
import {
  getPrimaryNavigation,
  isPrimaryNavigationActive,
} from '../src/navigation/appNavigation';
import { ICON_REGISTRY, resolveIconPath } from '../src/ui/iconRegistry';

function authority(
  overrides: Partial<AuthoritySnapshot> = {},
): AuthoritySnapshot {
  return {
    profile_id: 'profile-1',
    business_id: 'business-1',
    username: 'kasir',
    display_name: 'Kasir',
    status: 'ACTIVE',
    role_code: 'CASHIER',
    owner: false,
    permissions: [],
    session_id: 'session-1',
    device_id: 'device-1',
    device_kind: 'PERSONAL',
    ...overrides,
  };
}

describe('C1 app shell navigation', () => {
  it('keeps canonical mobile order for an authorized operator', () => {
    const items = getPrimaryNavigation(
      authority({
        permissions: ['SALE_EXECUTE', 'HISTORY_OWN'],
      }),
    );

    expect(items.map((item) => item.label)).toEqual([
      'Beranda',
      'Jual',
      'Riwayat',
      'Perhatian',
      'Menu',
    ]);
  });

  it('does not expose permission-gated primary entries to a restricted user', () => {
    const items = getPrimaryNavigation(authority());

    expect(items.map((item) => item.label)).toEqual([
      'Beranda',
      'Perhatian',
      'Menu',
    ]);
  });

  it('routes secondary modules through Menu active state', () => {
    const items = getPrimaryNavigation(
      authority({
        permissions: ['SALE_EXECUTE', 'HISTORY_OWN'],
      }),
    );
    const menu = items.find((item) => item.id === 'menu');
    const sale = items.find((item) => item.id === 'sale');

    expect(menu).toBeDefined();
    expect(sale).toBeDefined();
    expect(isPrimaryNavigationActive(menu!, '/keuangan')).toBe(true);
    expect(isPrimaryNavigationActive(menu!, '/stok')).toBe(true);
    expect(isPrimaryNavigationActive(sale!, '/jual')).toBe(true);
    expect(isPrimaryNavigationActive(menu!, '/jual')).toBe(false);
  });
});

describe('C1 icon authority', () => {
  it('keeps approved semantic icons separate from review navigation icons', () => {
    expect(ICON_REGISTRY.notification.status).toBe('APPROVED');
    expect(ICON_REGISTRY.activity.status).toBe('APPROVED');
    expect(ICON_REGISTRY.home.status).toBe('REVIEW');
    expect(ICON_REGISTRY['point-of-sale'].status).toBe('REVIEW');
    expect(ICON_REGISTRY.settings.status).toBe('REVIEW');
  });

  it('resolves active navigation variants without changing semantic icon paths', () => {
    expect(resolveIconPath('home', true)).toContain('home-active.png');
    expect(resolveIconPath('home', false)).toContain('home-outline.png');
    expect(resolveIconPath('activity', true)).toContain('activity.png');
  });
});
