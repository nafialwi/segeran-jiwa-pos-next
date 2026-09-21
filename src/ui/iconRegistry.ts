export type SegeranIconStatus = 'APPROVED' | 'REVIEW';

export type SegeranIconName =
  | 'home'
  | 'point-of-sale'
  | 'activity'
  | 'notification'
  | 'settings'
  | 'warehouse'
  | 'product'
  | 'users'
  | 'account'
  | 'logout'
  | 'diagnostics'
  | 'security-sync'
  | 'backup-restore';

type SegeranIconDefinition = {
  status: SegeranIconStatus;
  outline: string;
  active?: string;
};

const BASE = '/icons/segeran-jiwa';

export const ICON_REGISTRY: Record<SegeranIconName, SegeranIconDefinition> = {
  home: {
    status: 'REVIEW',
    outline: `${BASE}/home-outline.png`,
    active: `${BASE}/home-active.png`,
  },
  'point-of-sale': {
    status: 'REVIEW',
    outline: `${BASE}/point-of-sale-outline.png`,
    active: `${BASE}/point-of-sale-active.png`,
  },
  activity: {
    status: 'APPROVED',
    outline: `${BASE}/activity.png`,
  },
  notification: {
    status: 'APPROVED',
    outline: `${BASE}/notification.png`,
  },
  settings: {
    status: 'REVIEW',
    outline: `${BASE}/settings-outline.png`,
    active: `${BASE}/settings-active.png`,
  },
  warehouse: {
    status: 'APPROVED',
    outline: `${BASE}/warehouse.png`,
  },
  product: {
    status: 'APPROVED',
    outline: `${BASE}/product.png`,
  },
  users: {
    status: 'APPROVED',
    outline: `${BASE}/users.png`,
  },
  account: {
    status: 'APPROVED',
    outline: `${BASE}/account.png`,
  },
  logout: {
    status: 'APPROVED',
    outline: `${BASE}/logout.png`,
  },
  diagnostics: {
    status: 'APPROVED',
    outline: `${BASE}/diagnostics.png`,
  },
  'security-sync': {
    status: 'APPROVED',
    outline: `${BASE}/security-sync.png`,
  },
  'backup-restore': {
    status: 'APPROVED',
    outline: `${BASE}/backup-restore.png`,
  },
};

export function resolveIconPath(name: SegeranIconName, active = false): string {
  const definition = ICON_REGISTRY[name];
  return active && definition.active ? definition.active : definition.outline;
}
