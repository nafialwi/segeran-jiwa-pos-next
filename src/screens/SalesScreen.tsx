import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { hasPermission } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { Icon } from '../ui/Icon';
import { SearchablePicker } from '../components/SearchablePicker';
import {
  checkoutSale,
  fetchManualQrisImage,
  fetchSaleCustomers,
  fetchSalesCatalog,
  type CheckoutResult,
  type SaleCustomer,
  type SaleDiscountType,
  type SalePaymentMethod,
  type SalesCatalogItem,
} from '../sales/sales-api';
import { fetchMyOpenShift } from '../shift/shift-api';
import type { Shift } from '../shift/shift-core';

type CartLine = {
  item: SalesCatalogItem;
  quantity: number;
  lineNote: string;
};

type ProductGroup = {
  saleProductId: string;
  productCode: string;
  productName: string;
  categoryCode: string;
  variants: SalesCatalogItem[];
};

type SaleSuccess = {
  result: CheckoutResult;
  items: Array<{
    productName: string;
    variantName: string;
    quantity: number;
    lineNote: string;
  }>;
};

function formatIdr(value: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function paymentLabel(method: SalePaymentMethod): string {
  if (method === 'CASH') return 'Tunai';
  if (method === 'CREDIT') return 'Kasbon';
  if (method === 'TRANSFER') return 'Transfer';
  return 'QRIS';
}

function nextCashOptions(total: number): number[] {
  if (total <= 0) return [];
  const values = [
    total,
    Math.ceil(total / 5000) * 5000,
    Math.ceil(total / 10000) * 10000,
    20000,
    50000,
    100000,
  ];
  return Array.from(new Set(values.filter((value) => value >= total))).slice(
    0,
    5,
  );
}

export function SalesScreen() {
  const { authority } = useAuth();
  const [shift, setShift] = useState<Shift | null>(null);
  const [catalog, setCatalog] = useState<SalesCatalogItem[]>([]);
  const [customers, setCustomers] = useState<SaleCustomer[]>([]);
  const [qrisImage, setQrisImage] = useState<string | null>(null);
  const [customersLoaded, setCustomersLoaded] = useState(false);
  const [qrisLoaded, setQrisLoaded] = useState(false);
  const [cart, setCart] = useState<CartLine[]>([]);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('SEMUA');
  const [method, setMethod] = useState<SalePaymentMethod>('CASH');
  const [cashReceived, setCashReceived] = useState(0);
  const [customerId, setCustomerId] = useState('');
  const [qrisConfirmed, setQrisConfirmed] = useState(false);
  const [transferConfirmed, setTransferConfirmed] = useState(false);
  const [note, setNote] = useState('');
  const [discountType, setDiscountType] = useState<SaleDiscountType>('NONE');
  const [discountValue, setDiscountValue] = useState(0);
  const [discountReason, setDiscountReason] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [cartOpen, setCartOpen] = useState(false);
  const [variantPicker, setVariantPicker] = useState<ProductGroup | null>(null);
  const [success, setSuccess] = useState<SaleSuccess | null>(null);

  const submitGuardRef = useRef(false);
  const pendingOperationIdRef = useRef<string | null>(null);
  const customersLoadingRef = useRef(false);
  const qrisLoadingRef = useRef(false);

  async function warmCustomers() {
    if (customersLoaded || customersLoadingRef.current) return;
    customersLoadingRef.current = true;
    try {
      setCustomers(await fetchSaleCustomers());
      setCustomersLoaded(true);
    } catch {
      // Customer data is checkout support, not a catalog first-paint blocker.
    } finally {
      customersLoadingRef.current = false;
    }
  }

  async function warmQris() {
    if (qrisLoaded || qrisLoadingRef.current) return;
    qrisLoadingRef.current = true;
    try {
      setQrisImage(await fetchManualQrisImage());
      setQrisLoaded(true);
    } catch {
      setQrisImage(null);
      setQrisLoaded(true);
    } finally {
      qrisLoadingRef.current = false;
    }
  }

  async function load() {
    setLoading(true);
    setError('');
    try {
      const currentShift = await fetchMyOpenShift();
      setShift(currentShift);
      if (!currentShift) {
        setCatalog([]);
        return;
      }

      // First paint only waits for the active shift and sellable catalog.
      // Customers and QRIS are checkout support data and warm in background.
      const items = await fetchSalesCatalog(currentShift.location_id);
      setCatalog(items);
      void warmCustomers();
      void warmQris();
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : 'Data penjualan gagal dimuat.',
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  useEffect(() => {
    if (!cartOpen && !variantPicker && !success) return;
    const original = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = original;
    };
  }, [cartOpen, variantPicker, success]);

  const categories = useMemo(
    () =>
      Array.from(new Set(catalog.map((item) => item.category_code))).sort(
        (a, b) => a.localeCompare(b, 'id'),
      ),
    [catalog],
  );

  const visibleItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    return catalog.filter((item) => {
      const matchesCategory =
        category === 'SEMUA' || item.category_code === category;
      const matchesQuery =
        !query ||
        item.product_name.toLowerCase().includes(query) ||
        item.product_code.toLowerCase().includes(query) ||
        item.variant_name.toLowerCase().includes(query) ||
        item.variant_code.toLowerCase().includes(query) ||
        item.category_code.toLowerCase().includes(query);
      return matchesCategory && matchesQuery;
    });
  }, [catalog, search, category]);

  const productGroups = useMemo<ProductGroup[]>(() => {
    const groups = new Map<string, ProductGroup>();
    for (const item of visibleItems) {
      const existing = groups.get(item.sale_product_id);
      if (existing) {
        existing.variants.push(item);
      } else {
        groups.set(item.sale_product_id, {
          saleProductId: item.sale_product_id,
          productCode: item.product_code,
          productName: item.product_name,
          categoryCode: item.category_code,
          variants: [item],
        });
      }
    }
    return Array.from(groups.values());
  }, [visibleItems]);

  const catalogProductCount = useMemo(
    () => new Set(catalog.map((item) => item.sale_product_id)).size,
    [catalog],
  );

  const subtotal = cart.reduce(
    (sum, line) => sum + line.item.unit_price * line.quantity,
    0,
  );
  const cartQuantity = cart.reduce((sum, line) => sum + line.quantity, 0);
  const canDiscount = Boolean(
    authority && hasPermission(authority, 'SALE_DISCOUNT'),
  );
  const discountValueNumber = Number.isFinite(discountValue)
    ? discountValue
    : 0;
  const discountValid =
    discountType === 'NONE' ||
    (canDiscount &&
      discountReason.trim().length > 0 &&
      discountValueNumber > 0 &&
      (discountType === 'AMOUNT'
        ? discountValueNumber <= subtotal
        : discountValueNumber <= 100));
  const discountAmount =
    discountType === 'NONE' || !discountValid
      ? 0
      : discountType === 'AMOUNT'
        ? discountValueNumber
        : Math.round((subtotal * discountValueNumber) / 100);
  const total = Math.max(0, subtotal - discountAmount);
  const effectiveCashReceived = total === 0 ? 0 : cashReceived;
  const change = Math.max(0, effectiveCashReceived - total);
  const cashOptions = useMemo(() => nextCashOptions(total), [total]);

  function invalidatePendingOperation() {
    if (!submitGuardRef.current) {
      pendingOperationIdRef.current = null;
    }
  }

  function add(item: SalesCatalogItem) {
    setError('');
    invalidatePendingOperation();
    setCart((current) => {
      const existing = current.find(
        (line) => line.item.variant_id === item.variant_id,
      );
      const nextQuantity = (existing?.quantity ?? 0) + 1;

      if (
        item.inventory_managed &&
        item.available_quantity !== null &&
        nextQuantity > item.available_quantity
      ) {
        setError('Stok ' + item.product_name + ' tidak mencukupi.');
        return current;
      }

      if (existing) {
        return current.map((line) =>
          line.item.variant_id === item.variant_id
            ? { ...line, quantity: nextQuantity }
            : line,
        );
      }

      return [...current, { item, quantity: 1, lineNote: '' }];
    });
  }

  function adjust(variantId: string, delta: number) {
    invalidatePendingOperation();
    setCart((current) =>
      current.flatMap((line) => {
        if (line.item.variant_id !== variantId) return [line];
        const quantity = line.quantity + delta;
        if (quantity <= 0) return [];
        if (
          line.item.inventory_managed &&
          line.item.available_quantity !== null &&
          quantity > line.item.available_quantity
        ) {
          setError('Stok ' + line.item.product_name + ' tidak mencukupi.');
          return [line];
        }
        return [{ ...line, quantity }];
      }),
    );
  }

  function setLineNote(variantId: string, lineNote: string) {
    invalidatePendingOperation();
    setCart((current) =>
      current.map((line) =>
        line.item.variant_id === variantId ? { ...line, lineNote } : line,
      ),
    );
  }

  function chooseMethod(value: SalePaymentMethod) {
    invalidatePendingOperation();
    setMethod(value);
    setQrisConfirmed(false);
    setTransferConfirmed(false);
    if (value !== 'CREDIT') setCustomerId('');
    if (value !== 'CASH') setCashReceived(0);
    if (value === 'CREDIT') void warmCustomers();
    if (value === 'QRIS') void warmQris();
  }

  const allowedMethods: SalePaymentMethod[] = ['CASH'];
  if (authority && hasPermission(authority, 'PAYMENT_QRIS')) {
    allowedMethods.push('QRIS');
  }
  if (authority && hasPermission(authority, 'PAYMENT_TRANSFER')) {
    allowedMethods.push('TRANSFER');
  }
  if (authority && hasPermission(authority, 'CUSTOMER_DEBT_MANAGE')) {
    allowedMethods.push('CREDIT');
  }

  const canPay =
    cart.length > 0 &&
    !busy &&
    discountValid &&
    (total === 0
      ? method === 'CASH'
      : (method === 'CASH' && effectiveCashReceived >= total) ||
        (method === 'QRIS' && Boolean(qrisImage) && qrisConfirmed) ||
        (method === 'TRANSFER' && transferConfirmed) ||
        (method === 'CREDIT' && Boolean(customerId)));

  async function submit() {
    if (!shift || !canPay || submitGuardRef.current) return;

    submitGuardRef.current = true;
    setBusy(true);
    setError('');

    const operationId = pendingOperationIdRef.current ?? crypto.randomUUID();
    pendingOperationIdRef.current = operationId;

    try {
      const successItems = cart.map((line) => ({
        productName: line.item.product_name,
        variantName: line.item.variant_name,
        quantity: line.quantity,
        lineNote: line.lineNote,
      }));
      const result = await checkoutSale({
        operationId,
        locationId: shift.location_id,
        items: cart.map((line) => ({
          variant_id: line.item.variant_id,
          quantity: line.quantity,
          line_note: line.lineNote.trim() || undefined,
        })),
        method,
        total,
        tenderedAmount: method === 'CASH' ? effectiveCashReceived : undefined,
        discount: {
          type: discountType,
          value: discountType === 'NONE' ? 0 : discountValueNumber,
          reason: discountType === 'NONE' ? undefined : discountReason.trim(),
        },
        customerId: method === 'CREDIT' ? customerId : undefined,
        note,
      });

      pendingOperationIdRef.current = null;
      setSuccess({ result, items: successItems });
      setCart([]);
      setCashReceived(0);
      setCustomerId('');
      setQrisConfirmed(false);
      setTransferConfirmed(false);
      setDiscountType('NONE');
      setDiscountValue(0);
      setDiscountReason('');
      setNote('');
      setCartOpen(false);
      await load();
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : 'Penjualan gagal diproses.',
      );
    } finally {
      submitGuardRef.current = false;
      setBusy(false);
    }
  }

  return (
    <main className="shell sales-shell sales-v2-shell">
      <header className="sales-v2-header">
        <div>
          <Link className="sales-v2-back" to="/">
            Beranda
          </Link>
          <h1>Jual</h1>
        </div>
        <div className="sales-v2-header-meta">
          <span className="sales-v2-shift-dot" aria-hidden="true" />
          Shift aktif
        </div>
      </header>

      {error && <p className="error-banner sales-v2-banner">{error}</p>}

      {loading ? (
        <section className="identity-card">
          <p>Memuat data penjualan...</p>
        </section>
      ) : !shift ? (
        <section className="identity-card">
          <h2>Shift belum aktif</h2>
          <p className="muted">
            Buka Shift terlebih dahulu sebelum membuat transaksi.
          </p>
          <Link className="primary-link" to="/shift">
            Buka Shift
          </Link>
        </section>
      ) : (
        <>
          <section className="sales-v2-toolbar">
            <label className="sales-v2-search">
              <span className="sr-only">Cari produk</span>
              <Icon name="search" size={18} className="sales-v2-search-icon" />
              <input
                type="search"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Cari produk..."
              />
            </label>
            <div
              className="sales-v2-category-strip"
              aria-label="Kategori produk"
            >
              <button
                type="button"
                className={category === 'SEMUA' ? 'active' : ''}
                onClick={() => setCategory('SEMUA')}
              >
                Semua
              </button>
              {categories.map((value) => (
                <button
                  type="button"
                  key={value}
                  className={category === value ? 'active' : ''}
                  onClick={() => setCategory(value)}
                >
                  {value}
                </button>
              ))}
            </div>
          </section>

          {catalog.length === 0 ? (
            <section className="identity-card">
              <div className="empty-state">
                <strong>Master produk Next belum tersedia.</strong>
                <p>Import backup Legacy terlebih dahulu.</p>
                {authority?.owner && (
                  <Link className="primary-link" to="/legacy-import">
                    Migrasi Master Legacy
                  </Link>
                )}
              </div>
            </section>
          ) : (
            <section className="sales-v2-products" aria-label="Daftar produk">
              <div className="sales-v2-product-summary">
                <strong>{productGroups.length}</strong>
                <span>dari {catalogProductCount} produk</span>
              </div>
              <div className="sales-v2-product-grid">
                {productGroups.map((group) => {
                  const availableVariants = group.variants.filter(
                    (item) =>
                      !item.inventory_managed ||
                      (item.available_quantity ?? 0) > 0,
                  );
                  const unavailable = availableVariants.length === 0;
                  const inCart = cart
                    .filter((line) =>
                      group.variants.some(
                        (variant) =>
                          variant.variant_id === line.item.variant_id,
                      ),
                    )
                    .reduce((sum, line) => sum + line.quantity, 0);
                  const minPrice = Math.min(
                    ...group.variants.map((item) => item.unit_price),
                  );

                  return (
                    <button
                      className="sales-v2-product-card"
                      key={group.saleProductId}
                      type="button"
                      disabled={unavailable}
                      onClick={() => {
                        if (availableVariants.length === 1) {
                          add(availableVariants[0]);
                        } else {
                          setVariantPicker({
                            ...group,
                            variants: availableVariants,
                          });
                        }
                      }}
                    >
                      <span
                        className="sales-v2-product-visual"
                        aria-hidden="true"
                      >
                        <Icon name="product" size={26} />
                        <small>{group.categoryCode}</small>
                      </span>
                      <span className="sales-v2-product-name">
                        {group.productName}
                      </span>
                      <span className="sales-v2-variant-name">
                        {group.variants.length > 1
                          ? group.variants.length + ' varian'
                          : group.variants[0]?.variant_code !== 'DEFAULT' &&
                              group.variants[0]?.variant_name !==
                                group.productName
                            ? group.variants[0]?.variant_name
                            : group.categoryCode}
                      </span>
                      <strong>
                        {group.variants.length > 1 ? 'Mulai ' : ''}
                        {formatIdr(minPrice)}
                      </strong>
                      <span
                        className={
                          unavailable
                            ? 'sales-v2-stock-badge empty'
                            : 'sales-v2-stock-badge'
                        }
                      >
                        {unavailable ? 'Habis' : 'Pilih produk'}
                      </span>
                      {inCart > 0 && (
                        <span className="sales-v2-in-cart">{inCart}</span>
                      )}
                    </button>
                  );
                })}
              </div>
            </section>
          )}

          <button
            className="sales-v2-cart-bar"
            type="button"
            disabled={cart.length === 0}
            onClick={() => setCartOpen(true)}
          >
            <span className="sales-v2-cart-count">
              <Icon name="cart" size={18} />
              <strong>{cartQuantity}</strong>
            </span>
            <span className="sales-v2-cart-total">
              <small>Keranjang</small>
              <strong>{formatIdr(total)}</strong>
            </span>
            <span className="sales-v2-cart-action">
              {cart.length > 0 ? 'Lihat & Bayar' : 'Keranjang kosong'}
            </span>
          </button>

          {cartOpen && (
            <div
              className="sales-v2-sheet-backdrop"
              onMouseDown={(event) => {
                if (event.currentTarget === event.target && !busy) {
                  setCartOpen(false);
                }
              }}
            >
              <section
                className="sales-v2-sheet"
                role="dialog"
                aria-modal="true"
                aria-label="Keranjang dan pembayaran"
              >
                <div className="sales-v2-sheet-handle" />
                <header className="sales-v2-sheet-header">
                  <div>
                    <h2>Keranjang</h2>
                    <span>{cartQuantity} item</span>
                  </div>
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => setCartOpen(false)}
                  >
                    Tutup
                  </button>
                </header>

                <div className="sales-v2-cart-lines">
                  {cart.map((line) => (
                    <article
                      className="sales-v2-cart-line"
                      key={line.item.variant_id}
                    >
                      <div>
                        <strong>{line.item.product_name}</strong>
                        {line.item.variant_code !== 'DEFAULT' ||
                        line.item.variant_name !== line.item.product_name ? (
                          <span>{line.item.variant_name}</span>
                        ) : null}
                        <span>
                          {formatIdr(line.item.unit_price)} x {line.quantity}
                        </span>
                      </div>
                      <div className="sales-v2-qty">
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => adjust(line.item.variant_id, -1)}
                        >
                          -
                        </button>
                        <strong>{line.quantity}</strong>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => adjust(line.item.variant_id, 1)}
                        >
                          +
                        </button>
                      </div>
                      <label className="sales-v2-line-note">
                        <span>Catatan item</span>
                        <input
                          value={line.lineNote}
                          disabled={busy}
                          maxLength={160}
                          placeholder="Opsional"
                          onChange={(event) =>
                            setLineNote(
                              line.item.variant_id,
                              event.target.value,
                            )
                          }
                        />
                      </label>
                    </article>
                  ))}
                </div>

                <div className="sales-v2-total-stack">
                  <div>
                    <span>Subtotal</span>
                    <strong>{formatIdr(subtotal)}</strong>
                  </div>
                  {discountAmount > 0 && (
                    <div>
                      <span>Diskon</span>
                      <strong>-{formatIdr(discountAmount)}</strong>
                    </div>
                  )}
                  <div className="sales-v2-total-row">
                    <span>Total</span>
                    <strong>{formatIdr(total)}</strong>
                  </div>
                </div>

                {canDiscount && (
                  <details className="sales-v2-discount">
                    <summary>Diskon</summary>
                    <label>
                      <span>Jenis diskon</span>
                      <select
                        value={discountType}
                        disabled={busy}
                        onChange={(event) => {
                          invalidatePendingOperation();
                          setDiscountType(
                            event.target.value as SaleDiscountType,
                          );
                          setDiscountValue(0);
                          setDiscountReason('');
                        }}
                      >
                        <option value="NONE">Tanpa diskon</option>
                        <option value="AMOUNT">Nominal (Rp)</option>
                        <option value="PERCENT">Persen (%)</option>
                      </select>
                    </label>
                    {discountType !== 'NONE' && (
                      <>
                        <label>
                          <span>
                            {discountType === 'AMOUNT'
                              ? 'Nilai diskon (Rp)'
                              : 'Persentase diskon'}
                          </span>
                          <input
                            type="number"
                            min="0"
                            max={discountType === 'PERCENT' ? 100 : subtotal}
                            value={discountValue}
                            disabled={busy}
                            onChange={(event) => {
                              invalidatePendingOperation();
                              setDiscountValue(Number(event.target.value));
                            }}
                          />
                        </label>
                        <label>
                          <span>Alasan diskon</span>
                          <input
                            value={discountReason}
                            disabled={busy}
                            maxLength={200}
                            placeholder="Wajib untuk diskon"
                            onChange={(event) => {
                              invalidatePendingOperation();
                              setDiscountReason(event.target.value);
                            }}
                          />
                        </label>
                        {!discountValid && (
                          <p className="form-error">
                            Nilai dan alasan diskon harus valid.
                          </p>
                        )}
                      </>
                    )}
                  </details>
                )}

                <div className="sales-v2-payment-methods">
                  {allowedMethods.map((value) => (
                    <button
                      type="button"
                      key={value}
                      disabled={busy}
                      className={method === value ? 'active' : ''}
                      onClick={() => chooseMethod(value)}
                    >
                      <Icon
                        name={
                          value === 'CASH'
                            ? 'cash'
                            : value === 'QRIS'
                              ? 'qris'
                              : value === 'TRANSFER'
                                ? 'transfer'
                                : 'credit-debt'
                        }
                        size={20}
                      />
                      <span>{paymentLabel(value)}</span>
                    </button>
                  ))}
                </div>

                {method === 'CASH' && (
                  <div className="sales-v2-payment-panel">
                    <div className="sales-v2-quick-cash">
                      {cashOptions.map((value) => (
                        <button
                          type="button"
                          key={value}
                          disabled={busy}
                          onClick={() => {
                            invalidatePendingOperation();
                            setCashReceived(value);
                          }}
                        >
                          {value === total ? 'Uang Pas' : formatIdr(value)}
                        </button>
                      ))}
                    </div>
                    <label>
                      <span>Uang diterima</span>
                      <input
                        type="number"
                        min="0"
                        step="1000"
                        value={effectiveCashReceived}
                        disabled={busy || total === 0}
                        onChange={(event) => {
                          invalidatePendingOperation();
                          setCashReceived(Number(event.target.value));
                        }}
                      />
                    </label>
                    <div className="sales-v2-change">
                      <span>Kembalian</span>
                      <strong>{formatIdr(change)}</strong>
                    </div>
                  </div>
                )}

                {method === 'QRIS' && (
                  <div className="sales-v2-payment-panel">
                    {!qrisLoaded ? (
                      <p className="muted">Menyiapkan QRIS…</p>
                    ) : qrisImage ? (
                      <>
                        <img
                          className="sales-v2-qris"
                          src={qrisImage}
                          alt="QRIS Segeran Jiwa"
                        />
                        <label className="sales-v2-confirm-row">
                          <input
                            type="checkbox"
                            checked={qrisConfirmed}
                            disabled={busy}
                            onChange={(event) => {
                              invalidatePendingOperation();
                              setQrisConfirmed(event.target.checked);
                            }}
                          />
                          <span>Pembayaran QRIS sudah diverifikasi manual</span>
                        </label>
                      </>
                    ) : (
                      <p className="form-error">QRIS belum tersedia.</p>
                    )}
                  </div>
                )}

                {method === 'TRANSFER' && (
                  <div className="sales-v2-payment-panel">
                    <label className="sales-v2-confirm-row">
                      <input
                        type="checkbox"
                        checked={transferConfirmed}
                        disabled={busy}
                        onChange={(event) => {
                          invalidatePendingOperation();
                          setTransferConfirmed(event.target.checked);
                        }}
                      />
                      <span>Dana transfer sudah diverifikasi masuk</span>
                    </label>
                  </div>
                )}

                {method === 'CREDIT' && (
                  <div className="sales-v2-payment-panel">
                    {!customersLoaded && (
                      <p className="muted">Menyiapkan daftar pelanggan…</p>
                    )}
                    <SearchablePicker
                      label="Pelanggan Kasbon"
                      value={customerId}
                      disabled={busy || !customersLoaded}
                      options={customers.map((customer) => ({
                        id: customer.id,
                        label: customer.display_name,
                      }))}
                      onChange={(nextCustomerId) => {
                        invalidatePendingOperation();
                        setCustomerId(nextCustomerId);
                      }}
                      placeholder="Pilih pelanggan"
                      eyebrow="PILIH PELANGGAN"
                      searchPlaceholder="Cari nama pelanggan…"
                      emptyLabel="Pelanggan tidak ditemukan."
                      noun="pelanggan"
                    />
                  </div>
                )}

                <details className="sales-v2-note">
                  <summary>Catatan transaksi</summary>
                  <textarea
                    value={note}
                    disabled={busy}
                    onChange={(event) => {
                      invalidatePendingOperation();
                      setNote(event.target.value);
                    }}
                    rows={2}
                    placeholder="Opsional"
                  />
                </details>

                <button
                  className="sales-v2-pay-button"
                  type="button"
                  disabled={!canPay}
                  onClick={() => void submit()}
                >
                  <Icon name="checkout" size={19} />
                  <span>
                    {busy
                      ? 'Memproses satu transaksi...'
                      : 'Bayar ' + formatIdr(total)}
                  </span>
                </button>
              </section>
            </div>
          )}
        </>
      )}

      {variantPicker && (
        <div
          className="sales-v2-sheet-backdrop"
          onMouseDown={(event) => {
            if (event.currentTarget === event.target) {
              setVariantPicker(null);
            }
          }}
        >
          <section
            className="sales-v2-sheet sales-v2-variant-sheet"
            role="dialog"
            aria-modal="true"
            aria-label="Pilih Varian"
          >
            <div className="sales-v2-sheet-handle" />
            <header className="sales-v2-sheet-header">
              <div>
                <h2>Pilih Varian</h2>
                <span>{variantPicker.productName}</span>
              </div>
              <button type="button" onClick={() => setVariantPicker(null)}>
                Tutup
              </button>
            </header>
            <div className="sales-v2-variant-options">
              {variantPicker.variants.map((item) => {
                const unavailable =
                  item.inventory_managed && (item.available_quantity ?? 0) <= 0;
                return (
                  <button
                    type="button"
                    key={item.variant_id}
                    disabled={unavailable}
                    onClick={() => {
                      add(item);
                      setVariantPicker(null);
                    }}
                  >
                    <span>
                      <strong>{item.variant_name}</strong>
                      <small>
                        {item.inventory_managed
                          ? 'Tersedia ' + String(item.available_quantity ?? 0)
                          : item.fulfillment_mode === 'MAKE_TO_ORDER'
                            ? 'Siap dibuat'
                            : 'Siap dijual'}
                      </small>
                    </span>
                    <strong>{formatIdr(item.unit_price)}</strong>
                  </button>
                );
              })}
            </div>
          </section>
        </div>
      )}

      {success && (
        <div className="sales-v2-sheet-backdrop sales-v2-success-backdrop">
          <section
            className="sales-v2-success"
            role="dialog"
            aria-modal="true"
            aria-label="Pembayaran Berhasil"
          >
            <div className="sales-v2-success-mark" aria-hidden="true">
              <Icon name="check" size={30} />
            </div>
            <p className="eyebrow">TRANSAKSI SELESAI</p>
            <h2>Pembayaran Berhasil</h2>
            <p className="muted">{success.result.invoice_number}</p>
            <strong className="sales-v2-success-total">
              {formatIdr(success.result.total_amount)}
            </strong>
            <div className="sales-v2-success-facts">
              <span>
                Metode
                <strong>{paymentLabel(success.result.payment_method)}</strong>
              </span>
              {success.result.discount_amount > 0 && (
                <span>
                  Diskon
                  <strong>-{formatIdr(success.result.discount_amount)}</strong>
                </span>
              )}
              {success.result.payment_method === 'CASH' &&
                success.result.tendered_amount !== null && (
                  <>
                    <span>
                      Uang diterima
                      <strong>
                        {formatIdr(success.result.tendered_amount)}
                      </strong>
                    </span>
                    <span>
                      Kembalian
                      <strong>
                        {formatIdr(success.result.change_amount ?? 0)}
                      </strong>
                    </span>
                  </>
                )}
            </div>
            <div className="sales-v2-success-items">
              {success.items.map((item, index) => (
                <div key={item.productName + item.variantName + index}>
                  <span>
                    {item.productName}
                    {item.variantName !== item.productName
                      ? ' · ' + item.variantName
                      : ''}
                  </span>
                  <strong>× {item.quantity}</strong>
                </div>
              ))}
            </div>
            <div className="sales-v2-success-actions">
              <Link className="secondary-button" to="/riwayat">
                <Icon name="receipt" size={17} />
                <span>Lihat Riwayat</span>
              </Link>
              <button
                className="primary-button"
                type="button"
                onClick={() => setSuccess(null)}
              >
                <Icon name="add" size={17} />
                <span>Transaksi Baru</span>
              </button>
            </div>
          </section>
        </div>
      )}
    </main>
  );
}
