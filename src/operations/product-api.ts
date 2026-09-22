import { requireOnlineAction } from '../health/online-action';
import { supabase } from '../lib/supabase';

export type ProductComponent = {
  stockItemId: string;
  code: string;
  name: string;
  itemKind: string;
  baseUnit: string;
  role: 'INGREDIENT' | 'PACKAGING' | 'FINISHED_GOOD';
  quantityPerUnit: number;
};

export type ProductBomLine = {
  stockItemId: string;
  code: string;
  name: string;
  baseUnit: string;
  quantity: number;
};

export type ProductBom = {
  id: string;
  finishedGoodId: string;
  version: number;
  status: 'DRAFT' | 'ACTIVE' | 'RETIRED';
  yieldQuantity: number;
  lines: ProductBomLine[];
};

export type ProductVariantOps = {
  id: string;
  code: string;
  displayName: string;
  fulfillmentMode: 'DIRECT_STOCK' | 'MAKE_TO_ORDER' | 'PREPRODUCED';
  saleStockItemId: string | null;
  salePrice: number;
  active: boolean;
  isDefault: boolean;
  components: ProductComponent[];
  boms: ProductBom[];
};

export type ProductOperationsProduct = {
  id: string;
  code: string;
  displayName: string;
  categoryCode: string | null;
  description: string | null;
  active: boolean;
  legacyStockItemId: string | null;
  variants: ProductVariantOps[];
};

