import { createRoot } from 'react-dom/client';
import { MemoryRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppShell } from '../../../src/components/AppShell';
import { ReportsScreen } from '../../../src/screens/ReportsScreen';
import { TransactionHistoryScreen } from '../../../src/screens/TransactionHistoryScreen';
import '../../../src/app.css';
import '../f17/fixture.css';
const view = new URLSearchParams(window.location.search).get('view');
createRoot(document.getElementById('root')!).render(
  <>
    <div className="fixture-notice" role="note">
      DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE
    </div>
    <MemoryRouter
      initialEntries={[view === 'riwayat' ? '/riwayat' : '/laporan']}
    >
      <Routes>
        <Route element={<AppShell />}>
          <Route path="/laporan" element={<ReportsScreen />} />
          <Route path="/riwayat" element={<TransactionHistoryScreen />} />
          <Route path="*" element={<Navigate to="/laporan" replace />} />
        </Route>
      </Routes>
    </MemoryRouter>
  </>,
);
