import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  searchTransactionHistory,
  type TransactionHistoryFilters,
  type TransactionHistoryRow,
} from '../history/history-api';

function formatIdr(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

const EMPTY = {
  dateFrom: '',
  dateTo: '',
  invoiceNumber: '',
  product: '',
  user: '',
  paymentMethod: '',
  amountMin: '',
  amountMax: '',
  status: '',
};

export function TransactionHistoryScreen() {
  const [filters, setFilters] = useState(EMPTY);
  const [rows, setRows] = useState<TransactionHistoryRow[]>([]);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function search(next = filters) {
    setLoading(true);
    setError('');
    try {
      const query: TransactionHistoryFilters = {
        dateFrom: next.dateFrom || undefined,
        dateTo: next.dateTo || undefined,
        invoiceNumber: next.invoiceNumber || undefined,
        product: next.product || undefined,
        user: next.user || undefined,
        paymentMethod: next.paymentMethod || undefined,
        amountMin: next.amountMin ? Number(next.amountMin) : undefined,
        amountMax: next.amountMax ? Number(next.amountMax) : undefined,
        status: next.status || undefined,
        limit: 100,
      };
      setRows(await searchTransactionHistory(query));
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Gagal memuat Riwayat.',
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void search(EMPTY);
  }, []);

  function submit(event: FormEvent) {
    event.preventDefault();
    void search();
  }

  function reset() {
    setFilters(EMPTY);
    void search(EMPTY);
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link to="/">Beranda</Link>
          <p className="eyebrow">TRANSAKSI</p>
          <h1>Riwayat</h1>
          <p className="muted">
            Pencarian transaksi individual, bukan laporan agregat.
          </p>
        </div>
      </header>

      {error && <div className="error-banner">{error}</div>}

      <section className="identity-card">
        <form className="compact-grid-form" onSubmit={submit}>
          <label className="field-label">
            Tanggal / Hari Usaha - dari
            <input
              type="date"
              value={filters.dateFrom}
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  dateFrom: event.target.value,
                }))
              }
            />
          </label>
          <label className="field-label">
            Tanggal / Hari Usaha - sampai
            <input
              type="date"
              value={filters.dateTo}
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  dateTo: event.target.value,
                }))
              }
            />
          </label>
          <label className="field-label">
            Nomor Transaksi
            <input
              value={filters.invoiceNumber}
              placeholder="SJ-..."
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  invoiceNumber: event.target.value,
                }))
              }
            />
          </label>
          <label className="field-label">
            Produk
            <input
              value={filters.product}
              placeholder="Nama / kode produk"
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  product: event.target.value,
                }))
              }
            />
          </label>
          <label className="field-label">
            Pengguna
            <input
              value={filters.user}
              placeholder="Nama / username"
              onChange={(event) =>
                setFilters((value) => ({ ...value, user: event.target.value }))
              }
            />
          </label>
          <label className="field-label">
            Metode Pembayaran
            <select
              value={filters.paymentMethod}
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  paymentMethod: event.target.value,
                }))
              }
            >
              <option value="">Semua</option>
              <option value="CASH">Tunai</option>
              <option value="QRIS">QRIS</option>
              <option value="TRANSFER">Transfer</option>
              <option value="CREDIT">Hutang</option>
            </select>
          </label>
          <label className="field-label">
            Nominal minimum (Rp)
            <input
              type="number"
              min="0"
              value={filters.amountMin}
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  amountMin: event.target.value,
                }))
              }
            />
          </label>
          <label className="field-label">
            Nominal maksimum (Rp)
            <input
              type="number"
              min="0"
              value={filters.amountMax}
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  amountMax: event.target.value,
                }))
              }
            />
          </label>
          <label className="field-label">
            Status
            <select
              value={filters.status}
              onChange={(event) =>
                setFilters((value) => ({
                  ...value,
                  status: event.target.value,
                }))
              }
            >
              <option value="">Semua</option>
              <option value="COMPLETED">Selesai</option>
              <option value="VOID">Batal</option>
              <option value="REFUNDED">Dikembalikan</option>
            </select>
          </label>
          <div className="button-row">
            <button className="primary-button" type="submit" disabled={loading}>
              {loading ? 'Mencari...' : 'Cari Riwayat'}
            </button>
            <button
              className="secondary-button"
              type="button"
              onClick={reset}
              disabled={loading}
            >
              Reset Filter
            </button>
          </div>
        </form>
      </section>

      <section className="identity-card">
        <div className="section-heading">
          <div>
            <h2>Transaksi</h2>
            <p className="muted">{rows.length} transaksi ditampilkan.</p>
          </div>
        </div>

        {loading && rows.length === 0 ? (
          <p className="muted">Memuat Riwayat...</p>
        ) : rows.length === 0 ? (
          <p className="empty-state">Tidak ada transaksi sesuai filter.</p>
        ) : (
          <div className="stack-list">
            {rows.map((row) => (
              <article className="list-card" key={row.sale_id}>
                <div className="section-heading">
                  <div>
                    <strong>{row.invoice_number}</strong>
                    <p className="muted">
                      Hari Usaha {row.business_date} -{' '}
                      {formatTime(row.created_at)}
                    </p>
                  </div>
                  <strong>{formatIdr(row.total_amount)}</strong>
                </div>
                <p>
                  {row.payment_method || 'Metode tidak tersedia'} - {row.status}
                </p>
                <p className="muted">
                  {row.cashier_name}
                  {row.cashier_username
                    ? ' (@' + row.cashier_username + ')'
                    : ''}{' '}
                  - {row.location_name}
                  {row.customer_name ? ' - ' + row.customer_name : ''}
                </p>
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() =>
                    setExpanded((value) =>
                      value === row.sale_id ? null : row.sale_id,
                    )
                  }
                >
                  {expanded === row.sale_id ? 'Tutup Detail' : 'Lihat Detail'}
                </button>
                {expanded === row.sale_id && (
                  <div className="stack-list">
                    {row.items.map((item) => (
                      <div className="list-card" key={item.line_no}>
                        <strong>{item.display_name}</strong>
                        <span>
                          {item.quantity} x {formatIdr(item.unit_price)}
                        </span>
                        <span>{formatIdr(item.subtotal)}</span>
                      </div>
                    ))}
                    {row.note && <p className="muted">Catatan: {row.note}</p>}
                  </div>
                )}
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
