import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { hasPermission } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import {
  checkoutSale,
  fetchManualQrisImage,
  fetchSaleCustomers,
  fetchSalesCatalog,
  type SaleCustomer,
  type SalePaymentMethod,
  type SalesCatalogItem,
} from '../sales/sales-api';
import { fetchMyOpenShift } from '../shift/shift-api';
import type { Shift } from '../shift/shift-core';

type CartLine = {
  item: SalesCatalogItem;
  quantity: number;
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
  const [cart, setCart] = useState<CartLine[]>([]);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('SEMUA');
  const [method, setMethod] = useState<SalePaymentMethod>('CASH');
  const [cashReceived, setCashReceived] = useState(0);
  const [customerId, setCustomerId] = useState('');
  const [qrisConfirmed, setQrisConfirmed] = useState(false);
  const [transferConfirmed, setTransferConfirmed] = useState(false);
  const [note, setNote] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [cartOpen, setCartOpen] = useState(false);

  const submitGuardRef = useRef(false);
  const pendingOperationIdRef = useRef<string | null>(null);

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

      const [items, customerRows, qris] = await Promise.all([
        fetchSalesCatalog(currentShift.location_id),
        fetchSaleCustomers(),
        fetchManualQrisImage().catch(() => null),
      ]);
      setCatalog(items);
      setCustomers(customerRows);
      setQrisImage(qris);
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
    if (!cartOpen) return;
    const original = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = original;
    };
  }, [cartOpen]);

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

  const total = cart.reduce(
    (sum, line) => sum + line.item.unit_price * line.quantity,
    0,
  );
  const cartQuantity = cart.reduce((sum, line) => sum + line.quantity, 0);
  const change = Math.max(0, cashReceived - total);
  const cashOptions = useMemo(() => nextCashOptions(total), [total]);

  function invalidatePendingOperation() {
    if (!submitGuardRef.current) {
      pendingOperationIdRef.current = null;
    }
  }

  function add(item: SalesCatalogItem) {
    setMessage('');
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

      return [...current, { item, quantity: 1 }];
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

  function chooseMethod(value: SalePaymentMethod) {
    invalidatePendingOperation();
    setMethod(value);
    setQrisConfirmed(false);
    setTransferConfirmed(false);
    if (value !== 'CREDIT') setCustomerId('');
    if (value !== 'CASH') setCashReceived(0);
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
    ((method === 'CASH' && cashReceived >= total) ||
      (method === 'QRIS' && Boolean(qrisImage) && qrisConfirmed) ||
      (method === 'TRANSFER' && transferConfirmed) ||
      (method === 'CREDIT' && Boolean(customerId)));

  async function submit() {
    if (!shift || !canPay || submitGuardRef.current) return;

    submitGuardRef.current = true;
    setBusy(true);
    setError('');
    setMessage('');

    const operationId = pendingOperationIdRef.current ?? crypto.randomUUID();
    pendingOperationIdRef.current = operationId;

    try {
      const result = await checkoutSale({
        operationId,
        locationId: shift.location_id,
        items: cart.map((line) => ({
          variant_id: line.item.variant_id,
          quantity: line.quantity,
        })),
        method,
        total,
        customerId: method === 'CREDIT' ? customerId : undefined,
        note,
      });

      pendingOperationIdRef.current = null;
      setMessage(
        'Penjualan berhasil. Invoice: ' + String(result.invoice_number ?? '-'),
      );
      setCart([]);
      setCashReceived(0);
      setCustomerId('');
      setQrisConfirmed(false);
      setTransferConfirmed(false);
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
      {message && <p className="success-banner sales-v2-banner">{message}</p>}

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
                <strong>{visibleItems.length}</strong>
                <span>dari {catalog.length} produk</span>
              </div>
              <div className="sales-v2-product-grid">
                {visibleItems.map((item) => {
                  const unavailable =
                    item.inventory_managed &&
                    (item.available_quantity ?? 0) <= 0;
                  const inCart =
                    cart.find(
                      (line) => line.item.variant_id === item.variant_id,
                    )?.quantity ?? 0;
                  const showVariant =
                    item.variant_code !== 'DEFAULT' ||
                    item.variant_name !== item.product_name;

                  return (
                    <button
                      className="sales-v2-product-card"
                      key={item.variant_id}
                      type="button"
                      disabled={unavailable}
                      onClick={() => add(item)}
                    >
                      <span className="sales-v2-product-name">
                        {item.product_name}
                      </span>
                      {showVariant && (
                        <span className="sales-v2-variant-name">
                          {item.variant_name}
                        </span>
                      )}
                      <strong>{formatIdr(item.unit_price)}</strong>
                      <span
                        className={
                          unavailable
                            ? 'sales-v2-stock-badge empty'
                            : 'sales-v2-stock-badge'
                        }
                      >
                        {item.inventory_managed
                          ? 'Tersedia ' + String(item.available_quantity ?? 0)
                          : item.fulfillment_mode === 'MAKE_TO_ORDER'
                            ? 'Siap dibuat'
                            : 'Siap dijual'}
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
            <span className="sales-v2-cart-count">{cartQuantity}</span>
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
                    </article>
                  ))}
                </div>

                <div className="sales-v2-total-row">
                  <span>Total</span>
                  <strong>{formatIdr(total)}</strong>
                </div>

                <div className="sales-v2-payment-methods">
                  {allowedMethods.map((value) => (
                    <button
                      type="button"
                      key={value}
                      disabled={busy}
                      className={method === value ? 'active' : ''}
                      onClick={() => chooseMethod(value)}
                    >
                      {paymentLabel(value)}
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
                        value={cashReceived}
                        disabled={busy}
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
                    {qrisImage ? (
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
                    <label>
                      <span>Pelanggan Kasbon</span>
                      <select
                        value={customerId}
                        disabled={busy}
                        onChange={(event) => {
                          invalidatePendingOperation();
                          setCustomerId(event.target.value);
                        }}
                      >
                        <option value="">Pilih pelanggan</option>
                        {customers.map((customer) => (
                          <option value={customer.id} key={customer.id}>
                            {customer.display_name}
                          </option>
                        ))}
                      </select>
                    </label>
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
                  {busy
                    ? 'Memproses satu transaksi...'
                    : 'Bayar ' + formatIdr(total)}
                </button>
              </section>
            </div>
          )}
        </>
      )}
    </main>
  );
}
