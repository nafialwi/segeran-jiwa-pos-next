import { NavLink } from 'react-router-dom';
import { Icon } from '../ui/Icon';
import type { SegeranIconName } from '../ui/iconRegistry';

type ControlNavEntry = {
  label: string;
  to: string;
  icon: SegeranIconName;
};

const ENTRIES: ControlNavEntry[] = [
  { label: 'Pusat Kontrol', to: '/pengaturan', icon: 'settings' },
  { label: 'Keuangan', to: '/keuangan', icon: 'account' },
  { label: 'Pengguna', to: '/pengguna', icon: 'users' },
  { label: 'Approval', to: '/expense-approval', icon: 'diagnostics' },
  { label: 'Migrasi', to: '/legacy-import', icon: 'backup-restore' },
];

export function ControlCenterNav() {
  return (
    <nav className="control-center-nav" aria-label="Navigasi Pusat Kontrol">
      {ENTRIES.map((entry) => (
        <NavLink
          key={entry.to}
          to={entry.to}
          className={({ isActive }) =>
            isActive
              ? 'control-center-nav-link active'
              : 'control-center-nav-link'
          }
          end
        >
          <Icon name={entry.icon} size={17} />
          <span>{entry.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
