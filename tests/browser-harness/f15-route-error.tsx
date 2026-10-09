import { lazy, Suspense } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, useLocation } from 'react-router-dom';
import { RouteErrorBoundary } from '../../src/components/RouteErrorBoundary';
import '../../src/app.css';

// Simulates a rejected page-module fetch without credentials or business writes.
const FailedPage = lazy(() =>
  Promise.reject(new Error('SIMULATED_ROUTE_CHUNK_FAILED')),
);

function Harness() {
  const location = useLocation();
  const isRecoveryPage = location.pathname === '/';

  return (
    <div className="app-frame" data-testid="f15-test-harness">
      <header id="f15-header" className="app-mobile-header">
        Header tetap terlihat
      </header>
      <div className="app-route-content">
        <RouteErrorBoundary key={location.pathname}>
          <Suspense fallback={<main role="status">Memuat halaman…</main>}>
            {isRecoveryPage ? (
              <main id="f15-recovered">Beranda dapat dibuka kembali</main>
            ) : (
              <FailedPage />
            )}
          </Suspense>
        </RouteErrorBoundary>
      </div>
      <nav id="f15-navigation" aria-label="Navigasi utama">
        Navigasi tetap terlihat
      </nav>
    </div>
  );
}

createRoot(document.getElementById('root')!).render(
  <BrowserRouter>
    <Harness />
  </BrowserRouter>,
);
