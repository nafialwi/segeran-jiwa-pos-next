import { createRoot } from 'react-dom/client';
import { MemoryRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppShell } from '../../../src/components/AppShell';
import { SalesScreen } from '../../../src/screens/SalesScreen';
import '../../../src/app.css';
import '../f17/fixture.css';
createRoot(document.getElementById('root')!).render(
  <>
    <div className="fixture-notice" role="note">
      DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE · PEMBAYARAN DINONAKTIFKAN
    </div>
    <MemoryRouter initialEntries={['/jual']}>
      <Routes>
        <Route element={<AppShell />}>
          <Route path="/jual" element={<SalesScreen />} />
          <Route path="*" element={<Navigate to="/jual" replace />} />
        </Route>
      </Routes>
    </MemoryRouter>
  </>,
);
