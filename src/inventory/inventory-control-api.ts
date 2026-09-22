import { requireOnlineAction } from '../health/online-action';
import { supabase } from '../lib/supabase';

export type RestockRequestLine = {
  stockItemId: string;
  quantity: number;
};

export type RestockRequestRow = {
  id: string;
  destinationLocationId: string;
  status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED';
  notes: string | null;
  transferId: string | null;
  createdAt: string;
  lines: RestockRequestLine[];
};

export type StockTransferRow = {
  id: string;
  sourceLocationId: string;
  destinationLocationId: string;
  status: 'DRAFT' | 'SHIPPED' | 'RECEIVED';
  restockRequestId: string | null;
  createdAt: string;
  shippedAt: string | null;
  receivedAt: string | null;
  lines: Array<{
    stockItemId: string;
    quantity: number;
  }>;
};

export type InventoryCountLine = {
  stockItemId: string;
  expectedQuantity: number;
  physicalQuantity: number | null;
};

export type InventoryCountRow = {
  id: string;
  locationId: string;
  status: 'DRAFT' | 'COUNTED' | 'POSTED';
  notes: string | null;
  snapshotAt: string;
  createdAt: string;
  postedAt: string | null;
  movementId: string | null;
  lines: InventoryCountLine[];
};

export type InventoryAdjustmentRow = {
  id: string;
  locationId: string;
  stockItemId: string;
  adjustmentKind: 'ADJUSTMENT' | 'WRITE_OFF';
  quantityDelta: number;
  reasonCode: string;
  note: string | null;
  movementId: string;
  createdAt: string;
};

export type InventoryControlOverview = {
  restocks: RestockRequestRow[];
  transfers: StockTransferRow[];
  counts: InventoryCountRow[];
  adjustments: InventoryAdjustmentRow[];
};

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function fail(error: { message?: string; code?: string } | null): never {
  throw new Error(error?.message || error?.code || 'INVENTORY_CONTROL_FAILED');
}

