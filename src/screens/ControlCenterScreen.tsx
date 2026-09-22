import { Link } from 'react-router-dom';
import { canAccessOwnerArea } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { BACKUP_CHECKPOINT_EVIDENCE } from '../control/backup-evidence';
import { Icon } from '../ui/Icon';
import type { SegeranIconName } from '../ui/iconRegistry';

type ControlCard = {
  label: string;
  detail: string;
  to: string;
  icon: SegeranIconName;
  ownerOnly?: boolean;
};

const CONTROL_CARDS: ControlCard[] = [
  {
    label: 'Tampilan & Dashboard',
    detail: 'Kepadatan tampilan dan ukuran teks perangkat ini',
    to: '/pengaturan/tampilan',
    icon: 'settings',
  },
  {
    label: 'Keuangan',
    detail: 'Kas, bank, QRIS, hutang, modal, dan rekonsiliasi',
    to: '/keuangan',
    icon: 'account',
    ownerOnly: true,
  },
  {
    label: 'Pengguna & Izin',
    detail: 'Akun, role, dan permission operasional',
    to: '/pengguna#permissions',
    icon: 'users',
    ownerOnly: true,
  },
  {
    label: 'Perangkat Aktif',
    detail: 'Perangkat personal/shared, revoke, dan status akses',
    to: '/pengguna#devices',
    icon: 'security-sync',
    ownerOnly: true,
  },
  {
    label: 'Perhatian',
    detail: 'Kondisi yang memerlukan tindakan operator',
    to: '/perhatian',
    icon: 'notification',
  },
  {
    label: 'Backup & Restore',
    detail: 'Evidence backup terakhir dan batas restore',
    to: '/pengaturan/backup',
    icon: 'backup-restore',
    ownerOnly: true,
  },
  {
    label: 'Kesehatan Sistem',
    detail: 'Koneksi perangkat dan live backend authority probe',
    to: '/pengaturan/kesehatan',
    icon: 'security-sync',
  },
  {
    label: 'Offline & Sync',
    detail: 'Batas operasi online-only dan status koneksi',
    to: '/pengaturan/offline-sync',
    icon: 'activity',
  },
  {
    label: 'Diagnostik',
    detail: 'Evidence runtime aman tanpa credential',
    to: '/pengaturan/diagnostik',
    icon: 'diagnostics',
  },
];

export function ControlCenterScreen() {
  const { authority } = useAuth();
  if (!authority) return null;

  const owner = canAccessOwnerArea(authority);
  const cards = CONTROL_CARDS.filter((card) => owner || !card.ownerOnly);

  return (
    <main className="shell control-center-screen">
      <header className="control-center-hero">
        <div>
          <p className="eyebrow">SEGERAN JIWA · PENGATURAN</p>
          <h1>Pusat Kontrol</h1>
          <p>
            Pengaturan, authority, perangkat, evidence sistem, dan jalur
            pemulihan dalam satu tempat.
          </p>
        </div>
        <span className="role-badge">{authority.role_code}</span>
      </header>

      <section className="control-center-grid">
        {cards.map((card) => (
          <Link className="control-center-card" key={card.to} to={card.to}>
            <span className="control-center-icon">
              <Icon name={card.icon} />
            </span>
            <span>
              <strong>{card.label}</strong>
              <small>{card.detail}</small>
            </span>
          </Link>
        ))}
      </section>

      <section className="control-center-evidence-strip">
        <div>
          <span>Backup evidence</span>
          <strong>{BACKUP_CHECKPOINT_EVIDENCE.evidenceKind}</strong>
        </div>
        <p>
          Bukti P5C terakhir diverifikasi{' '}
          {new Date(BACKUP_CHECKPOINT_EVIDENCE.verifiedAt).toLocaleDateString(
            'id-ID',
          )}
          . Status ini bukan health realtime.
        </p>
      </section>
    </main>
  );
}
