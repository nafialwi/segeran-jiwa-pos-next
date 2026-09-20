import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
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
    const [frontDoor, overviewResult] = await Promise.all([
      fetchPurchaseFrontDoorOptions(),
      supabase.rpc('purchase_operational_overview'),
    ]);

    setOptions(frontDoor);

    if (overviewResult.error) throw new Error(overviewResult.error.message);
    const overview = (overviewResult.data ?? {}) as Partial<PurchaseOverview>;
    setPayables(overview.payables ?? []);

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

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            Kembali ke Beranda
          </Link>
          <p className="eyebrow">PEMBELIAN</p>
          <h1>Pembelian & Pemasok</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}
      {message && <p className="success-banner">{message}</p>}

      <section className="identity-card">
        <h2>Tambah Pemasok</h2>
        <form className="compact-grid-form" onSubmit={saveSupplier}>
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
          <button className="secondary-button" type="submit" disabled={busy}>
            Tambah Pemasok
          </button>
        </form>
      </section>

      <section className="identity-card">
        <h2>Tambah Barang</h2>
        <form className="compact-grid-form" onSubmit={saveItem}>
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
          <button className="secondary-button" type="submit" disabled={busy}>
            Tambah Barang
          </button>
        </form>
      </section>

      <section className="identity-card">
        <h2>Pembelian Baru</h2>
        {options.suppliers.length === 0 || options.items.length === 0 ? (
          <div className="empty-state">
            <strong>Master Pembelian belum lengkap.</strong>
            <p>
              Tambahkan minimal satu Pemasok dan satu Barang, atau import master
              Legacy untuk Barang jual.
            </p>
          </div>
        ) : (
          <>
            <div className="compact-grid-form">
              <label>
                Pemasok
                <select
                  value={supplierId}
                  onChange={(event) => setSupplierId(event.target.value)}
                >
                  {options.suppliers.map((supplier) => (
                    <option key={supplier.id} value={supplier.id}>
                      {supplier.display_name}
                    </option>
                  ))}
                </select>
              </label>
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
              <label>
                Barang
                <select
                  value={selectedItemId}
                  onChange={(event) => setSelectedItemId(event.target.value)}
                >
                  {options.items.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.display_name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Jumlah ({selectedItem?.base_unit ?? 'satuan'})
                <input
                  type="number"
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

            {draftLines.length > 0 && (
              <div className="stack-list purchase-draft">
                {draftLines.map((line) => (
                  <article className="cart-row" key={line.item.id}>
                    <div>
                      <strong>{line.item.display_name}</strong>
                      <span className="muted">
                        {line.quantity} {line.item.base_unit} x{' '}
                        {formatIdr(line.unitPrice)}
                      </span>
                    </div>
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
              </div>
            )}

            <label>
              Catatan Pembelian
              <textarea
                value={purchaseNotes}
                onChange={(event) => setPurchaseNotes(event.target.value)}
                rows={2}
              />
            </label>

            <div className="button-row">
              <button
                className="primary-button"
                type="button"
                disabled={busy || draftLines.length === 0}
                onClick={() => void saveDirectBuy()}
              >
                Belanja Langsung
              </button>
              <button
                className="secondary-button"
                type="button"
                disabled={busy || draftLines.length === 0}
                onClick={() => void saveOrder()}
              >
                Pesanan ke Pemasok
              </button>
            </div>
            <p className="muted">
              Belanja Langsung langsung mencatat Barang Diterima. Pesanan ke
              Pemasok belum menambah stok sampai penerimaan diposting.
            </p>
          </>
        )}
      </section>

      <section className="identity-card">
        <h2>Penerimaan Barang</h2>
        {options.receivable_orders.length === 0 ? (
          <p className="muted">
            Tidak ada Pesanan ke Pemasok yang menunggu penerimaan.
          </p>
        ) : (
          <>
            <div className="compact-grid-form">
              <label>
                Pesanan
                <select
                  value={receiveOrderId}
                  onChange={(event) => setReceiveOrderId(event.target.value)}
                >
                  {options.receivable_orders.map((order) => (
                    <option key={order.id} value={order.id}>
                      {order.order_number} - {order.supplier_name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Barang
                <select
                  value={receiveLineId}
                  onChange={(event) => setReceiveLineId(event.target.value)}
                >
                  {receivableLines.map((line) => (
                    <option key={line.id} value={line.id}>
                      {line.item_name} - sisa {Number(line.remaining_quantity)}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Jumlah Diterima
                <input
                  type="number"
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
                      receivableLines.find((line) => line.id === receiveLineId)
                        ?.remaining_quantity ?? 0,
                    )
                }
                onClick={() => void saveReceipt()}
              >
                Simpan Penerimaan Barang
              </button>
            </div>
          </>
        )}

        {options.receipts.length > 0 && (
          <div className="stack-list">
            {options.receipts.map((receipt) => (
              <article className="list-card" key={receipt.id}>
                <strong>{receipt.receipt_number}</strong>
                <span>
                  {receipt.order_number} - {receipt.supplier_name}
                </span>
                <span>
                  {receipt.location_name} - {receipt.status}
                </span>
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
            ))}
          </div>
        )}
      </section>

      <section className="identity-card">
        <h2>Utang Pemasok</h2>
        {payables.length === 0 ? (
          <p className="muted">Belum ada Utang Pemasok.</p>
        ) : (
          <div className="stack-list">
            {payables.map((row) => (
              <article className="list-card" key={row.payable_id}>
                <strong>{row.supplier_name}</strong>
                <span>
                  {row.invoice_reference ?? 'Tanpa referensi invoice'}
                </span>
                <span>
                  Sisa {formatIdr(Number(row.balance))} - {row.status}
                </span>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
