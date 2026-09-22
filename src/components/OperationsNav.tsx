import { NavLink } from 'react-router-dom';
import { hasAnyPermission, hasPermission } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { Icon } from '../ui/Icon';
import type { SegeranIconName } from '../ui/iconRegistry';

type OperationsNavEntry = {
  label: string;
  to: string;
  icon: SegeranIconName;
  visible: boolean;
};

export function OperationsNav() {
  const { authority } = useAuth();
  if (!authority) return null;

  const entries: OperationsNavEntry[] = [
    {
      label: 'Persediaan',
      to: '/stok',
      icon: 'warehouse',
      visible: hasPermission(authority, 'INVENTORY_READ'),
    },
    {
      label: 'Kontrol Stok',
      to: '/stok/kontrol',
      icon: 'diagnostics',
      visible: hasAnyPermission(authority, [
        'INVENTORY_REQUEST',
        'INVENTORY_TRANSFER',
        'INVENTORY_COUNT',
        'INVENTORY_ADJUST',
      ]),
    },
    {
      label: 'Produk & Resep',
      to: '/produk',
      icon: 'product',
      visible: hasAnyPermission(authority, [
        'INVENTORY_READ',
        'PRODUCTION_MANAGE',
      ]),
    },
    {
      label: 'Pembelian',
      to: '/pembelian',
      icon: 'product',
      visible: hasPermission(authority, 'PURCHASE_MANAGE'),
    },
    {
      label: 'Produksi',
      to: '/produksi',
      icon: 'activity',
      visible: hasPermission(authority, 'PRODUCTION_MANAGE'),
    },
    {
      label: 'Shift',
      to: '/shift',
      icon: 'security-sync',
      visible: hasPermission(authority, 'SHIFT_OPEN_CLOSE'),
    },
  ];

  return (
    <nav className="operations-nav" aria-label="Navigasi operasional">
      {entries
        .filter((entry) => entry.visible)
        .map((entry) => (
          <NavLink
            key={entry.to}
            to={entry.to}
            className={({ isActive }) =>
              isActive ? 'operations-nav-link active' : 'operations-nav-link'
            }
            end={entry.to === '/stok'}
          >
            <Icon name={entry.icon} size={18} />
            <span>{entry.label}</span>
          </NavLink>
        ))}
    </nav>
  );
}
