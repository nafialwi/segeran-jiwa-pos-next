import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { OperationsNav } from '../components/OperationsNav';
import {
  fetchInventoryItemDetail,
  type InventoryItemDetail,
} from '../inventory/inventory-api';
import { Icon } from '../ui/Icon';

function formatDateTime(value: string): string {
  if (!value) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function signedQuantity(value: number, unit: string): string {
  const sign = value > 0 ? '+' : '';
  return sign + value + ' ' + unit;
}

export function InventoryItemScreen() {
  const { stockItemId = '' } = useParams();
  const [detail, setDetail] = useState<InventoryItemDetail | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;

    void fetchInventoryItemDetail(stockItemId)
      .then((result) => {
        if (active) setDetail(result);
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error ? cause.message : 'INVENTORY_ITEM_READ_FAILED',
        );
      });

    return () => {
      active = false;
    };
  }, [stockItemId]);

  return (
    <main className="shell operations-shell">
      <header className="topbar operations-header">
        <div>
          <Link className="muted" to="/stok">
            Persediaan
          </Link>
          <p className="eyebrow">DETAIL BARANG</p>
          <h1>{detail?.item.displayName ?? 'Barang'}</h1>
          {detail && (
            <p className="muted">
              {detail.item.code} · {detail.item.itemKind}
            </p>
          )}
        </div>
      </header>

      <OperationsNav />

      {error && <p className="error-banner">{error}</p>}

      {!detail ? (
        error ? null : (
          <div className="operations-card-skeleton">
            <span />
            <span />
          </div>
        )
      ) : (
        <>
          <section className="inventory-detail-hero">
            <span className="operations-icon large inventory-detail-icon">
              <Icon
                name={
                  detail.item.itemKind === 'PACKAGING' ? 'product' : 'warehouse'
                }
              />
            </span>
            <div>
              <p className="eyebrow">INFORMASI BARANG</p>
              <h2>{detail.item.displayName}</h2>
              <p>
                Satuan dasar {detail.item.baseUnit} ·{' '}
                {detail.item.inventoryTracked
                  ? 'Stok dilacak'
                  : 'Tidak mengelola stok'}
              </p>
            </div>
            <span className="operations-status">
              {detail.item.saleEnabled ? 'Dijual' : 'Operasional'}
            </span>
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">SALDO</p>
                <h2>Saldo per Lokasi</h2>
              </div>
            </header>
            <div className="inventory-location-grid">
              {detail.item.locations.map((location) => (
                <article key={location.id}>
                  <span>{location.name}</span>
                  <strong>
                    {detail.item.inventoryTracked
                      ? location.quantity + ' ' + detail.item.baseUnit
                      : 'Non-stock'}
                  </strong>
                </article>
              ))}
            </div>
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">RIWAYAT</p>
                <h2>Pergerakan Stok</h2>
              </div>
              <small>40 fakta terbaru</small>
            </header>

            {detail.movements.length === 0 ? (
              <p className="operations-empty">
                Belum ada pergerakan stok untuk barang ini.
              </p>
            ) : (
              <div className="inventory-movement-list">
                {detail.movements.map((movement) => (
                  <article
                    key={
                      movement.movementId +
                      ':' +
                      movement.locationId +
                      ':' +
                      movement.quantityDelta
                    }
                  >
                    <span
                      className={
                        movement.quantityDelta > 0
                          ? 'inventory-delta positive'
                          : 'inventory-delta negative'
                      }
                    >
                      {signedQuantity(
                        movement.quantityDelta,
                        detail.item.baseUnit,
                      )}
                    </span>
                    <div>
                      <strong>{movement.locationName}</strong>
                      <span>
                        Alasan: {movement.reasonCode || movement.movementType}
                      </span>
                      <small>
                        {movement.sourceType} · {movement.sourceRef}
                      </small>
                    </div>
                    <time>{formatDateTime(movement.createdAt)}</time>
                  </article>
                ))}
              </div>
            )}
          </section>
        </>
      )}
    </main>
  );
}
