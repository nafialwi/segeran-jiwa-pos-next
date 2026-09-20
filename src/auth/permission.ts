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
  if (route === '/pengguna' || route === '/keuangan') {
    return canAccessOwnerArea(authority);
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
  return authority.status === 'ACTIVE';
}
