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
  const [
    accountResult,
    balanceResult,
    customerDebtResult,
    supplierPayableResult,
    employeeKasbonResult,
    reconciliationResult,
    settlementResult,
    userResult,
  ] = await Promise.all([
    supabase
      .from('money_accounts')
      .select('id,code,display_name,account_type')
      .order('code'),
    supabase.from('money_balances').select('account_id,balance'),
    supabase
      .from('customer_debt_balances')
      .select(
        'debt_id,customer_name,original_amount,paid_amount,balance,status,created_at',
      )
      .gt('balance', 0)
      .order('created_at', { ascending: false }),
    supabase
      .from('supplier_payable_balances')
      .select(
        'payable_id,supplier_name,invoice_reference,original_amount,paid_amount,balance,status,created_at',
      )
      .gt('balance', 0)
      .order('created_at', { ascending: false }),
    supabase
      .from('employee_kasbon_balances')
      .select(
        'kasbon_id,employee_profile_id,employee_name,original_amount,paid_amount,balance,status,note,created_at',
      )
      .order('created_at', { ascending: false }),
    supabase
      .from('finance_daily_reconciliations')
      .select(
        'id,business_date,expected_cash,counted_cash,cash_variance,qris_recorded,qris_settled,qris_variance,transfer_recorded,transfer_received,transfer_variance,stock_status,result,created_at',
      )
      .order('business_date', { ascending: false })
      .limit(10),
    supabase
      .from('qris_settlements')
      .select(
        'id,settlement_date,provider_reference,gross_amount,provider_fee,net_amount,created_at',
      )
      .order('settlement_date', { ascending: false })
      .limit(10),
    supabase.rpc('owner_list_users'),
  ]);

  for (const result of [
    accountResult,
    balanceResult,
    customerDebtResult,
    supplierPayableResult,
    employeeKasbonResult,
    reconciliationResult,
    settlementResult,
    userResult,
  ]) {
    if (result.error) fail(result.error);
  }

  const balanceMap = new Map(
    (
      (balanceResult.data ?? []) as Array<{
        account_id: string;
        balance: number | string;
      }>
    ).map((row) => [row.account_id, num(row.balance)]),
  );

  const accounts = (
    (accountResult.data ?? []) as Array<{
      id: string;
      code: string;
      display_name: string;
      account_type: string;
    }>
  ).map((row) => ({
    ...row,
    balance: balanceMap.get(row.id) ?? 0,
  }));

  return {
    accounts,
    customerDebts: (
      (customerDebtResult.data ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      original_amount: num(row.original_amount),
      paid_amount: num(row.paid_amount),
      balance: num(row.balance),
    })) as CustomerDebtBalance[],
    supplierPayables: (
      (supplierPayableResult.data ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      original_amount: num(row.original_amount),
      paid_amount: num(row.paid_amount),
      balance: num(row.balance),
    })) as SupplierPayableBalance[],
    employeeKasbons: (
      (employeeKasbonResult.data ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      original_amount: num(row.original_amount),
      paid_amount: num(row.paid_amount),
      balance: num(row.balance),
    })) as EmployeeKasbonBalance[],
    employees: ((userResult.data ?? []) as unknown as FinanceEmployee[]).filter(
      (row) => row.status === 'ACTIVE',
    ),
    reconciliations: (
      (reconciliationResult.data ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      expected_cash: num(row.expected_cash),
      counted_cash: num(row.counted_cash),
      cash_variance: num(row.cash_variance),
      qris_recorded: num(row.qris_recorded),
      qris_settled: num(row.qris_settled),
      qris_variance: num(row.qris_variance),
      transfer_recorded: num(row.transfer_recorded),
      transfer_received: num(row.transfer_received),
      transfer_variance: num(row.transfer_variance),
    })) as FinanceDailyReconciliation[],
    qrisSettlements: (
      (settlementResult.data ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      ...row,
      gross_amount: num(row.gross_amount),
      provider_fee: num(row.provider_fee),
      net_amount: num(row.net_amount),
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
