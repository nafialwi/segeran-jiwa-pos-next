import type { DeviceKind } from './device';

export type ProfileStatus = 'ACTIVE' | 'LEAVE' | 'DISABLED';

export interface AuthoritySnapshot {
  profile_id: string;
  business_id: string;
  username: string;
  display_name: string;
  status: ProfileStatus;
  role_code: string;
  owner: boolean;
  permissions: string[];
  session_id: string;
  device_id: string;
  device_kind: DeviceKind;
}

export type PermissionCode =
  | 'SALE_EXECUTE'
  | 'SHIFT_OPEN_CLOSE'
  | 'SHIFT_READ_OWN'
  | 'EXPENSE_SHIFT_CREATE'
  | 'INVENTORY_READ'
  | 'PAYMENT_QRIS'
  | 'PAYMENT_TRANSFER'
  | 'CUSTOMER_DEBT_MANAGE'
  | 'INVENTORY_TRANSFER'
  | 'PURCHASE_MANAGE'
  | 'PRODUCTION_MANAGE'
  | 'CUSTOMER_MANAGE'
  | 'EMPLOYEE_MANAGE'
  | 'CORRECTION_LIMITED'
  | 'REPORT_SALES_LIMITED'
  | 'REPORT_INVENTORY'
  | 'REPORT_PURCHASE'
  | 'REPORT_PRODUCTION'
  | 'SETTINGS_NONCRITICAL';
