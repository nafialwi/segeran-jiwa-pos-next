import { createRoot } from 'react-dom/client';
import { MemoryRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppShell } from '../../../src/components/AppShell';
import { FinanceScreen } from '../../../src/screens/FinanceScreen';
import { ShiftManagementScreen } from '../../../src/screens/ShiftManagementScreen';
import '../../../src/app.css';
import '../f17/fixture.css';
const view = new URLSearchParams(window.location.search).get('view');
createRoot(document.getElementById('root')!).render(
  <>
    <div className="fixture-notice" role="note">
      DATA CONTOH · KHUSUS UJI UI · TANPA DATABASE
    </div>
    <MemoryRouter initialEntries={[view === 'shift' ? '/shift' : '/keuangan']}>
      <Routes>
        <Route element={<AppShell />}>
          <Route path="/keuangan" element={<FinanceScreen />} />
          <Route path="/shift" element={<ShiftManagementScreen />} />
          <Route path="*" element={<Navigate to="/keuangan" replace />} />
        </Route>
      </Routes>
    </MemoryRouter>
  </>,
);
