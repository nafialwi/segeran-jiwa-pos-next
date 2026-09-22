import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { hasPermission } from '../auth/permission';
import { useAuth } from '../auth/AuthProvider';
import { OperationsNav } from '../components/OperationsNav';
import {
  approveRestockRequest,
  createInventoryCount,
  createStockTransfer,
  fetchInventoryControlOverview,
  postInventoryAdjustment,
  postInventoryCount,
  receiveStockTransfer,
  recordInventoryCount,
  rejectRestockRequest,
  saveRestockRequest,
  shipStockTransfer,
  submitRestockRequest,
  type InventoryControlOverview,
} from '../inventory/inventory-control-api';
import {
  aggregateInventoryItems,
  fetchInventoryOverview,
  type InventoryRow,
} from '../inventory/inventory-api';
import { Icon } from '../ui/Icon';

type ControlTab = 'RESTOCK' | 'TRANSFER' | 'COUNT' | 'ADJUST';

const EMPTY_OVERVIEW: InventoryControlOverview = {
  restocks: [],
  transfers: [],
  counts: [],
  adjustments: [],
};

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function signed(value: number): string {
  return value > 0 ? '+' + value : String(value);
}

export function InventoryControlScreen() {
  const { authority } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const [rows, setRows] = useState<InventoryRow[]>([]);
  const [overview, setOverview] =
    useState<InventoryControlOverview>(EMPTY_OVERVIEW);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const canRestock =
    authority !== null && hasPermission(authority, 'INVENTORY_REQUEST');
  const canTransfer =
    authority !== null && hasPermission(authority, 'INVENTORY_TRANSFER');
  const canCount =
    authority !== null && hasPermission(authority, 'INVENTORY_COUNT');
  const canAdjust =
    authority !== null && hasPermission(authority, 'INVENTORY_ADJUST');

  const tabs = useMemo(
    () =>
      [
        {
          value: 'RESTOCK' as const,
          label: 'Minta Restock',
          visible: canRestock,
        },
        { value: 'TRANSFER' as const, label: 'Transfer', visible: canTransfer },
        { value: 'COUNT' as const, label: 'Stok Opname', visible: canCount },
        { value: 'ADJUST' as const, label: 'Penyesuaian', visible: canAdjust },
      ].filter((tab) => tab.visible),
    [canAdjust, canCount, canRestock, canTransfer],
  );

  const requestedTab = (searchParams.get('tab') ?? '') as ControlTab;
  const activeTab = tabs.some((tab) => tab.value === requestedTab)
    ? requestedTab
    : (tabs[0]?.value ?? 'COUNT');

  const kindFilter = searchParams.get('kind')?.toUpperCase() ?? 'ALL';

  const load = useCallback(async () => {
    const [inventoryRows, controlOverview] = await Promise.all([
      fetchInventoryOverview(),
      fetchInventoryControlOverview(),
    ]);
    setRows(inventoryRows);
    setOverview(controlOverview);
  }, []);

  useEffect(() => {
    let active = true;
    void load()
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error
            ? cause.message
            : 'INVENTORY_CONTROL_READ_FAILED',
        );
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [load]);

  const locations = useMemo(
    () =>
      Array.from(
        new Map(
          rows.map((row) => [row.location_id, row.location_name] as const),
        ).entries(),
      ).map(([id, name]) => ({ id, name })),
    [rows],
  );

  const items = useMemo(() => aggregateInventoryItems(rows), [rows]);
  const itemMap = useMemo(
    () => new Map(items.map((item) => [item.stockItemId, item])),
    [items],
  );
  const locationMap = useMemo(
    () => new Map(locations.map((location) => [location.id, location.name])),
    [locations],
  );

  const countItems = useMemo(
    () =>
      items.filter(
        (item) =>
          item.inventoryTracked &&
          (kindFilter === 'ALL' || item.itemKind === kindFilter),
      ),
    [items, kindFilter],
  );

  const [restockLocationId, setRestockLocationId] = useState('');
  const [restockItemId, setRestockItemId] = useState('');
  const [restockQuantity, setRestockQuantity] = useState(1);
  const [restockNotes, setRestockNotes] = useState('');
  const [restockSourceId, setRestockSourceId] = useState('');
  const [rejectionReason, setRejectionReason] = useState('');

  const [transferSourceId, setTransferSourceId] = useState('');
  const [transferDestinationId, setTransferDestinationId] = useState('');
  const [transferItemId, setTransferItemId] = useState('');
  const [transferQuantity, setTransferQuantity] = useState(1);

  const [countLocationId, setCountLocationId] = useState('');
  const [countItemIds, setCountItemIds] = useState<string[]>([]);
  const [countNotes, setCountNotes] = useState('');
  const [selectedCountId, setSelectedCountId] = useState('');
  const [physicalValues, setPhysicalValues] = useState<Record<string, number>>(
    {},
  );

  const [adjustLocationId, setAdjustLocationId] = useState('');
  const [adjustItemId, setAdjustItemId] = useState('');
  const [adjustKind, setAdjustKind] = useState<'ADJUSTMENT' | 'WRITE_OFF'>(
    'ADJUSTMENT',
  );
  const [adjustDelta, setAdjustDelta] = useState(0);
  const [adjustReason, setAdjustReason] = useState('');
  const [adjustNote, setAdjustNote] = useState('');

  useEffect(() => {
    if (locations.length === 0) return;
    setRestockLocationId((current) => current || locations[0].id);
    setRestockSourceId((current) => current || locations[0].id);
    setTransferSourceId((current) => current || locations[0].id);
    setTransferDestinationId(
      (current) => current || locations[1]?.id || locations[0].id,
    );
    setCountLocationId((current) => current || locations[0].id);
    setAdjustLocationId((current) => current || locations[0].id);
  }, [locations]);

  useEffect(() => {
    if (items.length === 0) return;
    setRestockItemId((current) => current || items[0].stockItemId);
    setTransferItemId((current) => current || items[0].stockItemId);
    setAdjustItemId((current) => current || items[0].stockItemId);
  }, [items]);

  useEffect(() => {
    if (kindFilter === 'PACKAGING' && countItems.length > 0) {
      setCountItemIds((current) =>
        current.length > 0
          ? current.filter((id) =>
              countItems.some((item) => item.stockItemId === id),
            )
          : countItems.map((item) => item.stockItemId),
      );
    }
  }, [countItems, kindFilter]);

  const selectedCount = overview.counts.find(
    (count) => count.id === selectedCountId,
  );

  async function action(
    work: () => Promise<string | void>,
    options?: { keepCount?: boolean },
  ) {
    setBusy(true);
    setMessage('');
    setError('');
    try {
      const result = await work();
      if (result) setMessage(result);
      await load();
      if (!options?.keepCount) {
        // Selected count remains explicit unless the action is count-specific.
      }
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'INVENTORY_CONTROL_FAILED',
      );
    } finally {
      setBusy(false);
    }
  }

  async function submitRestock(event: React.FormEvent) {
    event.preventDefault();
    if (!restockLocationId || !restockItemId || restockQuantity <= 0) return;
    await action(async () => {
      const draft = await saveRestockRequest({
        destinationLocationId: restockLocationId,
        lines: [{ stockItemId: restockItemId, quantity: restockQuantity }],
        notes: restockNotes,
      });
      await submitRestockRequest(draft.request_id);
      setRestockQuantity(1);
      setRestockNotes('');
      return 'Permintaan restock dikirim.';
    });
  }

  async function approveRestock(requestId: string) {
    if (!restockSourceId) return;
    await action(async () => {
      await approveRestockRequest({
        requestId,
        sourceLocationId: restockSourceId,
      });
      return 'Restock disetujui dan draft transfer dibuat.';
    });
  }

  async function rejectRestock(requestId: string) {
    if (!rejectionReason.trim()) {
      setError('Alasan penolakan restock wajib diisi.');
      return;
    }
    await action(async () => {
      await rejectRestockRequest({ requestId, reason: rejectionReason });
      setRejectionReason('');
      return 'Permintaan restock ditolak.';
    });
  }

  async function createTransfer(event: React.FormEvent) {
    event.preventDefault();
    if (
      !transferSourceId ||
      !transferDestinationId ||
      transferSourceId === transferDestinationId ||
      !transferItemId ||
      transferQuantity <= 0
    ) {
      return;
    }

    await action(async () => {
      await createStockTransfer({
        sourceLocationId: transferSourceId,
        destinationLocationId: transferDestinationId,
        lines: [{ stockItemId: transferItemId, quantity: transferQuantity }],
      });
      setTransferQuantity(1);
      return 'Draft transfer stok dibuat.';
    });
  }

  async function shipTransfer(transferId: string) {
    await action(async () => {
      await shipStockTransfer(transferId);
      return 'Barang keluar dari lokasi sumber. Transfer berstatus SHIPPED.';
    });
  }

  async function receiveTransfer(transferId: string) {
    await action(async () => {
      await receiveStockTransfer(transferId);
      return 'Barang diterima di lokasi tujuan.';
    });
  }

  async function createCount(event: React.FormEvent) {
    event.preventDefault();
    if (!countLocationId || countItemIds.length === 0) return;
    await action(
      async () => {
        const result = await createInventoryCount({
          locationId: countLocationId,
          stockItemIds: countItemIds,
          notes: countNotes,
        });
        setSelectedCountId(result.count_id);
        setPhysicalValues({});
        setCountNotes('');
        return 'Snapshot stok opname dibuat. Isi jumlah fisik.';
      },
      { keepCount: true },
    );
  }

  async function savePhysicalCount() {
    if (!selectedCount || selectedCount.status !== 'DRAFT') return;
    const lines = selectedCount.lines.map((line) => ({
      stockItemId: line.stockItemId,
      physicalQuantity: physicalValues[line.stockItemId],
    }));
    if (lines.some((line) => !Number.isFinite(line.physicalQuantity))) {
      setError('Semua jumlah fisik wajib diisi.');
      return;
    }

    await action(
      async () => {
        await recordInventoryCount({
          countId: selectedCount.id,
          lines: lines as Array<{
            stockItemId: string;
            physicalQuantity: number;
          }>,
        });
        return 'Hitungan fisik tersimpan. Tinjau selisih sebelum posting.';
      },
      { keepCount: true },
    );
  }

  async function postCount() {
    if (!selectedCount || selectedCount.status !== 'COUNTED') return;
    await action(
      async () => {
        const result = await postInventoryCount(selectedCount.id);
        return result.zero_variance
          ? 'Stok opname diposting tanpa selisih.'
          : 'Selisih stok opname diposting ke inventory movement.';
      },
      { keepCount: true },
    );
  }

  async function postAdjustment(event: React.FormEvent) {
    event.preventDefault();
    if (
      !adjustLocationId ||
      !adjustItemId ||
      !adjustReason.trim() ||
      adjustDelta === 0
    ) {
      return;
    }

    await action(async () => {
      await postInventoryAdjustment({
        locationId: adjustLocationId,
        stockItemId: adjustItemId,
        adjustmentKind: adjustKind,
        quantityDelta: adjustDelta,
        reasonCode: adjustReason,
        note: adjustNote,
      });
      setAdjustDelta(0);
      setAdjustReason('');
      setAdjustNote('');
      return 'Penyesuaian persediaan diposting.';
    });
  }

  function selectTab(tab: ControlTab) {
    const next = new URLSearchParams(searchParams);
    next.set('tab', tab);
    setSearchParams(next, { replace: true });
  }

  if (loading) {
    return (
      <main className="shell operations-shell">
        <div className="operations-card-skeleton">
          <span />
          <span />
        </div>
      </main>
    );
  }

  return (
    <main className="shell operations-shell">
      <header className="topbar operations-header">
        <div>
          <p className="eyebrow">OPERASIONAL · KONTROL STOK</p>
          <h1>Kontrol Stok</h1>
          <p className="muted">
            Restock, transfer, opname, dan penyesuaian tetap memakai satu
            inventory movement authority.
          </p>
        </div>
      </header>

      <OperationsNav />

      {kindFilter === 'PACKAGING' && (
        <section className="packaging-control-banner">
          <Icon name="product" size={20} />
          <div>
            <strong>Kontrol Kemasan</strong>
            <span>
              Kemasan adalah Stock Item. Hitung fisik melalui Stok Opname, bukan
              engine cup terpisah.
            </span>
          </div>
        </section>
      )}

      {error && <p className="error-banner">{error}</p>}
      {message && <p className="success-banner">{message}</p>}

      <div className="inventory-control-tabs" role="tablist">
        {tabs.map((tab) => (
          <button
            type="button"
            key={tab.value}
            className={activeTab === tab.value ? 'active' : ''}
            onClick={() => selectTab(tab.value)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {activeTab === 'RESTOCK' && canRestock && (
        <div className="inventory-control-grid">
          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">PERMINTAAN</p>
                <h2>Minta Restock</h2>
              </div>
            </header>
            <form className="stack-form" onSubmit={submitRestock}>
              <label>
                Lokasi tujuan
                <select
                  value={restockLocationId}
                  onChange={(event) => setRestockLocationId(event.target.value)}
                >
                  {locations.map((location) => (
                    <option key={location.id} value={location.id}>
                      {location.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Barang
                <select
                  value={restockItemId}
                  onChange={(event) => setRestockItemId(event.target.value)}
                >
                  {items.map((item) => (
                    <option key={item.stockItemId} value={item.stockItemId}>
                      {item.displayName} · {item.baseUnit}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Jumlah
                <input
                  type="number"
                  min="0.001"
                  step="0.001"
                  value={restockQuantity}
                  onChange={(event) =>
                    setRestockQuantity(Number(event.target.value))
                  }
                />
              </label>
              <label>
                Catatan
                <textarea
                  rows={2}
                  value={restockNotes}
                  onChange={(event) => setRestockNotes(event.target.value)}
                />
              </label>
              <button className="primary-button" type="submit" disabled={busy}>
                Kirim Permintaan Restock
              </button>
            </form>
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">STATUS</p>
                <h2>Permintaan Terbaru</h2>
              </div>
            </header>
            <div className="inventory-control-list">
              {overview.restocks.length === 0 ? (
                <p className="operations-empty">
                  Belum ada permintaan restock.
                </p>
              ) : (
                overview.restocks.map((request) => (
                  <article key={request.id}>
                    <header>
                      <span>
                        <strong>
                          {locationMap.get(request.destinationLocationId) ??
                            request.destinationLocationId}
                        </strong>
                        <small>{formatDateTime(request.createdAt)}</small>
                      </span>
                      <span className="operations-status">
                        {request.status}
                      </span>
                    </header>
                    {request.lines.map((line) => (
                      <p key={line.stockItemId}>
                        {itemMap.get(line.stockItemId)?.displayName ??
                          line.stockItemId}{' '}
                        · {line.quantity}{' '}
                        {itemMap.get(line.stockItemId)?.baseUnit ?? ''}
                      </p>
                    ))}
                    {canTransfer && request.status === 'SUBMITTED' && (
                      <div className="inventory-control-inline-actions">
                        <select
                          value={restockSourceId}
                          onChange={(event) =>
                            setRestockSourceId(event.target.value)
                          }
                        >
                          {locations.map((location) => (
                            <option key={location.id} value={location.id}>
                              Sumber: {location.name}
                            </option>
                          ))}
                        </select>
                        <button
                          className="primary-button"
                          type="button"
                          disabled={busy}
                          onClick={() => void approveRestock(request.id)}
                        >
                          Setujui
                        </button>
                        <input
                          value={rejectionReason}
                          onChange={(event) =>
                            setRejectionReason(event.target.value)
                          }
                          placeholder="Alasan jika ditolak"
                        />
                        <button
                          className="secondary-button danger-lite"
                          type="button"
                          disabled={busy}
                          onClick={() => void rejectRestock(request.id)}
                        >
                          Tolak
                        </button>
                      </div>
                    )}
                  </article>
                ))
              )}
            </div>
          </section>
        </div>
      )}

      {activeTab === 'TRANSFER' && canTransfer && (
        <div className="inventory-control-grid">
          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">PERPINDAHAN</p>
                <h2>Transfer</h2>
              </div>
            </header>
            <form className="stack-form" onSubmit={createTransfer}>
              <label>
                Dari
                <select
                  value={transferSourceId}
                  onChange={(event) => setTransferSourceId(event.target.value)}
                >
                  {locations.map((location) => (
                    <option key={location.id} value={location.id}>
                      {location.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Ke
                <select
                  value={transferDestinationId}
                  onChange={(event) =>
                    setTransferDestinationId(event.target.value)
                  }
                >
                  {locations.map((location) => (
                    <option key={location.id} value={location.id}>
                      {location.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Barang
                <select
                  value={transferItemId}
                  onChange={(event) => setTransferItemId(event.target.value)}
                >
                  {items.map((item) => (
                    <option key={item.stockItemId} value={item.stockItemId}>
                      {item.displayName}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Jumlah
                <input
                  type="number"
                  min="0.001"
                  step="0.001"
                  value={transferQuantity}
                  onChange={(event) =>
                    setTransferQuantity(Number(event.target.value))
                  }
                />
              </label>
              <button
                className="primary-button"
                type="submit"
                disabled={
                  busy ||
                  transferSourceId === transferDestinationId ||
                  transferQuantity <= 0
                }
              >
                Buat Draft Transfer
              </button>
            </form>
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">EKSEKUSI</p>
                <h2>Transfer Terbaru</h2>
              </div>
            </header>
            <div className="inventory-control-list">
              {overview.transfers.length === 0 ? (
                <p className="operations-empty">Belum ada transfer stok.</p>
              ) : (
                overview.transfers.map((transfer) => (
                  <article key={transfer.id}>
                    <header>
                      <span>
                        <strong>
                          {locationMap.get(transfer.sourceLocationId) ??
                            transfer.sourceLocationId}{' '}
                          →{' '}
                          {locationMap.get(transfer.destinationLocationId) ??
                            transfer.destinationLocationId}
                        </strong>
                        <small>{formatDateTime(transfer.createdAt)}</small>
                      </span>
                      <span className="operations-status">
                        {transfer.status}
                      </span>
                    </header>
                    {transfer.lines.map((line) => (
                      <p key={line.stockItemId}>
                        {itemMap.get(line.stockItemId)?.displayName ??
                          line.stockItemId}{' '}
                        · {line.quantity}{' '}
                        {itemMap.get(line.stockItemId)?.baseUnit ?? ''}
                      </p>
                    ))}
                    {transfer.status === 'DRAFT' && (
                      <button
                        className="primary-button"
                        type="button"
                        disabled={busy}
                        onClick={() => void shipTransfer(transfer.id)}
                      >
                        Kirim Barang
                      </button>
                    )}
                    {transfer.status === 'SHIPPED' && (
                      <button
                        className="primary-button"
                        type="button"
                        disabled={busy}
                        onClick={() => void receiveTransfer(transfer.id)}
                      >
                        Terima Barang
                      </button>
                    )}
                  </article>
                ))
              )}
            </div>
          </section>
        </div>
      )}

      {activeTab === 'COUNT' && canCount && (
        <div className="inventory-control-grid">
          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">FISIK VS SISTEM</p>
                <h2>Stok Opname</h2>
              </div>
            </header>

            {!selectedCount ? (
              <form className="stack-form" onSubmit={createCount}>
                <label>
                  Lokasi
                  <select
                    value={countLocationId}
                    onChange={(event) => setCountLocationId(event.target.value)}
                  >
                    {locations.map((location) => (
                      <option key={location.id} value={location.id}>
                        {location.name}
                      </option>
                    ))}
                  </select>
                </label>

                <fieldset className="inventory-count-picker">
                  <legend>
                    Barang yang dihitung
                    {kindFilter === 'PACKAGING' ? ' · PACKAGING' : ''}
                  </legend>
                  {countItems.map((item) => (
                    <label key={item.stockItemId}>
                      <input
                        type="checkbox"
                        checked={countItemIds.includes(item.stockItemId)}
                        onChange={(event) =>
                          setCountItemIds((current) =>
                            event.target.checked
                              ? Array.from(
                                  new Set([...current, item.stockItemId]),
                                )
                              : current.filter((id) => id !== item.stockItemId),
                          )
                        }
                      />
                      <span>
                        <strong>{item.displayName}</strong>
                        <small>
                          {item.itemKind} · {item.baseUnit}
                        </small>
                      </span>
                    </label>
                  ))}
                </fieldset>

                <label>
                  Catatan
                  <textarea
                    rows={2}
                    value={countNotes}
                    onChange={(event) => setCountNotes(event.target.value)}
                  />
                </label>

                <button
                  className="primary-button"
                  type="submit"
                  disabled={busy || countItemIds.length === 0}
                >
                  Mulai Stok Opname
                </button>
              </form>
            ) : (
              <div className="inventory-count-workspace">
                <header>
                  <div>
                    <strong>
                      {locationMap.get(selectedCount.locationId) ??
                        selectedCount.locationId}
                    </strong>
                    <span>
                      Snapshot {formatDateTime(selectedCount.snapshotAt)}
                    </span>
                  </div>
                  <span className="operations-status">
                    {selectedCount.status}
                  </span>
                </header>

                <div className="inventory-count-table">
                  <div className="inventory-count-row heading">
                    <span>Barang</span>
                    <span>Expected</span>
                    <span>Fisik</span>
                  </div>
                  {selectedCount.lines.map((line) => {
                    const item = itemMap.get(line.stockItemId);
                    return (
                      <div
                        className="inventory-count-row"
                        key={line.stockItemId}
                      >
                        <span>
                          <strong>
                            {item?.displayName ?? line.stockItemId}
                          </strong>
                          <small>{item?.baseUnit ?? ''}</small>
                        </span>
                        <strong>{line.expectedQuantity}</strong>
                        {selectedCount.status === 'DRAFT' ? (
                          <input
                            type="number"
                            min="0"
                            step="0.001"
                            value={
                              physicalValues[line.stockItemId] ??
                              line.physicalQuantity ??
                              ''
                            }
                            onChange={(event) =>
                              setPhysicalValues((current) => ({
                                ...current,
                                [line.stockItemId]: Number(event.target.value),
                              }))
                            }
                          />
                        ) : (
                          <strong>{line.physicalQuantity ?? '-'}</strong>
                        )}
                      </div>
                    );
                  })}
                </div>

                <div className="button-row">
                  {selectedCount.status === 'DRAFT' && (
                    <button
                      className="primary-button"
                      type="button"
                      disabled={busy}
                      onClick={() => void savePhysicalCount()}
                    >
                      Simpan Hitungan Fisik
                    </button>
                  )}
                  {selectedCount.status === 'COUNTED' && (
                    <button
                      className="primary-button"
                      type="button"
                      disabled={busy}
                      onClick={() => void postCount()}
                    >
                      Posting Selisih
                    </button>
                  )}
                  <button
                    className="secondary-button"
                    type="button"
                    onClick={() => {
                      setSelectedCountId('');
                      setPhysicalValues({});
                    }}
                  >
                    Kembali
                  </button>
                </div>
              </div>
            )}
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">RIWAYAT</p>
                <h2>Opname Terbaru</h2>
              </div>
            </header>
            <div className="inventory-control-list">
              {overview.counts.map((count) => (
                <button
                  type="button"
                  className="inventory-control-history-button"
                  key={count.id}
                  onClick={() => {
                    setSelectedCountId(count.id);
                    setPhysicalValues(
                      Object.fromEntries(
                        count.lines
                          .filter((line) => line.physicalQuantity !== null)
                          .map((line) => [
                            line.stockItemId,
                            line.physicalQuantity as number,
                          ]),
                      ),
                    );
                  }}
                >
                  <span>
                    <strong>
                      {locationMap.get(count.locationId) ?? count.locationId}
                    </strong>
                    <small>{formatDateTime(count.createdAt)}</small>
                  </span>
                  <span className="operations-status">{count.status}</span>
                </button>
              ))}
            </div>
          </section>
        </div>
      )}

      {activeTab === 'ADJUST' && canAdjust && (
        <div className="inventory-control-grid">
          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">KOREKSI TERKONTROL</p>
                <h2>Penyesuaian</h2>
              </div>
            </header>
            <form className="stack-form" onSubmit={postAdjustment}>
              <label>
                Lokasi
                <select
                  value={adjustLocationId}
                  onChange={(event) => setAdjustLocationId(event.target.value)}
                >
                  {locations.map((location) => (
                    <option key={location.id} value={location.id}>
                      {location.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Barang
                <select
                  value={adjustItemId}
                  onChange={(event) => setAdjustItemId(event.target.value)}
                >
                  {items.map((item) => (
                    <option key={item.stockItemId} value={item.stockItemId}>
                      {item.displayName} · {item.baseUnit}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Jenis
                <select
                  value={adjustKind}
                  onChange={(event) =>
                    setAdjustKind(
                      event.target.value as 'ADJUSTMENT' | 'WRITE_OFF',
                    )
                  }
                >
                  <option value="ADJUSTMENT">Penyesuaian</option>
                  <option value="WRITE_OFF">Rusak / Hilang / Buang</option>
                </select>
              </label>
              <label>
                Perubahan jumlah
                <input
                  type="number"
                  step="0.001"
                  value={adjustDelta}
                  onChange={(event) =>
                    setAdjustDelta(Number(event.target.value))
                  }
                />
              </label>
              <label>
                Alasan
                <input
                  value={adjustReason}
                  onChange={(event) => setAdjustReason(event.target.value)}
                  placeholder="Contoh: RUSAK, SELISIH_FISIK"
                />
              </label>
              <label>
                Catatan
                <textarea
                  rows={2}
                  value={adjustNote}
                  onChange={(event) => setAdjustNote(event.target.value)}
                />
              </label>
              <p className="muted">
                WRITE_OFF wajib bernilai negatif. Sistem menolak penyesuaian
                yang membuat stok menjadi negatif.
              </p>
              <button
                className="primary-button"
                type="submit"
                disabled={busy || adjustDelta === 0 || !adjustReason.trim()}
              >
                Posting Penyesuaian
              </button>
            </form>
          </section>

          <section className="operations-panel">
            <header className="operations-panel-header">
              <div>
                <p className="eyebrow">FAKTA</p>
                <h2>Penyesuaian Terbaru</h2>
              </div>
            </header>
            <div className="inventory-control-list">
              {overview.adjustments.length === 0 ? (
                <p className="operations-empty">
                  Belum ada penyesuaian persediaan.
                </p>
              ) : (
                overview.adjustments.map((row) => (
                  <article key={row.id}>
                    <header>
                      <span>
                        <strong>
                          {itemMap.get(row.stockItemId)?.displayName ??
                            row.stockItemId}
                        </strong>
                        <small>
                          {locationMap.get(row.locationId) ?? row.locationId} ·{' '}
                          {formatDateTime(row.createdAt)}
                        </small>
                      </span>
                      <span
                        className={
                          row.quantityDelta > 0
                            ? 'inventory-delta positive'
                            : 'inventory-delta negative'
                        }
                      >
                        {signed(row.quantityDelta)}
                      </span>
                    </header>
                    <p>
                      {row.adjustmentKind} · {row.reasonCode}
                    </p>
                  </article>
                ))
              )}
            </div>
          </section>
        </div>
      )}
    </main>
  );
}
