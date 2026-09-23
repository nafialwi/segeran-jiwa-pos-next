import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../auth/AuthProvider';
import { currentConnectivity } from '../control/connectivity';
import { Icon } from '../ui/Icon';
import {
  probeBackendAuthority,
  type BackendAuthorityProbe,
} from '../control/control-center-api';

function maskId(value: string): string {
  if (value.length <= 10) return value;
  return value.slice(0, 6) + '…' + value.slice(-4);
}

export function DiagnosticsScreen() {
  const { authority } = useAuth();
  const [probe, setProbe] = useState<BackendAuthorityProbe | null>(null);
  const [checking, setChecking] = useState(false);

  const refresh = useCallback(async () => {
    setChecking(true);
    try {
      setProbe(await probeBackendAuthority());
    } finally {
      setChecking(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  if (!authority) return null;

  return (
    <main className="shell control-page">
      <header className="topbar control-page-header c11e-control-hero">
        <div>
          <p className="eyebrow">PENGATURAN · DIAGNOSTIK</p>
          <h1>Diagnostik</h1>
          <p className="muted">
            Ringkasan runtime aman untuk membantu pemeriksaan tanpa menampilkan
            credential.
          </p>
        </div>
        <span className="control-hero-icon" aria-hidden="true">
          <Icon name="diagnostics" size={28} />
        </span>
        <button
          className="secondary-button"
          type="button"
          disabled={checking}
          onClick={() => void refresh()}
        >
          <Icon name="refresh" size={17} />
          <span>{checking ? 'Memeriksa...' : 'Refresh'}</span>
        </button>
      </header>

      <section className="diagnostics-grid">
        <article>
          <span>Backend probe</span>
          <strong>{probe?.status ?? 'BELUM DIPERIKSA'}</strong>
          <small>
            {probe
              ? probe.latencyMs + ' ms · ' + probe.detail
              : 'Menunggu pemeriksaan'}
          </small>
        </article>
        <article>
          <span>Koneksi Perangkat</span>
          <strong>{currentConnectivity()}</strong>
          <small>Indikator browser saja.</small>
        </article>
        <article>
          <span>Role</span>
          <strong>{authority.role_code}</strong>
          <small>
            {authority.owner ? 'Owner authority' : 'Staff authority'}
          </small>
        </article>
        <article>
          <span>Device ID</span>
          <strong>{maskId(authority.device_id)}</strong>
          <small>{authority.device_kind}</small>
        </article>
        <article>
          <span>Mode aplikasi</span>
          <strong>{import.meta.env.MODE}</strong>
          <small>Build mode Vite.</small>
        </article>
        <article>
          <span>Sesi</span>
          <strong>{maskId(authority.session_id)}</strong>
          <small>Sesi aktif, disamarkan.</small>
        </article>
      </section>

      <section className="control-truth-note">
        <strong>Tidak menampilkan token</strong>
        <span>
          Diagnostik tidak menampilkan access token, refresh token, password,
          service-role key, connection string, atau credential database.
        </span>
      </section>
    </main>
  );
}
