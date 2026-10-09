import type {
  SalesCatalogItem,
  SaleCustomer,
  CheckoutResult,
} from '../../../src/sales/sales-api';
const rows: SalesCatalogItem[] = [
  {
    sale_product_id: 'p-bakaran',
    product_code: 'BAKARAN',
    product_name: 'BAKARAN 1K',
    category_code: 'BAKARAN',
    variant_id: 'v-bakaran',
    variant_code: 'DEFAULT',
    variant_name: 'BAKARAN 1K',
    fulfillment_mode: 'DIRECT_STOCK',
    unit_price: 1000,
    inventory_managed: true,
    available_quantity: 30,
    sale_stock_item_id: 's1',
  },
  {
    sale_product_id: 'p-cireng',
    product_code: 'CIRENG',
    product_name: 'CIRENG ISI',
    category_code: 'JAJANAN',
    variant_id: 'v-cireng',
    variant_code: 'DEFAULT',
    variant_name: 'CIRENG ISI',
    fulfillment_mode: 'DIRECT_STOCK',
    unit_price: 3000,
    inventory_managed: true,
    available_quantity: 11,
    sale_stock_item_id: 's2',
  },
  {
    sale_product_id: 'p-teh',
    product_code: 'ES-TEH',
    product_name: 'ES TEH',
    category_code: 'MINUMAN',
    variant_id: 'v-teh',
    variant_code: 'DEFAULT',
    variant_name: 'ES TEH',
    fulfillment_mode: 'DIRECT_STOCK',
    unit_price: 2000,
    inventory_managed: false,
    available_quantity: null,
    sale_stock_item_id: null,
  },
  {
    sale_product_id: 'p-variant',
    product_code: 'JUS',
    product_name: 'JUS BUAH',
    category_code: 'MINUMAN',
    variant_id: 'v-jus-kecil',
    variant_code: 'KECIL',
    variant_name: 'Kecil',
    fulfillment_mode: 'MAKE_TO_ORDER',
    unit_price: 5000,
    inventory_managed: false,
    available_quantity: null,
    sale_stock_item_id: null,
  },
  {
    sale_product_id: 'p-variant',
    product_code: 'JUS',
    product_name: 'JUS BUAH',
    category_code: 'MINUMAN',
    variant_id: 'v-jus-besar',
    variant_code: 'BESAR',
    variant_name: 'Besar',
    fulfillment_mode: 'MAKE_TO_ORDER',
    unit_price: 8000,
    inventory_managed: false,
    available_quantity: null,
    sale_stock_item_id: null,
  },
  {
    sale_product_id: 'p-out',
    product_code: 'BAKARAN2K',
    product_name: 'BAKARAN 2K',
    category_code: 'BAKARAN',
    variant_id: 'v-out',
    variant_code: 'DEFAULT',
    variant_name: 'BAKARAN 2K',
    fulfillment_mode: 'DIRECT_STOCK',
    unit_price: 2000,
    inventory_managed: true,
    available_quantity: 0,
    sale_stock_item_id: 's3',
  },
];
export async function fetchSalesCatalog(): Promise<SalesCatalogItem[]> {
  return rows.map((row) => ({ ...row }));
}
export async function fetchSaleCustomers(): Promise<SaleCustomer[]> {
  return [
    { id: 'fixture-customer', display_name: 'Pelanggan Contoh', phone: null },
  ];
}
export async function fetchManualQrisImage(): Promise<string | null> {
  return null;
}
export async function checkoutSale(): Promise<CheckoutResult> {
  throw new Error(
    'UI FIXTURE: Checkout dinonaktifkan. Tidak ada transaksi nyata.',
  );
}
