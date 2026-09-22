import { useEffect, useState } from 'react';
import { currentConnectivity } from '../control/connectivity';

export function OfflineSyncScreen() {
  const [connectivity, setConnectivity] = useState(currentConnectivity);

  useEffect(() => {
    const refresh = () => setConnectivity(currentConnectivity());
    window.addEventListener('online', refresh);
    window.addEventListener('offline', refresh);
    return () => {
      window.removeEventListener('online', refresh);
      window.removeEventListener('offline', refresh);
    };
  }, []);

  return (
    <main className="shell control-page">
      <header className="topbar control-page-header">
        <div>
          <p className="eyebrow">PENGATURAN · OFFLINE</p>
          <h1>Offline & Sync</h1>
          <p className="muted">
            Status koneksi perangkat ditampilkan terpisah dari status backend.
          </p>
        </div>
      </header>

      <section
        className={
          connectivity === 'ONLINE'
            ? 'control-evidence-card neutral'
            : 'control-evidence-card danger'
        }
      >
        <div>
          <span className="control-evidence-label">Koneksi Perangkat</span>
          <strong>{connectivity}</strong>
        </div>
        <p>
          Browser connectivity adalah indikator perangkat saja dan bukan status
          backend.
        </p>
      </section>

      <section className="control-settings-grid">
        <article className="control-setting-card">
          <h2>Tidak ada antrean mutasi offline</h2>
          <p className="muted">
            Penjualan, refund, koreksi, transfer stok, opname, produksi,
            pembelian, dan tindakan penting tidak disimpan diam-diam untuk
            dikirim nanti.
          </p>
        </article>
        <article className="control-setting-card">
          <h2>Operasi server tetap online-only</h2>
          <p className="muted">
            Jika koneksi atau backend tidak tersedia, operasi sensitif gagal
            tertutup dan harus dicoba kembali setelah layanan tersedia.
          </p>
        </article>
      </section>
    </main>
  );
}
