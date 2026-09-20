import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { canAccessOwnerArea } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { supabase } from '../lib/supabase';

type InventoryRow = {
  location_id: string;
  location_name: string;
  stock_item_id: string;
  code: string;
  display_name: string;
  item_kind: string;
  base_unit: string;
  quantity: number;
  sale_enabled: boolean;
  sale_price: number | null;
  sale_category: string | null;
  inventory_tracked: boolean;
};

function formatIdr(value: number | null): string {
  if (value === null) return '-';
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

export function InventoryScreen() {
  const { authority } = useAuth();
  const [rows, setRows] = useState<InventoryRow[]>([]);
  const [search, setSearch] = useState('');
  const [location, setLocation] = useState('ALL');
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      const { data, error: loadError } = await supabase.rpc(
        'inventory_operational_overview',
      );
      if (loadError) {
        setError(loadError.message);
        return;
      }
      setRows((data ?? []) as InventoryRow[]);
    })();
  }, []);

  const locations = useMemo(
    () =>
      Array.from(
        new Map(
          rows.map((row) => [row.location_id, row.location_name]),
        ).entries(),
      ),
    [rows],
  );

  const visible = useMemo(() => {
    const query = search.trim().toLowerCase();
    return rows.filter(
      (row) =>
        (location === 'ALL' || row.location_id === location) &&
        (!query ||
          row.display_name.toLowerCase().includes(query) ||
          row.code.toLowerCase().includes(query) ||
          String(row.sale_category ?? '')
            .toLowerCase()
            .includes(query)),
    );
  }, [rows, search, location]);

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            Kembali ke Beranda
          </Link>
          <p className="eyebrow">PERSEDIAAN</p>
          <h1>Stok</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}

      <section className="identity-card">
        <div className="section-heading">
          <div>
            <h2>Persediaan per lokasi</h2>
            <p className="muted">
              Saldo berasal dari inventory movement authority.
            </p>
          </div>
          {authority && canAccessOwnerArea(authority) && (
            <Link className="secondary-button link-button" to="/legacy-import">
              Migrasi Master Legacy
            </Link>
          )}
        </div>

        <div className="filter-row">
          <input
            type="search"
            placeholder="Cari item"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
          <select
            value={location}
            onChange={(event) => setLocation(event.target.value)}
          >
            <option value="ALL">Semua lokasi</option>
            {locations.map(([id, name]) => (
              <option key={id} value={id}>
                {name}
              </option>
            ))}
          </select>
        </div>

        {rows.length === 0 ? (
          <div className="empty-state">
            <strong>Master stok belum tersedia.</strong>
            <p>
              Import data Legacy terlebih dahulu. Sistem tidak membuat item
              dummy.
            </p>
          </div>
        ) : (
          <div className="data-table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Lokasi</th>
                  <th>Item</th>
                  <th>Stok</th>
                  <th>Harga Jual</th>
                  <th>Status Jual</th>
                </tr>
              </thead>
              <tbody>
                {visible.map((row) => (
                  <tr key={row.location_id + ':' + row.stock_item_id}>
                    <td>{row.location_name}</td>
                    <td>
                      <strong>{row.display_name}</strong>
                      <small>{row.code}</small>
                    </td>
                    <td>
                      {row.inventory_tracked
                        ? row.quantity + ' ' + row.base_unit
                        : 'Non-stock'}
                    </td>
                    <td>{formatIdr(row.sale_price)}</td>
                    <td>{row.sale_enabled ? 'Aktif' : 'Tidak dijual'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
