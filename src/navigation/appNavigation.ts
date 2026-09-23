import { hasAnyPermission, hasPermission } from '../auth/permission';
import type { AuthoritySnapshot } from '../auth/types';
import type { SegeranIconName } from '../ui/iconRegistry';

export type PrimaryNavigationId =
  'home' | 'sale' | 'history' | 'reports' | 'menu';

export type PrimaryNavigationItem = {
  id: PrimaryNavigationId;
  label: string;
  to: string;
  icon: SegeranIconName;
};

export function getPrimaryNavigation(
  authority: AuthoritySnapshot,
): PrimaryNavigationItem[] {
  const items: PrimaryNavigationItem[] = [
    { id: 'home', label: 'Beranda', to: '/', icon: 'home' },
  ];

  if (hasPermission(authority, 'SALE_EXECUTE')) {
    items.push({
      id: 'sale',
      label: 'Jual',
      to: '/jual',
      icon: 'point-of-sale',
    });
  }

  if (hasAnyPermission(authority, ['HISTORY_OWN', 'HISTORY_ALL'])) {
    items.push({
      id: 'history',
      label: 'Riwayat',
      to: '/riwayat',
      icon: 'activity',
    });
  }

  if (
    hasAnyPermission(authority, [
      'REPORT_SALES_LIMITED',
      'REPORT_INVENTORY',
      'REPORT_PURCHASE',
    ])
  ) {
    items.push({
      id: 'reports',
      label: 'Laporan',
      to: '/laporan',
      icon: 'reports',
    });
  }

  items.push({ id: 'menu', label: 'Menu', to: '/menu', icon: 'settings' });

  return items;
}

export function isPrimaryNavigationActive(
  item: PrimaryNavigationItem,
  pathname: string,
): boolean {
  if (item.id === 'home') return pathname === '/';
  if (item.id === 'sale') return pathname === '/jual';
  if (item.id === 'history') return pathname.startsWith('/riwayat');
  if (item.id === 'reports') return pathname.startsWith('/laporan');

  const canonicalPrimary = ['/', '/jual', '/riwayat', '/laporan'];
  return !canonicalPrimary.some((path) =>
    path === '/' ? pathname === '/' : pathname.startsWith(path),
  );
}
