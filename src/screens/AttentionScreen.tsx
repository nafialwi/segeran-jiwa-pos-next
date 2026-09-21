import { useEffect, useState } from 'react';
import { deriveOperationalHealth } from '../health/operational-health';
import { Icon } from '../ui/Icon';

function currentOnlineState(): boolean {
  if (typeof navigator === 'undefined') return true;
  return navigator.onLine;
}

export function AttentionScreen() {
  const [isOnline, setIsOnline] = useState(currentOnlineState);

  useEffect(() => {
    function refreshConnectivity() {
      setIsOnline(currentOnlineState());
    }

    window.addEventListener('online', refreshConnectivity);
    window.addEventListener('offline', refreshConnectivity);

    return () => {
      window.removeEventListener('online', refreshConnectivity);
      window.removeEventListener('offline', refreshConnectivity);
    };
  }, []);

  const health = deriveOperationalHealth(isOnline);

  return (
    <main className="shell attention-screen">
      <header className="topbar">
        <div>
          <p className="eyebrow">OPERASIONAL</p>
          <h1>Perhatian</h1>
          <p className="muted">
            Hanya kondisi yang membutuhkan tindakan yang ditampilkan di sini.
          </p>
        </div>
      </header>

      <section
        className={`attention-card${health.needsAttention ? ' warning' : ''}`}
      >
        <div className="attention-icon">
          <Icon name="notification" />
        </div>
        <div>
          <strong>
            {health.needsAttention
              ? health.title
              : 'Tidak ada perhatian konektivitas perangkat'}
          </strong>
          <p>{health.detail}</p>
        </div>
      </section>

      <section className="attention-footnote">
        <Icon name="diagnostics" />
        <div>
          <strong>Status ini tidak menyatakan database sehat.</strong>
          <p>
            Health backend, backup, sinkronisasi, stok, shift, dan exception
            bisnis tetap harus berasal dari evidence authority masing-masing.
          </p>
        </div>
      </section>
    </main>
  );
}
