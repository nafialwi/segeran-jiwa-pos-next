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
        permissions: ['SALE_EXECUTE', 'HISTORY_OWN', 'REPORT_SALES_LIMITED'],
      }),
    );

    expect(items.map((item) => item.label)).toEqual([
      'Beranda',
      'Jual',
      'Riwayat',
      'Laporan',
      'Menu',
    ]);
  });

  it('does not expose permission-gated primary entries to a restricted user', () => {
    const items = getPrimaryNavigation(authority());

    expect(items.map((item) => item.label)).toEqual(['Beranda', 'Menu']);
  });

  it('routes secondary modules through Menu active state', () => {
    const items = getPrimaryNavigation(
      authority({
        permissions: ['SALE_EXECUTE', 'HISTORY_OWN', 'REPORT_SALES_LIMITED'],
      }),
    );
    const menu = items.find((item) => item.id === 'menu');
    const sale = items.find((item) => item.id === 'sale');
    const reports = items.find((item) => item.id === 'reports');

    expect(menu).toBeDefined();
    expect(sale).toBeDefined();
    expect(reports).toBeDefined();
    expect(isPrimaryNavigationActive(menu!, '/keuangan')).toBe(true);
    expect(isPrimaryNavigationActive(menu!, '/stok')).toBe(true);
    expect(isPrimaryNavigationActive(menu!, '/perhatian')).toBe(true);
    expect(isPrimaryNavigationActive(sale!, '/jual')).toBe(true);
    expect(isPrimaryNavigationActive(reports!, '/laporan')).toBe(true);
    expect(isPrimaryNavigationActive(menu!, '/laporan')).toBe(false);
    expect(isPrimaryNavigationActive(menu!, '/jual')).toBe(false);
  });
});

describe('C11 icon authority', () => {
  it('uses the locked Legacy production SVG family as the canonical icon source', () => {
    expect(ICON_REGISTRY.notification.status).toBe('APPROVED');
    expect(ICON_REGISTRY.reports.status).toBe('APPROVED');
    expect(ICON_REGISTRY.activity.status).toBe('APPROVED');
    expect(ICON_REGISTRY.home.status).toBe('APPROVED');
    expect(ICON_REGISTRY['point-of-sale'].status).toBe('APPROVED');
    expect(ICON_REGISTRY.settings.status).toBe('APPROVED');
    expect(ICON_REGISTRY.cart.status).toBe('APPROVED');
    expect(ICON_REGISTRY.qris.status).toBe('APPROVED');
    expect(ICON_REGISTRY.inventory.status).toBe('APPROVED');
  });

  it('resolves canonical SVG navigation variants without raster fallback', () => {
    expect(resolveIconPath('home', true)).toContain(
      '/locked/active/navigation/home.svg',
    );
    expect(resolveIconPath('home', false)).toContain(
      '/locked/outline/navigation/home.svg',
    );
    expect(resolveIconPath('activity', true)).toContain(
      '/locked/outline/system/activity.svg',
    );
    expect(resolveIconPath('cart')).toContain(
      '/locked/outline/commerce/cart.svg',
    );
  });
});