function num(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function relationMissing(error: {
  code?: string;
  message?: string;
  details?: string | null;
}): boolean {
  const text = [error.code ?? '', error.message ?? '', error.details ?? '']
    .join(' ')
    .toLowerCase();

  return (
    error.code === '42P01' ||
    error.code === 'PGRST205' ||
    text.includes('sale_products') ||
    text.includes('product_variants') ||
    text.includes('variant_sale_components')
  );
}

function fail(
  error: { code?: string; message?: string; details?: string | null } | null,
): never {
  if (error && relationMissing(error)) {
    throw new Error(
      'REFINEMENT_DATABASE_NOT_READY: Product/Variant refinement C2 belum diterapkan.',
    );
  }

  throw new Error(
    error?.message || error?.code || 'PRODUCT_OPERATIONS_READ_FAILED',
  );
}

export async function fetchProductOperations(): Promise<
  ProductOperationsProduct[]
> {
  const [
    productResult,
    variantResult,
    componentResult,
    stockResult,
    bomResult,
    bomLineResult,
  ] = await Promise.all([
    supabase
      .from('sale_products')
      .select(
        'id,code,display_name,category_code,description,active,legacy_stock_item_id',
      )
      .order('display_name'),
    supabase
      .from('product_variants')
      .select(
        'id,product_id,code,display_name,fulfillment_mode,sale_stock_item_id,sale_price,active,is_default',
      )
      .order('display_name'),
    supabase
      .from('variant_sale_components')
      .select(
        'variant_id,line_no,stock_item_id,component_role,quantity_per_unit',
      )
      .order('line_no'),
    supabase
      .from('stock_items')
      .select('id,code,display_name,item_kind,base_unit')
      .eq('active', true),
    supabase
      .from('boms')
      .select(
        'id,finished_good_id,version,status,yield_quantity,created_at,activated_at',
      )
      .order('version', { ascending: false }),
    supabase
      .from('bom_lines')
      .select('bom_id,line_no,component_stock_item_id,base_quantity')
      .order('line_no'),
  ]);

  for (const result of [
    productResult,
    variantResult,
    componentResult,
    stockResult,
    bomResult,
    bomLineResult,
  ]) {
    if (result.error) fail(result.error);
  }

  const stocks = new Map(
    ((stockResult.data ?? []) as Array<Record<string, unknown>>).map((row) => [
      String(row.id),
      row,
    ]),
  );

  const componentsByVariant = new Map<string, ProductComponent[]>();
  for (const row of (componentResult.data ?? []) as Array<
    Record<string, unknown>
  >) {
    const variantId = String(row.variant_id);
    const stock = stocks.get(String(row.stock_item_id));
    if (!stock) continue;

    const component: ProductComponent = {
      stockItemId: String(row.stock_item_id),
      code: String(stock.code ?? ''),
      name: String(stock.display_name ?? ''),
      itemKind: String(stock.item_kind ?? ''),
      baseUnit: String(stock.base_unit ?? ''),
      role: String(
        row.component_role ?? 'INGREDIENT',
      ) as ProductComponent['role'],
      quantityPerUnit: num(row.quantity_per_unit),
    };

    const current = componentsByVariant.get(variantId) ?? [];
    current.push(component);
    componentsByVariant.set(variantId, current);
  }

  const bomLinesByBom = new Map<string, ProductBomLine[]>();
  for (const row of (bomLineResult.data ?? []) as Array<
    Record<string, unknown>
  >) {
    const bomId = String(row.bom_id);
    const stock = stocks.get(String(row.component_stock_item_id));
    if (!stock) continue;

    const line: ProductBomLine = {
      stockItemId: String(row.component_stock_item_id),
      code: String(stock.code ?? ''),
      name: String(stock.display_name ?? ''),
      baseUnit: String(stock.base_unit ?? ''),
      quantity: num(row.base_quantity),
    };

    const current = bomLinesByBom.get(bomId) ?? [];
    current.push(line);
    bomLinesByBom.set(bomId, current);
  }

  const bomsByFinishedGood = new Map<string, ProductBom[]>();
  for (const row of (bomResult.data ?? []) as Array<Record<string, unknown>>) {
    const finishedGoodId = String(row.finished_good_id);
    const bom: ProductBom = {
      id: String(row.id),
      finishedGoodId,
      version: num(row.version),
      status: String(row.status ?? 'DRAFT') as ProductBom['status'],
      yieldQuantity: num(row.yield_quantity),
      lines: bomLinesByBom.get(String(row.id)) ?? [],
    };
    const current = bomsByFinishedGood.get(finishedGoodId) ?? [];
    current.push(bom);
    bomsByFinishedGood.set(finishedGoodId, current);
  }

  const variantsByProduct = new Map<string, ProductVariantOps[]>();
  for (const row of (variantResult.data ?? []) as Array<
    Record<string, unknown>
  >) {
    const productId = String(row.product_id);
    const saleStockItemId =
      row.sale_stock_item_id == null ? null : String(row.sale_stock_item_id);

    const variant: ProductVariantOps = {
      id: String(row.id),
      code: String(row.code ?? ''),
      displayName: String(row.display_name ?? ''),
      fulfillmentMode: String(
        row.fulfillment_mode ?? 'DIRECT_STOCK',
      ) as ProductVariantOps['fulfillmentMode'],
      saleStockItemId,
      salePrice: num(row.sale_price),
      active: Boolean(row.active),
      isDefault: Boolean(row.is_default),
      components: componentsByVariant.get(String(row.id)) ?? [],
      boms: saleStockItemId
        ? (bomsByFinishedGood.get(saleStockItemId) ?? [])
        : [],
    };

    const current = variantsByProduct.get(productId) ?? [];
    current.push(variant);
    variantsByProduct.set(productId, current);
  }

  return ((productResult.data ?? []) as Array<Record<string, unknown>>).map(
    (row) => ({
      id: String(row.id),
      code: String(row.code ?? ''),
      displayName: String(row.display_name ?? ''),
      categoryCode:
        row.category_code == null ? null : String(row.category_code),
      description: row.description == null ? null : String(row.description),
      active: Boolean(row.active),
      legacyStockItemId:
        row.legacy_stock_item_id == null
          ? null
          : String(row.legacy_stock_item_id),
      variants: variantsByProduct.get(String(row.id)) ?? [],
    }),
  );
}

export type BomStockOption = {
  id: string;
  code: string;
  displayName: string;
  itemKind: string;
  baseUnit: string;
};

export async function fetchBomStockOptions(): Promise<{
  finishedGoods: BomStockOption[];
  components: BomStockOption[];
}> {
  const { data, error } = await supabase
    .from('stock_items')
    .select('id,code,display_name,item_kind,base_unit')
    .eq('active', true)
    .order('display_name');

  if (error) fail(error);

  const rows = ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    id: String(row.id),
    code: String(row.code ?? ''),
    displayName: String(row.display_name ?? ''),
    itemKind: String(row.item_kind ?? ''),
    baseUnit: String(row.base_unit ?? ''),
  }));

  return {
    finishedGoods: rows.filter((row) => row.itemKind === 'FINISHED_GOOD'),
    components: rows.filter((row) =>
      ['MATERIAL', 'PACKAGING', 'OTHER'].includes(row.itemKind),
    ),
  };
}

export async function saveBomDraft(args: {
  finishedGoodId: string;
  version: number;
  yieldQuantity: number;
  lines: Array<{ componentStockItemId: string; baseQuantity: number }>;
}) {
  requireOnlineAction('Simpan Draft BOM');
  const { data, error } = await supabase.rpc('save_bom_draft', {
    p_finished_good_id: args.finishedGoodId,
    p_version: args.version,
    p_yield_quantity: args.yieldQuantity,
    p_lines: args.lines.map((line) => ({
      component_stock_item_id: line.componentStockItemId,
      base_quantity: line.baseQuantity,
    })),
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay: boolean;
    bom_id: string;
    status: string;
    version: number;
  };
}

export async function activateBom(bomId: string) {
  requireOnlineAction('Aktifkan BOM');
  const { data, error } = await supabase.rpc('activate_bom', {
    p_bom_id: bomId,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as {
    success: boolean;
    replay?: boolean;
    bom_id: string;
    status: string;
    version: number;
  };
}
