import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { canAccessOwnerArea, hasPermission } from '../auth/permission';

export function HomeScreen() {
  const { authority, switchUser, logout } = useAuth();

  if (!authority) return null;

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">SEGERAN JIWA POS NEXT</p>
          <h1>Beranda</h1>
        </div>
        <span className="role-badge">{authority.role_code}</span>
      </header>

      <section className="identity-card">
        <div>
          <span className="muted">Pengguna aktif</span>
          <strong>{authority.display_name}</strong>
          <span className="muted">@{authority.username}</span>
        </div>
        <dl className="identity-meta">
          <div>
            <dt>Role</dt>
            <dd>{authority.role_code}</dd>
          </div>
          <div>
            <dt>Perangkat</dt>
            <dd>
              {authority.device_kind === 'SHARED'
                ? 'Perangkat Bersama'
                : 'Perangkat Pribadi'}
            </dd>
          </div>
        </dl>
      </section>

      <nav className="action-grid" aria-label="Akses utama">
        <Link className="nav-card" to="/">
          Beranda
        </Link>
        {hasPermission(authority, 'SALE_EXECUTE') && (
          <Link className="nav-card" to="/jual">
            Jual
          </Link>
        )}
        {canAccessOwnerArea(authority) && (
          <Link className="nav-card" to="/pengguna">
            Pengguna
          </Link>
        )}
      </nav>

      <div className="button-row">
        <button
          className="secondary-button"
          type="button"
          onClick={() => void switchUser()}
        >
          Ganti Pengguna
        </button>
        <button
          className="secondary-button"
          type="button"
          onClick={() => void logout()}
        >
          Keluar
        </button>
      </div>
    </main>
  );
}
