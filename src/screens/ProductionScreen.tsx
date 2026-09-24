import { useCallback, useEffect, useMemo, useState } from 'react';
import { OperationsNav } from '../components/OperationsNav';
import {
  createProductionBatch,
  fetchProductionOverview,
  postProductionBatch,
  type ProductionOverview,
} from '../production/production-api';
import { Icon } from '../ui/Icon';

const EMPTY: ProductionOverview = {
  locations: [],
  finishedGoods: [],
  activeBoms: [],
  batches: [],
};

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

export function ProductionScreen() {
  const [overview, setOverview] = useState<ProductionOverview>(EMPTY);
  const [locationId, setLocationId] = useState('');
  const [finishedGoodId, setFinishedGoodId] = useState('');
  const [plannedOutput, setPlannedOutput] = useState(1);
  const [actualOutputs, setActualOutputs] = useState<Record<string, number>>(
    {},
  );
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    const result = await fetchProductionOverview();
    setOverview(result);
    setLocationId((current) =>
      result.locations.some((row) => row.id === current)
        ? current
        : (result.locations[0]?.id ?? ''),
    );

    const activeFinishedIds = new Set(
      result.activeBoms.map((bom) => bom.finishedGoodId),
    );
    setFinishedGoodId((current) =>
      current && activeFinishedIds.has(current)
        ? current
        : (result.finishedGoods.find((row) => activeFinishedIds.has(row.id))
            ?.id ?? ''),
    );
    setLoading(false);
  }, []);

  useEffect(() => {
    void load().catch((cause: unknown) => {
      setError(
        cause instanceof Error ? cause.message : 'PRODUCTION_READ_FAILED',
      );
      setLoading(false);
    });
  }, [load]);

  const activeBomMap = useMemo(
    () => new Map(overview.activeBoms.map((bom) => [bom.finishedGoodId, bom])),
    [overview.activeBoms],
  );

  const producibleGoods = overview.finishedGoods.filter((good) =>
    activeBomMap.has(good.id),
  );
  const selectedGood =
    producibleGoods.find((good) => good.id === finishedGoodId) ?? null;
  const selectedBom = selectedGood ? activeBomMap.get(selectedGood.id) : null;

  async function createBatch(event: React.FormEvent) {
    event.preventDefault();
    if (!locationId || !finishedGoodId || plannedOutput <= 0) return;

    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await createProductionBatch({
        locationId,
        finishedGoodId,
        plannedOutput,
      });
      setMessage(
        result.replay
          ? 'Rencana produksi sudah pernah dibuat.'
          : 'Rencana produksi berhasil dibuat.',
      );
      setPlannedOutput(1);
      await load();
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'PRODUCTION_CREATE_FAILED',
      );
    } finally {
      setBusy(false);
    }
  }

  async function postBatch(batchId: string, fallback: number) {
    const actualOutput = actualOutputs[batchId] ?? fallback;
    if (actualOutput <= 0) return;

    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await postProductionBatch({ batchId, actualOutput });
      setMessage(
        result.already_posted
          ? 'Batch sudah pernah diposting.'
          : 'Produksi diposting. Bahan berkurang dan barang jadi bertambah.',
      );
      await load();
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'PRODUCTION_POST_FAILED',
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="shell operations-shell">
      <header className="topbar operations-header">
        <div>
          <p className="eyebrow">OPERASIONAL · PRODUKSI</p>
          <h1>Produksi</h1>
          <p className="muted">
            Satu batch mengikat satu BOM Aktif dan satu inventory movement.
          </p>
        </div>
      </header>

      <OperationsNav />

      {error && <p className="error-banner">{error}</p>}
      {message && <p className="success-banner">{message}</p>}

      <div className="production-layout">
        <section className="operations-panel">
          <header className="operations-panel-header">
            <div>
              <p className="eyebrow">RENCANA</p>
              <h2>Rencana Produksi</h2>
            </div>
            <span className="operations-icon">
              <Icon name="activity" />
            </span>
          </header>

          {loading ? (
            <div
              className="operations-card-skeleton production-loading"
              aria-label="Memuat produksi"
            >
              <span />
              <span />
            </div>
          ) : producibleGoods.length === 0 ? (
            <div className="empty-state">
              <strong>Belum ada BOM Aktif.</strong>
              <p>
                Produksi hanya dapat dibuat untuk barang jadi dengan BOM Aktif.
              </p>
            </div>
          ) : (
            <form className="stack-form" onSubmit={createBatch}>
              {selectedGood && (
                <div className="production-selected-good">
                  <span className="operations-icon large">
                    <Icon name="product" size={26} />
                  </span>
                  <span>
                    <small>Barang jadi terpilih</small>
                    <strong>{selectedGood.displayName}</strong>
                    <em>
                      {selectedGood.code} · BOM v{selectedBom?.version ?? '-'} ·
                      Yield {selectedBom?.yieldQuantity ?? '-'}{' '}
                      {selectedGood.baseUnit}
                    </em>
                  </span>
                </div>
              )}
              <label>
                Lokasi produksi
                <select
                  value={locationId}
                  onChange={(event) => setLocationId(event.target.value)}
                  required
                >
                  {overview.locations.map((location) => (
                    <option key={location.id} value={location.id}>
                      {location.displayName}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Barang jadi
                <select
                  value={finishedGoodId}
                  onChange={(event) => setFinishedGoodId(event.target.value)}
                  required
                >
                  {producibleGoods.map((good) => {
                    const bom = activeBomMap.get(good.id);
                    return (
                      <option key={good.id} value={good.id}>
                        {good.displayName} · BOM v{bom?.version ?? '-'}
                      </option>
                    );
                  })}
                </select>
              </label>

              <label>
                Target output
                <input
                  type="number"
                  inputMode="decimal"
                  min="0.001"
                  step="0.001"
                  value={plannedOutput}
                  onChange={(event) =>
                    setPlannedOutput(Number(event.target.value))
                  }
                  required
                />
              </label>

              <button className="primary-button" type="submit" disabled={busy}>
                <Icon name="operations" size={18} />
                <span>Buat Batch Produksi</span>
              </button>
            </form>
          )}
        </section>

        <section className="operations-panel">
          <header className="operations-panel-header">
            <div>
              <p className="eyebrow">RESEP PRODUKSI</p>
              <h2>BOM Aktif</h2>
            </div>
          </header>

          {loading ? (
            <div
              className="operations-card-skeleton production-loading"
              aria-label="Memuat BOM"
            >
              <span />
              <span />
            </div>
          ) : (
            <div className="production-bom-list">
              {producibleGoods.map((good) => {
                const bom = activeBomMap.get(good.id);
                return (
                  <article key={good.id}>
                    <span>
                      <strong>{good.displayName}</strong>
                      <small>{good.code}</small>
                    </span>
                    <span>
                      v{bom?.version ?? '-'} · Yield {bom?.yieldQuantity ?? '-'}{' '}
                      {good.baseUnit}
                    </span>
                  </article>
                );
              })}
            </div>
          )}
        </section>
      </div>

      <section className="operations-panel">
        <header className="operations-panel-header">
          <div>
            <p className="eyebrow">EKSEKUSI</p>
            <h2>Batch Produksi</h2>
          </div>
          <small>{overview.batches.length} batch terbaru</small>
        </header>

        {loading ? (
          <div
            className="operations-card-skeleton production-loading"
            aria-label="Memuat batch produksi"
          >
            <span />
            <span />
          </div>
        ) : overview.batches.length === 0 ? (
          <p className="operations-empty">Belum ada batch produksi.</p>
        ) : (
          <div className="production-batch-grid">
            {overview.batches.map((batch) => (
              <article
                className={
                  batch.status === 'POSTED'
                    ? 'production-batch-card posted'
                    : 'production-batch-card'
                }
                key={batch.id}
              >
                <header>
                  <span>
                    <strong>{batch.finishedGoodName}</strong>
                    <small>
                      {batch.finishedGoodCode} · {batch.locationName}
                    </small>
                  </span>
                  <span className="operations-status">{batch.status}</span>
                </header>

                <dl>
                  <div>
                    <dt>Rencana</dt>
                    <dd>
                      {batch.plannedOutput} {batch.baseUnit}
                    </dd>
                  </div>
                  <div>
                    <dt>BOM</dt>
                    <dd>v{batch.bomVersion || '-'}</dd>
                  </div>
                  <div>
                    <dt>Dibuat</dt>
                    <dd>{formatDateTime(batch.createdAt)}</dd>
                  </div>
                </dl>

                {batch.status === 'DRAFT' ? (
                  <div className="production-post-row">
                    <label>
                      Output aktual
                      <input
                        type="number"
                        inputMode="decimal"
                        min="0.001"
                        step="0.001"
                        value={actualOutputs[batch.id] ?? batch.plannedOutput}
                        onChange={(event) =>
                          setActualOutputs((current) => ({
                            ...current,
                            [batch.id]: Number(event.target.value),
                          }))
                        }
                      />
                    </label>
                    <button
                      className="primary-button"
                      type="button"
                      disabled={busy}
                      onClick={() =>
                        void postBatch(batch.id, batch.plannedOutput)
                      }
                    >
                      Posting Produksi
                    </button>
                  </div>
                ) : (
                  <p className="production-posted-note">
                    Output aktual {batch.actualOutput} {batch.baseUnit} ·
                    diposting{' '}
                    {batch.postedAt ? formatDateTime(batch.postedAt) : '-'}
                  </p>
                )}
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
