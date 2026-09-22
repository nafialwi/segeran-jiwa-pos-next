export type SegeranIconStatus = 'APPROVED' | 'REVIEW';

export type SegeranIconName =
  | 'home'
  | 'operations'
  | 'point-of-sale'
  | 'reports'
  | 'settings'
  | 'add'
  | 'barcode-scan'
  | 'cart'
  | 'cash-payment'
  | 'cash'
  | 'checkout'
  | 'credit-debt'
  | 'debt'
  | 'print'
  | 'qris'
  | 'receipt'
  | 'sales'
  | 'share'
  | 'subtract'
  | 'transfer'
  | 'whatsapp'
  | 'calendar'
  | 'camera'
  | 'check'
  | 'chevron-left'
  | 'chevron-right'
  | 'close'
  | 'filter'
  | 'help'
  | 'more'
  | 'notification'
  | 'profile'
  | 'refresh'
  | 'search'
  | 'inventory'
  | 'restock'
  | 'trend-down'
  | 'trend-up'
  | 'warning'
  | 'account'
  | 'active-device'
  | 'activity'
  | 'appearance'
  | 'backup-restore'
  | 'category'
  | 'customer'
  | 'diagnostics'
  | 'employee'
  | 'logout'
  | 'printer'
  | 'product'
  | 'security-sync'
  | 'sensitive-data'
  | 'store-identity'
  | 'users'
  | 'warehouse';

type SegeranIconDefinition = {
  status: SegeranIconStatus;
  outline: string;
  active?: string;
};

const BASE = '/icons/segeran-jiwa/locked';
const outline = (path: string): string => `${BASE}/outline/${path}.svg`;
const active = (path: string): string => `${BASE}/active/${path}.svg`;
const approved = (
  path: string,
  activePath?: string,
): SegeranIconDefinition => ({
  status: 'APPROVED',
  outline: outline(path),
  active: activePath ? active(activePath) : undefined,
});

export const ICON_REGISTRY: Record<SegeranIconName, SegeranIconDefinition> = {
  home: approved('navigation/home', 'navigation/home'),
  operations: approved('navigation/operations', 'navigation/operations'),
  'point-of-sale': approved(
    'navigation/point-of-sale',
    'navigation/point-of-sale',
  ),
  reports: approved('navigation/reports', 'navigation/reports'),
  settings: approved('navigation/settings', 'navigation/settings'),

  add: approved('commerce/add'),
  'barcode-scan': approved('commerce/barcode-scan'),
  cart: approved('commerce/cart'),
  'cash-payment': approved('commerce/cash-payment'),
  cash: approved('commerce/cash'),
  checkout: approved('commerce/checkout'),
  'credit-debt': approved('commerce/credit-debt'),
  debt: approved('commerce/debt'),
  print: approved('commerce/print'),
  qris: approved('commerce/qris'),
  receipt: approved('commerce/receipt'),
  sales: approved('commerce/sales'),
  share: approved('commerce/share'),
  subtract: approved('commerce/subtract'),
  transfer: approved('commerce/transfer'),
  whatsapp: approved('commerce/whatsapp'),

  calendar: approved('core/calendar'),
  camera: approved('core/camera'),
  check: approved('core/check'),
  'chevron-left': approved('core/chevron-left'),
  'chevron-right': approved('core/chevron-right'),
  close: approved('core/close'),
  filter: approved('core/filter'),
  help: approved('core/help'),
  more: approved('core/more'),
  notification: approved('core/notification'),
  profile: approved('core/profile'),
  refresh: approved('core/refresh'),
  search: approved('core/search'),

  inventory: approved('inventory/inventory'),
  restock: approved('inventory/restock'),

  'trend-down': approved('status/trend-down'),
  'trend-up': approved('status/trend-up'),
  warning: approved('status/warning'),

  account: approved('system/account'),
  'active-device': approved('system/active-device'),
  activity: approved('system/activity'),
  appearance: approved('system/appearance'),
  'backup-restore': approved('system/backup-restore'),
  category: approved('system/category'),
  customer: approved('system/customer'),
  diagnostics: approved('system/diagnostics'),
  employee: approved('system/employee'),
  logout: approved('system/logout'),
  printer: approved('system/printer'),
  product: approved('system/product'),
  'security-sync': approved('system/security-sync'),
  'sensitive-data': approved('system/sensitive-data'),
  'store-identity': approved('system/store-identity'),
  users: approved('system/users'),
  warehouse: approved('system/warehouse'),
};

export function resolveIconPath(
  name: SegeranIconName,
  activeState = false,
): string {
  const definition = ICON_REGISTRY[name];
  return activeState && definition.active
    ? definition.active
    : definition.outline;
}
