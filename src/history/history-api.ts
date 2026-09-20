import { supabase } from '../lib/supabase';

export type HistoryPayment = {
  method: string;
  amount: number;
  status: string;
  created_at: string;
};

export type HistoryItem = {
  line_no: number;
  stock_item_id: string;
  code: string;
  display_name: string;
  quantity: number;
  unit_price: number;
  subtotal: number;
};

export type TransactionHistoryRow = {
  sale_id: string;
  invoice_number: string;
  business_date: string;
  created_at: string;
  status: string;
  subtotal: number;
  discount_amount: number;
  total_amount: number;
  cashier_profile_id: string;
  cashier_name: string;
  cashier_username: string | null;
  customer_name: string | null;
  location_name: string;
  payment_method: string | null;
  payments: HistoryPayment[];
  items: HistoryItem[];
  note: string | null;
};

export type TransactionHistoryFilters = {
  dateFrom?: string;
  dateTo?: string;
  invoiceNumber?: string;
  product?: string;
  user?: string;
  paymentMethod?: string;
  amountMin?: number;
  amountMax?: number;
  status?: string;
  limit?: number;
};

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export async function searchTransactionHistory(
  filters: TransactionHistoryFilters = {},
): Promise<TransactionHistoryRow[]> {
  const { data, error } = await supabase.rpc('transaction_history_search', {
    p_date_from: filters.dateFrom || null,
    p_date_to: filters.dateTo || null,
    p_invoice_number: filters.invoiceNumber?.trim() || null,
    p_product: filters.product?.trim() || null,
    p_user: filters.user?.trim() || null,
    p_payment_method: filters.paymentMethod || null,
    p_amount_min: filters.amountMin ?? null,
    p_amount_max: filters.amountMax ?? null,
    p_status: filters.status || null,
    p_limit: filters.limit ?? 100,
  });

  if (error)
    throw new Error(error.message || error.code || 'HISTORY_SEARCH_FAILED');

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    ...row,
    subtotal: num(row.subtotal),
    discount_amount: num(row.discount_amount),
    total_amount: num(row.total_amount),
    payments: ((row.payments ?? []) as Array<Record<string, unknown>>).map(
      (payment) => ({
        method: String(payment.method ?? ''),
        amount: num(payment.amount),
        status: String(payment.status ?? ''),
        created_at: String(payment.created_at ?? ''),
      }),
    ),
    items: ((row.items ?? []) as Array<Record<string, unknown>>).map(
      (item) => ({
        line_no: Number(item.line_no ?? 0),
        stock_item_id: String(item.stock_item_id ?? ''),
        code: String(item.code ?? ''),
        display_name: String(item.display_name ?? ''),
        quantity: num(item.quantity),
        unit_price: num(item.unit_price),
        subtotal: num(item.subtotal),
      }),
    ),
  })) as TransactionHistoryRow[];
}
