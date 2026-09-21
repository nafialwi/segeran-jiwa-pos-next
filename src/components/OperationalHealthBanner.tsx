import { useEffect, useState } from 'react';
import { deriveOperationalHealth } from '../health/operational-health';

function currentOnlineState(): boolean {
  if (typeof navigator === 'undefined') return true;
  return navigator.onLine;
}

export function OperationalHealthBanner() {
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

  if (!health.needsAttention) return null;

  return (
    <aside
      className="operational-health-banner"
      role="status"
      aria-live="polite"
      data-connectivity={health.connectivity}
    >
      <strong>{health.title}</strong>
      <span>{health.detail}</span>
    </aside>
  );
}
