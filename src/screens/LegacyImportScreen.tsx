import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import {
  legacyMasterSummary,
  parseLegacyMaster,
  sha256Hex,
  type LegacyMasterPayload,
} from '../migration/legacy-master';
import { fetchLocations, type LocationOption } from '../shift/shift-api';

type ExistingImport = {
  source_hash: string;
  menu_count: number;
  tracked_inventory_count: number;
  customer_count: number;
  created_at: string;
};

export function LegacyImportScreen() {
  const [locations, setLocations] = useState<LocationOption[]>([]);
  const [locationId, setLocationId] = useState('');
  const [payload, setPayload] = useState<LegacyMasterPayload | null>(null);
  const [sourceHash, setSourceHash] = useState('');
  const [fileName, setFileName] = useState('');
  const [existing, setExisting] = useState<ExistingImport | null>(null);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void (async () => {
      const [locationRows, importResult] = await Promise.all([
        fetchLocations(),
        supabase
          .from('legacy_master_imports')
          .select(
            'source_hash,menu_count,tracked_inventory_count,customer_count,created_at',
          )
          .maybeSingle(),
      ]);
      setLocations(locationRows);
      setLocationId(locationRows[0]?.id ?? '');
      if (!importResult.error && importResult.data) {
        setExisting(importResult.data as ExistingImport);
      }
    })().catch((caught: unknown) => {
      setError(
        caught instanceof Error
          ? caught.message
          : 'Status migrasi Legacy gagal dimuat.',
      );
    });
  }, []);

  async function chooseFile(file: File | undefined) {
    if (!file) return;
    setError('');
    setMessage('');
    try {
      const [buffer, text] = await Promise.all([
        file.arrayBuffer(),
        file.text(),
      ]);
      const parsed = parseLegacyMaster(JSON.parse(text) as unknown);
      setPayload(parsed);
      setSourceHash(await sha256Hex(buffer));
      setFileName(file.name);
    } catch (caught) {
      setPayload(null);
      setSourceHash('');
      setFileName('');
      setError(
        caught instanceof Error ? caught.message : 'Backup Legacy tidak valid.',
      );
    }
  }

  async function runImport() {
    if (!payload || !locationId || !sourceHash || existing) return;

    const summary = legacyMasterSummary(payload);
    const ok = window.confirm(
      'Import satu kali ' +
        summary.menuCount +
        ' produk ke Next dan tempatkan saldo stok Legacy pada lokasi yang dipilih?',
    );
    if (!ok) return;

    setBusy(true);
    setError('');
    setMessage('');
    try {
      const { data, error: importError } = await supabase.rpc(
        'import_legacy_master',
        {
          p_location_id: locationId,
          p_menu: payload.menu,
          p_inventory: payload.inventory,
          p_customers: payload.customers,
          p_settings: payload.settings,
          p_source_hash: sourceHash,
        },
      );
      if (importError) throw new Error(importError.message);
      const result = data as {
        menu_count?: number;
        tracked_inventory_count?: number;
        customer_count?: number;
      };
      setMessage(
        'Import berhasil: ' +
          String(result.menu_count ?? 0) +
          ' produk, ' +
          String(result.tracked_inventory_count ?? 0) +
          ' saldo stok, ' +
          String(result.customer_count ?? 0) +
          ' pelanggan.',
      );
      setExisting({
        source_hash: sourceHash,
        menu_count: Number(result.menu_count ?? 0),
        tracked_inventory_count: Number(result.tracked_inventory_count ?? 0),
        customer_count: Number(result.customer_count ?? 0),
        created_at: new Date().toISOString(),
      });
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : 'Import Legacy gagal.',
      );
    } finally {
      setBusy(false);
    }
  }

  const summary = payload ? legacyMasterSummary(payload) : null;

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            Kembali ke Beranda
          </Link>
          <p className="eyebrow">MIGRASI MASTER</p>
          <h1>Legacy ke Next</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}
      {message && <p className="success-banner">{message}</p>}

      <section className="identity-card">
        <h2>Import satu kali</h2>
        <p className="muted">
          Gunakan backup JSON asli Segeran Jiwa Legacy. Next membaca
          global.menu, global.inventory, global.customers, dan
          global.settings.qris. Tidak ada produk atau harga yang dibuat
          otomatis.
        </p>

        {existing ? (
          <div className="success-banner">
            Master Legacy sudah pernah diimpor. Produk: {existing.menu_count};
            saldo stok: {existing.tracked_inventory_count}; pelanggan:{' '}
            {existing.customer_count}.
          </div>
        ) : (
          <div className="stack-form">
            <label>
              File backup JSON Legacy
              <input
                type="file"
                accept=".json,application/json"
                onChange={(event) => void chooseFile(event.target.files?.[0])}
              />
            </label>

            <label>
              Lokasi untuk saldo stok Legacy
              <select
                value={locationId}
                onChange={(event) => setLocationId(event.target.value)}
              >
                {locations.map((location) => (
                  <option value={location.id} key={location.id}>
                    {location.label}
                  </option>
                ))}
              </select>
            </label>

            {summary && (
              <div className="import-preview">
                <strong>{fileName}</strong>
                <span>Produk: {summary.menuCount}</span>
                <span>Produk track-stock: {summary.trackedCount}</span>
                <span>Pelanggan: {summary.customerCount}</span>
                <span>
                  QRIS: {summary.qrisPresent ? 'Terdeteksi' : 'Tidak ada'}
                </span>
                <small>SHA-256: {sourceHash}</small>
              </div>
            )}

            <button
              className="primary-button"
              type="button"
              disabled={!summary || !locationId || busy}
              onClick={() => void runImport()}
            >
              {busy ? 'Mengimpor...' : 'Import Master Legacy'}
            </button>
          </div>
        )}
      </section>
    </main>
  );
}
