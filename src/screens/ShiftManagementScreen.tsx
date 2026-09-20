import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { hasPermission } from '../auth/permission';
import {
  canCloseShift,
  formatIdr,
  formatVariance,
  toShiftErrorMessage,
  type Shift,
  type ShiftExpense,
} from '../shift/shift-core';
import {
  closeShift,
  fetchShiftExpenseApprovals,
  fetchShiftExpenses,
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
  const [loading, setLoading] = useState(true);
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
  const [expenseMessage, setExpenseMessage] = useState('');
  const [submittingExpense, setSubmittingExpense] = useState(false);

  const canCreateShiftExpense =
    authority !== null && hasPermission(authority, 'EXPENSE_SHIFT_CREATE');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [currentShift, locs] = await Promise.all([
          fetchMyOpenShift(),
          fetchLocations(),
        ]);
        if (cancelled) return;
        setShift(currentShift);
        setLocations(locs);
        if (locs.length > 0) setLocationId(locs[0].id);
      } catch (err) {
        if (!cancelled) setError(toShiftErrorMessage(err));
      } finally {
        if (!cancelled) setLoading(false);
      }
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
      return () => {
        cancelled = true;
      };
    }

    void (async () => {
      try {
        const [rows, approvals] = await Promise.all([
          fetchShiftExpenses(shift.id),
          fetchShiftExpenseApprovals(shift.id),
        ]);
        if (!cancelled) {
          setExpenses(rows);
          setExpenseApprovals(approvals);
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
      const [rows, approvals] = await Promise.all([
        fetchShiftExpenses(shift.id),
        fetchShiftExpenseApprovals(shift.id),
      ]);
      setExpenses(rows);
      setExpenseApprovals(approvals);
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
      <main className="shell">
        <p>Memuat shift…</p>
      </main>
    );
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            ← Beranda
          </Link>
          <h1>Shift Saya</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}

      {canCloseShift(shift) && shift ? (
        <>
          <section className="identity-card">
            <h2>Shift Aktif</h2>
            <dl className="identity-meta">
              <div>
                <dt>Dibuka</dt>
                <dd>{new Date(shift.opened_at).toLocaleString('id-ID')}</dd>
              </div>
              <div>
                <dt>Saldo Awal</dt>
                <dd>Rp {shift.opening_balance.toLocaleString('id-ID')}</dd>
              </div>
            </dl>
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
              <button
                className="primary-button"
                type="submit"
                disabled={closing}
              >
                {closing ? 'Menutup…' : 'Tutup Shift'}
              </button>
            </form>
          </section>

          {canCreateShiftExpense && (
            <section className="identity-card">
              <h2>Catat Pengeluaran Shift</h2>
              <form onSubmit={handleShiftExpense} className="stack-form">
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
                  {submittingExpense ? 'Mencatat&' : 'Catat Pengeluaran Shift'}
                </button>
              </form>

              {expenseMessage && <p className="muted">{expenseMessage}</p>}

              {expenseApprovals.length > 0 && (
                <div className="stack-list">
                  <h3>Status Approval</h3>
                  {expenseApprovals.map((request) => (
                    <article key={request.request_id} className="list-card">
                      <strong>{request.category_code}</strong>
                      <span>{request.description}</span>
                      <span>{formatIdr(request.amount)}</span>
                      <span>Status: {request.status}</span>
                    </article>
                  ))}
                </div>
              )}

              {expenses.length > 0 && (
                <div className="stack-list">
                  <h3>Pengeluaran Shift Ini</h3>
                  {expenses.map((expense) => (
                    <article key={expense.id} className="list-card">
                      <strong>{expense.category_code}</strong>
                      <span>{expense.description}</span>
                      <span>{formatIdr(expense.amount)}</span>
                    </article>
                  ))}
                </div>
              )}
            </section>
          )}
        </>
      ) : (
        <section className="identity-card">
          <h2>Buka Shift Baru</h2>
          <form onSubmit={handleOpen} className="stack-form">
            <label>
              Lokasi
              <select
                value={locationId}
                onChange={(e) => setLocationId(e.target.value)}
                required
              >
                {locations.map((loc) => (
                  <option key={loc.id} value={loc.id}>
                    {loc.label}
                  </option>
                ))}
              </select>
            </label>
            <p className="muted">
              Sumber saldo awal:{' '}
              {openingBalance > 0 ? 'Kas Utama' : 'Tanpa saldo awal'}
            </p>
            <label>
              Saldo Awal (Rp)
              <input
                type="number"
                step="1000"
                value={openingBalance}
                onChange={(e) => setOpeningBalance(Number(e.target.value))}
                required
              />
            </label>
            <button
              className="primary-button"
              type="submit"
              disabled={submitting}
            >
              {submitting ? 'Membuka…' : 'Buka Shift'}
            </button>
          </form>
        </section>
      )}
    </main>
  );
}