export async function fetchInventoryControlOverview(): Promise<InventoryControlOverview> {
  const [restockResult, transferResult, countResult, adjustmentResult] =
    await Promise.all([
      supabase
        .from('restock_requests')
        .select(
          'id,destination_location_id,status,notes,transfer_id,created_at,submitted_at,approved_at,rejected_at',
        )
        .order('created_at', { ascending: false })
        .limit(40),
      supabase
        .from('stock_transfers')
        .select(
          'id,source_location_id,destination_location_id,status,restock_request_id,created_at,shipped_at,received_at',
        )
        .order('created_at', { ascending: false })
        .limit(40),
      supabase
        .from('inventory_counts')
        .select(
          'id,location_id,status,notes,snapshot_at,created_at,posted_at,movement_id',
        )
        .order('created_at', { ascending: false })
        .limit(40),
      supabase
        .from('inventory_adjustments')
        .select(
          'id,location_id,stock_item_id,adjustment_kind,quantity_delta,reason_code,note,movement_id,created_at',
        )
        .order('created_at', { ascending: false })
        .limit(40),
    ]);

  for (const result of [
    restockResult,
    transferResult,
    countResult,
    adjustmentResult,
  ]) {
    if (result.error) fail(result.error);
  }

  const restockRows = (restockResult.data ?? []) as Array<
    Record<string, unknown>
  >;
  const transferRows = (transferResult.data ?? []) as Array<
    Record<string, unknown>
  >;
  const countRows = (countResult.data ?? []) as Array<Record<string, unknown>>;

  const restockIds = restockRows.map((row) => String(row.id));
  const transferIds = transferRows.map((row) => String(row.id));
  const countIds = countRows.map((row) => String(row.id));

  let restockLineRows: Array<Record<string, unknown>> = [];
  let transferLineRows: Array<Record<string, unknown>> = [];
  let countLineRows: Array<Record<string, unknown>> = [];

  if (restockIds.length > 0) {
    const result = await supabase
      .from('restock_request_lines')
      .select('request_id,line_no,stock_item_id,requested_quantity')
      .in('request_id', restockIds)
      .order('line_no');
    if (result.error) fail(result.error);
    restockLineRows = (result.data ?? []) as Array<Record<string, unknown>>;
  }

  if (transferIds.length > 0) {
    const result = await supabase
      .from('stock_transfer_lines')
      .select('transfer_id,line_no,stock_item_id,quantity')
      .in('transfer_id', transferIds)
      .order('line_no');
    if (result.error) fail(result.error);
    transferLineRows = (result.data ?? []) as Array<Record<string, unknown>>;
  }

  if (countIds.length > 0) {
    const result = await supabase
      .from('inventory_count_lines')
      .select(
        'count_id,line_no,stock_item_id,expected_quantity,physical_quantity',
      )
      .in('count_id', countIds)
      .order('line_no');
    if (result.error) fail(result.error);
    countLineRows = (result.data ?? []) as Array<Record<string, unknown>>;
  }

  const restockLines = new Map<string, RestockRequestLine[]>();
  for (const row of restockLineRows) {
    const requestId = String(row.request_id);
    const current = restockLines.get(requestId) ?? [];
    current.push({
      stockItemId: String(row.stock_item_id),
      quantity: num(row.requested_quantity),
    });
    restockLines.set(requestId, current);
  }

  const transferLines = new Map<
    string,
    Array<{ stockItemId: string; quantity: number }>
  >();
  for (const row of transferLineRows) {
    const transferId = String(row.transfer_id);
    const current = transferLines.get(transferId) ?? [];
    current.push({
      stockItemId: String(row.stock_item_id),
      quantity: num(row.quantity),
    });
    transferLines.set(transferId, current);
  }

  const countLines = new Map<string, InventoryCountLine[]>();
  for (const row of countLineRows) {
    const countId = String(row.count_id);
    const current = countLines.get(countId) ?? [];
    current.push({
      stockItemId: String(row.stock_item_id),
      expectedQuantity: num(row.expected_quantity),
      physicalQuantity:
        row.physical_quantity == null ? null : num(row.physical_quantity),
    });
    countLines.set(countId, current);
  }

  return {
    restocks: restockRows.map((row) => ({
      id: String(row.id),
      destinationLocationId: String(row.destination_location_id),
      status: String(row.status) as RestockRequestRow['status'],
      notes: row.notes == null ? null : String(row.notes),
      transferId: row.transfer_id == null ? null : String(row.transfer_id),
      createdAt: String(row.created_at),
      lines: restockLines.get(String(row.id)) ?? [],
    })),
    transfers: transferRows.map((row) => ({
      id: String(row.id),
      sourceLocationId: String(row.source_location_id),
      destinationLocationId: String(row.destination_location_id),
      status: String(row.status) as StockTransferRow['status'],
      restockRequestId:
        row.restock_request_id == null ? null : String(row.restock_request_id),
      createdAt: String(row.created_at),
      shippedAt: row.shipped_at == null ? null : String(row.shipped_at),
      receivedAt: row.received_at == null ? null : String(row.received_at),
      lines: transferLines.get(String(row.id)) ?? [],
    })),
    counts: countRows.map((row) => ({
      id: String(row.id),
      locationId: String(row.location_id),
      status: String(row.status) as InventoryCountRow['status'],
      notes: row.notes == null ? null : String(row.notes),
      snapshotAt: String(row.snapshot_at),
      createdAt: String(row.created_at),
      postedAt: row.posted_at == null ? null : String(row.posted_at),
      movementId: row.movement_id == null ? null : String(row.movement_id),
      lines: countLines.get(String(row.id)) ?? [],
    })),
    adjustments: (
      (adjustmentResult.data ?? []) as Array<Record<string, unknown>>
    ).map((row) => ({
      id: String(row.id),
      locationId: String(row.location_id),
      stockItemId: String(row.stock_item_id),
      adjustmentKind: String(
        row.adjustment_kind,
      ) as InventoryAdjustmentRow['adjustmentKind'],
      quantityDelta: num(row.quantity_delta),
      reasonCode: String(row.reason_code),
      note: row.note == null ? null : String(row.note),
      movementId: String(row.movement_id),
      createdAt: String(row.created_at),
    })),
  };
}

