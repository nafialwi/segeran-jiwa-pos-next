import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  canCloseShift,
  formatMovementLabel,
  formatVariance,
  toShiftErrorMessage,
  type CashMovementType,
  type Shift,
} from '../shift/shift-core';
import {
  addCashMovement,
  closeShift,
  fetchLocations,
  fetchMyOpenShift,
  openShift,
  type LocationOption,
} from '../shift/shift-api';

export function ShiftManagementScreen() {
  const [shift, setShift] = useState<Shift | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [locationId, setLocationId] = useState('');
  const [locations, setLocations] = useState<LocationOption[]>([]);
  const [openingBalance, setOpeningBalance] = useState(0);
  const [submitting, setSubmitting] = useState(false);

  const [actualCash, setActualCash] = useState(0);
  const [closing, setClosing] = useState(false);

  const [movementType, setMovementType] = useState<CashMovementType>('CASH_IN');
  const [movementAmount, setMovementAmount] = useState(0);
  const [movementNotes, setMovementNotes] = useState('');
  const [submittingMovement, setSubmittingMovement] = useState(false);

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

  const handleCashMovement = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmittingMovement(true);
    try {
      await addCashMovement(
        movementType,
        movementAmount,
        movementNotes || undefined,
      );
      alert(`${formatMovementLabel(movementType)} berhasil dicatat.`);
      setMovementAmount(0);
      setMovementNotes('');
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setSubmittingMovement(false);
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

          <section className="identity-card">
            <h2>Gerakan Kas</h2>
            <form onSubmit={handleCashMovement} className="stack-form">
              <label>
                Tipe
                <select
                  value={movementType}
                  onChange={(e) =>
                    setMovementType(e.target.value as CashMovementType)
                  }
                >
                  <option value="CASH_IN">Uang Masuk</option>
                  <option value="CASH_OUT">Uang Keluar</option>
                  <option value="ADJUSTMENT">Penyesuaian</option>
                </select>
              </label>
              <label>
                Jumlah (Rp)
                <input
                  type="number"
                  step="1000"
                  value={movementAmount}
                  onChange={(e) => setMovementAmount(Number(e.target.value))}
                  required
                />
              </label>
              <label>
                Catatan
                <input
                  type="text"
                  value={movementNotes}
                  onChange={(e) => setMovementNotes(e.target.value)}
                  placeholder="Opsional"
                />
              </label>
              <button
                className="primary-button"
                type="submit"
                disabled={submittingMovement}
              >
                {submittingMovement ? 'Mencatat…' : 'Catat Gerakan'}
              </button>
            </form>
          </section>
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
