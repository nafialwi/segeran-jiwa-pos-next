import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAccess } from './auth/RequireAccess';
import { useAuth } from './auth/AuthProvider';
import { AccessDeniedScreen } from './screens/AccessDeniedScreen';
import { HomeScreen } from './screens/HomeScreen';
import { LoginScreen } from './screens/LoginScreen';
import { OwnerUsersScreen } from './screens/OwnerUsersScreen';

function RootRoute() {
  const { state } = useAuth();

  if (state.kind === 'loading') {
    return <main className="center-card">Memverifikasi sesi…</main>;
  }

  if (state.kind === 'anonymous') {
    return <Navigate to="/login" replace />;
  }

  return <HomeScreen />;
}

function SalesFoundationScreen() {
  return (
    <main className="center-card">
      <p className="eyebrow">PENJUALAN</p>
      <h1>Fondasi akses Penjualan aktif.</h1>
      <p>Modul Penjualan dibangun pada milestone berikutnya.</p>
    </main>
  );
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginScreen />} />
      <Route path="/" element={<RootRoute />} />
      <Route
        path="/jual"
        element={
          <RequireAccess permission="SALE_EXECUTE">
            <SalesFoundationScreen />
          </RequireAccess>
        }
      />
      <Route
        path="/pengguna"
        element={
          <RequireAccess ownerOnly>
            <OwnerUsersScreen />
          </RequireAccess>
        }
      />
      <Route path="/akses-ditolak" element={<AccessDeniedScreen />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
