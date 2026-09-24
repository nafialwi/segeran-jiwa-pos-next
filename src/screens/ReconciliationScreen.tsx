import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { OperationsNav } from '../components/OperationsNav';
import { OperationalState } from '../components/OperationalState';
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
    setReconciliation(null);
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
      <main className="shell operations-shell shift-reconciliation-screen">
        <header className="topbar operations-header secondary-hero">
          <div>
            <Link className="muted" to="/">
              ← Beranda
            </Link>
            <p className="eyebrow">OPERASIONAL · SHIFT</p>
            <h1>Rekonsiliasi Shift</h1>
          </div>
        </header>
        <OperationsNav />
        <OperationalState
          kind="loading"
          message="Memuat riwayat shift untuk rekonsiliasi"
          skeletonItems={2}
        />
      </main>
    );
  }

  if (shifts.length === 0) {
    return (
      <main className="shell operations-shell shift-reconciliation-screen">
        <header className="topbar operations-header">
          <div>
            <Link className="muted" to="/">
              ← Beranda
            </Link>
            <p className="eyebrow">OPERASIONAL · SHIFT</p>
            <h1>Rekonsiliasi Shift</h1>
          </div>
        </header>
        <OperationsNav />
        <OperationalState
          kind="empty"
          title="Belum ada shift untuk direkonsiliasi"
          message="Rekonsiliasi tersedia setelah sebuah shift selesai ditutup."
        />
      </main>
    );
  }

  return (
    <main className="shell operations-shell shift-reconciliation-screen">
      <header className="topbar operations-header">
        <div>
          <Link className="muted" to="/">
            ← Beranda
          </Link>
          <p className="eyebrow">OPERASIONAL · SHIFT</p>
          <h1>Rekonsiliasi Shift</h1>
        </div>
      </header>

      <OperationsNav />

      {error && (
        <p className="error-banner" role="alert">
          {error}
        </p>
      )}

      <section className="operations-panel">
        <label>
          Pilih Shift
          <select
            value={selectedShiftId}
            onChange={(e) => setSelectedShiftId(e.target.value)}
            disabled={loadingRecon}
          >
            {shifts.map((s) => (
              <option key={s.id} value={s.id}>
                {new Date(s.closed_at ?? s.opened_at).toLocaleString('id-ID')} ·{' '}
                {s.id.slice(0, 8)}
              </option>
            ))}
          </select>
        </label>
      </section>

      {loadingRecon ? (
        <div
          className="operations-card-skeleton reconciliation-loading"
          aria-label="Memuat rekonsiliasi"
        >
          <span />
          <span />
          <span />
        </div>
      ) : reconciliation ? (
        <section className="operations-panel">
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

          <div className="section-heading reconciliation-summary-heading">
            <div>
              <p className="eyebrow">HASIL REKONSILIASI</p>
              <h2>Expected vs Kas Fisik</h2>
            </div>
            <span
              className={
                reconciliation.actual_cash === null
                  ? 'operations-status neutral'
                  : reconciliationVariance(reconciliation) === 0
                    ? 'operations-status'
                    : 'operations-status warning'
              }
            >
              {reconciliation.actual_cash === null
                ? 'Belum ada kas fisik'
                : reconciliationVariance(reconciliation) === 0
                  ? 'Sesuai'
                  : 'Ada selisih'}
            </span>
          </div>
          <dl className="identity-meta reconciliation-summary-grid">
            <div>
              <dt>Kas Diharapkan (Expected)</dt>
              <dd>{formatIdr(reconciliationExpectedCash(reconciliation))}</dd>
            </div>
            <div>
              <dt>Kas Fisik (Actual)</dt>
              <dd>
                {reconciliation.actual_cash !== null
                  ? formatIdr(reconciliation.actual_cash)
                  : 'Belum dicatat'}
              </dd>
            </div>
            <div>
              <dt>Varians</dt>
              <dd>{formatVariance(reconciliationVariance(reconciliation))}</dd>
            </div>
          </dl>
          {reconciliation.actual_cash === null && (
            <p className="muted reconciliation-note">
              Varians belum dapat dihitung karena hasil hitung kas fisik belum
              tercatat pada penutupan shift.
            </p>
          )}
        </section>
      ) : null}
    </main>
  );
}
