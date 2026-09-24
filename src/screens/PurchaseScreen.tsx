import { useCallback, useEffect, useMemo, useState } from 'react';
import { OperationsNav } from '../components/OperationsNav';
import { SearchablePicker } from '../components/SearchablePicker';
import { Icon } from '../ui/Icon';
import { supabase } from '../lib/supabase';
import {
  createGoodsReceipt,
  createPurchaseItem,
  createPurchaseOrder,
  createPurchaseSupplier,
  directBuy,
  fetchPurchaseFrontDoorOptions,
  postGoodsReceipt,
  type PurchaseFrontDoorOptions,
  type PurchaseItem,
  type PurchaseLineInput,
} from '../purchase/purchase-api';

type PayableRow = {
  payable_id: string;
  supplier_name: string;
  invoice_reference: string | null;
  original_amount: number;
  paid_amount: number;
  balance: number;
  status: string;
  created_at: string;
};

type PurchaseOverview = {
  payables: PayableRow[];
};

type PurchaseTab = 'DIRECT' | 'ORDER' | 'RECEIPT' | 'MASTER';

type DraftLine = {
  item: PurchaseItem;
  quantity: number;
  unitPrice: number;
};

function formatIdr(value: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

const EMPTY_OPTIONS: PurchaseFrontDoorOptions = {
  suppliers: [],
  locations: [],
  units: [],
  items: [],
  receivable_orders: [],
  receipts: [],
};

export function PurchaseScreen() {
  const [options, setOptions] =
    useState<PurchaseFrontDoorOptions>(EMPTY_OPTIONS);
  const [payables, setPayables] = useState<PayableRow[]>([]);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loadingOptions, setLoadingOptions] = useState(true);
  const [loadingFinance, setLoadingFinance] = useState(true);
  const [purchaseTab, setPurchaseTab] = useState<PurchaseTab>('DIRECT');

  const [supplierCode, setSupplierCode] = useState('');
  const [supplierName, setSupplierName] = useState('');
  const [supplierPhone, setSupplierPhone] = useState('');

  const [itemCode, setItemCode] = useState('');
  const [itemName, setItemName] = useState('');
  const [itemKind, setItemKind] = useState('MATERIAL');
  const [itemUnitId, setItemUnitId] = useState('');

  const [supplierId, setSupplierId] = useState('');
  const [locationId, setLocationId] = useState('');
  const [selectedItemId, setSelectedItemId] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [unitPrice, setUnitPrice] = useState(0);
  const [draftLines, setDraftLines] = useState<DraftLine[]>([]);
  const [purchaseNotes, setPurchaseNotes] = useState('');

  const [receiveOrderId, setReceiveOrderId] = useState('');
  const [receiveLineId, setReceiveLineId] = useState('');
  const [receiveQuantity, setReceiveQuantity] = useState(1);
  const [receiveNotes, setReceiveNotes] = useState('');

  const load = useCallback(async () => {
    setLoadingOptions(true);
    setLoadingFinance(true);

    const frontDoorPromise = fetchPurchaseFrontDoorOptions()
      .then((frontDoor) => {
        setOptions(frontDoor);
        setSupplierId((current) =>
          frontDoor.suppliers.some((row) => row.id === current)
            ? current
            : (frontDoor.suppliers[0]?.id ?? ''),
        );
        setLocationId((current) =>
          frontDoor.locations.some((row) => row.id === current)
            ? current
            : (frontDoor.locations[0]?.id ?? ''),
        );
        setSelectedItemId((current) =>
          frontDoor.items.some((row) => row.id === current)
            ? current
            : (frontDoor.items[0]?.id ?? ''),
        );
        setItemUnitId((current) =>
          frontDoor.units.some((row) => row.id === current)
            ? current
            : (frontDoor.units[0]?.id ?? ''),
        );
        setReceiveOrderId((current) =>
          frontDoor.receivable_orders.some((row) => row.id === current)
            ? current
            : (frontDoor.receivable_orders[0]?.id ?? ''),
        );
      })
      .finally(() => setLoadingOptions(false));

    const financePromise = (async () => {
      try {
        const overviewResult = await supabase.rpc(
          'purchase_operational_overview',
        );
        if (overviewResult.error) throw new Error(overviewResult.error.message);
        const overview = (overviewResult.data ??
          {}) as Partial<PurchaseOverview>;
        setPayables(overview.payables ?? []);
      } finally {
        setLoadingFinance(false);
      }
    })();

    await Promise.all([frontDoorPromise, financePromise]);
  }, []);

  useEffect(() => {
    void load().catch((caught: unknown) => {
      setError(
        caught instanceof Error
          ? caught.message
          : 'Data pembelian gagal dimuat.',
      );
    });
  }, [load]);

  const selectedItem = options.items.find((item) => item.id === selectedItemId);

  const selectedReceiveOrder = options.receivable_orders.find(
    (order) => order.id === receiveOrderId,
  );

  const receivableLines = useMemo(
    () =>
      (selectedReceiveOrder?.lines ?? []).filter(
        (line) => Number(line.remaining_quantity) > 0,
      ),
    [selectedReceiveOrder],
  );

  useEffect(() => {
    if (!receivableLines.some((line) => line.id === receiveLineId)) {
      setReceiveLineId(receivableLines[0]?.id ?? '');
      setReceiveQuantity(
        Math.min(1, Number(receivableLines[0]?.remaining_quantity ?? 1)),
      );
    }
  }, [receivableLines, receiveLineId]);

  async function action(work: () => Promise<string | void>) {
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await work();
      if (result) setMessage(result);
      await load();
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : 'Aksi pembelian gagal.',
      );
    } finally {
      setBusy(false);
    }
  }

  function addDraftLine() {
    if (!selectedItem || quantity <= 0 || unitPrice < 0) return;

    setDraftLines((current) => {
      const without = current.filter(
        (line) => line.item.id !== selectedItem.id,
      );
      return [...without, { item: selectedItem, quantity, unitPrice }];
    });
    setQuantity(1);
    setUnitPrice(0);
  }

  function purchaseLines(): PurchaseLineInput[] {
    return draftLines.map((line) => ({
      stock_item_id: line.item.id,
      unit_id: line.item.base_unit_id,
      quantity: line.quantity,
      unit_price: line.unitPrice,
    }));
  }

  async function saveSupplier(event: React.FormEvent) {
    event.preventDefault();
    await action(async () => {
      await createPurchaseSupplier({
        code: supplierCode,
        displayName: supplierName,
        phone: supplierPhone,
      });
      setSupplierCode('');
      setSupplierName('');
      setSupplierPhone('');
      return 'Pemasok berhasil ditambahkan.';
    });
  }

  async function saveItem(event: React.FormEvent) {
    event.preventDefault();
    await action(async () => {
      await createPurchaseItem({
        code: itemCode,
        displayName: itemName,
        itemKind,
        unitId: itemUnitId,
      });
      setItemCode('');
      setItemName('');
      return 'Barang berhasil ditambahkan.';
    });
  }

  async function saveOrder() {
    if (!supplierId || !locationId || draftLines.length === 0) return;
    await action(async () => {
      const result = await createPurchaseOrder({
        supplierId,
        locationId,
        lines: purchaseLines(),
        notes: purchaseNotes,
      });
      setDraftLines([]);
      setPurchaseNotes('');
      return 'Pesanan ke Pemasok tersimpan: ' + result.order_number;
    });
  }

  async function saveDirectBuy() {
    if (!supplierId || !locationId || draftLines.length === 0) return;
    await action(async () => {
      const result = await directBuy({
        supplierId,
        locationId,
        lines: purchaseLines(),
        notes: purchaseNotes,
      });
      setDraftLines([]);
      setPurchaseNotes('');
      return (
        'Belanja Langsung selesai. ' +
        result.order_number +
        ' / ' +
        result.receipt_number
      );
    });
  }

  async function saveReceipt() {
    if (!receiveOrderId || !receiveLineId || receiveQuantity <= 0) return;
    await action(async () => {
      const result = await createGoodsReceipt({
        purchaseOrderId: receiveOrderId,
        lines: [
          {
            purchase_order_line_id: receiveLineId,
            received_quantity: receiveQuantity,
          },
        ],
        notes: receiveNotes,
      });
      setReceiveNotes('');
      return (
        'Penerimaan Barang tersimpan: ' +
        result.receipt_number +
        '. Tekan Barang Diterima untuk menambah stok.'
      );
    });
  }

  async function postReceipt(receiptId: string) {
    await action(async () => {
      const result = await postGoodsReceipt(receiptId);
      return result.already_posted
        ? 'Penerimaan sudah pernah diposting.'
        : 'Barang Diterima. Stok sudah bertambah.';
    });
  }

  const payableBalance = payables.reduce(
    (total, row) => total + Number(row.balance ?? 0),
    0,
  );
  const pendingReceipts = options.receipts.filter(
    (receipt) => receipt.status === 'RECEIVED',
  ).length;

  const purchaseTabs: Array<{
    value: PurchaseTab;
    label: string;
    detail: string;
  }> = [
    {
      value: 'DIRECT',
      label: 'Belanja Langsung',
      detail: 'Beli dan terima stok dalam satu alur',
    },
    {
      value: 'ORDER',
      label: 'Pesanan Pemasok',
      detail: 'Buat PO tanpa menambah stok',
    },
    {
      value: 'RECEIPT',
      label: 'Penerimaan Barang',
      detail: 'Terima dan posting barang dari PO',
    },
    {
      value: 'MASTER',
      label: 'Master Data',
      detail: 'Pemasok dan barang pembelian',
    },
  ];

  const renderDraftBuilder = (mode: 'DIRECT' | 'ORDER') => (
    <>
      {options.suppliers.length === 0 || options.items.length === 0 ? (
        <div className="empty-state">
          <strong>Master Pembelian belum lengkap.</strong>
          <p>
            Tambahkan minimal satu Pemasok dan satu Barang pada tab Master Data,
            atau import master Legacy untuk Barang jual.
          </p>
        </div>
      ) : (
        <>
          <div className="purchase-flow-guide">
            <span className="active">1 · Pilih pemasok</span>
            <span>2 · Tambah barang</span>
            <span>3 · {mode === 'DIRECT' ? 'Terima stok' : 'Simpan PO'}</span>
          </div>

          <div className="compact-grid-form purchase-order-fields">
            <SearchablePicker
              label="Pemasok"
              value={supplierId}
              options={options.suppliers.map((supplier) => ({
                id: supplier.id,
                label: supplier.display_name,
                meta:
                  supplier.code +
                  (supplier.phone ? ' · ' + supplier.phone : ''),
              }))}
              onChange={setSupplierId}
              placeholder="Pilih pemasok"
              eyebrow="PILIH PEMASOK"
              searchPlaceholder="Cari nama, kode, atau telepon…"
              emptyLabel="Pemasok tidak ditemukan."
              noun="pemasok"
            />
            <label>
              Lokasi Penerimaan
              <select
                value={locationId}
                onChange={(event) => setLocationId(event.target.value)}
              >
                {options.locations.map((location) => (
                  <option key={location.id} value={location.id}>
                    {location.display_name}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <section className="purchase-line-builder">
            <header>
              <div>
                <p className="eyebrow">BARANG</p>
                <h3>Tambah ke Pembelian</h3>
              </div>
            </header>
            <div className="compact-grid-form">
              <SearchablePicker
                label="Barang"
                value={selectedItemId}
                options={options.items.map((item) => ({
                  id: item.id,
                  label: item.display_name,
                  meta: item.code + ' · ' + item.base_unit,
                  keywords: item.item_kind,
                }))}
                onChange={setSelectedItemId}
                placeholder="Pilih barang"
                eyebrow="PILIH BARANG"
                searchPlaceholder="Cari nama, kode, kategori, atau satuan…"
                emptyLabel="Barang tidak ditemukan."
                noun="barang"
              />
              <label>
                Jumlah ({selectedItem?.base_unit ?? 'satuan'})
                <input
                  type="number"
                  inputMode="decimal"
                  min="0.001"
                  step="0.001"
                  value={quantity}
                  onChange={(event) => setQuantity(Number(event.target.value))}
                />
              </label>
              <label>
                Harga per Satuan
                <input
                  type="number"
                  inputMode="numeric"
                  min="0"
                  step="1"
                  value={unitPrice}
                  onChange={(event) => setUnitPrice(Number(event.target.value))}
                />
              </label>
              <button
                className="secondary-button"
                type="button"
                onClick={addDraftLine}
              >
                Tambah ke Pembelian
              </button>
            </div>
          </section>

          {draftLines.length > 0 ? (
            <div className="stack-list purchase-draft">
              {draftLines.map((line) => (
                <article className="cart-row" key={line.item.id}>
                  <div>
                    <strong>{line.item.display_name}</strong>
                    <span className="muted">
                      {line.quantity} {line.item.base_unit} ×{' '}
                      {formatIdr(line.unitPrice)}
                    </span>
                  </div>
                  <strong>{formatIdr(line.quantity * line.unitPrice)}</strong>
                  <button
                    className="secondary-button"
                    type="button"
                    onClick={() =>
                      setDraftLines((current) =>
                        current.filter(
                          (entry) => entry.item.id !== line.item.id,
                        ),
                      )
                    }
                  >
                    Hapus
                  </button>
                </article>
              ))}
              <div className="purchase-total-row">
                <span>Total</span>
                <strong>
                  {formatIdr(
                    draftLines.reduce(
                      (total, line) => total + line.quantity * line.unitPrice,
                      0,
                    ),
                  )}
                </strong>
              </div>
            </div>
          ) : (
            <p className="operations-empty">
              Belum ada barang pada pembelian ini.
            </p>
          )}

          <label>
            Catatan Pembelian
            <textarea
              value={purchaseNotes}
              onChange={(event) => setPurchaseNotes(event.target.value)}
              rows={2}
            />
          </label>

          <button
            className="primary-button purchase-primary-action"
            type="button"
            disabled={busy || draftLines.length === 0}
            onClick={() =>
              void (mode === 'DIRECT' ? saveDirectBuy() : saveOrder())
            }
          >
            {mode === 'DIRECT'
              ? 'Selesaikan Belanja Langsung'
              : 'Simpan Pesanan Pemasok'}
          </button>

          <div className="purchase-authority-note">
            <strong>
              {mode === 'DIRECT'
                ? 'Stok akan bertambah setelah alur direct-buy selesai.'
                : 'Pesanan Pemasok belum menambah stok.'}
            </strong>
            <span>
              {mode === 'DIRECT'
                ? 'Engine tetap memakai purchase + goods receipt authority yang sama.'
                : 'Stok baru berubah setelah Penerimaan Barang diposting.'}
            </span>
          </div>
        </>
      )}
    </>
  );

  return (
    <main className="shell operations-shell">
      <header className="topbar operations-header">
        <div>
          <p className="eyebrow">OPERASIONAL · PEMBELIAN</p>
          <h1>Pembelian & Pemasok</h1>
          <p className="muted">
            Pisahkan pembelian langsung, pesanan, dan penerimaan agar status
            stok selalu jelas.
          </p>
        </div>
      </header>

      <OperationsNav />

      {error && <p className="error-banner" role="alert">{error}</p>}
      {message && <p className="success-banner" role="status" aria-live="polite">{message}</p>}

      <section
        className="purchase-summary-grid"
        aria-label="Ringkasan pembelian"
      >
        <article>
          <span className="purchase-summary-icon">
            <Icon name="users" size={20} />
          </span>
          <span>Pemasok</span>
          <strong>{loadingOptions ? '…' : options.suppliers.length}</strong>
        </article>
        <article>
          <span className="purchase-summary-icon">
            <Icon name="cart" size={20} />
          </span>
          <span>PO Menunggu Barang</span>
          <strong>
            {loadingOptions ? '…' : options.receivable_orders.length}
          </strong>
        </article>
        <article>
          <span className="purchase-summary-icon">
            <Icon name="restock" size={20} />
          </span>
          <span>Siap Diposting</span>
          <strong>{loadingOptions ? '…' : pendingReceipts}</strong>
        </article>
        <article>
          <span className="purchase-summary-icon">
            <Icon name="debt" size={20} />
          </span>
          <span>Utang Pemasok</span>
          <strong>{loadingFinance ? '…' : formatIdr(payableBalance)}</strong>
        </article>
      </section>

      <div className="purchase-workflow-tabs" role="tablist">
        {purchaseTabs.map((tab) => (
          <button
            type="button"
            key={tab.value}
            className={purchaseTab === tab.value ? 'active' : ''}
            onClick={() => setPurchaseTab(tab.value)}
          >
            <Icon
              name={
                tab.value === 'DIRECT'
                  ? 'cart'
                  : tab.value === 'ORDER'
                    ? 'receipt'
                    : tab.value === 'RECEIPT'
                      ? 'restock'
                      : 'category'
              }
              size={22}
            />
            <span className="purchase-tab-copy">
              <strong>{tab.label}</strong>
              <span>{tab.detail}</span>
            </span>
          </button>
        ))}
      </div>

      {purchaseTab === 'DIRECT' && (
        <section className="operations-panel purchase-workflow-panel">
          <header className="operations-panel-header">
            <div>
              <p className="eyebrow">SATU LANGKAH</p>
              <h2>Belanja Langsung</h2>
              <p className="muted">
                Untuk pembelian yang barangnya langsung diterima di lokasi.
              </p>
            </div>
          </header>
          {renderDraftBuilder('DIRECT')}
        </section>
      )}

      {purchaseTab === 'ORDER' && (
        <section className="operations-panel purchase-workflow-panel">
          <header className="operations-panel-header">
            <div>
              <p className="eyebrow">ORDER</p>
              <h2>Pesanan Pemasok</h2>
              <p className="muted">
                Buat pesanan terlebih dahulu. Stok belum berubah sampai barang
                diterima.
              </p>
            </div>
          </header>
          {renderDraftBuilder('ORDER')}
        </section>
      )}

      {purchaseTab === 'RECEIPT' && (
        <section className="operations-panel purchase-workflow-panel">
          <header className="operations-panel-header">
            <div>
              <p className="eyebrow">PENERIMAAN</p>
              <h2>Penerimaan Barang</h2>
              <p className="muted">
                Catat jumlah datang, lalu posting hanya setelah barang
                benar-benar diterima.
              </p>
            </div>
          </header>

          {options.receivable_orders.length === 0 ? (
            <p className="operations-empty">
              Tidak ada Pesanan Pemasok yang menunggu penerimaan.
            </p>
          ) : (
            <div className="purchase-receipt-layout">
              <div className="compact-grid-form">
                <SearchablePicker
                  label="Pesanan"
                  value={receiveOrderId}
                  options={options.receivable_orders.map((order) => ({
                    id: order.id,
                    label: order.order_number,
                    meta: order.supplier_name + ' · ' + order.location_name,
                    keywords: order.status,
                  }))}
                  onChange={setReceiveOrderId}
                  placeholder="Pilih pesanan pemasok"
                  eyebrow="PILIH PESANAN"
                  searchPlaceholder="Cari nomor PO atau pemasok…"
                  emptyLabel="Pesanan tidak ditemukan."
                  noun="pesanan"
                />
                <label>
                  Barang
                  <select
                    value={receiveLineId}
                    onChange={(event) => setReceiveLineId(event.target.value)}
                  >
                    {receivableLines.map((line) => (
                      <option key={line.id} value={line.id}>
                        {line.item_name} · sisa{' '}
                        {Number(line.remaining_quantity)}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Jumlah Diterima
                  <input
                    type="number"
                    inputMode="decimal"
                    min="0.001"
                    step="0.001"
                    value={receiveQuantity}
                    onChange={(event) =>
                      setReceiveQuantity(Number(event.target.value))
                    }
                  />
                </label>
                <label>
                  Catatan
                  <input
                    value={receiveNotes}
                    onChange={(event) => setReceiveNotes(event.target.value)}
                  />
                </label>
                <button
                  className="secondary-button"
                  type="button"
                  disabled={
                    busy ||
                    !receiveLineId ||
                    receiveQuantity <= 0 ||
                    receiveQuantity >
                      Number(
                        receivableLines.find(
                          (line) => line.id === receiveLineId,
                        )?.remaining_quantity ?? 0,
                      )
                  }
                  onClick={() => void saveReceipt()}
                >
                  Simpan Penerimaan Barang
                </button>
              </div>

              <div className="purchase-receipt-list">
                <h3>Dokumen Penerimaan</h3>
                {options.receipts.length === 0 ? (
                  <p className="operations-empty">
                    Belum ada dokumen penerimaan.
                  </p>
                ) : (
                  options.receipts.map((receipt) => (
                    <article key={receipt.id}>
                      <header>
                        <span>
                          <strong>{receipt.receipt_number}</strong>
                          <small>
                            {receipt.order_number} · {receipt.supplier_name}
                          </small>
                        </span>
                        <span className="operations-status">
                          {receipt.status}
                        </span>
                      </header>
                      <p>{receipt.location_name}</p>
                      {receipt.status === 'RECEIVED' && (
                        <button
                          className="primary-button"
                          type="button"
                          disabled={busy}
                          onClick={() => void postReceipt(receipt.id)}
                        >
                          Barang Diterima
                        </button>
                      )}
                    </article>
                  ))
                )}
              </div>
            </div>
          )}
        </section>
      )}

      {purchaseTab === 'MASTER' && (
        <div className="purchase-master-grid">
          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">MASTER</p>
                <h2>Tambah Pemasok</h2>
              </div>
            </header>
            <form className="stack-form" onSubmit={saveSupplier}>
              <label>
                Kode
                <input
                  value={supplierCode}
                  onChange={(event) => setSupplierCode(event.target.value)}
                  placeholder="MISAL: TOKO_A"
                  required
                />
              </label>
              <label>
                Nama Pemasok
                <input
                  value={supplierName}
                  onChange={(event) => setSupplierName(event.target.value)}
                  required
                />
              </label>
              <label>
                Telepon
                <input
                  value={supplierPhone}
                  onChange={(event) => setSupplierPhone(event.target.value)}
                />
              </label>
              <button
                className="secondary-button"
                type="submit"
                disabled={busy}
              >
                Tambah Pemasok
              </button>
            </form>
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">MASTER</p>
                <h2>Tambah Barang</h2>
              </div>
            </header>
            <form className="stack-form" onSubmit={saveItem}>
              <label>
                Kode
                <input
                  value={itemCode}
                  onChange={(event) => setItemCode(event.target.value)}
                  placeholder="MISAL: GULA"
                  required
                />
              </label>
              <label>
                Nama Barang
                <input
                  value={itemName}
                  onChange={(event) => setItemName(event.target.value)}
                  required
                />
              </label>
              <label>
                Jenis
                <select
                  value={itemKind}
                  onChange={(event) => setItemKind(event.target.value)}
                >
                  <option value="MATERIAL">Bahan</option>
                  <option value="FINISHED_GOOD">Barang Jadi</option>
                  <option value="PACKAGING">Kemasan</option>
                  <option value="OTHER">Lainnya</option>
                </select>
              </label>
              <label>
                Satuan Dasar
                <select
                  value={itemUnitId}
                  onChange={(event) => setItemUnitId(event.target.value)}
                  required
                >
                  {options.units.map((unit) => (
                    <option key={unit.id} value={unit.id}>
                      {unit.display_name}
                    </option>
                  ))}
                </select>
              </label>
              <button
                className="secondary-button"
                type="submit"
                disabled={busy}
              >
                Tambah Barang
              </button>
            </form>
          </section>
        </div>
      )}

      <section className="operations-panel purchase-payable-panel">
        <header className="operations-panel-header">
          <div>
            <p className="eyebrow">KEWAJIBAN</p>
            <h2>Utang Pemasok</h2>
          </div>
          <strong>{formatIdr(payableBalance)}</strong>
        </header>
        {payables.length === 0 ? (
          <p className="operations-empty">Belum ada Utang Pemasok.</p>
        ) : (
          <div className="inventory-control-list">
            {payables.map((row) => (
              <article key={row.payable_id}>
                <header>
                  <span>
                    <strong>{row.supplier_name}</strong>
                    <small>
                      {row.invoice_reference ?? 'Tanpa referensi invoice'}
                    </small>
                  </span>
                  <span className="operations-status">{row.status}</span>
                </header>
                <p>Sisa {formatIdr(Number(row.balance))}</p>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
