import { createRoot } from 'react-dom/client';
import { MemoryRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AppShell } from '../../../src/components/AppShell';
import { MenuScreen } from '../../../src/screens/MenuScreen';
import { ProductionScreen } from '../../../src/screens/ProductionScreen';
import '../../../src/app.css';
import './fixture.css';

const view = new URLSearchParams(window.location.search).get('view');

createRoot(document.getElementById('root')!).render(
  <>
    <div className="fixture-notice" role="note">
      DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE
    </div>
    <MemoryRouter
      initialEntries={[view === 'produksi' ? '/produksi' : '/menu']}
    >
      <Routes>
        <Route element={<AppShell />}>
          <Route path="/menu" element={<MenuScreen />} />
          <Route path="/produksi" element={<ProductionScreen />} />
          <Route path="*" element={<Navigate to="/menu" replace />} />
        </Route>
      </Routes>
    </MemoryRouter>
  </>,
);
// This harness is served only through the dedicated F17 Vite configuration.
