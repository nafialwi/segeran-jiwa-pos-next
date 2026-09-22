import { supabase } from '../lib/supabase';
import { requireOnlineAction } from '../health/online-action';

export type FinanceAccount = {
  id: string;
  code: string;
  display_name: string;
  account_type: string;
  balance: number;
};

export type CustomerDebtBalance = {
  debt_id: string;
  customer_name: string;
  original_amount: number;
  paid_amount: number;
  balance: number;
  status: string;
  created_at: string;
};

export type SupplierPayableBalance = {
  payable_id: string;
  supplier_name: string;
  invoice_reference: string | null;
  original_amount: number;
  paid_amount: number;
  balance: number;
  status: string;
  created_at: string;
};

export type EmployeeKasbonBalance = {
  kasbon_id: string;
  employee_profile_id: string;
  employee_name: string;
  original_amount: number;
  paid_amount: number;
  balance: number;
  status: string;
  note: string | null;
  created_at: string;
};

export type FinanceEmployee = {
  profile_id: string;
  username: string;
  display_name: string;
  status: string;
  role_code: string;
};

export type FinanceDailyReconciliation = {
  id: string;
  business_date: string;
  expected_cash: number;
  counted_cash: number;
  cash_variance: number;
  qris_recorded: number;
  qris_settled: number;
  qris_variance: number;
  transfer_recorded: number;
  transfer_received: number;
  transfer_variance: number;
  stock_status: string;
  result: string;
  created_at: string;
};

export type QrisSettlement = {
  id: string;
  settlement_date: string;
  provider_reference: string;
  gross_amount: number;
  provider_fee: number;
  net_amount: number;
  created_at: string;
};

export type FinanceOverview = {
  accounts: FinanceAccount[];
  customerDebts: CustomerDebtBalance[];
  supplierPayables: SupplierPayableBalance[];
  employeeKasbons: EmployeeKasbonBalance[];
  employees: FinanceEmployee[];
  reconciliations: FinanceDailyReconciliation[];
  qrisSettlements: QrisSettlement[];
};

function fail(error: { message?: string; code?: string } | null): never {
  throw new Error(error?.message || error?.code || 'SJ_FINANCE_UNKNOWN');
}

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export async function fetchFinanceOverview(): Promise<FinanceOverview> {
  const { data, error } = await supabase.rpc('finance_owner_overview');
  if (error) fail(error);

  const raw = (data ?? {}) as Record<string, unknown>;

  const accounts = ((raw.accounts ?? []) as Array<Record<string, unknown>>).map(
    (row) => ({
      id: String(row.id),
      code: String(row.code),
      display_name: String(row.display_name),
      account_type: String(row.account_type),
      balance: num(row.balance),
    }),
  ) as FinanceAccount[];

  return {
    accounts,
    customerDebts: (
      (raw.customerDebts ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      debt_id: String(row.debt_id),
      customer_name: String(row.customer_name),
      original_amount: num(row.original_amount),
      paid_amount: num(row.paid_amount),
      balance: num(row.balance),
      status: String(row.status),
      created_at: String(row.created_at),
    })) as CustomerDebtBalance[],
    supplierPayables: (
      (raw.supplierPayables ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      payable_id: String(row.payable_id),
      supplier_name: String(row.supplier_name),
      invoice_reference:
        row.invoice_reference === null || row.invoice_reference === undefined
          ? null
          : String(row.invoice_reference),
      original_amount: num(row.original_amount),
      paid_amount: num(row.paid_amount),
      balance: num(row.balance),
      status: String(row.status),
      created_at: String(row.created_at),
    })) as SupplierPayableBalance[],
    employeeKasbons: (
      (raw.employeeKasbons ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      kasbon_id: String(row.kasbon_id),
      employee_profile_id: String(row.employee_profile_id),
      employee_name: String(row.employee_name),
      original_amount: num(row.original_amount),
      paid_amount: num(row.paid_amount),
      balance: num(row.balance),
      status: String(row.status),
      note:
        row.note === null || row.note === undefined ? null : String(row.note),
      created_at: String(row.created_at),
    })) as EmployeeKasbonBalance[],
    employees: ((raw.employees ?? []) as FinanceEmployee[]).filter(
      (row) => row.status === 'ACTIVE',
    ),
    reconciliations: (
      (raw.reconciliations ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      id: String(row.id),
      business_date: String(row.business_date),
      expected_cash: num(row.expected_cash),
      counted_cash: num(row.counted_cash),
      cash_variance: num(row.cash_variance),
      qris_recorded: num(row.qris_recorded),
      qris_settled: num(row.qris_settled),
      qris_variance: num(row.qris_variance),
      transfer_recorded: num(row.transfer_recorded),
      transfer_received: num(row.transfer_received),
      transfer_variance: num(row.transfer_variance),
      stock_status: String(row.stock_status),
      result: String(row.result),
      created_at: String(row.created_at),
    })) as FinanceDailyReconciliation[],
    qrisSettlements: (
      (raw.qrisSettlements ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      id: String(row.id),
      settlement_date: String(row.settlement_date),
      provider_reference: String(row.provider_reference),
      gross_amount: num(row.gross_amount),
      provider_fee: num(row.provider_fee),
      net_amount: num(row.net_amount),
      created_at: String(row.created_at),
    })) as QrisSettlement[],
  };
}

