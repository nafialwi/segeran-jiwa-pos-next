import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { canAccessOwnerArea } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { currentConnectivity } from '../control/connectivity';
import {
  backupEvidenceAgeDays,
  BACKUP_CHECKPOINT_EVIDENCE,
} from '../control/backup-evidence';
import {
  probeBackendAuthority,
  type BackendAuthorityProbe,
} from '../control/control-center-api';
import { Icon } from '../ui/Icon';

export function AttentionScreen() {
  const { authority } = useAuth();
  const [connectivity, setConnectivity] = useState(currentConnectivity);
  const [probe, setProbe] = useState<BackendAuthorityProbe | null>(null);
  const [checking, setChecking] = useState(false);

  const runProbe = useCallback(async () => {
    if (currentConnectivity() === 'OFFLINE') {
      setProbe(null);
      return;
    }
    setChecking(true);
    try {
      setProbe(await probeBackendAuthority());
    } finally {
      setChecking(false);
    }
  }, []);

  useEffect(() => {
    const refresh = () => {
      setConnectivity(currentConnectivity());
      void runProbe();
    };
    window.addEventListener('online', refresh);
    window.addEventListener('offline', refresh);
    void runProbe();

    return () => {
      window.removeEventListener('online', refresh);
      window.removeEventListener('offline', refresh);
    };
  }, [runProbe]);

  const owner = authority ? canAccessOwnerArea(authority) : false;
  const backupAge = backupEvidenceAgeDays();
  const backupNeedsAttention = owner && backupAge > 7;
  const backendNeedsAttention =
    connectivity === 'ONLINE' && probe?.status === 'FAIL';
  const noAttention =
    connectivity === 'ONLINE' &&
    !backendNeedsAttention &&
    !backupNeedsAttention &&
    probe?.status === 'PASS';

  return (
    <main className="shell attention-screen">
      <header className="topbar">
        <div>
          <p className="eyebrow">OPERASIONAL</p>
          <h1>Perhatian</h1>
          <p className="muted">
            Hanya evidence yang tersedia dan dapat ditindaklanjuti yang
            ditampilkan.
          </p>
        </div>
        <button
          className="secondary-button"
          type="button"
          disabled={checking}
          onClick={() => void runProbe()}
        >
          {checking ? 'Memeriksa...' : 'Coba Lagi'}
        </button>
      </header>

      {connectivity === 'OFFLINE' && (
        <section className="attention-card warning">
          <div className="attention-icon">
            <Icon name="notification" />
          </div>
          <div>
            <strong>Perangkat offline</strong>
            <p>
              Operasi yang memerlukan server dapat gagal. Tidak ada antrean
              mutasi offline.
            </p>
            <Link to="/pengaturan/offline-sync">Lihat Offline & Sync</Link>
          </div>
        </section>
      )}

      {backendNeedsAttention && (
        <section className="attention-card warning">
          <div className="attention-icon">
            <Icon name="diagnostics" />
          </div>
          <div>
            <strong>Backend Authority perlu perhatian</strong>
            <p>{probe?.detail}</p>
            <Link to="/pengaturan/kesehatan">Lihat Kesehatan Sistem</Link>
          </div>
        </section>
      )}

      {backupNeedsAttention && (
        <section className="attention-card warning">
          <div className="attention-icon">
            <Icon name="backup-restore" />
          </div>
          <div>
            <strong>Evidence backup sudah berumur {backupAge} hari</strong>
            <p>
              Bukti terakhir berasal dari checkpoint{' '}
              {new Date(
                BACKUP_CHECKPOINT_EVIDENCE.verifiedAt,
              ).toLocaleDateString('id-ID')}
              . Verifikasi ulang diperlukan sesuai prosedur operasional.
            </p>
            <Link to="/pengaturan/backup">Lihat Backup & Restore</Link>
          </div>
        </section>
      )}

      {noAttention && (
        <section className="attention-card">
          <div className="attention-icon">
            <Icon name="notification" />
          </div>
          <div>
            <strong>Tidak ada perhatian aktif dari pemeriksaan tersedia</strong>
            <p>
              Koneksi perangkat tersedia dan live Backend Authority probe
              berhasil pada pemeriksaan ini.
            </p>
          </div>
        </section>
      )}

      <section className="attention-footnote">
        <Icon name="diagnostics" />
        <div>
          <strong>Tidak berarti seluruh sistem sehat.</strong>
          <p>
            Stok, shift, finance, backup, dan proses bisnis lain tetap mengikuti
            evidence authority masing-masing. Layar ini tidak mengubah fakta
            bisnis.
          </p>
        </div>
      </section>
    </main>
  );
}
