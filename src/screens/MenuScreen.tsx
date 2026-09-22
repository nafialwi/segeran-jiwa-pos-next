import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import {
  canAccessOwnerArea,
  hasAnyPermission,
  hasPermission,
} from '../auth/permission';
import { Icon } from '../ui/Icon';
import type { SegeranIconName } from '../ui/iconRegistry';

type MenuEntry = {
  label: string;
  detail: string;
  to: string;
  icon: SegeranIconName;
};

function MenuGroup({
  title,
  entries,
}: {
  title: string;
  entries: MenuEntry[];
}) {
  if (entries.length === 0) return null;

  return (
    <section className="menu-group">
      <h2>{title}</h2>
      <div className="menu-card-grid">
        {entries.map((entry) => (
          <Link className="menu-card" to={entry.to} key={entry.to}>
            <span className="menu-card-icon">
              <Icon name={entry.icon} />
            </span>
            <span>
              <strong>{entry.label}</strong>
              <small>{entry.detail}</small>
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}

export function MenuScreen() {
  const { authority, switchUser, logout } = useAuth();

  if (!authority) return null;

  const operations: MenuEntry[] = [];
  const business: MenuEntry[] = [];
  const system: MenuEntry[] = [];

  if (hasPermission(authority, 'SALE_EXECUTE')) {
    operations.push({
      label: 'Jual',
      detail: 'Kasir dan pembayaran',
      to: '/jual',
      icon: 'point-of-sale',
    });
  }
  if (hasPermission(authority, 'SHIFT_OPEN_CLOSE')) {
    operations.push(
      {
        label: 'Shift Saya',
        detail: 'Buka, jalankan, dan tutup shift',
        to: '/shift',
        icon: 'activity',
      },
      {
        label: 'Serah Terima',
        detail: 'Alihkan tanggung jawab shift',
        to: '/handover',
        icon: 'security-sync',
      },
    );
  }
  if (hasPermission(authority, 'SHIFT_READ_OWN')) {
    operations.push(
      {
        label: 'Riwayat Shift',
        detail: 'Lihat shift sebelumnya',
        to: '/shift-history',
        icon: 'activity',
      },
      {
        label: 'Rekonsiliasi',
        detail: 'Expected, aktual, dan selisih kas',
        to: '/rekonsiliasi',
        icon: 'diagnostics',
      },
    );
  }

  if (hasPermission(authority, 'INVENTORY_READ')) {
    business.push({
      label: 'Persediaan',
      detail: 'Gudang, Gerai, dan saldo stok',
      to: '/stok',
      icon: 'warehouse',
    });
  }
  if (
    hasAnyPermission(authority, [
      'INVENTORY_REQUEST',
      'INVENTORY_TRANSFER',
      'INVENTORY_COUNT',
      'INVENTORY_ADJUST',
    ])
  ) {
    business.push({
      label: 'Kontrol Stok',
      detail: 'Restock, transfer, opname, dan penyesuaian',
      to: '/stok/kontrol',
      icon: 'diagnostics',
    });
  }
  if (hasAnyPermission(authority, ['INVENTORY_READ', 'PRODUCTION_MANAGE'])) {
    business.push({
      label: 'Produk & Resep',
      detail: 'Varian, resep penjualan, kemasan, dan BOM',
      to: '/produk',
      icon: 'product',
    });
  }
  if (hasPermission(authority, 'PRODUCTION_MANAGE')) {
    business.push({
      label: 'Produksi',
      detail: 'Rencana batch dan posting hasil produksi',
      to: '/produksi',
      icon: 'activity',
    });
  }
  if (hasPermission(authority, 'PURCHASE_MANAGE')) {
    business.push({
      label: 'Pembelian',
      detail: 'Pemasok, pesanan, dan penerimaan',
      to: '/pembelian',
      icon: 'product',
    });
  }
  if (
    hasAnyPermission(authority, [
      'REPORT_SALES_LIMITED',
      'REPORT_INVENTORY',
      'REPORT_PURCHASE',
    ])
  ) {
    business.push({
      label: 'Laporan',
      detail: 'Penjualan, stok, dan pembelian',
      to: '/laporan',
      icon: 'activity',
    });
  }
  if (hasPermission(authority, 'SETTINGS_NONCRITICAL')) {
    system.push({
      label: 'Pengaturan',
      detail: 'Pusat kontrol sistem dan perangkat',
      to: '/pengaturan',
      icon: 'settings',
    });
  }

  if (canAccessOwnerArea(authority)) {
    business.push({
      label: 'Keuangan',
      detail: 'Kas, bank, QRIS, hutang, dan modal',
      to: '/keuangan',
      icon: 'account',
    });

    system.push(
      {
        label: 'Pengguna & Izin',
        detail: 'Akun, role, permission, dan perangkat',
        to: '/pengguna',
        icon: 'users',
      },
      {
        label: 'Approval Pengeluaran',
        detail: 'Tinjau permintaan yang memerlukan Owner',
        to: '/expense-approval',
        icon: 'diagnostics',
      },
      {
        label: 'Migrasi Master Legacy',
        detail: 'Pintu migrasi data yang diaudit',
        to: '/legacy-import',
        icon: 'backup-restore',
      },
    );
  }

  return (
    <main className="shell menu-screen">
      <header className="topbar">
        <div>
          <p className="eyebrow">SEGERAN JIWA POS NEXT</p>
          <h1>Menu</h1>
          <p className="muted">
            Modul yang tampil mengikuti izin pengguna aktif.
          </p>
        </div>
      </header>

      <MenuGroup title="Operasional" entries={operations} />
      <MenuGroup title="Bisnis" entries={business} />
      <MenuGroup title="Sistem" entries={system} />

      <section className="menu-account-card">
        <div>
          <strong>{authority.display_name}</strong>
          <span>@{authority.username}</span>
        </div>
        <div className="menu-account-actions">
          <button
            className="secondary-button"
            type="button"
            onClick={() => void switchUser()}
          >
            Ganti Pengguna
          </button>
          <button
            className="secondary-button danger-lite"
            type="button"
            onClick={() => void logout()}
          >
            <Icon name="logout" size={18} />
            Keluar
          </button>
        </div>
      </section>
    </main>
  );
}
