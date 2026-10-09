import type { FinanceOverview } from '../../../src/finance/finance-api';

const base: FinanceOverview = {
  accounts: [
    {
      id: 'fixture-kasutama',
      code: 'KAS_UTAMA',
      display_name: 'Kas Utama',
      account_type: 'CASH',
      balance: 3500000,
    },
    {
      id: 'fixture-kasshift',
      code: 'KAS_SHIFT',
      display_name: 'Kas Shift',
      account_type: 'CASH',
      balance: 850000,
    },
    {
      id: 'fixture-bank',
      code: 'BANK',
      display_name: 'Bank',
      account_type: 'BANK',
      balance: 12300000,
    },
    {
      id: 'fixture-qris',
      code: 'QRIS_UNSETTLED',
      display_name: 'QRIS Belum Cair',
      account_type: 'CLEARING',
      balance: 245000,
    },
  ],
  customerDebts: [
    {
      debt_id: 'fixture-debt',
      customer_name: 'Pelanggan Contoh',
      original_amount: 220000,
      paid_amount: 100000,
      balance: 120000,
      status: 'OPEN',
      created_at: '2026-10-09T08:00:00+07:00',
    },
  ],
  supplierPayables: [
    {
      payable_id: 'fixture-payable',
      supplier_name: 'Pemasok Contoh',
      invoice_reference: 'CONTOH/INV/01',
      original_amount: 450000,
      paid_amount: 100000,
      balance: 350000,
      status: 'OPEN',
      created_at: '2026-10-09T08:00:00+07:00',
    },
  ],
  employeeKasbons: [
    {
      kasbon_id: 'fixture-kasbon',
      employee_profile_id: 'fixture-employee',
      employee_name: 'Staf Contoh',
      original_amount: 75000,
      paid_amount: 0,
      balance: 75000,
      status: 'OPEN',
      note: 'Contoh',
      created_at: '2026-10-09T08:00:00+07:00',
    },
  ],
  employees: [
    {
      profile_id: 'fixture-employee',
      username: 'staf-contoh',
      display_name: 'Staf Contoh',
      status: 'ACTIVE',
      role_code: 'CASHIER',
    },
  ],
  reconciliations: [],
  qrisSettlements: [],
};
export async function fetchFinanceOverview(): Promise<FinanceOverview> {
  return structuredClone(base);
}
const disabled = async (): Promise<never> => {
  throw new Error('Fixture visual: operasi uang dinonaktifkan');
};
export const createEmployeeKasbon = disabled;
export const payCustomerDebt = disabled;
export const paySupplierPayable = disabled;
export const postFinanceTransfer = disabled;
export const postOwnerCapital = disabled;
export const postOwnerPersonalWithdrawal = disabled;
export const reconcileFinanceDay = disabled;
export const settleQris = disabled;
