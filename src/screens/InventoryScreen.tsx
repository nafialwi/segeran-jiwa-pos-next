import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { canAccessOwnerArea } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { OperationsNav } from '../components/OperationsNav';
import {
  aggregateInventoryItems,
  fetchInventoryOverview,
  prefetchInventoryItemDetail,
  type InventoryRow,
} from '../inventory/inventory-api';
import { Icon } from '../ui/Icon';

function formatIdr(value: number | null): string {
  if (value === null) return '-';
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function itemKindLabel(value: string): string {
  if (value === 'MATERIAL') return 'Bahan';
  if (value === 'PACKAGING') return 'Kemasan';
  if (value === 'FINISHED_GOOD') return 'Barang Jadi';
  return 'Lainnya';
}

export function InventoryScreen() {
  const { authority } = useAuth();
  const [rows, setRows] = useState<InventoryRow[]>([]);
  const [search, setSearch] = useState('');
  const [location, setLocation] = useState('ALL');
  const [kind, setKind] = useState('ALL');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;

    void fetchInventoryOverview()
      .then((result) => {
        if (active) setRows(result);
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error ? cause.message : 'INVENTORY_READ_FAILED',
        );
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
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

  const filteredRows = useMemo(
    () =>
      rows.filter(
        (row) =>
          (location === 'ALL' || row.location_id === location) &&
          (kind === 'ALL' || row.item_kind === kind),
      ),
    [rows, location, kind],
  );

  const items = useMemo(() => {
    const query = search.trim().toLowerCase();
    return aggregateInventoryItems(filteredRows).filter(
      (item) =>
        !query ||
        item.displayName.toLowerCase().includes(query) ||
        item.code.toLowerCase().includes(query) ||
        String(item.saleCategory ?? '')
          .toLowerCase()
          .includes(query),
    );
  }, [filteredRows, search]);

  const allItems = useMemo(() => aggregateInventoryItems(rows), [rows]);
  const trackedCount = allItems.filter((item) => item.inventoryTracked).length;
  const saleCount = allItems.filter((item) => item.saleEnabled).length;

  return (
    <main className="shell operations-shell">
      <header className="topbar operations-header">
        <div>
          <p className="eyebrow">OPERASIONAL · PERSEDIAAN</p>
          <h1>Persediaan</h1>
          <p className="muted">
            Saldo berasal dari satu inventory movement authority.
          </p>
        </div>
        {authority && canAccessOwnerArea(authority) && (
          <Link className="secondary-button link-button" to="/legacy-import">
            Migrasi Legacy
          </Link>
        )}
      </header>

      <OperationsNav />

      {error && <p className="error-banner">{error}</p>}

      <section
        className="inventory-summary-grid"
        aria-label="Ringkasan persediaan"
      >
        <article>
          <Icon name="product" />
          <span>Barang</span>
          <strong>{allItems.length}</strong>
        </article>
        <article>
          <Icon name="warehouse" />
          <span>Dilacak Stok</span>
          <strong>{trackedCount}</strong>
        </article>
        <article>
          <Icon name="activity" />
          <span>Lokasi</span>
          <strong>{locations.length}</strong>
        </article>
        <article>
          <Icon name="point-of-sale" />
          <span>Barang Jual</span>
          <strong>{saleCount}</strong>
        </article>
      </section>

      <section className="operations-panel">
        <div className="operations-filter-row">
          <label className="operations-search-field">
            <span className="sr-only">Cari barang</span>
            <Icon name="search" size={18} />
            <input
              type="search"
              placeholder="Cari barang, kode, atau kategori"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </label>
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
          <select
            value={kind}
            onChange={(event) => setKind(event.target.value)}
          >
            <option value="ALL">Semua kategori</option>
            <option value="MATERIAL">Bahan</option>
            <option value="PACKAGING">Kemasan</option>
            <option value="FINISHED_GOOD">Barang Jadi</option>
            <option value="OTHER">Lainnya</option>
          </select>
        </div>

        {loading ? (
          <div className="operations-card-skeleton" aria-label="Memuat stok">
            <span />
            <span />
            <span />
          </div>
        ) : rows.length === 0 ? (
          <div className="empty-state">
            <strong>Master stok belum tersedia.</strong>
            <p>
              Import data Legacy atau tambahkan barang lewat alur Pembelian.
              Sistem tidak membuat item dummy.
            </p>
          </div>
        ) : items.length === 0 ? (
          <p className="operations-empty">Tidak ada barang sesuai filter.</p>
        ) : (
          <div className="inventory-item-grid">
            {items.map((item) => (
              <Link
                className="inventory-item-card"
                key={item.stockItemId}
                to={'/stok/' + item.stockItemId}
                onPointerDown={() =>
                  prefetchInventoryItemDetail(item.stockItemId)
                }
              >
                <div className="inventory-item-head">
                  <span className="operations-icon">
                    <Icon
                      name={
                        item.itemKind === 'PACKAGING' ? 'product' : 'warehouse'
                      }
                    />
                  </span>
                  <span>
                    <strong>{item.displayName}</strong>
                    <small>{item.code}</small>
                    <span className="inventory-kind-chip">
                      {itemKindLabel(item.itemKind)}
                    </span>
                  </span>
                </div>

                <div className="inventory-item-balance">
                  <span>
                    {item.inventoryTracked ? 'Saldo' : 'Status persediaan'}
                  </span>
                  <strong>
                    {item.inventoryTracked
                      ? item.totalQuantity + ' ' + item.baseUnit
                      : 'Non-stock'}
                  </strong>
                </div>

                <div className="inventory-item-meta">
                  <span>
                    {item.saleEnabled
                      ? 'Dijual · ' + formatIdr(item.salePrice)
                      : 'Tidak dijual'}
                  </span>
                  <span>
                    {item.locations.length}{' '}
                    {item.locations.length === 1 ? 'lokasi' : 'lokasi'}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
