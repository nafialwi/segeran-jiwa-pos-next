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

export type HistoryDebt = {
  debt_id: string;
  original_amount: number;
  paid_amount: number;
  balance: number;
  status: string;
};

export type HistoryRefund = {
  refund_id: string;
  stock_disposition: string;
  refund_method: string;
  sale_total: number;
  payout_amount: number;
  receivable_cancelled_amount: number;
  reason: string;
  created_at: string;
};

export type HistoryCorrection = {
  correction_id: string;
  original_payment_method: string;
  sale_total: number;
  inventory_reversal_movement_id: string | null;
  money_reversal_movement_id: string;
  cash_adjustment_transaction_id: string | null;
  reason: string;
  created_at: string;
};

export type CorrectionPreview = {
  sale_id: string;
  invoice_number: string;
  can_execute: boolean;
  blocker: string | null;
  payment_method: string;
  sale_total: number;
  stock: { tracked_lines: number; action: string };
  cash_qris_transfer: string;
  debt: string;
  hpp: { available: boolean; message: string };
  finance: string;
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
  customer_debt: HistoryDebt | null;
  refund: HistoryRefund | null;
  correction: HistoryCorrection | null;
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

export type RefundStockDisposition =
  'RETURN_TO_STOCK' | 'DAMAGED_UNFIT' | 'NO_GOODS_RETURNED';
export type RefundMethod = 'CASH' | 'TRANSFER' | 'NONE';

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

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => {
    const debt = row.customer_debt as Record<string, unknown> | null;
    const refund = row.refund as Record<string, unknown> | null;
    const correction = row.correction as Record<string, unknown> | null;

    return {
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
      customer_debt: debt
        ? {
            debt_id: String(debt.debt_id ?? ''),
            original_amount: num(debt.original_amount),
            paid_amount: num(debt.paid_amount),
            balance: num(debt.balance),
            status: String(debt.status ?? ''),
          }
        : null,
      refund: refund
        ? {
            refund_id: String(refund.refund_id ?? ''),
            stock_disposition: String(refund.stock_disposition ?? ''),
            refund_method: String(refund.refund_method ?? ''),
            sale_total: num(refund.sale_total),
            payout_amount: num(refund.payout_amount),
            receivable_cancelled_amount: num(
              refund.receivable_cancelled_amount,
            ),
            reason: String(refund.reason ?? ''),
            created_at: String(refund.created_at ?? ''),
          }
        : null,
      correction: correction
        ? {
            correction_id: String(correction.correction_id ?? ''),
            original_payment_method: String(
              correction.original_payment_method ?? '',
            ),
            sale_total: num(correction.sale_total),
            inventory_reversal_movement_id:
              correction.inventory_reversal_movement_id == null
                ? null
                : String(correction.inventory_reversal_movement_id),
            money_reversal_movement_id: String(
              correction.money_reversal_movement_id ?? '',
            ),
            cash_adjustment_transaction_id:
              correction.cash_adjustment_transaction_id == null
                ? null
                : String(correction.cash_adjustment_transaction_id),
            reason: String(correction.reason ?? ''),
            created_at: String(correction.created_at ?? ''),
          }
        : null,
    } as TransactionHistoryRow;
  });
}

export async function refundSale(args: {
  saleId: string;
  stockDisposition: RefundStockDisposition;
  refundMethod: RefundMethod;
  reason: string;
}) {
  const { data, error } = await supabase.rpc('refund_sale', {
    p_sale_id: args.saleId,
    p_stock_disposition: args.stockDisposition,
    p_refund_method: args.refundMethod,
    p_reason: args.reason.trim(),
    p_idempotency_key: crypto.randomUUID(),
  });

  if (error)
    throw new Error(error.message || error.code || 'SALE_REFUND_FAILED');
  return data as {
    refund_id: string;
    sale_id: string;
    payout_amount: number;
    receivable_cancelled_amount: number;
    stock_disposition: RefundStockDisposition;
    refund_method: RefundMethod;
    already_posted: boolean;
  };
}

export async function previewSaleCorrection(
  saleId: string,
): Promise<CorrectionPreview> {
  const { data, error } = await supabase.rpc('sale_correction_preview', {
    p_sale_id: saleId,
  });
  if (error)
    throw new Error(
      error.message || error.code || 'SALE_CORRECTION_PREVIEW_FAILED',
    );
  const row = data as Record<string, unknown>;
  return {
    ...(row as unknown as CorrectionPreview),
    sale_total: num(row.sale_total),
  };
}

export async function correctSale(args: { saleId: string; reason: string }) {
  const { data, error } = await supabase.rpc('correct_sale', {
    p_sale_id: args.saleId,
    p_reason: args.reason.trim(),
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error)
    throw new Error(error.message || error.code || 'SALE_CORRECTION_FAILED');
  return data as {
    correction_id: string;
    sale_id: string;
    inventory_reversal_movement_id: string | null;
    money_reversal_movement_id: string;
    cash_adjustment_transaction_id: string | null;
    already_posted: boolean;
  };
}
