import type {
  TransactionHistoryRow,
  TransactionHistoryFilters,
} from '../../../src/history/history-api';

const rows: TransactionHistoryRow[] = Array.from({ length: 24 }, (_, i) => ({
  sale_id: `fixture-sale-${i + 1}`,
  invoice_number: `CONTOH-${String(i + 1).padStart(4, '0')}`,
  business_date: '2026-10-09',
  created_at: '2026-10-09T14:00:00+07:00',
  status: 'COMPLETED',
  subtotal: (i + 1) * 1500,
  discount_amount: 0,
  discount_type: 'NONE',
  discount_value: 0,
  discount_reason: null,
  discount_approved_by: null,
  discount_approved_by_name: null,
  total_amount: (i + 1) * 1500,
  cashier_profile_id: 'fixture-profile',
  cashier_name: 'Kasir Contoh',
  cashier_username: 'kasir-demo',
  customer_name: null,
  location_name: 'Gerai Contoh',
  payment_method: i % 3 === 0 ? 'QRIS' : 'CASH',
  payments: [
    {
      method: 'CASH',
      amount: (i + 1) * 1500,
      tendered_amount: (i + 1) * 1500,
      change_amount: 0,
      status: 'POSTED',
      created_at: '2026-10-09T14:00:00+07:00',
    },
  ],
  items: [
    {
      line_no: 1,
      stock_item_id: 'fixture-stock',
      sale_product_id: 'fixture-product',
      variant_id: null,
      code: 'CONTOH-01',
      display_name: 'BAKARAN CONTOH',
      variant_code: null,
      variant_name: null,
      fulfillment_mode: null,
      category_code: 'BAKARAN',
      line_note: null,
      quantity: 1,
      unit_price: (i + 1) * 1500,
      subtotal: (i + 1) * 1500,
    },
  ],
  customer_debt: null,
  refund: null,
  correction: null,
  note: null,
}));

export async function searchTransactionHistory(
  filters: TransactionHistoryFilters = {},
): Promise<TransactionHistoryRow[]> {
  return rows.filter(
    (row) =>
      !filters.invoiceNumber ||
      row.invoice_number
        .toLowerCase()
        .includes(filters.invoiceNumber.toLowerCase()),
  );
}
export async function refundSale(): Promise<never> {
  throw new Error('Fixture: refund dinonaktifkan');
}
export async function correctSale(): Promise<never> {
  throw new Error('Fixture: koreksi dinonaktifkan');
}
export async function previewSaleCorrection(): Promise<never> {
  throw new Error('Fixture: koreksi dinonaktifkan');
}
