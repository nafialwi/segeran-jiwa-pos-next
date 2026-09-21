import { hasAnyPermission, hasPermission } from '../auth/permission';
import type { AuthoritySnapshot } from '../auth/types';
import type { SegeranIconName } from '../ui/iconRegistry';

export type PrimaryNavigationId =
  'home' | 'sale' | 'history' | 'attention' | 'menu';

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

  items.push(
    {
      id: 'attention',
      label: 'Perhatian',
      to: '/perhatian',
      icon: 'notification',
    },
    { id: 'menu', label: 'Menu', to: '/menu', icon: 'settings' },
  );

  return items;
}

export function isPrimaryNavigationActive(
  item: PrimaryNavigationItem,
  pathname: string,
): boolean {
  if (item.id === 'home') return pathname === '/';
  if (item.id === 'sale') return pathname === '/jual';
  if (item.id === 'history') return pathname.startsWith('/riwayat');
  if (item.id === 'attention') return pathname.startsWith('/perhatian');

  const canonicalPrimary = ['/', '/jual', '/riwayat', '/perhatian'];
  return !canonicalPrimary.some((path) =>
    path === '/' ? pathname === '/' : pathname.startsWith(path),
  );
}
