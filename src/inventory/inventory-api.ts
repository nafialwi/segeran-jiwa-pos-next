import { supabase } from '../lib/supabase';

export type InventoryRow = {
  location_id: string;
  location_name: string;
  stock_item_id: string;
  code: string;
  display_name: string;
  item_kind: string;
  base_unit: string;
  quantity: number;
  sale_enabled: boolean;
  sale_price: number | null;
  sale_category: string | null;
  inventory_tracked: boolean;
};

export type InventoryItemSummary = {
  stockItemId: string;
  code: string;
  displayName: string;
  itemKind: string;
  baseUnit: string;
  saleEnabled: boolean;
  salePrice: number | null;
  saleCategory: string | null;
  inventoryTracked: boolean;
  totalQuantity: number;
  locations: Array<{
    id: string;
    name: string;
    quantity: number;
  }>;
};

export type InventoryMovementRow = {
  movementId: string;
  movementType: string;
  sourceType: string;
  sourceRef: string;
  reasonCode: string;
  createdAt: string;
  locationId: string;
  locationName: string;
  quantityDelta: number;
};

export type InventoryItemDetail = {
  item: InventoryItemSummary;
  movements: InventoryMovementRow[];
};

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function nullableNum(value: unknown): number | null {
  if (value == null) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function fail(error: { message?: string; code?: string } | null): never {
  throw new Error(error?.message || error?.code || 'INVENTORY_READ_FAILED');
}

export async function fetchInventoryOverview(): Promise<InventoryRow[]> {
  const { data, error } = await supabase.rpc('inventory_operational_overview');
  if (error) fail(error);

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    location_id: String(row.location_id ?? ''),
    location_name: String(row.location_name ?? ''),
    stock_item_id: String(row.stock_item_id ?? ''),
    code: String(row.code ?? ''),
    display_name: String(row.display_name ?? ''),
    item_kind: String(row.item_kind ?? 'OTHER'),
    base_unit: String(row.base_unit ?? ''),
    quantity: num(row.quantity),
    sale_enabled: Boolean(row.sale_enabled),
    sale_price: nullableNum(row.sale_price),
    sale_category: row.sale_category == null ? null : String(row.sale_category),
    inventory_tracked: Boolean(row.inventory_tracked),
  }));
}

export function aggregateInventoryItems(
  rows: InventoryRow[],
): InventoryItemSummary[] {
  const items = new Map<string, InventoryItemSummary>();

  for (const row of rows) {
    const current = items.get(row.stock_item_id);
    if (current) {
      current.locations.push({
        id: row.location_id,
        name: row.location_name,
        quantity: row.quantity,
      });
      if (row.inventory_tracked) current.totalQuantity += row.quantity;
      continue;
    }

    items.set(row.stock_item_id, {
      stockItemId: row.stock_item_id,
      code: row.code,
      displayName: row.display_name,
      itemKind: row.item_kind,
      baseUnit: row.base_unit,
      saleEnabled: row.sale_enabled,
      salePrice: row.sale_price,
      saleCategory: row.sale_category,
      inventoryTracked: row.inventory_tracked,
      totalQuantity: row.inventory_tracked ? row.quantity : 0,
      locations: [
        {
          id: row.location_id,
          name: row.location_name,
          quantity: row.quantity,
        },
      ],
    });
  }

  return Array.from(items.values()).sort((a, b) =>
    a.displayName.localeCompare(b.displayName, 'id'),
  );
}

const inventoryDetailInflight: Record<
  string,
  Promise<InventoryItemDetail> | undefined
> = Object.create(null);

async function loadInventoryItemDetail(
  stockItemId: string,
): Promise<InventoryItemDetail> {
  const overview = await fetchInventoryOverview();
  const item = aggregateInventoryItems(
    overview.filter((row) => row.stock_item_id === stockItemId),
  )[0];

  if (!item) throw new Error('INVENTORY_ITEM_NOT_FOUND');

  const lineResult = await supabase
    .from('inventory_movement_lines')
    .select('movement_id,line_no,location_id,quantity_delta')
    .eq('stock_item_id', stockItemId)
    .limit(120);

  if (lineResult.error) fail(lineResult.error);

  const lines = (lineResult.data ?? []) as Array<{
    movement_id: string;
    line_no: number;
    location_id: string;
    quantity_delta: number | string;
  }>;

  if (lines.length === 0) return { item, movements: [] };

  const movementIds = Array.from(new Set(lines.map((row) => row.movement_id)));
  const locationIds = Array.from(new Set(lines.map((row) => row.location_id)));

  const [movementResult, locationResult] = await Promise.all([
    supabase
      .from('inventory_movements')
      .select('id,movement_type,source_type,source_ref,reason_code,created_at')
      .in('id', movementIds),
    supabase.from('locations').select('id,display_name').in('id', locationIds),
  ]);

  if (movementResult.error) fail(movementResult.error);
  if (locationResult.error) fail(locationResult.error);

  const movements = new Map(
    ((movementResult.data ?? []) as Array<Record<string, unknown>>).map(
      (row) => [String(row.id), row],
    ),
  );
  const locations = new Map(
    ((locationResult.data ?? []) as Array<Record<string, unknown>>).map(
      (row) => [String(row.id), String(row.display_name ?? row.id)],
    ),
  );

  const result = lines
    .map((line): InventoryMovementRow | null => {
      const movement = movements.get(line.movement_id);
      if (!movement) return null;

      return {
        movementId: line.movement_id,
        movementType: String(movement.movement_type ?? ''),
        sourceType: String(movement.source_type ?? ''),
        sourceRef: String(movement.source_ref ?? ''),
        reasonCode: String(movement.reason_code ?? ''),
        createdAt: String(movement.created_at ?? ''),
        locationId: line.location_id,
        locationName: locations.get(line.location_id) ?? line.location_id,
        quantityDelta: num(line.quantity_delta),
      };
    })
    .filter((row): row is InventoryMovementRow => row !== null)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 40);

  return { item, movements: result };
}

export function fetchInventoryItemDetail(
  stockItemId: string,
): Promise<InventoryItemDetail> {
  const existing = inventoryDetailInflight[stockItemId];
  if (existing) return existing;

  const pending = loadInventoryItemDetail(stockItemId).finally(() => {
    inventoryDetailInflight[stockItemId] = undefined;
  });
  inventoryDetailInflight[stockItemId] = pending;
  return pending;
}

export function prefetchInventoryItemDetail(stockItemId: string): void {
  void fetchInventoryItemDetail(stockItemId).catch(() => undefined);
}
