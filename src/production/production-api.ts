import { requireOnlineAction } from '../health/online-action';
import { supabase } from '../lib/supabase';

export type ProductionLocation = {
  id: string;
  code: string;
  displayName: string;
  locationType: string;
};

export type ProductionFinishedGood = {
  id: string;
  code: string;
  displayName: string;
  baseUnit: string;
};

export type ProductionBomOption = {
  id: string;
  finishedGoodId: string;
  version: number;
  yieldQuantity: number;
};

export type ProductionBatch = {
  id: string;
  locationId: string;
  locationName: string;
  finishedGoodId: string;
  finishedGoodName: string;
  finishedGoodCode: string;
  baseUnit: string;
  bomId: string;
  bomVersion: number;
  plannedOutput: number;
  actualOutput: number | null;
  status: 'DRAFT' | 'POSTED';
  createdAt: string;
  postedAt: string | null;
};

export type ProductionOverview = {
  locations: ProductionLocation[];
  finishedGoods: ProductionFinishedGood[];
  activeBoms: ProductionBomOption[];
  batches: ProductionBatch[];
};

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function fail(error: { message?: string; code?: string } | null): never {
  throw new Error(error?.message || error?.code || 'PRODUCTION_READ_FAILED');
}

export async function fetchProductionOverview(): Promise<ProductionOverview> {
  const [locationResult, stockResult, bomResult, batchResult] =
    await Promise.all([
      supabase
        .from('locations')
        .select('id,code,display_name,location_type')
        .eq('active', true)
        .in('location_type', ['STORE', 'WAREHOUSE'])
        .order('display_name'),
      supabase
        .from('stock_items')
        .select('id,code,display_name,base_unit')
        .eq('active', true)
        .eq('item_kind', 'FINISHED_GOOD')
        .order('display_name'),
      supabase
        .from('boms')
        .select('id,finished_good_id,version,yield_quantity')
        .eq('status', 'ACTIVE')
        .order('version', { ascending: false }),
      supabase
        .from('production_batches')
        .select(
          'id,location_id,finished_good_id,bom_id,planned_output,actual_output,status,created_at,posted_at',
        )
        .order('created_at', { ascending: false })
        .limit(50),
    ]);

  for (const result of [locationResult, stockResult, bomResult, batchResult]) {
    if (result.error) fail(result.error);
  }

  const locations: ProductionLocation[] = (
    (locationResult.data ?? []) as Array<Record<string, unknown>>
  ).map((row) => ({
    id: String(row.id),
    code: String(row.code ?? ''),
    displayName: String(row.display_name ?? ''),
    locationType: String(row.location_type ?? ''),
  }));

  const finishedGoods: ProductionFinishedGood[] = (
    (stockResult.data ?? []) as Array<Record<string, unknown>>
  ).map((row) => ({
    id: String(row.id),
    code: String(row.code ?? ''),
    displayName: String(row.display_name ?? ''),
    baseUnit: String(row.base_unit ?? ''),
  }));

  const activeBoms: ProductionBomOption[] = (
    (bomResult.data ?? []) as Array<Record<string, unknown>>
  ).map((row) => ({
    id: String(row.id),
    finishedGoodId: String(row.finished_good_id),
    version: num(row.version),
    yieldQuantity: num(row.yield_quantity),
  }));

  const locationMap = new Map(locations.map((row) => [row.id, row]));
  const goodMap = new Map(finishedGoods.map((row) => [row.id, row]));
  const bomMap = new Map(activeBoms.map((row) => [row.id, row]));

  const batches: ProductionBatch[] = (
    (batchResult.data ?? []) as Array<Record<string, unknown>>
  ).map((row) => {
    const locationId = String(row.location_id);
    const finishedGoodId = String(row.finished_good_id);
    const bomId = String(row.bom_id);
    const good = goodMap.get(finishedGoodId);
    const location = locationMap.get(locationId);
    const bom = bomMap.get(bomId);

    return {
      id: String(row.id),
      locationId,
      locationName: location?.displayName ?? locationId,
      finishedGoodId,
      finishedGoodName: good?.displayName ?? finishedGoodId,
      finishedGoodCode: good?.code ?? '',
      baseUnit: good?.baseUnit ?? '',
      bomId,
      bomVersion: bom?.version ?? 0,
      plannedOutput: num(row.planned_output),
      actualOutput: row.actual_output == null ? null : num(row.actual_output),
      status: String(row.status ?? 'DRAFT') as ProductionBatch['status'],
      createdAt: String(row.created_at ?? ''),
      postedAt: row.posted_at == null ? null : String(row.posted_at),
    };
  });

  return { locations, finishedGoods, activeBoms, batches };
}

export async function createProductionBatch(args: {
  locationId: string;
  finishedGoodId: string;
  plannedOutput: number;
}) {
  requireOnlineAction('Rencana produksi');
  const { data, error } = await supabase.rpc('create_production_batch', {
    p_location_id: args.locationId,
    p_finished_good_id: args.finishedGoodId,
    p_planned_output: args.plannedOutput,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    batch_id: string;
    bom_id: string;
    bom_version: number;
    location_id: string;
    finished_good_id: string;
    status: string;
  };
}

export async function postProductionBatch(args: {
  batchId: string;
  actualOutput: number;
}) {
  requireOnlineAction('Posting produksi');
  const { data, error } = await supabase.rpc('post_production_batch', {
    p_batch_id: args.batchId,
    p_actual_output: args.actualOutput,
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    already_posted: boolean;
    batch_id: string;
    movement_id: string;
    actual_output: number;
    status: string;
  };
}
