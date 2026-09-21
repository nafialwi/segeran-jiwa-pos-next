import { supabase } from '../lib/supabase';
import { requireOnlineAction } from '../health/online-action';

export type PurchaseSupplier = {
  id: string;
  code: string;
  display_name: string;
  phone: string | null;
};

export type PurchaseLocation = {
  id: string;
  code: string;
  display_name: string;
  location_type: string;
};

export type PurchaseUnit = {
  id: string;
  code: string;
  display_name: string;
};

export type PurchaseItem = {
  id: string;
  code: string;
  display_name: string;
  item_kind: string;
  base_unit: string;
  base_unit_id: string;
};

export type ReceivableOrderLine = {
  id: string;
  stock_item_id: string;
  item_name: string;
  unit_id: string;
  unit_name: string;
  ordered_quantity: number;
  conversion_factor_snapshot: number;
  base_quantity: number;
  unit_price: number;
  received_base_quantity: number;
  remaining_base_quantity: number;
  remaining_quantity: number;
};

export type ReceivableOrder = {
  id: string;
  order_number: string;
  status: string;
  ordered_at: string;
  supplier_id: string;
  supplier_name: string;
  location_id: string;
  location_name: string;
  lines: ReceivableOrderLine[];
};

export type PurchaseReceipt = {
  id: string;
  receipt_number: string;
  status: string;
  received_at: string;
  posted_at: string | null;
  order_number: string;
  supplier_name: string;
  location_name: string;
};

export type PurchaseFrontDoorOptions = {
  suppliers: PurchaseSupplier[];
  locations: PurchaseLocation[];
  units: PurchaseUnit[];
  items: PurchaseItem[];
  receivable_orders: ReceivableOrder[];
  receipts: PurchaseReceipt[];
};

export type PurchaseLineInput = {
  stock_item_id: string;
  unit_id: string;
  quantity: number;
  unit_price: number;
};

function fail(error: { message: string; code?: string }): never {
  throw new Error(error.message || error.code || 'SJ_UNKNOWN');
}

export async function fetchPurchaseFrontDoorOptions(): Promise<PurchaseFrontDoorOptions> {
  const { data, error } = await supabase.rpc('purchase_front_door_options');
  if (error) fail(error);
  const value = (data ?? {}) as Partial<PurchaseFrontDoorOptions>;
  return {
    suppliers: value.suppliers ?? [],
    locations: value.locations ?? [],
    units: value.units ?? [],
    items: value.items ?? [],
    receivable_orders: value.receivable_orders ?? [],
    receipts: value.receipts ?? [],
  };
}

export async function createPurchaseSupplier(args: {
  code: string;
  displayName: string;
  phone?: string;
}): Promise<string> {
  requireOnlineAction('Pembuatan supplier');
  const { data, error } = await supabase.rpc('purchase_create_supplier', {
    p_code: args.code,
    p_display_name: args.displayName,
    p_phone: args.phone?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return String(data);
}

export async function createPurchaseItem(args: {
  code: string;
  displayName: string;
  itemKind: string;
  unitId: string;
}): Promise<string> {
  requireOnlineAction('Pembuatan item pembelian');
  const { data, error } = await supabase.rpc('purchase_create_item', {
    p_code: args.code,
    p_display_name: args.displayName,
    p_item_kind: args.itemKind,
    p_unit_id: args.unitId,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return String(data);
}

export async function createPurchaseOrder(args: {
  supplierId: string;
  locationId: string;
  lines: PurchaseLineInput[];
  notes?: string;
}) {
  requireOnlineAction('Purchase order');
  const { data, error } = await supabase.rpc('purchase_create_order', {
    p_supplier_id: args.supplierId,
    p_location_id: args.locationId,
    p_lines: args.lines,
    p_notes: args.notes?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    purchase_order_id: string;
    order_number: string;
    status: string;
  };
}

export async function createGoodsReceipt(args: {
  purchaseOrderId: string;
  lines: Array<{
    purchase_order_line_id: string;
    received_quantity: number;
  }>;
  notes?: string;
}) {
  requireOnlineAction('Penerimaan barang');
  const { data, error } = await supabase.rpc('purchase_create_goods_receipt', {
    p_purchase_order_id: args.purchaseOrderId,
    p_lines: args.lines,
    p_notes: args.notes?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    goods_receipt_id: string;
    receipt_number: string;
    status: string;
  };
}

export async function directBuy(args: {
  supplierId: string;
  locationId: string;
  lines: PurchaseLineInput[];
  notes?: string;
}) {
  requireOnlineAction('Pembelian langsung');
  const { data, error } = await supabase.rpc('purchase_direct_buy', {
    p_supplier_id: args.supplierId,
    p_location_id: args.locationId,
    p_lines: args.lines,
    p_notes: args.notes?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    purchase_order_id: string;
    order_number: string;
    goods_receipt_id: string;
    receipt_number: string;
    po_status: string;
  };
}

export async function postGoodsReceipt(goodsReceiptId: string) {
  requireOnlineAction('Posting penerimaan barang');
  const { data, error } = await supabase.rpc('post_goods_receipt', {
    p_goods_receipt_id: goodsReceiptId,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_posted: boolean;
    movement_id: string;
    po_status: string;
  };
}
