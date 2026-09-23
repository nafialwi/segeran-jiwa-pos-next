import { useCallback, useEffect, useMemo, useState } from 'react';
import { hasPermission } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { OperationsNav } from '../components/OperationsNav';
import {
  activateBom,
  fetchBomStockOptions,
  fetchProductOperations,
  saveBomDraft,
  type BomStockOption,
  type ProductOperationsProduct,
  type ProductVariantOps,
} from '../operations/product-api';
import { Icon } from '../ui/Icon';

type ProductTab = 'INFO' | 'VARIANTS' | 'RECIPE' | 'PACKAGING';

type BomDraftLine = {
  componentStockItemId: string;
  baseQuantity: number;
};

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
  const { authority } = useAuth();
  const [products, setProducts] = useState<ProductOperationsProduct[]>([]);
  const [bomComponents, setBomComponents] = useState<BomStockOption[]>([]);
  const [selectedId, setSelectedId] = useState('');
  const [tab, setTab] = useState<ProductTab>('INFO');
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [loadingProducts, setLoadingProducts] = useState(true);
  const [loadingBomOptions, setLoadingBomOptions] = useState(false);
  const [bomOptionsLoaded, setBomOptionsLoaded] = useState(false);

  const canManageProduction =
    authority !== null && hasPermission(authority, 'PRODUCTION_MANAGE');

  const load = useCallback(async () => {
    setLoadingProducts(true);
    try {
      const productRows = await fetchProductOperations();
      setProducts(productRows);
      setSelectedId((current) => current || productRows[0]?.id || '');
    } finally {
      setLoadingProducts(false);
    }
  }, []);

  const ensureBomOptions = useCallback(async () => {
    if (bomOptionsLoaded || loadingBomOptions) return;
    setLoadingBomOptions(true);
    try {
      const bomOptions = await fetchBomStockOptions();
      setBomComponents(bomOptions.components);
      setBomOptionsLoaded(true);
    } finally {
      setLoadingBomOptions(false);
    }
  }, [bomOptionsLoaded, loadingBomOptions]);

  useEffect(() => {
    let active = true;
    void load().catch((cause: unknown) => {
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
  }, [load]);

  useEffect(() => {
    if (tab === 'RECIPE' && canManageProduction) {
      void ensureBomOptions().catch((cause: unknown) => {
        setError(
          cause instanceof Error ? cause.message : 'BOM_OPTIONS_READ_FAILED',
        );
      });
    }
  }, [tab, canManageProduction, ensureBomOptions]);

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

  const preproducedVariants = useMemo(
    () =>
      selected?.variants.filter(
        (variant) =>
          variant.fulfillmentMode === 'PREPRODUCED' &&
          variant.saleStockItemId !== null,
      ) ?? [],
    [selected],
  );

  const [bomFinishedGoodId, setBomFinishedGoodId] = useState('');
  const [bomVersion, setBomVersion] = useState(1);
  const [bomYield, setBomYield] = useState(1);
  const [bomLines, setBomLines] = useState<BomDraftLine[]>([]);
  const [bomComponentId, setBomComponentId] = useState('');
  const [bomComponentQuantity, setBomComponentQuantity] = useState(1);

  useEffect(() => {
    const validIds = new Set(
      preproducedVariants
        .map((variant) => variant.saleStockItemId)
        .filter((value): value is string => Boolean(value)),
    );
    setBomFinishedGoodId((current) => {
      if (current && validIds.has(current)) return current;
      return preproducedVariants[0]?.saleStockItemId ?? '';
    });
  }, [preproducedVariants]);

  useEffect(() => {
    setBomComponentId((current) =>
      bomComponents.some((item) => item.id === current)
        ? current
        : (bomComponents[0]?.id ?? ''),
    );
  }, [bomComponents]);

  function addBomLine() {
    if (!bomComponentId || bomComponentQuantity <= 0) return;
    setBomLines((current) => [
      ...current.filter((line) => line.componentStockItemId !== bomComponentId),
      {
        componentStockItemId: bomComponentId,
        baseQuantity: bomComponentQuantity,
      },
    ]);
    setBomComponentQuantity(1);
  }

  async function saveDraft(event: React.FormEvent) {
    event.preventDefault();
    if (
      !bomFinishedGoodId ||
      bomVersion <= 0 ||
      bomYield <= 0 ||
      bomLines.length === 0
    ) {
      return;
    }
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await saveBomDraft({
        finishedGoodId: bomFinishedGoodId,
        version: bomVersion,
        yieldQuantity: bomYield,
        lines: bomLines,
      });
      setMessage(
        result.replay
          ? 'Draft BOM v' + result.version + ' sudah tersimpan.'
          : 'Draft BOM v' + result.version + ' berhasil disimpan.',
      );
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'BOM_SAVE_FAILED');
    } finally {
      setBusy(false);
    }
  }

  async function activate(bomId: string) {
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await activateBom(bomId);
      setMessage('BOM v' + result.version + ' sekarang ' + result.status + '.');
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'BOM_ACTIVATE_FAILED');
    } finally {
      setBusy(false);
    }
  }

  const componentMap = new Map(
    bomComponents.map((component) => [component.id, component]),
  );

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
      {message && <p className="success-banner">{message}</p>}

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
            {loadingProducts ? (
              <div
                className="operations-card-skeleton product-ops-loading"
                aria-label="Memuat produk"
              >
                <span />
                <span />
                <span />
              </div>
            ) : visibleProducts.length === 0 ? (
              <p className="operations-empty">Belum ada produk jual.</p>
            ) : (
              visibleProducts.map((product) => (
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
              ))
            )}
          </div>
        </aside>

        <section className="operations-panel product-ops-detail">
          {!selected ? (
            loadingProducts ? (
              <div
                className="operations-card-skeleton product-detail-loading"
                aria-label="Memuat detail produk"
              >
                <span />
                <span />
              </div>
            ) : (
              <p className="operations-empty">
                {error
                  ? 'Data Product/Variant belum siap.'
                  : 'Belum ada produk jual.'}
              </p>
            )
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
                            {canManageProduction && bom.status === 'DRAFT' && (
                              <button
                                className="secondary-button"
                                type="button"
                                disabled={busy}
                                onClick={() => void activate(bom.id)}
                              >
                                Aktifkan BOM
                              </button>
                            )}
                          </article>
                        )),
                      )
                    )}
                  </section>

                  {canManageProduction && (
                    <section className="bom-config-panel">
                      <header>
                        <div>
                          <p className="eyebrow">OWNER / PRODUKSI</p>
                          <h3>Konfigurasi BOM</h3>
                        </div>
                        <span className="operations-status">
                          PRODUCTION_MANAGE
                        </span>
                      </header>
                      <p className="muted">
                        Simpan sebagai draft versioned. Aktivasi memakai
                        authority BOM yang sama; BOM aktif sebelumnya akan
                        mengikuti aturan backend.
                      </p>

                      {preproducedVariants.length === 0 ? (
                        <p className="operations-empty">
                          Produk ini belum mempunyai varian PREPRODUCED dengan
                          finished good.
                        </p>
                      ) : (
                        <form className="stack-form" onSubmit={saveDraft}>
                          <label>
                            Barang jadi varian
                            <select
                              value={bomFinishedGoodId}
                              onChange={(event) =>
                                setBomFinishedGoodId(event.target.value)
                              }
                            >
                              {preproducedVariants.map((variant) => (
                                <option
                                  key={variant.id}
                                  value={variant.saleStockItemId ?? ''}
                                >
                                  {variant.displayName}
                                </option>
                              ))}
                            </select>
                          </label>
                          <div className="bom-config-numbers">
                            <label>
                              Versi
                              <input
                                type="number"
                                min="1"
                                step="1"
                                value={bomVersion}
                                onChange={(event) =>
                                  setBomVersion(Number(event.target.value))
                                }
                              />
                            </label>
                            <label>
                              Yield
                              <input
                                type="number"
                                min="0.001"
                                step="0.001"
                                value={bomYield}
                                onChange={(event) =>
                                  setBomYield(Number(event.target.value))
                                }
                              />
                            </label>
                          </div>

                          <div className="bom-config-add-line">
                            <label>
                              Komponen
                              <select
                                value={bomComponentId}
                                onChange={(event) =>
                                  setBomComponentId(event.target.value)
                                }
                              >
                                {!bomOptionsLoaded && (
                                  <option value="">
                                    {loadingBomOptions
                                      ? 'Memuat komponen…'
                                      : 'Buka tab Resep untuk memuat komponen'}
                                  </option>
                                )}
                                {bomComponents.map((component) => (
                                  <option
                                    key={component.id}
                                    value={component.id}
                                  >
                                    {component.displayName} ·{' '}
                                    {component.itemKind}
                                  </option>
                                ))}
                              </select>
                            </label>
                            <label>
                              Jumlah dasar
                              <input
                                type="number"
                                min="0.001"
                                step="0.001"
                                value={bomComponentQuantity}
                                onChange={(event) =>
                                  setBomComponentQuantity(
                                    Number(event.target.value),
                                  )
                                }
                              />
                            </label>
                            <button
                              className="secondary-button"
                              type="button"
                              onClick={addBomLine}
                            >
                              Tambah Komponen
                            </button>
                          </div>

                          <div className="product-component-list">
                            {bomLines.map((line) => {
                              const component = componentMap.get(
                                line.componentStockItemId,
                              );
                              return (
                                <article key={line.componentStockItemId}>
                                  <span>
                                    <strong>
                                      {component?.displayName ??
                                        line.componentStockItemId}
                                    </strong>
                                    <small>
                                      {component?.itemKind ?? 'KOMPONEN'}
                                    </small>
                                  </span>
                                  <span className="bom-config-line-actions">
                                    <strong>
                                      {line.baseQuantity}{' '}
                                      {component?.baseUnit ?? ''}
                                    </strong>
                                    <button
                                      className="secondary-button"
                                      type="button"
                                      onClick={() =>
                                        setBomLines((current) =>
                                          current.filter(
                                            (entry) =>
                                              entry.componentStockItemId !==
                                              line.componentStockItemId,
                                          ),
                                        )
                                      }
                                    >
                                      Hapus
                                    </button>
                                  </span>
                                </article>
                              );
                            })}
                          </div>

                          <button
                            className="primary-button"
                            type="submit"
                            disabled={
                              busy ||
                              !bomFinishedGoodId ||
                              bomLines.length === 0
                            }
                          >
                            Simpan Draft BOM
                          </button>
                        </form>
                      )}
                    </section>
                  )}
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
