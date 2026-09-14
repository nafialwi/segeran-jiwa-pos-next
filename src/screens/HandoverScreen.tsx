import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  canAcceptHandover,
  toShiftErrorMessage,
  type Handover,
} from '../shift/shift-core';
import { fetchMyPendingHandovers, resolveHandover } from '../shift/shift-api';

export function HandoverScreen() {
  const [handovers, setHandovers] = useState<Handover[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [processingId, setProcessingId] = useState<string | null>(null);

  const reload = async () => {
    try {
      const list = await fetchMyPendingHandovers();
      setHandovers(list);
    } catch (err) {
      setError(toShiftErrorMessage(err));
    }
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const list = await fetchMyPendingHandovers();
        if (!cancelled) setHandovers(list);
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

  const handle = async (id: string, accept: boolean) => {
    setError(null);
    setProcessingId(id);
    try {
      await resolveHandover(id, accept);
      await reload();
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setProcessingId(null);
    }
  };

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            ← Beranda
          </Link>
          <h1>Serah Terima Shift</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}

      {loading ? (
        <p>Memuat…</p>
      ) : handovers.length === 0 ? (
        <p className="muted">Tidak ada serah-terima menunggu keputusan Anda.</p>
      ) : (
        <ul className="list-cards">
          {handovers.map((h) => (
            <li key={h.id} className="identity-card">
              <div>
                <strong>Dari kasir</strong>
                <span className="muted">
                  {h.from_cashier_profile_id.slice(0, 8)}…
                </span>
              </div>
              <dl className="identity-meta">
                <div>
                  <dt>Saldo Diharapkan</dt>
                  <dd>Rp {h.expected_balance.toLocaleString('id-ID')}</dd>
                </div>
                <div>
                  <dt>Saldo Diserahkan</dt>
                  <dd>Rp {h.actual_balance.toLocaleString('id-ID')}</dd>
                </div>
                <div>
                  <dt>Selisih</dt>
                  <dd>{h.discrepancy.toLocaleString('id-ID')}</dd>
                </div>
              </dl>
              <div className="button-row">
                <button
                  className="secondary-button"
                  type="button"
                  disabled={processingId === h.id || !canAcceptHandover(h)}
                  onClick={() => void handle(h.id, false)}
                >
                  Tolak
                </button>
                <button
                  className="primary-button"
                  type="button"
                  disabled={processingId === h.id || !canAcceptHandover(h)}
                  onClick={() => void handle(h.id, true)}
                >
                  Terima
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
