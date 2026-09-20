import { useEffect, useMemo, useState } from 'react';
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

export function SalesScreen() {
  const { authority } = useAuth();
  const [shift, setShift] = useState<Shift | null>(null);
  const [catalog, setCatalog] = useState<SalesCatalogItem[]>([]);
  const [customers, setCustomers] = useState<SaleCustomer[]>([]);
  const [qrisImage, setQrisImage] = useState<string | null>(null);
  const [cart, setCart] = useState<CartLine[]>([]);
  const [search, setSearch] = useState('');
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

  const visibleItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return catalog;
    return catalog.filter(
      (item) =>
        item.display_name.toLowerCase().includes(query) ||
        item.code.toLowerCase().includes(query) ||
        item.category_code.toLowerCase().includes(query),
    );
  }, [catalog, search]);

  const total = cart.reduce(
    (sum, line) => sum + line.item.unit_price * line.quantity,
    0,
  );

  const change = Math.max(0, cashReceived - total);

  function add(item: SalesCatalogItem) {
    setMessage('');
    setError('');
    setCart((current) => {
      const existing = current.find(
        (line) => line.item.stock_item_id === item.stock_item_id,
      );
      const nextQuantity = (existing?.quantity ?? 0) + 1;

      if (
        item.inventory_tracked &&
        item.quantity !== null &&
        nextQuantity > item.quantity
      ) {
        setError('Stok ' + item.display_name + ' tidak mencukupi.');
        return current;
      }

      if (existing) {
        return current.map((line) =>
          line.item.stock_item_id === item.stock_item_id
            ? { ...line, quantity: nextQuantity }
            : line,
        );
      }

      return [...current, { item, quantity: 1 }];
    });
  }

  function adjust(stockItemId: string, delta: number) {
    setCart((current) =>
      current.flatMap((line) => {
        if (line.item.stock_item_id !== stockItemId) return [line];
        const quantity = line.quantity + delta;
        if (quantity <= 0) return [];
        if (
          line.item.inventory_tracked &&
          line.item.quantity !== null &&
          quantity > line.item.quantity
        ) {
          setError('Stok ' + line.item.display_name + ' tidak mencukupi.');
          return [line];
        }
        return [{ ...line, quantity }];
      }),
    );
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
    if (!shift || !canPay) return;
    setBusy(true);
    setError('');
    setMessage('');

    try {
      const result = await checkoutSale({
        locationId: shift.location_id,
        items: cart.map((line) => ({
          stock_item_id: line.item.stock_item_id,
          quantity: line.quantity,
        })),
        method,
        total,
        customerId: method === 'CREDIT' ? customerId : undefined,
        note,
      });

      setMessage(
        'Penjualan berhasil. Invoice: ' + String(result.invoice_number ?? '-'),
      );
      setCart([]);
      setCashReceived(0);
      setCustomerId('');
      setQrisConfirmed(false);
      setTransferConfirmed(false);
      setNote('');
      await load();
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : 'Penjualan gagal diproses.',
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="shell sales-shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            Kembali ke Beranda
          </Link>
          <p className="eyebrow">PENJUALAN</p>
          <h1>Jual</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}
      {message && <p className="success-banner">{message}</p>}

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
          <section className="identity-card">
            <div className="section-heading">
              <div>
                <h2>Produk</h2>
                <p className="muted">
                  Pilih produk untuk ditambahkan ke keranjang.
                </p>
              </div>
              <span className="role-badge">{catalog.length} produk</span>
            </div>
            <input
              type="search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Cari nama, kode, atau kategori"
            />

            {catalog.length === 0 ? (
              <div className="empty-state">
                <strong>Master produk Next belum tersedia.</strong>
                <p>
                  Import backup Legacy terlebih dahulu. Harga tidak akan dibuat
                  atau ditebak oleh sistem.
                </p>
                {authority?.owner && (
                  <Link className="primary-link" to="/legacy-import">
                    Migrasi Master Legacy
                  </Link>
                )}
              </div>
            ) : (
              <div className="product-grid">
                {visibleItems.map((item) => {
                  const unavailable =
                    item.inventory_tracked && (item.quantity ?? 0) <= 0;
                  return (
                    <button
                      className="product-card"
                      key={item.stock_item_id}
                      type="button"
                      disabled={unavailable}
                      onClick={() => add(item)}
                    >
                      <span className="product-category">
                        {item.category_code}
                      </span>
                      <strong>{item.display_name}</strong>
                      <span>{formatIdr(item.unit_price)}</span>
                      <small>
                        {item.inventory_tracked
                          ? 'Stok: ' + String(item.quantity ?? 0)
                          : 'Dibuat saat dijual'}
                      </small>
                    </button>
                  );
                })}
              </div>
            )}
          </section>

          <section className="identity-card">
            <h2>Keranjang</h2>
            {cart.length === 0 ? (
              <p className="muted">Keranjang masih kosong.</p>
            ) : (
              <div className="stack-list">
                {cart.map((line) => (
                  <article className="cart-row" key={line.item.stock_item_id}>
                    <div>
                      <strong>{line.item.display_name}</strong>
                      <span className="muted">
                        {formatIdr(line.item.unit_price)} x {line.quantity}
                      </span>
                    </div>
                    <div className="qty-control">
                      <button
                        type="button"
                        onClick={() => adjust(line.item.stock_item_id, -1)}
                      >
                        -
                      </button>
                      <strong>{line.quantity}</strong>
                      <button
                        type="button"
                        onClick={() => adjust(line.item.stock_item_id, 1)}
                      >
                        +
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            )}

            <div className="checkout-total">
              <span>Total</span>
              <strong>{formatIdr(total)}</strong>
            </div>

            <h3>Metode Pembayaran</h3>
            <div className="payment-methods">
              {allowedMethods.map((value) => (
                <button
                  type="button"
                  key={value}
                  className={
                    method === value ? 'method-card active' : 'method-card'
                  }
                  onClick={() => setMethod(value)}
                >
                  {value === 'CASH'
                    ? 'Tunai'
                    : value === 'CREDIT'
                      ? 'Kasbon'
                      : value === 'TRANSFER'
                        ? 'Transfer'
                        : 'QRIS'}
                </button>
              ))}
            </div>

            {method === 'CASH' && (
              <div className="payment-panel">
                <label>
                  Uang diterima (Rp)
                  <input
                    type="number"
                    min="0"
                    step="1000"
                    value={cashReceived}
                    onChange={(event) =>
                      setCashReceived(Number(event.target.value))
                    }
                  />
                </label>
                <div className="checkout-total">
                  <span>Kembalian</span>
                  <strong>{formatIdr(change)}</strong>
                </div>
              </div>
            )}

            {method === 'QRIS' && (
              <div className="payment-panel">
                {qrisImage ? (
                  <>
                    <img
                      className="qris-image"
                      src={qrisImage}
                      alt="QRIS Segeran Jiwa"
                    />
                    <label className="radio-row">
                      <input
                        type="checkbox"
                        checked={qrisConfirmed}
                        onChange={(event) =>
                          setQrisConfirmed(event.target.checked)
                        }
                      />
                      Pembayaran QRIS sudah diverifikasi manual
                    </label>
                  </>
                ) : (
                  <p className="form-error">
                    QRIS belum tersedia di Next. Import setting QRIS dari backup
                    Legacy terlebih dahulu.
                  </p>
                )}
              </div>
            )}

            {method === 'TRANSFER' && (
              <div className="payment-panel">
                <label className="radio-row">
                  <input
                    type="checkbox"
                    checked={transferConfirmed}
                    onChange={(event) =>
                      setTransferConfirmed(event.target.checked)
                    }
                  />
                  Dana transfer sudah diverifikasi masuk
                </label>
              </div>
            )}

            {method === 'CREDIT' && (
              <div className="payment-panel">
                <label>
                  Pelanggan Kasbon
                  <select
                    value={customerId}
                    onChange={(event) => setCustomerId(event.target.value)}
                  >
                    <option value="">Pilih pelanggan</option>
                    {customers.map((customer) => (
                      <option value={customer.id} key={customer.id}>
                        {customer.display_name}
                      </option>
                    ))}
                  </select>
                </label>
                {customers.length === 0 && (
                  <p className="form-error">
                    Belum ada pelanggan aktif. Import master Legacy terlebih
                    dahulu.
                  </p>
                )}
              </div>
            )}

            <label>
              Catatan transaksi (opsional)
              <textarea
                value={note}
                onChange={(event) => setNote(event.target.value)}
                rows={2}
              />
            </label>

            <button
              className="primary-button checkout-button"
              type="button"
              disabled={!canPay}
              onClick={() => void submit()}
            >
              {busy ? 'Memproses...' : 'Proses Pembayaran'}
            </button>
          </section>
        </>
      )}
    </main>
  );
}
