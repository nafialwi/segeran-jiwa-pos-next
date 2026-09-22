import type { AuthoritySnapshot, PermissionCode } from './types';

export function hasPermission(
  authority: AuthoritySnapshot,
  code: PermissionCode,
): boolean {
  return (
    authority.status === 'ACTIVE' &&
    (authority.owner || authority.permissions.includes(code))
  );
}

export function hasAnyPermission(
  authority: AuthoritySnapshot,
  codes: PermissionCode[],
): boolean {
  return codes.some((code) => hasPermission(authority, code));
}

export function canAccessOwnerArea(authority: AuthoritySnapshot): boolean {
  return authority.status === 'ACTIVE' && authority.owner;
}

export function canAccessRoute(
  authority: AuthoritySnapshot,
  route: string,
): boolean {
  if (
    route === '/pengguna' ||
    route === '/keuangan' ||
    route === '/pengaturan/backup'
  ) {
    return canAccessOwnerArea(authority);
  }
  if (route === '/pengaturan' || route === '/pengaturan/tampilan') {
    return hasPermission(authority, 'SETTINGS_NONCRITICAL');
  }
  if (
    route === '/pengaturan/kesehatan' ||
    route === '/pengaturan/offline-sync' ||
    route === '/pengaturan/diagnostik'
  ) {
    return authority.status === 'ACTIVE';
  }
  if (route === '/riwayat') {
    return hasAnyPermission(authority, ['HISTORY_OWN', 'HISTORY_ALL']);
  }
  if (route === '/laporan') {
    return hasAnyPermission(authority, [
      'REPORT_SALES_LIMITED',
      'REPORT_INVENTORY',
      'REPORT_PURCHASE',
    ]);
  }
  if (route === '/jual') return hasPermission(authority, 'SALE_EXECUTE');
  if (route === '/stok/kontrol') {
    return hasAnyPermission(authority, [
      'INVENTORY_REQUEST',
      'INVENTORY_TRANSFER',
      'INVENTORY_COUNT',
      'INVENTORY_ADJUST',
    ]);
  }
  if (route === '/stok' || route.startsWith('/stok/')) {
    return hasPermission(authority, 'INVENTORY_READ');
  }
  if (route === '/produk') {
    return hasAnyPermission(authority, ['INVENTORY_READ', 'PRODUCTION_MANAGE']);
  }
  if (route === '/pembelian') {
    return hasPermission(authority, 'PURCHASE_MANAGE');
  }
  if (route === '/produksi') {
    return hasPermission(authority, 'PRODUCTION_MANAGE');
  }
  if (route === '/shift' || route === '/handover') {
    return hasPermission(authority, 'SHIFT_OPEN_CLOSE');
  }
  if (route === '/shift-history' || route === '/rekonsiliasi') {
    return hasPermission(authority, 'SHIFT_READ_OWN');
  }
  return authority.status === 'ACTIVE';
}
