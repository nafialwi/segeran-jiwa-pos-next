import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { OperationsNav } from '../components/OperationsNav';
import { OperationalState } from '../components/OperationalState';
import {
  formatVariance,
  toShiftErrorMessage,
  type Shift,
} from '../shift/shift-core';
import { fetchMyShiftHistory } from '../shift/shift-api';

export function ShiftHistoryScreen() {
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const list = await fetchMyShiftHistory();
        if (!cancelled) setShifts(list);
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

  return (
    <main className="shell operations-shell shift-history-screen">
      <header className="topbar operations-header secondary-hero">
        <div>
          <Link className="muted" to="/">
            ← Beranda
          </Link>
          <p className="eyebrow">OPERASIONAL · SHIFT</p>
          <h1>Riwayat Shift</h1>
        </div>
      </header>

      <OperationsNav />

      {error && (
        <OperationalState
          kind="error"
          title="Riwayat shift tidak dapat dimuat"
          message={error}
        />
      )}

      {loading ? (
        <OperationalState
          kind="loading"
          message="Memuat riwayat shift"
          skeletonItems={2}
        />
      ) : shifts.length === 0 ? (
        <OperationalState
          kind="empty"
          title="Belum ada shift tertutup"
          message="Riwayat shift akan muncul setelah shift pertama selesai ditutup."
        />
      ) : (
        <ul className="list-cards">
          {shifts.map((s) => (
            <li key={s.id} className="identity-card">
              <div>
                <strong>
                  {new Date(s.opened_at).toLocaleDateString('id-ID')}
                </strong>
                <span className="muted">
                  {new Date(s.opened_at).toLocaleTimeString('id-ID', {
                    hour: '2-digit',
                    minute: '2-digit',
                  })}{' '}
                  –{' '}
                  {s.closed_at
                    ? new Date(s.closed_at).toLocaleTimeString('id-ID', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })
                    : '—'}
                </span>
              </div>
              <dl className="identity-meta">
                <div>
                  <dt>Saldo Awal</dt>
                  <dd>Rp {s.opening_balance.toLocaleString('id-ID')}</dd>
                </div>
                <div>
                  <dt>Saldo Akhir</dt>
                  <dd>Rp {(s.closing_balance ?? 0).toLocaleString('id-ID')}</dd>
                </div>
                <div>
                  <dt>Varians</dt>
                  <dd>{formatVariance(s.variance)}</dd>
                </div>
              </dl>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
