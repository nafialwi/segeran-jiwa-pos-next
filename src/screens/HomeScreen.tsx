import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import {
  canAccessOwnerArea,
  hasAnyPermission,
  hasPermission,
} from '../auth/permission';

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
        {hasAnyPermission(authority, ['HISTORY_OWN', 'HISTORY_ALL']) && (
          <Link className="nav-card" to="/riwayat">
            Riwayat
          </Link>
        )}
        {hasAnyPermission(authority, [
          'REPORT_SALES_LIMITED',
          'REPORT_INVENTORY',
          'REPORT_PURCHASE',
        ]) && (
          <Link className="nav-card" to="/laporan">
            Laporan
          </Link>
        )}
        {hasPermission(authority, 'INVENTORY_READ') && (
          <Link className="nav-card" to="/stok">
            Stok
          </Link>
        )}
        {hasPermission(authority, 'PURCHASE_MANAGE') && (
          <Link className="nav-card" to="/pembelian">
            Pembelian
          </Link>
        )}
        {canAccessOwnerArea(authority) && (
          <>
            <Link className="nav-card" to="/keuangan">
              Keuangan
            </Link>
            <Link className="nav-card" to="/pengguna">
              Pengguna
            </Link>
            <Link className="nav-card" to="/expense-approval">
              Approval Pengeluaran
            </Link>
            <Link className="nav-card" to="/legacy-import">
              Migrasi Master Legacy
            </Link>
          </>
        )}
        {hasPermission(authority, 'SHIFT_OPEN_CLOSE') && (
          <Link className="nav-card" to="/shift">
            Shift Saya
          </Link>
        )}
        {hasPermission(authority, 'SHIFT_OPEN_CLOSE') && (
          <Link className="nav-card" to="/handover">
            Serah Terima
          </Link>
        )}
        {hasPermission(authority, 'SHIFT_READ_OWN') && (
          <Link className="nav-card" to="/shift-history">
            Riwayat Shift
          </Link>
        )}
        {hasPermission(authority, 'SHIFT_READ_OWN') && (
          <Link className="nav-card" to="/rekonsiliasi">
            Rekonsiliasi
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

// CS-05-P3: Shift navigation cards added below existing nav
