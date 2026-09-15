import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  formatIdr,
  formatVariance,
  reconciliationExpectedCash,
  reconciliationVariance,
  toShiftErrorMessage,
  type Reconciliation,
  type Shift,
} from '../shift/shift-core';
import {
  fetchMyClosedShifts,
  fetchShiftReconciliation,
} from '../shift/shift-api';

export function ReconciliationScreen() {
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [selectedShiftId, setSelectedShiftId] = useState('');
  const [reconciliation, setReconciliation] = useState<Reconciliation | null>(
    null,
  );
  const [loading, setLoading] = useState(true);
  const [loadingRecon, setLoadingRecon] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const closedShifts = await fetchMyClosedShifts();
        if (!cancelled) {
          setShifts(closedShifts);
          if (closedShifts.length > 0) {
            setSelectedShiftId(closedShifts[0].id);
          }
        }
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
    if (!selectedShiftId) return;
    let cancelled = false;
    setLoadingRecon(true);
    setError(null);
    (async () => {
      try {
        const recon = await fetchShiftReconciliation(selectedShiftId);
        if (!cancelled) setReconciliation(recon);
      } catch (err) {
        if (!cancelled) setError(toShiftErrorMessage(err));
      } finally {
        if (!cancelled) setLoadingRecon(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [selectedShiftId]);

  if (loading) {
    return (
      <main className="shell">
        <p>Memuat riwayat shift…</p>
      </main>
    );
  }

  if (shifts.length === 0) {
    return (
      <main className="shell">
        <header className="topbar">
          <div>
            <Link className="muted" to="/">
              ← Beranda
            </Link>
            <h1>Rekonsiliasi Shift</h1>
          </div>
        </header>
        <section className="identity-card">
          <p className="muted">
            Belum ada shift tertutup untuk direkonsiliasi.
          </p>
        </section>
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
          <h1>Rekonsiliasi Shift</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}

      <section className="identity-card">
        <label>
          Pilih Shift
          <select
            value={selectedShiftId}
            onChange={(e) => setSelectedShiftId(e.target.value)}
            disabled={loadingRecon}
          >
            {shifts.map((s) => (
              <option key={s.id} value={s.id}>
                {new Date(s.closed_at ?? s.opened_at).toLocaleString('id-ID')}
              </option>
            ))}
          </select>
        </label>
      </section>

      {loadingRecon ? (
        <p>Memuat rekonsiliasi…</p>
      ) : reconciliation ? (
        <section className="identity-card">
          <h2>Breakdown Kas</h2>
          <dl className="identity-meta">
            <div>
              <dt>Saldo Awal</dt>
              <dd>{formatIdr(reconciliation.opening_balance)}</dd>
            </div>
            <div>
              <dt>Penjualan Tunai</dt>
              <dd>{formatIdr(reconciliation.sale_total)}</dd>
            </div>
            <div>
              <dt>Refund</dt>
              <dd>-{formatIdr(reconciliation.refund_total)}</dd>
            </div>
            <div>
              <dt>Uang Masuk</dt>
              <dd>{formatIdr(reconciliation.cash_in_total)}</dd>
            </div>
            <div>
              <dt>Uang Keluar</dt>
              <dd>-{formatIdr(reconciliation.cash_out_total)}</dd>
            </div>
            <div>
              <dt>Penyesuaian</dt>
              <dd>{formatIdr(reconciliation.adjustment_total)}</dd>
            </div>
          </dl>

          <h2>Ringkasan</h2>
          <dl className="identity-meta">
            <div>
              <dt>Expected Cash</dt>
              <dd>{formatIdr(reconciliationExpectedCash(reconciliation))}</dd>
            </div>
            <div>
              <dt>Actual Cash</dt>
              <dd>
                {reconciliation.actual_cash !== null
                  ? formatIdr(reconciliation.actual_cash)
                  : '—'}
              </dd>
            </div>
            <div>
              <dt>Varians</dt>
              <dd>{formatVariance(reconciliationVariance(reconciliation))}</dd>
            </div>
          </dl>
        </section>
      ) : null}
    </main>
  );
}
