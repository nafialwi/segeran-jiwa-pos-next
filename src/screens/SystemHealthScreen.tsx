import { useCallback, useEffect, useState } from 'react';
import { currentConnectivity } from '../control/connectivity';
import {
  probeBackendAuthority,
  type BackendAuthorityProbe,
} from '../control/control-center-api';
import { BACKUP_CHECKPOINT_EVIDENCE } from '../control/backup-evidence';

function formatCheckedAt(value: string | null): string {
  if (!value) return 'Belum diperiksa';
  return new Date(value).toLocaleString('id-ID');
}

export function SystemHealthScreen() {
  const [connectivity, setConnectivity] = useState(currentConnectivity);
  const [probe, setProbe] = useState<BackendAuthorityProbe | null>(null);
  const [checking, setChecking] = useState(false);

  const checkBackend = useCallback(async () => {
    setChecking(true);
    try {
      setProbe(await probeBackendAuthority());
    } finally {
      setChecking(false);
    }
  }, []);

  useEffect(() => {
    const refresh = () => setConnectivity(currentConnectivity());
    window.addEventListener('online', refresh);
    window.addEventListener('offline', refresh);
    void checkBackend();
    return () => {
      window.removeEventListener('online', refresh);
      window.removeEventListener('offline', refresh);
    };
  }, [checkBackend]);

  return (
    <main className="shell control-page">
      <header className="topbar control-page-header">
        <div>
          <p className="eyebrow">PENGATURAN · HEALTH</p>
          <h1>Kesehatan Sistem</h1>
          <p className="muted">
            Setiap status diberi sumber bukti yang berbeda. Koneksi browser
            bukan bukti kesehatan backend.
          </p>
        </div>
        <button
          className="secondary-button"
          type="button"
          disabled={checking}
          onClick={() => void checkBackend()}
        >
          {checking ? 'Memeriksa...' : 'Periksa Lagi'}
        </button>
      </header>

      <section className="control-health-grid">
        <article
          className={
            connectivity === 'ONLINE'
              ? 'control-health-card neutral'
              : 'control-health-card danger'
          }
        >
          <span>Koneksi Perangkat</span>
          <strong>{connectivity}</strong>
          <p>
            Berdasarkan event online/offline browser; bukan bukti kesehatan
            backend.
          </p>
        </article>

        <article
          className={
            probe?.status === 'PASS'
              ? 'control-health-card evidence'
              : probe?.status === 'FAIL'
                ? 'control-health-card danger'
                : 'control-health-card neutral'
          }
        >
          <span>Backend Authority</span>
          <strong>{probe?.status ?? 'BELUM DIPERIKSA'}</strong>
          <p>{probe?.detail ?? 'Belum ada live authority probe.'}</p>
          <small>
            {formatCheckedAt(probe?.checkedAt ?? null)}
            {probe ? ' · ' + probe.latencyMs + ' ms' : ''}
          </small>
        </article>

        <article className="control-health-card neutral">
          <span>Backup / Restore</span>
          <strong>{BACKUP_CHECKPOINT_EVIDENCE.evidenceKind}</strong>
          <p>
            Bukti terakhir P5C: restore{' '}
            {BACKUP_CHECKPOINT_EVIDENCE.restoreStatus}. Ini evidence checkpoint,
            bukan status realtime.
          </p>
          <small>
            {new Date(BACKUP_CHECKPOINT_EVIDENCE.verifiedAt).toLocaleString(
              'id-ID',
            )}
          </small>
        </article>
      </section>

      <section className="control-truth-note">
        <strong>Interpretasi status</strong>
        <span>
          PASS Backend Authority hanya membuktikan bahwa saat pemeriksaan,
          layanan backend merespons dan authority sesi dapat diverifikasi. Ini
          tidak menyatakan semua tabel, backup, jaringan, atau fungsi bisnis
          sedang sehat.
        </span>
      </section>
    </main>
  );
}
