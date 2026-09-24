import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { OperationsNav } from '../components/OperationsNav';
import { useActionDialog } from '../components/ActionDialogProvider';
import {
  canAcceptHandover,
  formatIdr,
  formatVariance,
  toShiftErrorMessage,
  type Handover,
} from '../shift/shift-core';
import { fetchMyPendingHandovers, resolveHandover } from '../shift/shift-api';

export function HandoverScreen() {
  const { confirmAction } = useActionDialog();
  const [handovers, setHandovers] = useState<Handover[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [processingId, setProcessingId] = useState<string | null>(null);

  const reload = async () => {
    setError(null);
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

  const handle = async (handover: Handover, accept: boolean) => {
    const confirmed = await confirmAction({
      title: accept
        ? 'Terima serah terima shift?'
        : 'Tolak serah terima shift?',
      description: accept
        ? 'Kas fisik yang diserahkan adalah ' +
          formatIdr(handover.actual_balance) +
          ' dengan selisih ' +
          formatVariance(handover.discrepancy) +
          '. Pastikan nominal sudah sesuai hasil hitung.'
        : 'Serah terima akan ditolak dan tidak membentuk shift penerima. Pastikan keputusan ini memang disengaja.',
      confirmLabel: accept ? 'Terima Serah Terima' : 'Tolak Serah Terima',
      cancelLabel: 'Kembali',
      tone: accept ? 'default' : 'danger',
    });
    if (!confirmed) return;

    setError(null);
    setProcessingId(handover.id);
    try {
      await resolveHandover(handover.id, accept);
      await reload();
    } catch (err) {
      setError(toShiftErrorMessage(err));
    } finally {
      setProcessingId(null);
    }
  };

  return (
    <main className="shell operations-shell handover-screen">
      <header className="topbar operations-header secondary-hero">
        <div>
          <Link className="muted" to="/">
            ← Beranda
          </Link>
          <p className="eyebrow">OPERASIONAL · SHIFT</p>
          <h1>Serah Terima Shift</h1>
        </div>
      </header>

      <OperationsNav />

      {error && (
        <p className="error-banner" role="alert">
          {error}
        </p>
      )}

      {loading ? (
        <div
          className="operations-card-skeleton handover-loading"
          aria-label="Memuat serah terima"
        >
          <span />
          <span />
        </div>
      ) : handovers.length === 0 ? (
        <p className="empty-state">
          Tidak ada serah-terima menunggu keputusan Anda.
        </p>
      ) : (
        <ul className="list-cards">
          {handovers.map((h) => (
            <li
              key={h.id}
              className={
                h.discrepancy === 0
                  ? 'identity-card handover-card'
                  : 'identity-card handover-card warning'
              }
            >
              <div className="handover-card-head">
                <span>
                  <strong>Serah terima masuk</strong>
                  <small className="muted">
                    Pengirim {h.from_cashier_profile_id.slice(0, 8)}… ·{' '}
                    {new Date(h.created_at).toLocaleString('id-ID')}
                  </small>
                </span>
                <span
                  className={
                    h.discrepancy === 0
                      ? 'operations-status'
                      : 'operations-status warning'
                  }
                >
                  {h.discrepancy === 0 ? 'Sesuai' : 'Ada selisih'}
                </span>
              </div>
              <dl className="identity-meta handover-balance-grid">
                <div>
                  <dt>Kas Diharapkan</dt>
                  <dd>{formatIdr(h.expected_balance)}</dd>
                </div>
                <div>
                  <dt>Kas Diserahkan</dt>
                  <dd>{formatIdr(h.actual_balance)}</dd>
                </div>
                <div>
                  <dt>Varians</dt>
                  <dd>{formatVariance(h.discrepancy)}</dd>
                </div>
                <div>
                  <dt>Referensi Shift</dt>
                  <dd>{h.from_shift_id.slice(0, 8)}…</dd>
                </div>
              </dl>
              <div className="button-row">
                <button
                  className="secondary-button"
                  type="button"
                  disabled={processingId === h.id || !canAcceptHandover(h)}
                  onClick={() => void handle(h, false)}
                >
                  Tolak
                </button>
                <button
                  className="primary-button"
                  type="button"
                  disabled={processingId === h.id || !canAcceptHandover(h)}
                  onClick={() => void handle(h, true)}
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
