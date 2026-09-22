import { useEffect, useMemo, useState } from 'react';
import { OperationsNav } from '../components/OperationsNav';
import {
  fetchProductOperations,
  type ProductOperationsProduct,
  type ProductVariantOps,
} from '../operations/product-api';
import { Icon } from '../ui/Icon';

type ProductTab = 'INFO' | 'VARIANTS' | 'RECIPE' | 'PACKAGING';

function formatIdr(value: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function modeLabel(mode: ProductVariantOps['fulfillmentMode']): string {
  if (mode === 'MAKE_TO_ORDER') return 'Dibuat saat dijual';
  if (mode === 'PREPRODUCED') return 'Dibuat sebelumnya';
  return 'Stok langsung';
}

export function ProductOperationsScreen() {
  const [products, setProducts] = useState<ProductOperationsProduct[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [tab, setTab] = useState<ProductTab>('INFO');
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;

    void fetchProductOperations()
      .then((result) => {
        if (!active) return;
        setProducts(result);
        setSelectedId((current) => current || result[0]?.id || '');
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error
            ? cause.message
            : 'PRODUCT_OPERATIONS_READ_FAILED',
        );
      });

    return () => {
      active = false;
    };
  }, []);

  const visibleProducts = useMemo(() => {
    const query = search.trim().toLowerCase();
    return products.filter(
      (product) =>
        !query ||
        product.displayName.toLowerCase().includes(query) ||
        product.code.toLowerCase().includes(query) ||
        String(product.categoryCode ?? '')
          .toLowerCase()
          .includes(query),
    );
  }, [products, search]);

  const selected =
    products.find((product) => product.id === selectedId) ??
    visibleProducts[0] ??
    null;

  const ingredientComponents =
    selected?.variants.flatMap((variant) =>
      variant.components
        .filter((component) => component.role === 'INGREDIENT')
        .map((component) => ({ variant, component })),
    ) ?? [];

  const packagingComponents =
    selected?.variants.flatMap((variant) =>
      variant.components
        .filter((component) => component.role === 'PACKAGING')
        .map((component) => ({ variant, component })),
    ) ?? [];

  return (
    <main className="shell operations-shell">
      <header className="topbar operations-header">
        <div>
          <p className="eyebrow">OPERASIONAL · PRODUK</p>
          <h1>Produk & Resep</h1>
          <p className="muted">
            Produk jual, varian, konsumsi saat penjualan, dan BOM Produksi.
          </p>
        </div>
      </header>

      <OperationsNav />

      {error && <p className="error-banner">{error}</p>}

      <section className="product-ops-layout">
        <aside className="product-ops-list">
          <label>
            <span className="field-label">Cari produk</span>
            <input
              type="search"
              placeholder="Nama, kode, kategori"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </label>

          <div className="product-ops-list-items">
            {visibleProducts.map((product) => (
              <button
                type="button"
                key={product.id}
                className={
                  selected?.id === product.id
                    ? 'product-ops-select active'
                    : 'product-ops-select'
                }
                onClick={() => {
                  setSelectedId(product.id);
                  setTab('INFO');
                }}
              >
                <span className="operations-icon">
                  <Icon name="product" size={18} />
                </span>
                <span>
                  <strong>{product.displayName}</strong>
                  <small>
                    {product.code} · {product.variants.length} varian
                  </small>
                </span>
              </button>
            ))}
          </div>
        </aside>

        <section className="operations-panel product-ops-detail">
          {!selected ? (
            <p className="operations-empty">
              {error
                ? 'Data Product/Variant belum siap.'
                : 'Belum ada produk jual.'}
            </p>
          ) : (
            <>
              <header className="product-ops-detail-head">
                <div>
                  <p className="eyebrow">{selected.categoryCode ?? 'PRODUK'}</p>
                  <h2>{selected.displayName}</h2>
                  <p className="muted">
                    {selected.code} ·{' '}
                    {selected.active ? 'Aktif dijual' : 'Nonaktif'}
                  </p>
                </div>
                <span className="operations-status">
                  {selected.variants.length} Varian
                </span>
              </header>

              <div className="product-ops-tabs" role="tablist">
                {[
                  ['INFO', 'Informasi'],
                  ['VARIANTS', 'Varian'],
                  ['RECIPE', 'Resep'],
                  ['PACKAGING', 'Kemasan'],
                ].map(([value, label]) => (
                  <button
                    type="button"
                    key={value}
                    className={tab === value ? 'active' : ''}
                    onClick={() => setTab(value as ProductTab)}
                  >
                    {label}
                  </button>
                ))}
              </div>

              {tab === 'INFO' && (
                <div className="product-ops-info-grid">
                  <article>
                    <span>Kode Produk</span>
                    <strong>{selected.code}</strong>
                  </article>
                  <article>
                    <span>Kategori</span>
                    <strong>{selected.categoryCode ?? '-'}</strong>
                  </article>
                  <article>
                    <span>Varian Aktif</span>
                    <strong>
                      {
                        selected.variants.filter((variant) => variant.active)
                          .length
                      }
                    </strong>
                  </article>
                  <article>
                    <span>Sumber kompatibilitas</span>
                    <strong>
                      {selected.legacyStockItemId
                        ? 'Legacy mapped'
                        : 'Product V2'}
                    </strong>
                  </article>
                  {selected.description && (
                    <p className="product-ops-description">
                      {selected.description}
                    </p>
                  )}
                </div>
              )}

              {tab === 'VARIANTS' && (
                <div className="product-variant-list">
                  {selected.variants.map((variant) => (
                    <article key={variant.id}>
                      <div>
                        <strong>{variant.displayName}</strong>
                        <span>{variant.code}</span>
                      </div>
                      <span className="operations-mode">
                        {variant.fulfillmentMode}
                      </span>
                      <span>{modeLabel(variant.fulfillmentMode)}</span>
                      <strong>{formatIdr(variant.salePrice)}</strong>
                    </article>
                  ))}
                </div>
              )}

              {tab === 'RECIPE' && (
                <div className="product-ops-stack">
                  <section>
                    <h3>Resep saat Penjualan</h3>
                    <p className="muted">
                      Komponen INGREDIENT untuk varian MAKE_TO_ORDER. Mode
                      PREPRODUCED memakai barang jadi saat dijual.
                    </p>
                    {ingredientComponents.length === 0 ? (
                      <p className="operations-empty">
                        Tidak ada ingredient sale-stage pada produk ini.
                      </p>
                    ) : (
                      <div className="product-component-list">
                        {ingredientComponents.map(({ variant, component }) => (
                          <article
                            key={variant.id + ':' + component.stockItemId}
                          >
                            <span>
                              <strong>{component.name}</strong>
                              <small>{variant.displayName}</small>
                            </span>
                            <strong>
                              {component.quantityPerUnit} {component.baseUnit}
                            </strong>
                          </article>
                        ))}
                      </div>
                    )}
                  </section>

                  <section>
                    <h3>BOM Produksi</h3>
                    <p className="muted">
                      Authority resep produksi versioned untuk barang
                      PREPRODUCED.
                    </p>
                    {selected.variants.every(
                      (variant) => variant.boms.length === 0,
                    ) ? (
                      <p className="operations-empty">
                        Belum ada BOM Produksi pada finished good varian ini.
                      </p>
                    ) : (
                      selected.variants.map((variant) =>
                        variant.boms.map((bom) => (
                          <article className="product-bom-card" key={bom.id}>
                            <header>
                              <span>
                                <strong>{variant.displayName}</strong>
                                <small>
                                  BOM v{bom.version} · {bom.status}
                                </small>
                              </span>
                              <span>Yield {bom.yieldQuantity}</span>
                            </header>
                            <div className="product-component-list">
                              {bom.lines.map((line) => (
                                <article key={bom.id + ':' + line.stockItemId}>
                                  <span>
                                    <strong>{line.name}</strong>
                                    <small>{line.code}</small>
                                  </span>
                                  <strong>
                                    {line.quantity} {line.baseUnit}
                                  </strong>
                                </article>
                              ))}
                            </div>
                          </article>
                        )),
                      )
                    )}
                  </section>
                </div>
              )}

              {tab === 'PACKAGING' && (
                <div className="product-ops-stack">
                  <section>
                    <h3>Kemasan saat Penjualan</h3>
                    <p className="muted">
                      Packaging ditentukan per varian, bukan berdasarkan nama
                      atau kategori produk.
                    </p>
                    {packagingComponents.length === 0 ? (
                      <p className="operations-empty">
                        Tidak ada packaging sale-stage pada produk ini.
                      </p>
                    ) : (
                      <div className="product-component-list">
                        {packagingComponents.map(({ variant, component }) => (
                          <article
                            key={variant.id + ':' + component.stockItemId}
                          >
                            <span>
                              <strong>{component.name}</strong>
                              <small>{variant.displayName}</small>
                            </span>
                            <strong>
                              {component.quantityPerUnit} {component.baseUnit}
                            </strong>
                          </article>
                        ))}
                      </div>
                    )}
                  </section>
                </div>
              )}
            </>
          )}
        </section>
      </section>
    </main>
  );
}
