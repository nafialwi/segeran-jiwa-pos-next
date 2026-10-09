import type { AuthoritySnapshot } from '../../../src/auth/types';
const cashier =
  new URLSearchParams(window.location.search).get('role') === 'kasir';
const authority: AuthoritySnapshot = {
  profile_id: 'fixture-profile',
  business_id: 'fixture-business',
  username: cashier ? 'kasir-demo' : 'owner-demo',
  display_name: cashier ? 'Kasir Contoh' : 'Owner Contoh',
  status: 'ACTIVE',
  role_code: cashier ? 'CASHIER' : 'OWNER',
  owner: !cashier,
  permissions: cashier
    ? ['SALE_EXECUTE', 'SHIFT_OPEN_CLOSE', 'SHIFT_READ_OWN', 'INVENTORY_READ']
    : [],
  session_id: 'fixture-session',
  device_id: 'fixture-device',
  device_kind: 'PERSONAL',
};
export function useAuth() {
  return {
    authority,
    state: { kind: 'authenticated' as const, authority },
    logout: async () => {},
    switchUser: async () => {},
    refreshAuthority: async () => {},
    retryVerification: async () => {},
    login: async () => {},
  };
}
