import type { Shift, Reconciliation } from '../../../src/shift/shift-core';
import type {
  ShiftPackagingReconciliation,
  LocationOption,
} from '../../../src/shift/shift-api';

const fixtureShift: Shift = {
  id: 'fixture-shift',
  business_id: 'fixture-business',
  location_id: 'fixture-gerai',
  cashier_profile_id: 'fixture-profile',
  opened_at: '2026-10-09T08:00:00+07:00',
  closed_at: null,
  opening_balance: 150000,
  closing_balance: null,
  status: 'OPEN',
  config_snapshot: {},
  expected_cash: 865000,
  actual_cash: null,
  variance: null,
};
const reconciliation: Reconciliation = {
  shift_id: 'fixture-shift',
  opening_balance: 150000,
  sale_total: 765000,
  refund_total: 0,
  cash_in_total: 0,
  cash_out_total: 50000,
  adjustment_total: 0,
  expected_cash: 865000,
  actual_cash: null,
  variance: null,
};
export async function fetchMyOpenShift(): Promise<Shift> {
  return structuredClone(fixtureShift);
}
export async function fetchLocations(): Promise<LocationOption[]> {
  return [{ id: 'fixture-gerai', label: 'Gerai Contoh' }];
}
export async function fetchShiftExpenses() {
  return [];
}
export async function fetchShiftExpenseApprovals() {
  return [];
}
export async function fetchShiftReconciliation(): Promise<Reconciliation> {
  return structuredClone(reconciliation);
}
export async function fetchShiftPackagingReconciliation(): Promise<ShiftPackagingReconciliation> {
  return {
    ready: false,
    shiftId: 'fixture-shift',
    shiftStatus: 'OPEN',
    locationId: 'fixture-gerai',
    hasSales: true,
    openingTooLate: false,
    openingCount: null,
    closingCount: null,
    items: [],
  };
}
const disabled = async (): Promise<never> => {
  throw new Error('Fixture visual: perubahan shift dinonaktifkan');
};
export const openShift = disabled;
export const closeShift = disabled;
export const postShiftExpense = disabled;
export const createShiftPackagingCount = disabled;
