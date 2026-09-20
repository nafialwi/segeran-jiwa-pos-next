import { supabase } from '../lib/supabase';

export type SalesCatalogItem = {
  stock_item_id: string;
  code: string;
  display_name: string;
  category_code: string;
  unit_price: number;
  inventory_tracked: boolean;
  quantity: number | null;
};

export type SaleCustomer = {
  id: string;
  display_name: string;
  phone: string | null;
};

export type SalePaymentMethod = 'CASH' | 'QRIS' | 'TRANSFER' | 'CREDIT';

export type CheckoutResult = {
  success: boolean;
  sale_id: string;
  invoice_number: string;
  customer_debt_id: string | null;
  already_posted: boolean;
};

function fail(error: { code?: string; message: string }): never {
  throw new Error(error.message || error.code || 'SJ_UNKNOWN');
}

export async function fetchSalesCatalog(
  locationId: string,
): Promise<SalesCatalogItem[]> {
  const { data, error } = await supabase.rpc('sales_catalog', {
    p_location_id: locationId,
  });
  if (error) fail(error);

  return ((data ?? []) as Record<string, unknown>[]).map((row) => ({
    stock_item_id: String(row.stock_item_id),
    code: String(row.code ?? ''),
    display_name: String(row.display_name ?? ''),
    category_code: String(row.category_code ?? 'LAINNYA'),
    unit_price: Number(row.unit_price ?? 0),
    inventory_tracked: Boolean(row.inventory_tracked),
    quantity:
      row.quantity === null || row.quantity === undefined
        ? null
        : Number(row.quantity),
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
  items: Array<{ stock_item_id: string; quantity: number }>;
  method: SalePaymentMethod;
  total: number;
  customerId?: string;
  note?: string;
}): Promise<CheckoutResult> {
  const payment: Record<string, unknown> = {
    method: args.method,
    amount: args.total,
  };

  if (args.method === 'CREDIT') {
    payment.customer_id = args.customerId ?? null;
  }

  const { data, error } = await supabase.rpc('checkout_sale', {
    p_operation_id: args.operationId,
    p_location_id: args.locationId,
    p_items: args.items,
    p_payment: payment,
    p_note: args.note?.trim() || null,
  });

  if (error) fail(error);
  return data as CheckoutResult;
}
