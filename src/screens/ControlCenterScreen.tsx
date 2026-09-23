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
  group: 'Bisnis' | 'Orang' | 'Sistem';
  ownerOnly?: boolean;
};

const CONTROL_CARDS: ControlCard[] = [
  {
    label: 'Tampilan & Dashboard',
    group: 'Sistem',
    detail: 'Kepadatan tampilan dan ukuran teks perangkat ini',
    to: '/pengaturan/tampilan',
    icon: 'settings',
  },
  {
    label: 'Keuangan',
    group: 'Bisnis',
    detail: 'Kas, bank, QRIS, hutang, modal, dan rekonsiliasi',
    to: '/keuangan',
    icon: 'cash',
    ownerOnly: true,
  },
  {
    label: 'Pengguna & Izin',
    group: 'Orang',
    detail: 'Akun, role, dan permission operasional',
    to: '/pengguna#permissions',
    icon: 'users',
    ownerOnly: true,
  },
  {
    label: 'Perangkat Aktif',
    group: 'Orang',
    detail: 'Perangkat personal/shared, revoke, dan status akses',
    to: '/pengguna#devices',
    icon: 'active-device',
    ownerOnly: true,
  },
  {
    label: 'Perhatian',
    group: 'Sistem',
    detail: 'Kondisi yang memerlukan tindakan operator',
    to: '/perhatian',
    icon: 'warning',
  },
  {
    label: 'Backup & Restore',
    group: 'Sistem',
    detail: 'Evidence backup terakhir dan batas restore',
    to: '/pengaturan/backup',
    icon: 'backup-restore',
    ownerOnly: true,
  },
  {
    label: 'Kesehatan Sistem',
    group: 'Sistem',
    detail: 'Koneksi perangkat dan live backend authority probe',
    to: '/pengaturan/kesehatan',
    icon: 'security-sync',
  },
  {
    label: 'Offline & Sync',
    group: 'Sistem',
    detail: 'Batas operasi online-only dan status koneksi',
    to: '/pengaturan/offline-sync',
    icon: 'security-sync',
  },
  {
    label: 'Diagnostik',
    group: 'Sistem',
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

      <div className="control-center-groups">
        {(['Bisnis', 'Orang', 'Sistem'] as const).map((group) => {
          const groupCards = cards.filter((card) => card.group === group);
          if (groupCards.length === 0) return null;
          return (
            <section className="control-center-group" key={group}>
              <header>
                <h2>{group}</h2>
              </header>
              <div className="control-center-grid">
                {groupCards.map((card) => (
                  <Link
                    className="control-center-card"
                    key={card.to}
                    to={card.to}
                  >
                    <span className="control-center-icon">
                      <Icon name={card.icon} />
                    </span>
                    <span>
                      <strong>{card.label}</strong>
                      <small>{card.detail}</small>
                    </span>
                    <Icon name="chevron-right" size={16} />
                  </Link>
                ))}
              </div>
            </section>
          );
        })}
      </div>

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
