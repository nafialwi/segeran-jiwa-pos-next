import { supabase } from '../lib/supabase';
import { requireOnlineAction } from '../health/online-action';

export type SaleFulfillmentMode =
  'DIRECT_STOCK' | 'MAKE_TO_ORDER' | 'PREPRODUCED';

export type SalesCatalogItem = {
  sale_product_id: string;
  product_code: string;
  product_name: string;
  category_code: string;
  variant_id: string;
  variant_code: string;
  variant_name: string;
  fulfillment_mode: SaleFulfillmentMode;
  unit_price: number;
  inventory_managed: boolean;
  available_quantity: number | null;
  sale_stock_item_id: string | null;
};

export type SaleCustomer = {
  id: string;
  display_name: string;
  phone: string | null;
};

export type SalePaymentMethod = 'CASH' | 'QRIS' | 'TRANSFER' | 'CREDIT';
export type SaleDiscountType = 'NONE' | 'AMOUNT' | 'PERCENT';

export type CheckoutResult = {
  success: boolean;
  sale_id: string;
  invoice_number: string;
  subtotal: number;
  discount_amount: number;
  total_amount: number;
  payment_method: SalePaymentMethod;
  tendered_amount: number | null;
  change_amount: number | null;
  customer_debt_id: string | null;
  inventory_basis: 'SNAPSHOT_V2' | 'LEGACY_SALE_ITEM' | null;
  already_posted: boolean;
};

type RpcError = {
  code?: string;
  message: string;
  details?: string | null;
  hint?: string | null;
};

function fail(error: RpcError): never {
  throw new Error(error.message || error.code || 'SJ_UNKNOWN');
}

function isMissingV2Rpc(error: RpcError, rpcName: string): boolean {
  const text = [
    error.code ?? '',
    error.message ?? '',
    error.details ?? '',
    error.hint ?? '',
  ]
    .join(' ')
    .toLowerCase();

  return (
    error.code === 'PGRST202' ||
    error.code === '42883' ||
    (text.includes(rpcName.toLowerCase()) &&
      (text.includes('could not find') ||
        text.includes('does not exist') ||
        text.includes('schema cache')))
  );
}

function failV2Boundary(
  error: RpcError,
  rpcName: string,
  legacyTarget: 'katalog Legacy' | 'checkout Legacy',
): never {
  if (isMissingV2Rpc(error, rpcName)) {
    const boundaryMessage =
      legacyTarget === 'katalog Legacy'
        ? 'Penjualan V2 diblokir dan tidak dialihkan ke katalog Legacy.'
        : 'Penjualan V2 diblokir dan tidak dialihkan ke checkout Legacy.';

    throw new Error(
      'REFINEMENT_DATABASE_NOT_READY: Database refinement C2 belum diterapkan. ' +
        boundaryMessage,
    );
  }

  fail(error);
}

function finiteNumber(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function nullableFiniteNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export async function fetchSalesCatalog(
  locationId: string,
): Promise<SalesCatalogItem[]> {
  const { data, error } = await supabase.rpc('sales_catalog_v2', {
    p_location_id: locationId,
  });

  if (error) {
    failV2Boundary(error, 'sales_catalog_v2', 'katalog Legacy');
  }

  return ((data ?? []) as Record<string, unknown>[]).map((row) => ({
    sale_product_id: String(row.sale_product_id ?? ''),
    product_code: String(row.product_code ?? ''),
    product_name: String(row.product_name ?? ''),
    category_code: String(row.category_code ?? 'LAINNYA'),
    variant_id: String(row.variant_id ?? ''),
    variant_code: String(row.variant_code ?? ''),
    variant_name: String(row.variant_name ?? ''),
    fulfillment_mode: String(
      row.fulfillment_mode ?? 'DIRECT_STOCK',
    ) as SaleFulfillmentMode,
    unit_price: finiteNumber(row.unit_price),
    inventory_managed: Boolean(row.inventory_managed),
    available_quantity: nullableFiniteNumber(row.available_quantity),
    sale_stock_item_id:
      row.sale_stock_item_id === null || row.sale_stock_item_id === undefined
        ? null
        : String(row.sale_stock_item_id),
  }));
}

export async function fetchSaleCustomers(): Promise<SaleCustomer[]> {
  const { data, error } = await supabase
    .from('customers')
    .select('id,display_name,phone')
    .eq('active', true)
    .order('display_name');
  if (error) fail(error);
  return (data ?? []) as SaleCustomer[];
}

export async function fetchManualQrisImage(): Promise<string | null> {
  const { data, error } = await supabase
    .from('business_checkout_settings')
    .select('qris_image')
    .maybeSingle();
  if (error) fail(error);
  const row = data as { qris_image?: string | null } | null;
  return row?.qris_image ?? null;
}

export async function checkoutSale(args: {
  operationId: string;
  locationId: string;
  items: Array<{ variant_id: string; quantity: number; line_note?: string }>;
  method: SalePaymentMethod;
  total: number;
  tenderedAmount?: number;
  discount: {
    type: SaleDiscountType;
    value: number;
    reason?: string;
  };
  customerId?: string;
  note?: string;
}): Promise<CheckoutResult> {
  requireOnlineAction('Penjualan');

  const payment: Record<string, unknown> = {
    method: args.method,
    amount: args.total,
  };

  if (args.method === 'CASH') {
    payment.tendered_amount = args.tenderedAmount ?? null;
  }

  if (args.method === 'CREDIT') {
    payment.customer_id = args.customerId ?? null;
  }

  const { data, error } = await supabase.rpc('checkout_sale_v2', {
    p_operation_id: args.operationId,
    p_location_id: args.locationId,
    p_items: args.items,
    p_payment: payment,
    p_discount: {
      type: args.discount.type,
      value: args.discount.value,
      reason: args.discount.reason?.trim() || null,
    },
    p_note: args.note?.trim() || null,
  });

  if (error) {
    failV2Boundary(error, 'checkout_sale_v2', 'checkout Legacy');
  }

  return data as CheckoutResult;
}