export async function saveRestockRequest(args: {
  requestId?: string | null;
  destinationLocationId: string;
  lines: RestockRequestLine[];
  notes?: string;
}) {
  requireOnlineAction('Permintaan restock');
  const { data, error } = await supabase.rpc('save_restock_request', {
    p_request_id: args.requestId ?? null,
    p_destination_location_id: args.destinationLocationId,
    p_lines: args.lines.map((line) => ({
      stock_item_id: line.stockItemId,
      quantity: line.quantity,
    })),
    p_notes: args.notes?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    request_id: string;
    status: string;
    destination_location_id: string;
  };
}

export async function submitRestockRequest(requestId: string) {
  requireOnlineAction('Pengiriman permintaan restock');
  const { data, error } = await supabase.rpc('submit_restock_request', {
    p_request_id: requestId,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_submitted: boolean;
    request_id: string;
    status: string;
  };
}

export async function approveRestockRequest(args: {
  requestId: string;
  sourceLocationId: string;
}) {
  requireOnlineAction('Persetujuan restock');
  const { data, error } = await supabase.rpc('approve_restock_request', {
    p_request_id: args.requestId,
    p_source_location_id: args.sourceLocationId,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    request_id: string;
    transfer_id: string;
    status: string;
  };
}

export async function rejectRestockRequest(args: {
  requestId: string;
  reason: string;
}) {
  requireOnlineAction('Penolakan restock');
  const { data, error } = await supabase.rpc('reject_restock_request', {
    p_request_id: args.requestId,
    p_reason: args.reason,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_rejected: boolean;
    request_id: string;
    status: string;
  };
}

export async function createStockTransfer(args: {
  sourceLocationId: string;
  destinationLocationId: string;
  lines: Array<{ stockItemId: string; quantity: number }>;
}) {
  requireOnlineAction('Transfer stok');
  const { data, error } = await supabase.rpc('create_stock_transfer', {
    p_source_location_id: args.sourceLocationId,
    p_destination_location_id: args.destinationLocationId,
    p_lines: args.lines.map((line) => ({
      stock_item_id: line.stockItemId,
      quantity: line.quantity,
    })),
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    transfer_id: string;
    status: string;
  };
}

export async function shipStockTransfer(transferId: string) {
  requireOnlineAction('Pengiriman transfer stok');
  const { data, error } = await supabase.rpc('ship_stock_transfer', {
    p_transfer_id: transferId,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_shipped: boolean;
    transfer_id: string;
    movement_id: string;
    status: string;
  };
}

export async function receiveStockTransfer(transferId: string) {
  requireOnlineAction('Penerimaan transfer stok');
  const { data, error } = await supabase.rpc('receive_stock_transfer', {
    p_transfer_id: transferId,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_received: boolean;
    transfer_id: string;
    movement_id: string;
    status: string;
  };
}

export async function createInventoryCount(args: {
  locationId: string;
  stockItemIds: string[];
  notes?: string;
}) {
  requireOnlineAction('Stok opname');
  const { data, error } = await supabase.rpc('create_inventory_count', {
    p_location_id: args.locationId,
    p_stock_item_ids: args.stockItemIds,
    p_notes: args.notes?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    count_id: string;
    status: string;
    location_id: string;
  };
}

export async function recordInventoryCount(args: {
  countId: string;
  lines: Array<{ stockItemId: string; physicalQuantity: number }>;
}) {
  requireOnlineAction('Pencatatan stok opname');
  const { data, error } = await supabase.rpc('record_inventory_count', {
    p_count_id: args.countId,
    p_lines: args.lines.map((line) => ({
      stock_item_id: line.stockItemId,
      physical_quantity: line.physicalQuantity,
    })),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    count_id: string;
    status: string;
    counted_at: string;
  };
}

export async function postInventoryCount(countId: string) {
  requireOnlineAction('Posting stok opname');
  const { data, error } = await supabase.rpc('post_inventory_count', {
    p_count_id: countId,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_posted: boolean;
    zero_variance?: boolean;
    count_id: string;
    movement_id: string | null;
    status: string;
  };
}

export async function postInventoryAdjustment(args: {
  locationId: string;
  stockItemId: string;
  adjustmentKind: 'ADJUSTMENT' | 'WRITE_OFF';
  quantityDelta: number;
  reasonCode: string;
  note?: string;
}) {
  requireOnlineAction('Penyesuaian persediaan');
  const { data, error } = await supabase.rpc('post_inventory_adjustment', {
    p_location_id: args.locationId,
    p_stock_item_id: args.stockItemId,
    p_adjustment_kind: args.adjustmentKind,
    p_quantity_delta: args.quantityDelta,
    p_reason_code: args.reasonCode,
    p_note: args.note?.trim() || null,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    adjustment_id: string;
    movement_id: string;
    quantity_delta: number;
  };
}
