import { useEffect, useMemo, useState, type FormEvent } from 'react';
import {
  saveProductVariantMaster,
  saveSaleProductMaster,
  type ProductMasterComponentInput,
  type ProductMasterStockOption,
  type ProductOperationsProduct,
  type ProductVariantOps,
} from '../operations/product-api';
import {
  productMediaPublicUrl,
  removeProductImage,
  uploadProductImage,
} from '../operations/product-media';
import { Icon } from '../ui/Icon';
import { SearchablePicker } from './SearchablePicker';

type Props = {
  product: ProductOperationsProduct | null;
  initialVariantId?: string | null;
  stockOptions: ProductMasterStockOption[];
  businessId: string;
  imagePath: string | null;
  productMediaReady: boolean;
  onMediaChanged: (productId: string, imagePath: string | null) => void;
  onClose: () => void;
  onSaved: (productId: string) => Promise<void>;
};

type VariantDraft = {
  id: string | null;
  code: string;
  displayName: string;
  fulfillmentMode: ProductVariantOps['fulfillmentMode'];
  saleStockItemId: string | null;
  salePrice: number;
  active: boolean;
  isDefault: boolean;
};

function newVariantDraft(product: ProductOperationsProduct): VariantDraft {
  return {
    id: null,
    code: '',
    displayName: product.displayName,
    fulfillmentMode: 'DIRECT_STOCK',
    saleStockItemId: product.legacyStockItemId,
    salePrice: 1000,
    active: true,
    isDefault: product.variants.length === 0,
  };
}

function fromVariant(variant: ProductVariantOps): VariantDraft {
  return {
    id: variant.id,
    code: variant.code,
    displayName: variant.displayName,
    fulfillmentMode: variant.fulfillmentMode,
    saleStockItemId: variant.saleStockItemId,
    salePrice: variant.salePrice,
    active: variant.active,
    isDefault: variant.isDefault,
  };
}

