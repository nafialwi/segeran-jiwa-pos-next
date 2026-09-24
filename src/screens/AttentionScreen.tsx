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
import { fetchMyOperationalMessages } from '../operations/operational-message-api';

export function AttentionScreen() {
  const { authority } = useAuth();
  const [connectivity, setConnectivity] = useState(currentConnectivity);
  const [probe, setProbe] = useState<BackendAuthorityProbe | null>(null);
  const [checking, setChecking] = useState(false);
  const [messageCheck, setMessageCheck] = useState({
    checked: false,
    unread: 0,
    highUnread: 0,
  });

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

  const checkOperationalMessages = useCallback(async () => {
    if (currentConnectivity() === 'OFFLINE') {
      setMessageCheck({ checked: false, unread: 0, highUnread: 0 });
      return;
    }

    try {
      const rows = await fetchMyOperationalMessages(20);
      const unread = rows.filter((message) => !message.readAt);
      setMessageCheck({
        checked: true,
        unread: unread.length,
        highUnread: unread.filter((message) => message.priority === 'HIGH')
          .length,
      });
    } catch {
      setMessageCheck({ checked: false, unread: 0, highUnread: 0 });
    }
  }, []);

  useEffect(() => {
    const refresh = () => {
      setConnectivity(currentConnectivity());
      void runProbe();
      void checkOperationalMessages();
    };
    window.addEventListener('online', refresh);
    window.addEventListener('offline', refresh);
    void runProbe();
    void checkOperationalMessages();

    return () => {
      window.removeEventListener('online', refresh);
      window.removeEventListener('offline', refresh);
    };
  }, [runProbe, checkOperationalMessages]);

  const owner = authority ? canAccessOwnerArea(authority) : false;
  const backupAge = backupEvidenceAgeDays();
  const backupNeedsAttention = owner && backupAge > 7;
  const backendNeedsAttention =
    connectivity === 'ONLINE' && probe?.status === 'FAIL';
  const operationalUnread = owner ? 0 : messageCheck.unread;
  const operationalHighUnread = owner ? 0 : messageCheck.highUnread;
  const operationalNeedsAttention = operationalUnread > 0;
  const operationalCheckReady = owner || messageCheck.checked;
  const noAttention =
    connectivity === 'ONLINE' &&
    !backendNeedsAttention &&
    !backupNeedsAttention &&
    !operationalNeedsAttention &&
    operationalCheckReady &&
    probe?.status === 'PASS';

  return (
    <main className="shell attention-screen">
      <header className="topbar control-page-header attention-hero">
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
          <Icon name="refresh" size={17} />
          <span>{checking ? 'Memeriksa...' : 'Coba Lagi'}</span>
        </button>
      </header>

      {connectivity === 'OFFLINE' && (
        <section className="attention-card warning">
          <div className="attention-icon">
            <Icon name="warning" />
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

      {operationalNeedsAttention && (
        <section className="attention-card warning operational-message-attention">
          <div className="attention-icon">
            <Icon
              name={operationalHighUnread > 0 ? 'warning' : 'notification'}
            />
          </div>
          <div>
            <strong>
              {operationalHighUnread > 0
                ? operationalHighUnread + ' pesan penting belum dibaca'
                : operationalUnread + ' pesan operasional belum dibaca'}
            </strong>
            <p>
              Instruksi dari pengelola perlu ditinjau oleh kasir agar pekerjaan
              shift mengikuti arahan terbaru.
            </p>
            <Link to="/#pesan-operasional">Buka Pesan Operasional</Link>
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
            <Icon name="check" />
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
