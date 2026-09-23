import { useEffect, useState } from 'react';
import { OperationsNav } from '../components/OperationsNav';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { hasPermission } from '../auth/permission';
import { Icon } from '../ui/Icon';
import {
  postInventoryCount,
  recordInventoryCount,
} from '../inventory/inventory-control-api';
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
  fetchShiftPackagingReconciliation,
  createShiftPackagingCount,
  fetchLocations,
  fetchMyOpenShift,
  openShift,
  postShiftExpense,
  type LocationOption,
  type ShiftExpenseApproval,
  type ShiftPackagingReconciliation,
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

  const [actualCashInput, setActualCashInput] = useState('');
  const [closing, setClosing] = useState(false);
  const [shiftMessage, setShiftMessage] = useState('');

  const [expenseCategory, setExpenseCategory] = useState('');
  const [expenseDescription, setExpenseDescription] = useState('');
  const [expenseAmount, setExpenseAmount] = useState(0);
  const [expenses, setExpenses] = useState<ShiftExpense[]>([]);
  const [expenseApprovals, setExpenseApprovals] = useState<
    ShiftExpenseApproval[]
  >([]);
  const [packagingReconciliation, setPackagingReconciliation] =
    useState<ShiftPackagingReconciliation | null>(null);
  const [openingPackagingPhysical, setOpeningPackagingPhysical] = useState<
    Record<string, string>
  >({});
  const [closingPackagingPhysical, setClosingPackagingPhysical] = useState<
    Record<string, string>
  >({});
  const [packagingBusy, setPackagingBusy] = useState(false);
  const [packagingMessage, setPackagingMessage] = useState('');
  const [expenseMessage, setExpenseMessage] = useState('');
  const [submittingExpense, setSubmittingExpense] = useState(false);

  const canCreateShiftExpense =
    authority !== null && hasPermission(authority, 'EXPENSE_SHIFT_CREATE');
  const canCountPackaging =
    authority !== null && hasPermission(authority, 'INVENTORY_COUNT');

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
      setPackagingReconciliation(null);
      setOpeningPackagingPhysical({});
      setClosingPackagingPhysical({});
      setActualCashInput('');
      setExpenseCategory('');
      setExpenseDescription('');
      setExpenseAmount(0);
      setExpenseMessage('');
      setPackagingMessage('');
      return () => {
        cancelled = true;
      };
    }

    setActualCashInput('');
    setExpenseMessage('');
    setPackagingMessage('');

    void (async () => {
      try {
        const [rows, approvals, reconciliation, packaging] = await Promise.all([
          fetchShiftExpenses(shift.id),
          fetchShiftExpenseApprovals(shift.id),
          fetchShiftReconciliation(shift.id),
          fetchShiftPackagingReconciliation(shift.id),
        ]);
        if (!cancelled) {
          setExpenses(rows);
          setExpenseApprovals(approvals);
          setRunningReconciliation(reconciliation);
          setPackagingReconciliation(packaging);
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
    setShiftMessage('');
    setSubmitting(true);
    try {
      await openShift(locationId, openingBalance);
      const updated = await fetchMyOpenShift();
      setOpeningBalance(0);
      setActualCashInput('');
      setShift(updated);
      setShiftMessage('Shift berhasil dibuka. Saldo awal sudah dikunci.');
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleClose = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!shift) return;

    const actualCash = Number(actualCashInput);
    if (
      actualCashInput.trim() === '' ||
      !Number.isFinite(actualCash) ||
      actualCash < 0
    ) {
      setError('Uang aktual wajib diisi dari hasil hitung fisik.');
      return;
    }

    setError(null);
    setShiftMessage('');
    setClosing(true);
    try {
      const variance = await closeShift(shift.id, actualCash);
      setActualCashInput('');
      setOpeningBalance(0);
      setShift(null);
      setShiftMessage(
        'Shift berhasil ditutup. Varians kas: ' + formatVariance(variance),
      );
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

  async function refreshPackaging() {
    if (!shift) return;
    const next = await fetchShiftPackagingReconciliation(shift.id);
    setPackagingReconciliation(next);
  }

  async function createPackagingCheckpoint(checkpoint: 'OPENING' | 'CLOSING') {
    if (!shift) return;
    setPackagingBusy(true);
    setPackagingMessage('');
    setError(null);
    try {
      await createShiftPackagingCount(shift.id, checkpoint);
      await refreshPackaging();
      if (checkpoint === 'OPENING') {
        setOpeningPackagingPhysical({});
      } else {
        setClosingPackagingPhysical({});
      }
      setPackagingMessage(
        checkpoint === 'OPENING'
          ? 'Snapshot opening kemasan dibuat. Hitung jumlah fisik setiap item.'
          : 'Snapshot closing kemasan dibuat. Hitung jumlah fisik setiap item.',
      );
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setPackagingBusy(false);
    }
  }

  async function savePackagingPhysical(checkpoint: 'OPENING' | 'CLOSING') {
    const reconciliation = packagingReconciliation;
    const count =
      checkpoint === 'OPENING'
        ? reconciliation?.openingCount
        : reconciliation?.closingCount;
    if (!count || count.status !== 'DRAFT') return;

    const physical =
      checkpoint === 'OPENING'
        ? openingPackagingPhysical
        : closingPackagingPhysical;
    const lines = (reconciliation?.items ?? [])
      .filter((item) =>
        checkpoint === 'OPENING'
          ? item.openingExpectedQuantity !== null
          : item.closingExpectedQuantity !== null,
      )
      .map((item) => {
        const raw = physical[item.stockItemId];
        const quantity =
          raw === undefined || raw.trim() === '' ? NaN : Number(raw);
        return {
          stockItemId: item.stockItemId,
          physicalQuantity: quantity,
        };
      });

    if (
      lines.length === 0 ||
      lines.some(
        (line) =>
          !Number.isFinite(line.physicalQuantity) || line.physicalQuantity < 0,
      )
    ) {
      setError('Semua jumlah fisik kemasan wajib diisi dengan angka valid.');
      return;
    }

    setPackagingBusy(true);
    setPackagingMessage('');
    setError(null);
    try {
      await recordInventoryCount({
        countId: count.id,
        lines,
      });
      await refreshPackaging();
      setPackagingMessage(
        'Hitungan fisik tersimpan. Posting checkpoint untuk mengunci fakta inventory.',
      );
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setPackagingBusy(false);
    }
  }

  async function postPackagingCheckpoint(checkpoint: 'OPENING' | 'CLOSING') {
    const count =
      checkpoint === 'OPENING'
        ? packagingReconciliation?.openingCount
        : packagingReconciliation?.closingCount;
    if (!count || count.status !== 'COUNTED') return;

    setPackagingBusy(true);
    setPackagingMessage('');
    setError(null);
    try {
      await postInventoryCount(count.id);
      await refreshPackaging();
      setPackagingMessage(
        checkpoint === 'OPENING'
          ? 'Opening kemasan terposting. Ledger inventory sekarang memakai hasil fisik sebagai baseline.'
          : 'Closing kemasan terposting. Selisih fisik tersimpan sebagai fakta stok opname.',
      );
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setPackagingBusy(false);
    }
  }

  function packagingQuantity(value: number | null, unit = '') {
    if (value === null) return '—';
    const formatted = value.toLocaleString('id-ID', {
      maximumFractionDigits: 3,
    });
    return unit ? formatted + ' ' + unit : formatted;
  }

  const packagingClosingStale =
    packagingReconciliation?.items.some((item) => item.closingStale) ?? false;
  const packagingClosingComplete =
    packagingReconciliation?.closingCount?.status === 'POSTED' &&
    !packagingClosingStale;

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
  const parsedActualCash =
    actualCashInput.trim() === '' ? null : Number(actualCashInput);
  const actualCashValid =
    parsedActualCash !== null &&
    Number.isFinite(parsedActualCash) &&
    parsedActualCash >= 0;
  const previewVariance = actualCashValid
    ? parsedActualCash - expectedCash
    : null;

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
      {shiftMessage && (
        <p className="success-banner shift-inline-message" role="status">
          {shiftMessage}
        </p>
      )}

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
                <h2>Rekonsiliasi Kemasan</h2>
              </div>
              <Link
                className="secondary-button link-button"
                to="/stok/kontrol?tab=COUNT&kind=PACKAGING"
              >
                Kontrol Stok
              </Link>
            </header>

            {packagingMessage && (
              <p className="success-banner shift-inline-message">
                {packagingMessage}
              </p>
            )}

            {packagingReconciliation === null ? (
              <div
                className="operations-card-skeleton shift-packaging-loading"
                aria-label="Memuat rekonsiliasi kemasan"
              >
                <span />
                <span />
              </div>
            ) : !packagingReconciliation.ready ? (
              <>
                <div className="empty-state">
                  <strong>
                    Rekonsiliasi fisik per shift belum tersedia pada backend
                    ini.
                  </strong>
                  <p>
                    Preview lama tetap fail-closed. Pemakaian teoritis di bawah
                    ini berasal dari authority C10 dan tidak dianggap sebagai
                    hitungan fisik.
                  </p>
                </div>
                {packagingReconciliation.items.length > 0 && (
                  <div className="shift-packaging-list legacy">
                    {packagingReconciliation.items.map((item) => (
                      <article key={item.stockItemId}>
                        <span
                          className="shift-packaging-icon"
                          aria-hidden="true"
                        >
                          <Icon name="product" size={18} />
                        </span>
                        <span>
                          <strong>{item.name}</strong>
                          <small>{item.code}</small>
                        </span>
                        <span>
                          <small>Pemakaian teoritis</small>
                          <strong>{item.theoreticalUsage}</strong>
                        </span>
                      </article>
                    ))}
                  </div>
                )}
              </>
            ) : packagingReconciliation.items.length === 0 ? (
              <div className="empty-state">
                <strong>Belum ada Stock Item jenis PACKAGING.</strong>
                <p>
                  Tambahkan cup/kemasan sebagai Stock Item yang dilacak
                  inventory sebelum menggunakan rekonsiliasi shift.
                </p>
              </div>
            ) : (
              <>
                <div className="shift-packaging-checkpoints">
                  <article
                    className={
                      'shift-packaging-checkpoint' +
                      (packagingReconciliation.openingCount?.status === 'POSTED'
                        ? ' complete'
                        : '')
                    }
                  >
                    <header>
                      <span className="shift-packaging-icon">
                        <Icon name="inventory" size={18} />
                      </span>
                      <span>
                        <strong>Opening Fisik</strong>
                        <small>
                          Baseline kemasan sebelum transaksi pertama
                        </small>
                      </span>
                      <span className="operations-status">
                        {packagingReconciliation.openingCount?.status ??
                          (packagingReconciliation.openingTooLate
                            ? 'TERLEWAT'
                            : 'BELUM')}
                      </span>
                    </header>

                    {packagingReconciliation.openingTooLate && (
                      <p className="shift-packaging-warning">
                        Opening fisik tidak boleh direkonstruksi setelah
                        transaksi pertama. Lakukan closing fisik pada shift ini,
                        lalu mulai shift berikutnya dengan checkpoint opening.
                      </p>
                    )}

                    {!packagingReconciliation.openingCount &&
                      !packagingReconciliation.openingTooLate &&
                      canCountPackaging && (
                        <button
                          className="secondary-button"
                          type="button"
                          disabled={packagingBusy}
                          onClick={() =>
                            void createPackagingCheckpoint('OPENING')
                          }
                        >
                          Mulai Hitung Opening
                        </button>
                      )}

                    {packagingReconciliation.openingCount?.status === 'DRAFT' &&
                      !packagingReconciliation.openingTooLate && (
                        <div className="shift-packaging-count-form">
                          {packagingReconciliation.items
                            .filter(
                              (item) => item.openingExpectedQuantity !== null,
                            )
                            .map((item) => (
                              <label key={item.stockItemId}>
                                <span>
                                  <strong>{item.name}</strong>
                                  <small>
                                    Sistem{' '}
                                    {packagingQuantity(
                                      item.openingExpectedQuantity,
                                      item.baseUnit,
                                    )}
                                  </small>
                                </span>
                                <input
                                  type="number"
                                  min="0"
                                  step="0.001"
                                  inputMode="decimal"
                                  placeholder="Fisik"
                                  value={
                                    openingPackagingPhysical[
                                      item.stockItemId
                                    ] ?? ''
                                  }
                                  onChange={(event) =>
                                    setOpeningPackagingPhysical((current) => ({
                                      ...current,
                                      [item.stockItemId]: event.target.value,
                                    }))
                                  }
                                />
                              </label>
                            ))}
                          <button
                            className="primary-button"
                            type="button"
                            disabled={packagingBusy}
                            onClick={() =>
                              void savePackagingPhysical('OPENING')
                            }
                          >
                            Simpan Hitungan Opening
                          </button>
                        </div>
                      )}

                    {packagingReconciliation.openingCount?.status ===
                      'COUNTED' &&
                      !packagingReconciliation.openingTooLate && (
                        <div className="shift-packaging-post-row">
                          <span>
                            Fisik sudah dicatat. Posting untuk mengunci
                            baseline.
                          </span>
                          <button
                            className="primary-button"
                            type="button"
                            disabled={packagingBusy}
                            onClick={() =>
                              void postPackagingCheckpoint('OPENING')
                            }
                          >
                            Posting Opening
                          </button>
                        </div>
                      )}

                    {packagingReconciliation.openingCount?.status ===
                      'POSTED' && (
                      <p className="shift-packaging-complete-note">
                        Opening terkunci pada inventory authority.
                      </p>
                    )}
                  </article>

                  <article
                    className={
                      'shift-packaging-checkpoint' +
                      (packagingClosingComplete ? ' complete' : '')
                    }
                  >
                    <header>
                      <span className="shift-packaging-icon">
                        <Icon name="check" size={18} />
                      </span>
                      <span>
                        <strong>Closing Fisik</strong>
                        <small>
                          Hitung setelah transaksi selesai, sebelum tutup shift
                        </small>
                      </span>
                      <span className="operations-status">
                        {packagingReconciliation.closingCount?.status ??
                          'BELUM'}
                      </span>
                    </header>

                    {(!packagingReconciliation.closingCount ||
                      packagingClosingStale) &&
                      canCountPackaging && (
                        <button
                          className="secondary-button"
                          type="button"
                          disabled={packagingBusy}
                          onClick={() =>
                            void createPackagingCheckpoint('CLOSING')
                          }
                        >
                          {packagingClosingStale
                            ? 'Hitung Ulang Closing'
                            : 'Mulai Hitung Closing'}
                        </button>
                      )}

                    {packagingReconciliation.closingCount?.status ===
                      'DRAFT' && (
                      <div className="shift-packaging-count-form">
                        {packagingReconciliation.items
                          .filter(
                            (item) => item.closingExpectedQuantity !== null,
                          )
                          .map((item) => (
                            <label key={item.stockItemId}>
                              <span>
                                <strong>{item.name}</strong>
                                <small>
                                  Expected{' '}
                                  {packagingQuantity(
                                    item.closingExpectedQuantity,
                                    item.baseUnit,
                                  )}
                                </small>
                              </span>
                              <input
                                type="number"
                                min="0"
                                step="0.001"
                                inputMode="decimal"
                                placeholder="Fisik"
                                value={
                                  closingPackagingPhysical[item.stockItemId] ??
                                  ''
                                }
                                onChange={(event) =>
                                  setClosingPackagingPhysical((current) => ({
                                    ...current,
                                    [item.stockItemId]: event.target.value,
                                  }))
                                }
                              />
                            </label>
                          ))}
                        <button
                          className="primary-button"
                          type="button"
                          disabled={packagingBusy}
                          onClick={() => void savePackagingPhysical('CLOSING')}
                        >
                          Simpan Hitungan Closing
                        </button>
                      </div>
                    )}

                    {packagingReconciliation.closingCount?.status ===
                      'COUNTED' && (
                      <div className="shift-packaging-post-row">
                        <span>
                          Fisik sudah dicatat. Posting untuk menyimpan varians
                          sebagai fakta inventory.
                        </span>
                        <button
                          className="primary-button"
                          type="button"
                          disabled={packagingBusy}
                          onClick={() =>
                            void postPackagingCheckpoint('CLOSING')
                          }
                        >
                          Posting Closing
                        </button>
                      </div>
                    )}

                    {packagingClosingStale && (
                      <p className="shift-packaging-warning">
                        Ada pergerakan stok setelah snapshot closing. Gunakan
                        Hitung Ulang Closing agar expected dan fisik memakai
                        snapshot terbaru.
                      </p>
                    )}

                    {packagingClosingComplete && (
                      <p className="shift-packaging-complete-note">
                        Closing terposting dan tidak ada pergerakan stok sesudah
                        snapshot.
                      </p>
                    )}
                  </article>
                </div>

                <div
                  className="shift-packaging-reconciliation-grid"
                  aria-label="Rekonsiliasi kemasan per item"
                >
                  {packagingReconciliation.items.map((item) => {
                    const expectedClosing =
                      item.closingExpectedQuantity ??
                      item.currentExpectedQuantity;
                    return (
                      <article
                        className={
                          'shift-packaging-reconciliation-card' +
                          (item.closingStale ? ' stale' : '')
                        }
                        key={item.stockItemId}
                      >
                        <header>
                          <span className="shift-packaging-icon">
                            <Icon name="product" size={18} />
                          </span>
                          <span>
                            <strong>{item.name}</strong>
                            <small>
                              {item.code} · {item.baseUnit}
                            </small>
                          </span>
                          {!item.inventoryTracked && (
                            <span className="operations-status warning">
                              TIDAK DILACAK
                            </span>
                          )}
                        </header>
                        <dl>
                          <div>
                            <dt>Awal Fisik</dt>
                            <dd>
                              {packagingQuantity(
                                item.openingPhysicalQuantity,
                                item.baseUnit,
                              )}
                            </dd>
                          </div>
                          <div>
                            <dt>Pemakaian Teoritis</dt>
                            <dd>
                              {packagingQuantity(
                                item.theoreticalUsage,
                                item.baseUnit,
                              )}
                            </dd>
                          </div>
                          <div>
                            <dt>Expected Closing</dt>
                            <dd>
                              {packagingQuantity(
                                expectedClosing,
                                item.baseUnit,
                              )}
                            </dd>
                          </div>
                          <div>
                            <dt>Fisik Closing</dt>
                            <dd>
                              {packagingQuantity(
                                item.closingPhysicalQuantity,
                                item.baseUnit,
                              )}
                            </dd>
                          </div>
                          <div
                            className={
                              item.variance === null
                                ? 'variance neutral'
                                : item.variance === 0
                                  ? 'variance neutral'
                                  : item.variance > 0
                                    ? 'variance positive'
                                    : 'variance negative'
                            }
                          >
                            <dt>Selisih</dt>
                            <dd>
                              {packagingQuantity(item.variance, item.baseUnit)}
                            </dd>
                          </div>
                        </dl>
                      </article>
                    );
                  })}
                </div>

                <div className="purchase-authority-note">
                  <strong>
                    Satu authority inventory, bukan engine cup kedua.
                  </strong>
                  <span>
                    Opening dan closing adalah Stock Opname yang ditautkan ke
                    shift. Pemakaian teoritis berasal dari snapshot komponen
                    transaksi. Selisih hanya muncul setelah jumlah fisik benar
                    benar dicatat.
                  </span>
                </div>
              </>
            )}
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
                <strong>
                  {actualCashValid && parsedActualCash !== null
                    ? formatIdr(parsedActualCash)
                    : 'Belum diisi'}
                </strong>
              </div>
              <div
                className={
                  previewVariance === null || previewVariance === 0
                    ? 'variance neutral'
                    : previewVariance > 0
                      ? 'variance positive'
                      : 'variance negative'
                }
              >
                <span>Preview Varians</span>
                <strong>
                  {previewVariance === null
                    ? '—'
                    : formatVariance(previewVariance)}
                </strong>
              </div>
            </div>

            <form onSubmit={handleClose} className="stack-form">
              <label>
                Uang Aktual di Laci
                <input
                  type="number"
                  step="1000"
                  min="0"
                  inputMode="numeric"
                  value={actualCashInput}
                  placeholder="Masukkan hasil hitung fisik"
                  onChange={(e) => {
                    setError(null);
                    setActualCashInput(e.target.value);
                  }}
                  required
                />
              </label>
              <div
                className={
                  'shift-closing-warning' +
                  (packagingClosingComplete ? ' complete' : '')
                }
              >
                <strong>
                  {packagingClosingComplete
                    ? 'Kas dan kemasan siap ditinjau'
                    : 'Sebelum menutup shift'}
                </strong>
                <span>
                  {packagingClosingComplete
                    ? 'Closing kemasan sudah terposting tanpa pergerakan stok setelah snapshot. Tetap pastikan kas fisik sudah dihitung.'
                    : 'Pastikan kas fisik sudah dihitung. Jika kemasan dilacak, selesaikan closing fisik di Rekonsiliasi Kemasan. Shift tidak mengarang angka fisik yang belum dicatat.'}
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
                  disabled={
                    closing || !runningReconciliation || !actualCashValid
                  }
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