export function ProductMasterEditor({
  product,
  initialVariantId = null,
  stockOptions,
  businessId,
  imagePath,
  productMediaReady,
  onMediaChanged,
  onClose,
  onSaved,
}: Props) {
  const [productCode, setProductCode] = useState('');
  const [productName, setProductName] = useState('');
  const [categoryCode, setCategoryCode] = useState('');
  const [description, setDescription] = useState('');
  const [productActive, setProductActive] = useState(true);
  const [variantId, setVariantId] = useState<string | null>(null);
  const [variantDraft, setVariantDraft] = useState<VariantDraft | null>(null);
  const [components, setComponents] = useState<ProductMasterComponentInput[]>(
    [],
  );
  const [componentRole, setComponentRole] =
    useState<ProductMasterComponentInput['role']>('PACKAGING');
  const [componentStockItemId, setComponentStockItemId] = useState('');
  const [componentQuantity, setComponentQuantity] = useState(1);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

  useEffect(() => {
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !busy) onClose();
    };
    window.addEventListener('keydown', closeOnEscape);

    return () => {
      document.body.style.overflow = originalOverflow;
      window.removeEventListener('keydown', closeOnEscape);
    };
  }, [busy, onClose]);

  useEffect(() => {
    setProductCode(product?.code ?? '');
    setProductName(product?.displayName ?? '');
    setCategoryCode(product?.categoryCode ?? '');
    setDescription(product?.description ?? '');
    setProductActive(product?.active ?? true);
    const initial =
      product?.variants.find((variant) => variant.id === initialVariantId) ??
      product?.variants[0] ??
      null;
    setVariantId(initial?.id ?? null);
    setVariantDraft(
      initial
        ? fromVariant(initial)
        : product
          ? newVariantDraft(product)
          : null,
    );
    setComponents(
      initial?.components
        .filter((component) => component.role !== 'FINISHED_GOOD')
        .map((component) => ({
          stockItemId: component.stockItemId,
          role: component.role as ProductMasterComponentInput['role'],
          quantityPerUnit: component.quantityPerUnit,
        })) ?? [],
    );
    setError('');
    setMessage('');
  }, [product, initialVariantId]);

  const selectedVariant =
    product?.variants.find((variant) => variant.id === variantId) ?? null;
  const productImageUrl = productMediaPublicUrl(imagePath);

  const componentStockOptions = useMemo(() => {
    if (componentRole === 'PACKAGING') {
      return stockOptions.filter((item) => item.itemKind === 'PACKAGING');
    }
    return stockOptions.filter((item) =>
      ['MATERIAL', 'OTHER'].includes(item.itemKind),
    );
  }, [componentRole, stockOptions]);

  const saleStockOptions = useMemo(() => {
    if (!variantDraft) return [];
    return stockOptions.filter(
      (item) =>
        item.itemKind === 'FINISHED_GOOD' ||
        item.id === variantDraft.saleStockItemId,
    );
  }, [stockOptions, variantDraft]);

  useEffect(() => {
    setComponentStockItemId((current) =>
      componentStockOptions.some((item) => item.id === current)
        ? current
        : (componentStockOptions[0]?.id ?? ''),
    );
  }, [componentStockOptions]);
  function selectVariant(nextId: string | null) {
    if (!product) return;
    const next =
      product.variants.find((variant) => variant.id === nextId) ?? null;
    setVariantId(next?.id ?? null);
    setVariantDraft(next ? fromVariant(next) : newVariantDraft(product));
    setComponents(
      next?.components
        .filter((component) => component.role !== 'FINISHED_GOOD')
        .map((component) => ({
          stockItemId: component.stockItemId,
          role: component.role as ProductMasterComponentInput['role'],
          quantityPerUnit: component.quantityPerUnit,
        })) ?? [],
    );
    setError('');
    setMessage('');
  }

  function addComponent() {
    if (!componentStockItemId || componentQuantity <= 0) return;
    setComponents((current) => [
      ...current.filter((item) => item.stockItemId !== componentStockItemId),
      {
        stockItemId: componentStockItemId,
        role: componentRole,
        quantityPerUnit: componentQuantity,
      },
    ]);
    setComponentQuantity(1);
  }

  async function submitProduct(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await saveSaleProductMaster({
        productId: product?.id ?? null,
        code: productCode,
        displayName: productName,
        categoryCode,
        description,
        active: productActive,
      });
      setMessage(
        result.created
          ? 'Produk berhasil dibuat.'
          : 'Produk berhasil diperbarui.',
      );
      await onSaved(result.product_id);
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Produk gagal disimpan.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function submitVariant(event: FormEvent) {
    event.preventDefault();
    if (!product || !variantDraft) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const effectiveComponents =
        variantDraft.fulfillmentMode === 'MAKE_TO_ORDER'
          ? components
          : components.filter((item) => item.role === 'PACKAGING');

      const result = await saveProductVariantMaster({
        variantId: variantDraft.id,
        productId: product.id,
        code: variantDraft.code,
        displayName: variantDraft.displayName,
        fulfillmentMode: variantDraft.fulfillmentMode,
        saleStockItemId:
          variantDraft.fulfillmentMode === 'MAKE_TO_ORDER'
            ? null
            : variantDraft.saleStockItemId,
        salePrice: variantDraft.salePrice,
        active: variantDraft.active,
        isDefault: variantDraft.isDefault,
        components: effectiveComponents,
      });
      setMessage(
        result.created
          ? 'Varian berhasil dibuat.'
          : 'Varian berhasil diperbarui.',
      );
      await onSaved(product.id);
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Varian gagal disimpan.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function replaceProductImage(file: File | undefined) {
    if (!product || !file || !productMediaReady || busy) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await uploadProductImage({
        businessId,
        productId: product.id,
        file,
        previousPath: imagePath,
      });
      onMediaChanged(product.id, result.path);
      setMessage(
        `Foto produk diperbarui · ${Math.max(1, Math.round(result.size / 1024))} KB.`,
      );
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Foto produk gagal diperbarui.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function clearProductImage() {
    if (!product || !imagePath || !productMediaReady || busy) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      await removeProductImage({
        productId: product.id,
        imagePath,
      });
      onMediaChanged(product.id, null);
      setMessage('Foto produk dihapus. Katalog kembali memakai placeholder.');
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Foto produk gagal dihapus.',
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="product-master-backdrop" role="presentation">
      <section
        className="product-master-dialog"
        role="dialog"
        aria-modal="true"
        aria-label={product ? 'Kelola produk' : 'Tambah produk'}
      >
        <header className="product-master-header">
          <div>
            <p className="eyebrow">PRODUCT MASTER</p>
            <h2>{product ? 'Kelola Produk' : 'Tambah Produk'}</h2>
            <p className="muted">
              Perubahan berlaku untuk transaksi berikutnya. Riwayat transaksi
              lama tetap memakai snapshot saat transaksi.
            </p>
          </div>
          <button
            type="button"
            className="icon-button"
            aria-label="Tutup editor produk"
            onClick={onClose}
            disabled={busy}
          >
            <Icon name="close" size={20} />
          </button>
        </header>

        <div className="product-master-body">
          {error && <p className="error-banner">{error}</p>}
          {message && <p className="success-banner">{message}</p>}

          <form
            className="product-master-section stack-form"
            onSubmit={submitProduct}
          >
            <div className="section-heading">
              <div>
                <p className="eyebrow">INFORMASI PRODUK</p>
                <h3>Produk Jual</h3>
              </div>
              {product && (
                <span className="operations-status">{product.code}</span>
              )}
            </div>

            <div className="compact-grid-form product-master-product-grid">
              <label>
                Kode
                <input
                  value={productCode}
                  onChange={(event) =>
                    setProductCode(event.target.value.toUpperCase())
                  }
                  placeholder="CONTOH_PRODUK"
                  maxLength={64}
                  required
                />
              </label>
              <label>
                Nama produk
                <input
                  value={productName}
                  onChange={(event) => setProductName(event.target.value)}
                  placeholder="Nama yang tampil di Jual"
                  required
                />
              </label>
              <label>
                Kategori
                <input
                  value={categoryCode}
                  onChange={(event) =>
                    setCategoryCode(event.target.value.toUpperCase())
                  }
                  placeholder="MINUMAN"
                  maxLength={64}
                />
              </label>
              <label className="product-master-active-toggle">
                <input
                  type="checkbox"
                  checked={productActive}
                  onChange={(event) => setProductActive(event.target.checked)}
                />
                <span>Aktif dijual</span>
              </label>
            </div>

            <label>
              Deskripsi
              <textarea
                rows={3}
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                placeholder="Catatan produk untuk operasional"
              />
            </label>

            <button className="primary-button" type="submit" disabled={busy}>
              <Icon name="check" size={18} />
              <span>
                {busy
                  ? 'Menyimpan…'
                  : product
                    ? 'Simpan Produk'
                    : 'Buat Produk'}
              </span>
            </button>
          </form>

          {product && (
            <section className="product-master-section product-master-media-section">
              <div className="section-heading">
                <div>
                  <p className="eyebrow">FOTO PRODUK</p>
                  <h3>Gambar di Katalog Jual</h3>
                </div>
                {imagePath && <span className="operations-status">Aktif</span>}
              </div>

              {!productMediaReady ? (
                <p className="muted">
                  Foto produk belum aktif pada backend ini. Produk tetap dapat
                  dijual dengan placeholder.
                </p>
              ) : (
                <div className="product-master-media-layout">
                  <div className="product-master-media-preview">
                    <Icon name="product" size={28} />
                    {productImageUrl ? (
                      <img
                        src={productImageUrl}
                        alt={`Foto ${product.displayName}`}
                        onError={(event) => {
                          event.currentTarget.hidden = true;
                        }}
                      />
                    ) : (
                      <span>Belum ada foto</span>
                    )}
                  </div>

                  <div className="product-master-media-copy">
                    <strong>
                      {imagePath
                        ? 'Foto dipakai di katalog Jual.'
                        : 'Tambahkan foto agar produk lebih cepat dikenali.'}
                    </strong>
                    <small>
                      JPG, PNG, atau WebP. Foto otomatis diperkecil maksimal
                      1200 px dan 2 MB sebelum diunggah.
                    </small>
                    <div className="product-master-media-actions">
                      <label
                        className={
                          busy
                            ? 'secondary-button product-media-file-button disabled'
                            : 'secondary-button product-media-file-button'
                        }
                      >
                        <Icon name="add" size={17} />
                        <span>{imagePath ? 'Ganti Foto' : 'Pilih Foto'}</span>
                        <input
                          className="sr-only"
                          type="file"
                          accept="image/jpeg,image/png,image/webp"
                          disabled={busy}
                          onChange={(event) => {
                            const file = event.currentTarget.files?.[0];
                            event.currentTarget.value = '';
                            void replaceProductImage(file);
                          }}
                        />
                      </label>
                      {imagePath && (
                        <button
                          className="secondary-button"
                          type="button"
                          disabled={busy}
                          onClick={() => void clearProductImage()}
                        >
                          Hapus Foto
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              )}
            </section>
          )}

          {product && variantDraft && (
            <form
              className="product-master-section stack-form"
              onSubmit={submitVariant}
            >
              <div className="section-heading product-master-variant-head">
                <div>
                  <p className="eyebrow">VARIAN & KOMPONEN</p>
                  <h3>Varian Penjualan</h3>
                </div>
                <button
                  className="secondary-button"
                  type="button"
                  disabled={busy}
                  onClick={() => selectVariant(null)}
                >
                  <Icon name="add" size={17} />
                  <span>Varian Baru</span>
                </button>
              </div>

              {product.variants.length > 0 && (
                <div
                  className="product-master-variant-strip"
                  aria-label="Pilih varian"
                >
                  {product.variants.map((variant) => (
                    <button
                      key={variant.id}
                      type="button"
                      className={variantId === variant.id ? 'active' : ''}
                      onClick={() => selectVariant(variant.id)}
                    >
                      <strong>{variant.displayName}</strong>
                      <small>{variant.code}</small>
                    </button>
                  ))}
                </div>
              )}

              <div className="compact-grid-form product-master-variant-grid">
                <label>
                  Kode varian
                  <input
                    value={variantDraft.code}
                    onChange={(event) =>
                      setVariantDraft((current) =>
                        current
                          ? {
                              ...current,
                              code: event.target.value.toUpperCase(),
                            }
                          : current,
                      )
                    }
                    placeholder="DEFAULT"
                    maxLength={64}
                    required
                  />
                </label>
                <label>
                  Nama varian
                  <input
                    value={variantDraft.displayName}
                    onChange={(event) =>
                      setVariantDraft((current) =>
                        current
                          ? { ...current, displayName: event.target.value }
                          : current,
                      )
                    }
                    required
                  />
                </label>
                <label>
                  Harga jual (Rp)
                  <input
                    type="number"
                    inputMode="numeric"
                    min="1"
                    step="1"
                    value={variantDraft.salePrice}
                    onChange={(event) =>
                      setVariantDraft((current) =>
                        current
                          ? {
                              ...current,
                              salePrice: Number(event.target.value),
                            }
                          : current,
                      )
                    }
                    required
                  />
                </label>
                <label>
                  Cara pemenuhan
                  <select
                    value={variantDraft.fulfillmentMode}
                    onChange={(event) => {
                      const mode = event.target
                        .value as VariantDraft['fulfillmentMode'];
                      setVariantDraft((current) =>
                        current
                          ? {
                              ...current,
                              fulfillmentMode: mode,
                              saleStockItemId:
                                mode === 'MAKE_TO_ORDER'
                                  ? null
                                  : current.saleStockItemId,
                            }
                          : current,
                      );
                      if (mode !== 'MAKE_TO_ORDER') {
                        setComponents((current) =>
                          current.filter((item) => item.role === 'PACKAGING'),
                        );
                        setComponentRole('PACKAGING');
                      }
                    }}
                  >
                    <option value="DIRECT_STOCK">Stok langsung</option>
                    <option value="MAKE_TO_ORDER">Dibuat saat dijual</option>
                    <option value="PREPRODUCED">Dibuat sebelumnya</option>
                  </select>
                </label>
              </div>

              {variantDraft.fulfillmentMode !== 'MAKE_TO_ORDER' && (
                <SearchablePicker
                  label="Barang stok penjualan"
                  value={variantDraft.saleStockItemId ?? ''}
                  options={saleStockOptions.map((item) => ({
                    id: item.id,
                    label: item.displayName,
                    meta: item.code + ' · ' + item.baseUnit,
                    keywords: item.itemKind,
                  }))}
                  onChange={(saleStockItemId) =>
                    setVariantDraft((current) =>
                      current ? { ...current, saleStockItemId } : current,
                    )
                  }
                  placeholder="Pilih barang stok"
                  eyebrow="PILIH BARANG JADI"
                  searchPlaceholder="Cari nama atau kode barang…"
                  emptyLabel="Barang stok tidak ditemukan."
                  noun="barang"
                />
              )}

              <div className="product-master-switches">
                <label>
                  <input
                    type="checkbox"
                    checked={variantDraft.active}
                    onChange={(event) =>
                      setVariantDraft((current) =>
                        current
                          ? { ...current, active: event.target.checked }
                          : current,
                      )
                    }
                  />
                  <span>Varian aktif</span>
                </label>
                <label>
                  <input
                    type="checkbox"
                    checked={variantDraft.isDefault}
                    onChange={(event) =>
                      setVariantDraft((current) =>
                        current
                          ? { ...current, isDefault: event.target.checked }
                          : current,
                      )
                    }
                  />
                  <span>Varian utama</span>
                </label>
              </div>
              <section className="product-master-components">
                <div className="section-heading">
                  <div>
                    <h4>Komponen saat dijual</h4>
                    <p className="muted">
                      {variantDraft.fulfillmentMode === 'MAKE_TO_ORDER'
                        ? 'Bahan dan kemasan dikurangi saat transaksi.'
                        : 'Barang jadi dikurangi otomatis; tambahkan hanya kemasan yang dipakai saat penjualan.'}
                    </p>
                  </div>
                </div>

                <div className="product-master-component-builder">
                  <label>
                    Jenis
                    <select
                      value={componentRole}
                      onChange={(event) =>
                        setComponentRole(
                          event.target
                            .value as ProductMasterComponentInput['role'],
                        )
                      }
                      disabled={
                        variantDraft.fulfillmentMode !== 'MAKE_TO_ORDER'
                      }
                    >
                      {variantDraft.fulfillmentMode === 'MAKE_TO_ORDER' && (
                        <option value="INGREDIENT">Bahan</option>
                      )}
                      <option value="PACKAGING">Kemasan</option>
                    </select>
                  </label>
                  <SearchablePicker
                    label={componentRole === 'PACKAGING' ? 'Kemasan' : 'Bahan'}
                    value={componentStockItemId}
                    options={componentStockOptions.map((item) => ({
                      id: item.id,
                      label: item.displayName,
                      meta: item.code + ' · ' + item.baseUnit,
                      keywords: item.itemKind,
                    }))}
                    onChange={setComponentStockItemId}
                    placeholder={
                      componentRole === 'PACKAGING'
                        ? 'Pilih kemasan'
                        : 'Pilih bahan'
                    }
                    eyebrow={
                      componentRole === 'PACKAGING'
                        ? 'PILIH KEMASAN'
                        : 'PILIH BAHAN'
                    }
                    searchPlaceholder="Cari nama atau kode…"
                    emptyLabel="Komponen tidak ditemukan."
                    noun="komponen"
                  />
                  <label>
                    Jumlah / produk
                    <input
                      type="number"
                      inputMode="decimal"
                      min="0.001"
                      step="0.001"
                      value={componentQuantity}
                      onChange={(event) =>
                        setComponentQuantity(Number(event.target.value))
                      }
                    />
                  </label>
                  <button
                    className="secondary-button"
                    type="button"
                    onClick={addComponent}
                    disabled={!componentStockItemId || componentQuantity <= 0}
                  >
                    <Icon name="add" size={17} />
                    <span>Tambah</span>
                  </button>
                </div>

                <div className="product-component-list product-master-component-list">
                  {components.length === 0 ? (
                    <p className="operations-empty">
                      {variantDraft.fulfillmentMode === 'MAKE_TO_ORDER'
                        ? 'Tambahkan minimal satu bahan atau kemasan.'
                        : 'Belum ada kemasan tambahan untuk varian ini.'}
                    </p>
                  ) : (
                    components.map((component) => {
                      const stock = stockOptions.find(
                        (item) => item.id === component.stockItemId,
                      );
                      return (
                        <article key={component.stockItemId}>
                          <span>
                            <strong>
                              {stock?.displayName ?? component.stockItemId}
                            </strong>
                            <small>
                              {component.role === 'PACKAGING'
                                ? 'Kemasan'
                                : 'Bahan'}{' '}
                              · {stock?.code ?? '-'}
                            </small>
                          </span>
                          <span className="bom-config-line-actions">
                            <strong>
                              {component.quantityPerUnit}{' '}
                              {stock?.baseUnit ?? ''}
                            </strong>
                            <button
                              className="secondary-button"
                              type="button"
                              onClick={() =>
                                setComponents((current) =>
                                  current.filter(
                                    (entry) =>
                                      entry.stockItemId !==
                                      component.stockItemId,
                                  ),
                                )
                              }
                            >
                              Hapus
                            </button>
                          </span>
                        </article>
                      );
                    })
                  )}
                </div>
              </section>

              <button
                className="primary-button"
                type="submit"
                disabled={
                  busy ||
                  !variantDraft.code.trim() ||
                  !variantDraft.displayName.trim() ||
                  variantDraft.salePrice <= 0 ||
                  (variantDraft.fulfillmentMode !== 'MAKE_TO_ORDER' &&
                    !variantDraft.saleStockItemId) ||
                  (variantDraft.fulfillmentMode === 'MAKE_TO_ORDER' &&
                    components.length === 0)
                }
              >
                <Icon name="check" size={18} />
                <span>
                  {busy
                    ? 'Menyimpan…'
                    : selectedVariant
                      ? 'Simpan Varian'
                      : 'Buat Varian'}
                </span>
              </button>
            </form>
          )}
        </div>
      </section>
    </div>
  );
}
