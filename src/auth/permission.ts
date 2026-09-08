import type { AuthoritySnapshot, PermissionCode } from './types';

export function hasPermission(
  authority: AuthoritySnapshot,
  code: PermissionCode,
): boolean {
  return authority.status === 'ACTIVE' && authority.permissions.includes(code);
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
  if (route === '/jual') return hasPermission(authority, 'SALE_EXECUTE');
  return authority.status === 'ACTIVE';
}
