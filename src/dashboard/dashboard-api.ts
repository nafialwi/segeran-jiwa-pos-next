import { supabase } from '../lib/supabase';
import { runReport, type ReportEnvelope } from '../reports/report-api';
import { fetchMyOpenShift, fetchShiftReconciliation } from '../shift/shift-api';
import type { Shift } from '../shift/shift-core';

export type DashboardTrendPoint = {
  date: string;
  label: string;
  value: number;
};

export type DashboardBestSeller = {
  product: string;
  variant: string | null;
  quantity: number;
  value: number;
};

export type OwnerDashboardData = {
  salesToday: number;
  transactionsToday: number;
  cashAvailable: number;
  qrisPending: number;
  trend: DashboardTrendPoint[];
  bestSellers: DashboardBestSeller[];
};

export type CashierDashboardData = {
  shift: Shift | null;
  openingCash: number;
  salesTotal: number;
  refundTotal: number;
  expectedCash: number;
};

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function localDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function dateDaysAgo(days: number): Date {
  const date = new Date();
  date.setHours(12, 0, 0, 0);
  date.setDate(date.getDate() - days);
  return date;
}

function summaryNumber(report: ReportEnvelope, label: string): number {
  const item = report.summary.find((entry) => entry.label === label);
  return num(item?.value);
}

function sectionRows(
  report: ReportEnvelope,
  key: string,
): Array<Record<string, unknown>> {
  return report.sections.find((section) => section.key === key)?.rows ?? [];
}

function trendFromReport(report: ReportEnvelope): DashboardTrendPoint[] {
  const days = Array.from({ length: 7 }, (_, index) => dateDaysAgo(6 - index));
  const totals = new Map(days.map((date) => [localDateKey(date), 0]));

  for (const row of sectionRows(report, 'transactions')) {
    const date = String(row.tanggal ?? '');
    if (!totals.has(date)) continue;
    totals.set(date, (totals.get(date) ?? 0) + num(row.nominal));
  }

  return days.map((date) => {
    const key = localDateKey(date);
    return {
      date: key,
      label: new Intl.DateTimeFormat('id-ID', {
        weekday: 'short',
      }).format(date),
      value: totals.get(key) ?? 0,
    };
  });
}

function bestSellersFromReport(report: ReportEnvelope): DashboardBestSeller[] {
  return sectionRows(report, 'products')
    .map((row) => ({
      product: String(row.produk ?? 'Produk'),
      variant:
        row.varian == null || String(row.varian).trim() === ''
          ? null
          : String(row.varian),
      quantity: num(row.qty_bersih),
      value: num(row.nilai_bersih_item),
    }))
    .filter((row) => row.quantity > 0)
    .sort((a, b) => b.quantity - a.quantity || b.value - a.value)
    .slice(0, 5);
}

async function fetchOwnerMoneyBalances(): Promise<{
  cashAvailable: number;
  qrisPending: number;
}> {
  const [accountsResult, balancesResult] = await Promise.all([
    supabase
      .from('money_accounts')
      .select('id,code')
      .in('code', ['KAS_UTAMA', 'KAS_SHIFT', 'QRIS_BELUM_CAIR'])
      .eq('active', true),
    supabase.from('money_balances').select('account_id,balance'),
  ]);

  if (accountsResult.error) {
    throw new Error(
      accountsResult.error.message ||
        accountsResult.error.code ||
        'DASHBOARD_FINANCE_ACCOUNT_FAILED',
    );
  }
  if (balancesResult.error) {
    throw new Error(
      balancesResult.error.message ||
        balancesResult.error.code ||
        'DASHBOARD_FINANCE_BALANCE_FAILED',
    );
  }

  const balances = new Map(
    (
      (balancesResult.data ?? []) as Array<{
        account_id: string;
        balance: number | string;
      }>
    ).map((row) => [row.account_id, num(row.balance)]),
  );

  let cashAvailable = 0;
  let qrisPending = 0;

  for (const account of (accountsResult.data ?? []) as Array<{
    id: string;
    code: string;
  }>) {
    const balance = balances.get(account.id) ?? 0;
    if (account.code === 'KAS_UTAMA' || account.code === 'KAS_SHIFT') {
      cashAvailable += balance;
    }
    if (account.code === 'QRIS_BELUM_CAIR') {
      qrisPending += balance;
    }
  }

  return { cashAvailable, qrisPending };
}

export async function fetchOwnerDashboard(): Promise<OwnerDashboardData> {
  const today = localDateKey(new Date());
  const start = localDateKey(dateDaysAgo(6));

  const [todayReport, trendReport, finance] = await Promise.all([
    runReport('SALES', today, today),
    runReport('SALES', start, today),
    fetchOwnerMoneyBalances(),
  ]);

  return {
    salesToday: summaryNumber(todayReport, 'Penjualan Bersih'),
    transactionsToday: summaryNumber(todayReport, 'Transaksi Penjualan'),
    cashAvailable: finance.cashAvailable,
    qrisPending: finance.qrisPending,
    trend: trendFromReport(trendReport),
    bestSellers: bestSellersFromReport(todayReport),
  };
}

export async function fetchCashierDashboard(): Promise<CashierDashboardData> {
  const shift = await fetchMyOpenShift();

  if (!shift) {
    return {
      shift: null,
      openingCash: 0,
      salesTotal: 0,
      refundTotal: 0,
      expectedCash: 0,
    };
  }

  const reconciliation = await fetchShiftReconciliation(shift.id);

  return {
    shift,
    openingCash: reconciliation.opening_balance,
    salesTotal: reconciliation.sale_total,
    refundTotal: reconciliation.refund_total,
    expectedCash: reconciliation.expected_cash,
  };
}
