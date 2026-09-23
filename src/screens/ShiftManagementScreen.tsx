import { useEffect, useState } from 'react';
import { OperationsNav } from '../components/OperationsNav';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { hasPermission } from '../auth/permission';
import { Icon } from '../ui/Icon';
import {
  canCloseShift,
  formatIdr,
  formatVariance,
  toShiftErrorMessage,
  type Reconciliation,
  type Shift,
  type ShiftExpense,
} from '../shift/shift-core';
import {
  closeShift,
  fetchShiftExpenseApprovals,
  fetchShiftExpenses,
  fetchShiftReconciliation,
  fetchShiftPackagingUsage,
  fetchLocations,
  fetchMyOpenShift,
  openShift,
  postShiftExpense,
  type LocationOption,
  type ShiftExpenseApproval,
} from '../shift/shift-api';

export function ShiftManagementScreen() {
  const { authority } = useAuth();
  const [shift, setShift] = useState<Shift | null>(null);
  const [runningReconciliation, setRunningReconciliation] =
    useState<Reconciliation | null>(null);
  const [loading, setLoading] = useState(true);
  const [locationsLoading, setLocationsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [locationId, setLocationId] = useState('');
  const [locations, setLocations] = useState<LocationOption[]>([]);
  const [openingBalance, setOpeningBalance] = useState(0);
  const [submitting, setSubmitting] = useState(false);

  const [actualCash, setActualCash] = useState(0);
  const [closing, setClosing] = useState(false);

  const [expenseCategory, setExpenseCategory] = useState('');
  const [expenseDescription, setExpenseDescription] = useState('');
  const [expenseAmount, setExpenseAmount] = useState(0);
  const [expenses, setExpenses] = useState<ShiftExpense[]>([]);
  const [expenseApprovals, setExpenseApprovals] = useState<
    ShiftExpenseApproval[]
  >([]);
  const [packagingUsage, setPackagingUsage] = useState<{
    ready: boolean;
    items: Array<{
      stockItemId: string;
      code: string;
      name: string;
      theoreticalUsage: number;
    }>;
  }>({ ready: true, items: [] });
  const [expenseMessage, setExpenseMessage] = useState('');
  const [submittingExpense, setSubmittingExpense] = useState(false);

  const canCreateShiftExpense =
    authority !== null && hasPermission(authority, 'EXPENSE_SHIFT_CREATE');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const locationPromise = fetchLocations()
        .then((locs) => {
          if (cancelled) return;
          setLocations(locs);
          if (locs.length > 0) setLocationId(locs[0].id);
        })
        .catch((err) => {
          if (!cancelled) setError(toShiftErrorMessage(err));
        })
        .finally(() => {
          if (!cancelled) setLocationsLoading(false);
        });

      try {
        const currentShift = await fetchMyOpenShift();
        if (cancelled) return;
        setShift(currentShift);
      } catch (err) {
        if (!cancelled) setError(toShiftErrorMessage(err));
      } finally {
        if (!cancelled) setLoading(false);
      }

      void locationPromise;
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    if (!shift) {
      setExpenses([]);
      setExpenseApprovals([]);
      setRunningReconciliation(null);
      setPackagingUsage({ ready: true, items: [] });
      return () => {
        cancelled = true;
      };
    }

    void (async () => {
      try {
        const [rows, approvals, reconciliation, packaging] = await Promise.all([
          fetchShiftExpenses(shift.id),
          fetchShiftExpenseApprovals(shift.id),
          fetchShiftReconciliation(shift.id),
          fetchShiftPackagingUsage(shift.id),
        ]);
        if (!cancelled) {
          setExpenses(rows);
          setExpenseApprovals(approvals);
          setRunningReconciliation(reconciliation);
          setPackagingUsage(packaging);
        }
      } catch (err) {
        if (!cancelled) setError(toShiftErrorMessage(err));
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [shift]);

  const handleOpen = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await openShift(locationId, openingBalance);
      const updated = await fetchMyOpenShift();
      setShift(updated);
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleClose = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!shift) return;
    setError(null);
    setClosing(true);
    try {
      const variance = await closeShift(shift.id, actualCash);
      alert(`Shift ditutup. Varians: ${formatVariance(variance)}`);
      setShift(null);
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setClosing(false);
    }
  };

  const handleShiftExpense = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!shift) return;
    setError(null);
    setSubmittingExpense(true);
    try {
      const result = await postShiftExpense(
        expenseCategory,
        expenseDescription,
        expenseAmount,
      );
      setExpenseMessage(
        result.status === 'PENDING'
          ? 'Menunggu persetujuan Owner.'
          : 'Pengeluaran berhasil dicatat.',
      );
      const [rows, approvals, reconciliation] = await Promise.all([
        fetchShiftExpenses(shift.id),
        fetchShiftExpenseApprovals(shift.id),
        fetchShiftReconciliation(shift.id),
      ]);
      setExpenses(rows);
      setExpenseApprovals(approvals);
      setRunningReconciliation(reconciliation);
      setExpenseCategory('');
      setExpenseDescription('');
      setExpenseAmount(0);
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setSubmittingExpense(false);
    }
  };

  if (loading) {
    return (
      <main className="shell operations-shell shift-operations-screen">
        <header className="topbar operations-header">
          <div>
            <p className="eyebrow">OPERASIONAL · SHIFT</p>
            <h1>Shift Saya</h1>
          </div>
        </header>
        <div
          className="operations-card-skeleton shift-loading"
          aria-label="Memuat shift"
        >
          <span />
          <span />
          <span />
        </div>
      </main>
    );
  }

  const expectedCash = runningReconciliation?.expected_cash ?? 0;
  const previewVariance = actualCash - expectedCash;

  return (
    <main className="shell operations-shell shift-operations-screen">
      <header className="topbar operations-header">
        <div>
          <p className="eyebrow">OPERASIONAL · SHIFT</p>
          <h1>Shift Saya</h1>
          <p className="muted">
            Opening, kas berjalan, pengeluaran, closing, dan rekonsiliasi dalam
            satu alur.
          </p>
        </div>
        {shift && <span className="operations-status">SHIFT AKTIF</span>}
      </header>

      <OperationsNav />

      {error && <p className="error-banner">{error}</p>}

      {canCloseShift(shift) && shift ? (
        <>
          <section className="shift-active-hero">
            <div>
              <p className="eyebrow">STATUS</p>
              <h2>Shift Aktif</h2>
              <p>Dibuka {new Date(shift.opened_at).toLocaleString('id-ID')}</p>
            </div>
            <Link className="primary-link shift-sale-link" to="/jual">
              Lanjut Jual
            </Link>
          </section>

          <section className="shift-kpi-grid" aria-label="Ringkasan shift">
            <article>
              <span className="shift-kpi-icon">
                <Icon name="cash" size={19} />
              </span>
              <span>Saldo Awal</span>
              <strong>{formatIdr(shift.opening_balance)}</strong>
            </article>
            <article>
              <span className="shift-kpi-icon">
                <Icon name="cash-payment" size={19} />
              </span>
              <span>Kas Berjalan</span>
              <strong>
                {runningReconciliation
                  ? formatIdr(runningReconciliation.expected_cash)
                  : 'Memuat...'}
              </strong>
            </article>
            <article>
              <span className="shift-kpi-icon">
                <Icon name="sales" size={19} />
              </span>
              <span>Penjualan Tunai</span>
              <strong>
                {runningReconciliation
                  ? formatIdr(runningReconciliation.sale_total)
                  : 'Memuat...'}
              </strong>
            </article>
            <article>
              <span className="shift-kpi-icon">
                <Icon name="debt" size={19} />
              </span>
              <span>Uang Keluar</span>
              <strong>
                {runningReconciliation
                  ? formatIdr(runningReconciliation.cash_out_total)
                  : 'Memuat...'}
              </strong>
            </article>
          </section>

          <section className="shift-action-grid">
            <Link to="/rekonsiliasi" className="shift-action-card">
              <span className="shift-action-icon">
                <Icon name="cash-payment" size={22} />
              </span>
              <strong>Rekonsiliasi</strong>
              <span>Expected, aktual, dan varians shift</span>
            </Link>
            <Link
              to="/stok/kontrol?tab=COUNT&kind=PACKAGING"
              className="shift-action-card"
            >
              <span className="shift-action-icon">
                <Icon name="inventory" size={22} />
              </span>
              <strong>Kontrol Kemasan</strong>
              <span>Hitung fisik cup/kemasan melalui inventory Stock Item</span>
            </Link>
            <Link to="/handover" className="shift-action-card">
              <span className="shift-action-icon">
                <Icon name="share" size={22} />
              </span>
              <strong>Handover</strong>
              <span>Serah terima operasional tanpa mengubah fakta shift</span>
            </Link>
          </section>

          <section className="operations-panel shift-reconciliation-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">REKONSILIASI BERJALAN</p>
                <h2>Kas Shift</h2>
              </div>
              <Link className="secondary-button link-button" to="/rekonsiliasi">
                Rekonsiliasi
              </Link>
            </header>
            <p className="muted">
              Kas Berjalan = saldo awal + transaksi tunai + uang masuk - refund
              - uang keluar + penyesuaian. QRIS, transfer, dan kasbon tidak
              menambah kas laci.
            </p>
            {runningReconciliation && (
              <dl className="shift-reconciliation-breakdown">
                <div>
                  <dt>Penjualan Tunai</dt>
                  <dd>{formatIdr(runningReconciliation.sale_total)}</dd>
                </div>
                <div>
                  <dt>Refund</dt>
                  <dd>-{formatIdr(runningReconciliation.refund_total)}</dd>
                </div>
                <div>
                  <dt>Uang Masuk</dt>
                  <dd>{formatIdr(runningReconciliation.cash_in_total)}</dd>
                </div>
                <div>
                  <dt>Uang Keluar</dt>
                  <dd>-{formatIdr(runningReconciliation.cash_out_total)}</dd>
                </div>
                <div>
                  <dt>Penyesuaian</dt>
                  <dd>{formatIdr(runningReconciliation.adjustment_total)}</dd>
                </div>
                <div className="strong">
                  <dt>Expected Cash</dt>
                  <dd>{formatIdr(runningReconciliation.expected_cash)}</dd>
                </div>
              </dl>
            )}
          </section>

          {canCreateShiftExpense && (
            <section className="operations-panel shift-expense-panel">
              <header className="operations-panel-header">
                <div>
                  <p className="eyebrow">KAS SHIFT</p>
                  <h2>Catat Pengeluaran Shift</h2>
                </div>
              </header>
              <form
                onSubmit={handleShiftExpense}
                className="stack-form shift-expense-form"
              >
                <label>
                  Kategori
                  <input
                    type="text"
                    value={expenseCategory}
                    onChange={(e) => setExpenseCategory(e.target.value)}
                    placeholder="Contoh: OPERASIONAL"
                    required
                  />
                </label>
                <label>
                  Deskripsi
                  <input
                    type="text"
                    value={expenseDescription}
                    onChange={(e) => setExpenseDescription(e.target.value)}
                    placeholder="Keperluan pengeluaran"
                    required
                  />
                </label>
                <label>
                  Jumlah (Rp)
                  <input
                    type="number"
                    min="1"
                    step="1000"
                    value={expenseAmount}
                    onChange={(e) => setExpenseAmount(Number(e.target.value))}
                    required
                  />
                </label>
                <button
                  className="primary-button"
                  type="submit"
                  disabled={submittingExpense}
                >
                  {submittingExpense
                    ? 'Mencatat...'
                    : 'Catat Pengeluaran Shift'}
                </button>
              </form>

              {expenseMessage && (
                <p className="success-banner shift-inline-message">
                  {expenseMessage}
                </p>
              )}

              {(expenseApprovals.length > 0 || expenses.length > 0) && (
                <div className="shift-expense-history-grid">
                  <section>
                    <h3>Status Approval</h3>
                    {expenseApprovals.length === 0 ? (
                      <p className="operations-empty">
                        Tidak ada approval pada shift ini.
                      </p>
                    ) : (
                      <div className="inventory-control-list">
                        {expenseApprovals.map((request) => (
                          <article key={request.request_id}>
                            <header>
                              <span>
                                <strong>{request.category_code}</strong>
                                <small>{request.description}</small>
                              </span>
                              <span className="operations-status">
                                {request.status}
                              </span>
                            </header>
                            <p>{formatIdr(request.amount)}</p>
                          </article>
                        ))}
                      </div>
                    )}
                  </section>
                  <section>
                    <h3>Pengeluaran Shift Ini</h3>
                    {expenses.length === 0 ? (
                      <p className="operations-empty">
                        Belum ada pengeluaran terposting.
                      </p>
                    ) : (
                      <div className="inventory-control-list">
                        {expenses.map((expense) => (
                          <article key={expense.id}>
                            <header>
                              <span>
                                <strong>{expense.category_code}</strong>
                                <small>{expense.description}</small>
                              </span>
                              <strong>{formatIdr(expense.amount)}</strong>
                            </header>
                          </article>
                        ))}
                      </div>
                    )}
                  </section>
                </div>
              )}
            </section>
          )}

          <section className="operations-panel shift-packaging-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">KEMASAN SHIFT</p>
                <h2>Kontrol Kemasan</h2>
              </div>
              <Link
                className="secondary-button link-button"
                to="/stok/kontrol?tab=COUNT&kind=PACKAGING"
              >
                Hitung Fisik
              </Link>
            </header>

            {!packagingUsage.ready ? (
              <div className="empty-state">
                <strong>Fakta konsumsi kemasan V2 belum dipromosikan.</strong>
                <p>
                  Tampilan theoretical usage akan aktif setelah schema C2
                  Product/Variant dipromosikan pada gate RC2. Shift tetap dapat
                  berjalan.
                </p>
              </div>
            ) : packagingUsage.items.length === 0 ? (
              <p className="operations-empty">
                Belum ada konsumsi kemasan dari transaksi V2 pada shift ini.
              </p>
            ) : (
              <div className="shift-packaging-list">
                {packagingUsage.items.map((item) => (
                  <article key={item.stockItemId}>
                    <span className="shift-packaging-icon" aria-hidden="true">
                      <Icon name="product" size={18} />
                    </span>
                    <span>
                      <strong>{item.name}</strong>
                      <small>{item.code}</small>
                    </span>
                    <span>
                      <small>Theoretical usage</small>
                      <strong>{item.theoreticalUsage}</strong>
                    </span>
                  </article>
                ))}
              </div>
            )}

            <div className="purchase-authority-note">
              <strong>Fisik tetap melalui inventory Stock Item.</strong>
              <span>
                Hitung closing fisik pada Kontrol Stok. C5-B tidak membuat
                engine cup kedua dan tidak mengubah stok dari angka theoretical.
              </span>
            </div>
          </section>

          <section className="operations-panel shift-closing-card">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">CLOSING</p>
                <h2>Tutup Shift</h2>
              </div>
              <span className="operations-status">HITUNG FISIK</span>
            </header>

            <div className="shift-closing-summary">
              <div>
                <span>Expected Cash</span>
                <strong>
                  {runningReconciliation
                    ? formatIdr(runningReconciliation.expected_cash)
                    : 'Memuat...'}
                </strong>
              </div>
              <div>
                <span>Uang Aktual di Laci</span>
                <strong>{formatIdr(actualCash)}</strong>
              </div>
              <div
                className={
                  previewVariance === 0
                    ? 'variance neutral'
                    : previewVariance > 0
                      ? 'variance positive'
                      : 'variance negative'
                }
              >
                <span>Preview Varians</span>
                <strong>{formatVariance(previewVariance)}</strong>
              </div>
            </div>

            <form onSubmit={handleClose} className="stack-form">
              <label>
                Uang Aktual di Laci
                <input
                  type="number"
                  step="1000"
                  value={actualCash}
                  onChange={(e) => setActualCash(Number(e.target.value))}
                  required
                />
              </label>
              <div className="shift-closing-warning">
                <strong>Sebelum menutup shift</strong>
                <span>
                  Pastikan kas fisik sudah dihitung. Untuk cup/kemasan, gunakan
                  Kontrol Kemasan agar expected dan fisik tercatat melalui
                  inventory authority.
                </span>
              </div>
              <div className="button-row">
                <Link
                  className="secondary-button link-button"
                  to="/stok/kontrol?tab=COUNT&kind=PACKAGING"
                >
                  Kontrol Kemasan
                </Link>
                <button
                  className="primary-button"
                  type="submit"
                  disabled={closing || !runningReconciliation}
                >
                  {closing ? 'Menutup…' : 'Tutup Shift'}
                </button>
              </div>
            </form>
          </section>
        </>
      ) : (
        <section className="operations-panel shift-opening-card">
          <header className="operations-panel-header">
            <div>
              <p className="eyebrow">OPENING</p>
              <h2>Buka Shift Baru</h2>
              <p className="muted">
                Pilih lokasi kerja dan saldo awal sebelum transaksi pertama.
              </p>
            </div>
          </header>
          <form onSubmit={handleOpen} className="stack-form">
            <label>
              Lokasi
              <select
                value={locationId}
                onChange={(e) => setLocationId(e.target.value)}
                disabled={locationsLoading}
                required
              >
                {locations.map((loc) => (
                  <option key={loc.id} value={loc.id}>
                    {loc.label}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Saldo Awal (Rp)
              <input
                type="number"
                step="1000"
                min="0"
                value={openingBalance}
                onChange={(e) => setOpeningBalance(Number(e.target.value))}
                required
              />
            </label>
            <div className="shift-opening-source">
              <span>Sumber saldo awal</span>
              <strong>
                {openingBalance > 0 ? 'Kas Utama' : 'Tanpa saldo awal'}
              </strong>
            </div>
            <button
              className="primary-button"
              type="submit"
              disabled={submitting || !locationId}
            >
              {locationsLoading
                ? 'Menyiapkan lokasi…'
                : submitting
                  ? 'Membuka…'
                  : 'Buka Shift'}
            </button>
          </form>
        </section>
      )}
    </main>
  );
}
