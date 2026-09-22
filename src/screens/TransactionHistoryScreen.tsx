import { FormEvent, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { hasPermission } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import {
  correctSale,
  previewSaleCorrection,
  refundSale,
  searchTransactionHistory,
  type CorrectionPreview,
  type RefundMethod,
  type RefundStockDisposition,
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
  const { authority } = useAuth();
  const canRefund =
    Boolean(authority?.owner) ||
    Boolean(authority && hasPermission(authority, 'CORRECTION_LIMITED'));
  const canCorrect = canRefund;
  const [filters, setFilters] = useState(EMPTY);
  const [rows, setRows] = useState<TransactionHistoryRow[]>([]);
  const [expanded, setExpanded] = useState<string | null>(null);
  const [refundTarget, setRefundTarget] =
    useState<TransactionHistoryRow | null>(null);
  const [stockDisposition, setStockDisposition] =
    useState<RefundStockDisposition>('RETURN_TO_STOCK');
  const [refundMethod, setRefundMethod] = useState<RefundMethod>('CASH');
  const [refundReason, setRefundReason] = useState('');
  const [refundBusy, setRefundBusy] = useState(false);
  const [correctionTarget, setCorrectionTarget] =
    useState<TransactionHistoryRow | null>(null);
  const [correctionPreview, setCorrectionPreview] =
    useState<CorrectionPreview | null>(null);
  const [correctionReason, setCorrectionReason] = useState('');
  const [correctionBusy, setCorrectionBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

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

  const refundImpact = useMemo(() => {
    if (!refundTarget) return null;
    const debt = refundTarget.customer_debt;
    const payout =
      refundTarget.payment_method === 'CREDIT'
        ? (debt?.paid_amount ?? 0)
        : refundTarget.total_amount;
    const debtCancel =
      refundTarget.payment_method === 'CREDIT' ? (debt?.balance ?? 0) : 0;
    return { payout, debtCancel };
  }, [refundTarget]);

  function submit(event: FormEvent) {
    event.preventDefault();
    void search();
  }

  function reset() {
    setFilters(EMPTY);
    void search(EMPTY);
  }

  function openRefund(row: TransactionHistoryRow) {
    setRefundTarget(row);
    setStockDisposition('RETURN_TO_STOCK');
    setRefundReason('');
    const paid =
      row.payment_method === 'CREDIT'
        ? (row.customer_debt?.paid_amount ?? 0)
        : row.total_amount;
    setRefundMethod(paid > 0 ? 'CASH' : 'NONE');
  }

  async function submitRefund(event: FormEvent) {
    event.preventDefault();
    if (!refundTarget || !refundImpact || refundBusy) return;
    if (!refundReason.trim()) {
      setError('Alasan refund wajib diisi.');
      return;
    }

    const confirmed = window.confirm(
      'Refund ' +
        refundTarget.invoice_number +
        ' akan membuat fakta reversal baru. Transaksi asli tidak diubah. Lanjutkan?',
    );
    if (!confirmed) return;

    setRefundBusy(true);
    setError('');
    setMessage('');
    try {
      await refundSale({
        saleId: refundTarget.sale_id,
        stockDisposition,
        refundMethod,
        reason: refundReason,
      });
      setMessage('Refund Transaksi berhasil dicatat.');
      setRefundTarget(null);
      await search();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Refund gagal.');
    } finally {
      setRefundBusy(false);
    }
  }

  async function openCorrection(row: TransactionHistoryRow) {
    setError('');
    setMessage('');

    if (!navigator.onLine) {
      setError(
        'Koreksi memerlukan koneksi internet aktif dan tidak diantrikan offline.',
      );
      return;
    }

    try {
      const preview = await previewSaleCorrection(row.sale_id);
      if (!preview.can_execute) {
        setError(
          'Koreksi belum dapat dilakukan: ' +
            (preview.blocker || 'aturan koreksi tidak terpenuhi.'),
        );
        return;
      }
      setCorrectionTarget(row);
      setCorrectionPreview(preview);
      setCorrectionReason('');
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Gagal menyiapkan preview Koreksi.',
      );
    }
  }

  async function submitCorrection(event: FormEvent) {
    event.preventDefault();
    if (!correctionTarget || !correctionPreview || correctionBusy) return;

    if (!navigator.onLine) {
      setError(
        'Koreksi memerlukan koneksi internet aktif dan tidak diantrikan offline.',
      );
      return;
    }

    if (!correctionReason.trim()) {
      setError('Alasan koreksi wajib diisi.');
      return;
    }

    const confirmed = window.confirm(
      'Koreksi ' +
        correctionTarget.invoice_number +
        ' akan membuat pembalikan pencatatan. Ini bukan refund pelanggan dan transaksi asli tetap utuh. Lanjutkan?',
    );
    if (!confirmed) return;

    setCorrectionBusy(true);
    setError('');
    setMessage('');
    try {
      await correctSale({
        saleId: correctionTarget.sale_id,
        reason: correctionReason,
      });
      setMessage('Koreksi Transaksi berhasil dicatat.');
      setCorrectionTarget(null);
      setCorrectionPreview(null);
      await search();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Koreksi gagal.');
    } finally {
      setCorrectionBusy(false);
    }
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link to="/">Beranda</Link>
          <p className="eyebrow">TRANSAKSI</p>
          <h1>Riwayat</h1>
          <p className="muted">
            Pencarian transaksi individual, refund, dan koreksi terkontrol.
          </p>
        </div>
      </header>

      {error && <div className="error-banner">{error}</div>}
      {message && <div className="success-banner">{message}</div>}

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
              <option value="CORRECTED">Dikoreksi</option>
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
                <div className="button-row">
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
                  {canRefund &&
                    row.status === 'COMPLETED' &&
                    !row.refund &&
                    !row.correction && (
                      <button
                        className="secondary-button"
                        type="button"
                        onClick={() => openRefund(row)}
                      >
                        Refund Transaksi
                      </button>
                    )}
                  {canCorrect &&
                    row.status === 'COMPLETED' &&
                    !row.refund &&
                    !row.correction && (
                      <button
                        className="secondary-button"
                        type="button"
                        onClick={() => void openCorrection(row)}
                      >
                        Koreksi Transaksi
                      </button>
                    )}
                </div>
                {expanded === row.sale_id && (
                  <div className="stack-list">
                    {row.items.map((item) => (
                      <div className="list-card" key={item.line_no}>
                        <strong>{item.display_name}</strong>
                        {item.variant_name &&
                          item.variant_name !== item.display_name && (
                            <span className="muted">
                              Varian: {item.variant_name}
                            </span>
                          )}
                        <span>
                          {item.quantity} x {formatIdr(item.unit_price)}
                        </span>
                        <span>{formatIdr(item.subtotal)}</span>
                        {item.line_note && (
                          <span className="muted">
                            Catatan item: {item.line_note}
                          </span>
                        )}
                      </div>
                    ))}
                    {row.discount_amount > 0 && (
                      <div className="list-card">
                        <strong>Diskon</strong>
                        <span>
                          {row.discount_type === 'PERCENT'
                            ? row.discount_value + '%'
                            : formatIdr(row.discount_value)}
                          {' · '}-{formatIdr(row.discount_amount)}
                        </span>
                        {row.discount_reason && (
                          <span className="muted">
                            {row.discount_reason}
                            {row.discount_approved_by_name
                              ? ' · ' + row.discount_approved_by_name
                              : ''}
                          </span>
                        )}
                      </div>
                    )}
                    {row.payments.map((payment, index) =>
                      payment.method === 'CASH' &&
                      payment.tendered_amount !== null ? (
                        <div
                          className="list-card"
                          key={'payment-cash-' + index}
                        >
                          <strong>Tunai</strong>
                          <span>
                            Uang diterima {formatIdr(payment.tendered_amount)}
                          </span>
                          <span>
                            Kembalian {formatIdr(payment.change_amount ?? 0)}
                          </span>
                        </div>
                      ) : null,
                    )}
                    {row.customer_debt && (
                      <p className="muted">
                        Hutang: dibayar{' '}
                        {formatIdr(row.customer_debt.paid_amount)} · sisa{' '}
                        {formatIdr(row.customer_debt.balance)} ·{' '}
                        {row.customer_debt.status}
                      </p>
                    )}
                    {row.refund && (
                      <div className="list-card">
                        <strong>Refund tercatat</strong>
                        <span>
                          {row.refund.stock_disposition} ·{' '}
                          {row.refund.refund_method}
                        </span>
                        <span>
                          Dana {formatIdr(row.refund.payout_amount)} · Piutang
                          dibatalkan{' '}
                          {formatIdr(row.refund.receivable_cancelled_amount)}
                        </span>
                        <span className="muted">{row.refund.reason}</span>
                      </div>
                    )}
                    {row.correction && (
                      <div className="list-card">
                        <strong>Koreksi / Pembalikan tercatat</strong>
                        <span>
                          {row.correction.original_payment_method} ·{' '}
                          {formatIdr(row.correction.sale_total)}
                        </span>
                        <span className="muted">
                          Transaksi asli tetap utuh. {row.correction.reason}
                        </span>
                      </div>
                    )}
                    {row.note && <p className="muted">Catatan: {row.note}</p>}
                  </div>
                )}
              </article>
            ))}
          </div>
        )}
      </section>

      {refundTarget && refundImpact && (
        <section className="identity-card">
          <div className="section-heading">
            <div>
              <p className="eyebrow">REFUND / REVERSAL</p>
              <h2>Refund Transaksi</h2>
              <p className="muted">{refundTarget.invoice_number}</p>
            </div>
            <button
              type="button"
              className="secondary-button"
              onClick={() => setRefundTarget(null)}
              disabled={refundBusy}
            >
              Tutup
            </button>
          </div>

          <form className="stack-form" onSubmit={submitRefund}>
            <label className="field-label">
              Dampak Stok
              <select
                value={stockDisposition}
                onChange={(event) =>
                  setStockDisposition(
                    event.target.value as RefundStockDisposition,
                  )
                }
              >
                <option value="RETURN_TO_STOCK">Kembali ke stok</option>
                <option value="DAMAGED_UNFIT">Rusak / tidak layak</option>
                <option value="NO_GOODS_RETURNED">Barang tidak kembali</option>
              </select>
            </label>

            <label className="field-label">
              Pengembalian dana
              <select
                value={refundMethod}
                onChange={(event) =>
                  setRefundMethod(event.target.value as RefundMethod)
                }
              >
                <option value="CASH">Tunai dari Kas Shift</option>
                <option value="TRANSFER">Transfer dari Bank</option>
                {refundImpact.payout === 0 && (
                  <option value="NONE">Tidak ada dana yang dikembalikan</option>
                )}
              </select>
            </label>

            <label className="field-label">
              Alasan
              <textarea
                rows={3}
                value={refundReason}
                onChange={(event) => setRefundReason(event.target.value)}
                placeholder="Wajib diisi"
                required
              />
            </label>

            <div className="stack-list">
              <article className="list-card">
                <strong>Dampak Stok</strong>
                <span>
                  {stockDisposition === 'RETURN_TO_STOCK'
                    ? 'Stok tracked dikembalikan ke lokasi penjualan.'
                    : stockDisposition === 'DAMAGED_UNFIT'
                      ? 'Barang rusak/tidak layak tidak menambah stok jual.'
                      : 'Barang tidak kembali; stok jual tidak bertambah.'}
                </span>
              </article>
              <article className="list-card">
                <strong>Dampak Dana</strong>
                <span>
                  {formatIdr(refundImpact.payout)} dikembalikan sekarang.
                </span>
              </article>
              <article className="list-card">
                <strong>Dampak Hutang</strong>
                <span>
                  {refundImpact.debtCancel > 0
                    ? formatIdr(refundImpact.debtCancel) +
                      ' sisa piutang dibatalkan.'
                    : 'Tidak ada sisa piutang yang dibatalkan.'}
                </span>
              </article>
              <article className="list-card">
                <strong>Dampak HPP / Laba</strong>
                <span>
                  Disposisi barang disimpan untuk reporting; transaksi asli
                  tidak ditulis ulang.
                </span>
              </article>
              <article className="list-card">
                <strong>Dampak Keuangan</strong>
                <span>
                  Refund dicatat sebagai REVERSAL, bukan biaya usaha baru.
                  {refundTarget.payment_method === 'QRIS'
                    ? ' QRIS provider tidak dibatalkan otomatis; pengembalian dilakukan melalui metode yang dipilih.'
                    : ''}
                </span>
              </article>
            </div>

            <button
              className="primary-button"
              type="submit"
              disabled={refundBusy}
            >
              {refundBusy ? 'Memproses Refund...' : 'Konfirmasi Refund'}
            </button>
          </form>
        </section>
      )}

      {correctionTarget && correctionPreview && (
        <section className="identity-card">
          <div className="section-heading">
            <div>
              <p className="eyebrow">KOREKSI / PEMBALIKAN</p>
              <h2>Koreksi Transaksi</h2>
              <p className="muted">{correctionTarget.invoice_number}</p>
            </div>
            <button
              type="button"
              className="secondary-button"
              onClick={() => {
                setCorrectionTarget(null);
                setCorrectionPreview(null);
              }}
              disabled={correctionBusy}
            >
              Tutup
            </button>
          </div>

          <div className="info-banner">
            Koreksi memperbaiki pencatatan transaksi yang salah. Ini bukan
            refund pelanggan. Transaksi asli tetap utuh dan ditautkan ke fakta
            pembalikan.
          </div>

          <form className="stack-form" onSubmit={submitCorrection}>
            <label className="field-label">
              Alasan Koreksi
              <textarea
                rows={3}
                value={correctionReason}
                onChange={(event) => setCorrectionReason(event.target.value)}
                placeholder="Contoh: produk/nominal/metode transaksi tersimpan salah"
                required
              />
            </label>

            <div className="stack-list">
              <article className="list-card">
                <strong>Dampak Stok</strong>
                <span>
                  {correctionPreview.stock.tracked_lines > 0
                    ? correctionPreview.stock.tracked_lines +
                      ' baris stok tracked dari transaksi asli akan dibalik melalui pergerakan persediaan.'
                    : 'Transaksi ini tidak memiliki baris stok tracked yang perlu dibalik.'}
                </span>
              </article>
              <article className="list-card">
                <strong>Dampak Kas / QRIS / Transfer</strong>
                <span>{correctionPreview.cash_qris_transfer}</span>
              </article>
              <article className="list-card">
                <strong>Dampak Hutang</strong>
                <span>{correctionPreview.debt}</span>
              </article>
              <article className="list-card">
                <strong>Dampak HPP / Laba</strong>
                <span>
                  {correctionPreview.hpp.message} Nilai HPP tidak diasumsikan
                  nol.
                </span>
              </article>
              <article className="list-card">
                <strong>Dampak Keuangan</strong>
                <span>{correctionPreview.finance}</span>
              </article>
            </div>

            <button
              className="primary-button"
              type="submit"
              disabled={correctionBusy}
            >
              {correctionBusy
                ? 'Memproses Koreksi...'
                : 'Konfirmasi Koreksi / Pembalikan'}
            </button>
          </form>
        </section>
      )}
    </main>
  );
}