export async function postFinanceTransfer(args: {
  fromAccountId: string;
  toAccountId: string;
  amount: number;
  reason: string;
}) {
  requireOnlineAction('Transfer keuangan');
  const { data, error } = await supabase.rpc('finance_post_transfer', {
    p_from_account_id: args.fromAccountId,
    p_to_account_id: args.toAccountId,
    p_amount: args.amount,
    p_reason_code: args.reason,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return String(data);
}

export async function postOwnerCapital(args: {
  toAccountId: string;
  amount: number;
  reason: string;
}) {
  requireOnlineAction('Setoran modal');
  const { data, error } = await supabase.rpc('finance_post_owner_capital', {
    p_to_account_id: args.toAccountId,
    p_amount: args.amount,
    p_reason_code: args.reason,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return String(data);
}

export async function postOwnerPersonalWithdrawal(args: {
  fromAccountId: string;
  amount: number;
  reason: string;
}) {
  requireOnlineAction('Pengambilan pribadi');
  const { data, error } = await supabase.rpc(
    'finance_post_owner_personal_withdrawal',
    {
      p_from_account_id: args.fromAccountId,
      p_amount: args.amount,
      p_reason_code: args.reason,
      p_idempotency_key: crypto.randomUUID(),
    },
  );
  if (error) fail(error);
  return String(data);
}

export async function settleQris(args: {
  settlementDate: string;
  providerReference: string;
  grossAmount: number;
  providerFee: number;
}) {
  requireOnlineAction('Settlement QRIS');
  const { data, error } = await supabase.rpc('finance_settle_qris', {
    p_settlement_date: args.settlementDate,
    p_provider_reference: args.providerReference,
    p_gross_amount: args.grossAmount,
    p_provider_fee: args.providerFee,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return String(data);
}

export async function reconcileFinanceDay(args: {
  businessDate: string;
  countedCash: number;
  bankTransferReceived: number;
  stockStatus: 'SESUAI' | 'PERLU_DIPERIKSA' | 'NOT_CHECKED';
}) {
  requireOnlineAction('Rekonsiliasi harian');
  const { data, error } = await supabase.rpc('finance_reconcile_day', {
    p_business_date: args.businessDate,
    p_counted_cash: args.countedCash,
    p_bank_transfer_received: args.bankTransferReceived,
    p_stock_status: args.stockStatus,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return String(data);
}

export async function payCustomerDebt(args: {
  debtId: string;
  method: 'CASH' | 'TRANSFER';
  amount: number;
}) {
  requireOnlineAction('Pembayaran hutang pelanggan');
  const { data, error } = await supabase.rpc('finance_pay_customer_debt', {
    p_debt_id: args.debtId,
    p_method: args.method,
    p_amount: args.amount,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data;
}

export async function paySupplierPayable(args: {
  payableId: string;
  method: 'CASH' | 'TRANSFER';
  amount: number;
}) {
  requireOnlineAction('Pembayaran hutang supplier');
  const { data, error } = await supabase.rpc('finance_pay_supplier_payable', {
    p_payable_id: args.payableId,
    p_method: args.method,
    p_amount: args.amount,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data;
}

export async function createEmployeeKasbon(args: {
  employeeProfileId: string;
  sourceMethod: 'CASH' | 'TRANSFER';
  amount: number;
  note?: string;
}) {
  requireOnlineAction('Kasbon karyawan');
  const { data, error } = await supabase.rpc('finance_create_employee_kasbon', {
    p_employee_profile_id: args.employeeProfileId,
    p_source_method: args.sourceMethod,
    p_amount: args.amount,
    p_note: args.note?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data;
}
