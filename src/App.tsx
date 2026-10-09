import { lazy, Suspense } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAccess } from './auth/RequireAccess';
import { useAuth } from './auth/AuthProvider';
import { AppShell } from './components/AppShell';
import { OperationalHealthBanner } from './components/OperationalHealthBanner';
import { ActionDialogProvider } from './components/ActionDialogProvider';
import { AccessDeniedScreen } from './screens/AccessDeniedScreen';
const AppearanceSettingsScreen = lazy(() =>
  import('./screens/AppearanceSettingsScreen').then((module) => ({
    default: module.AppearanceSettingsScreen,
  })),
);
const AttentionScreen = lazy(() =>
  import('./screens/AttentionScreen').then((module) => ({
    default: module.AttentionScreen,
  })),
);
const BackupRestoreScreen = lazy(() =>
  import('./screens/BackupRestoreScreen').then((module) => ({
    default: module.BackupRestoreScreen,
  })),
);
const ControlCenterScreen = lazy(() =>
  import('./screens/ControlCenterScreen').then((module) => ({
    default: module.ControlCenterScreen,
  })),
);
const DiagnosticsScreen = lazy(() =>
  import('./screens/DiagnosticsScreen').then((module) => ({
    default: module.DiagnosticsScreen,
  })),
);
const ExpenseApprovalScreen = lazy(() =>
  import('./screens/ExpenseApprovalScreen').then((module) => ({
    default: module.ExpenseApprovalScreen,
  })),
);
const FinanceScreen = lazy(() =>
  import('./screens/FinanceScreen').then((module) => ({
    default: module.FinanceScreen,
  })),
);
const HandoverScreen = lazy(() =>
  import('./screens/HandoverScreen').then((module) => ({
    default: module.HandoverScreen,
  })),
);
const HomeScreen = lazy(() =>
  import('./screens/HomeScreen').then((module) => ({
    default: module.HomeScreen,
  })),
);
const InventoryControlScreen = lazy(() =>
  import('./screens/InventoryControlScreen').then((module) => ({
    default: module.InventoryControlScreen,
  })),
);
const InventoryItemScreen = lazy(() =>
  import('./screens/InventoryItemScreen').then((module) => ({
    default: module.InventoryItemScreen,
  })),
);
const InventoryScreen = lazy(() =>
  import('./screens/InventoryScreen').then((module) => ({
    default: module.InventoryScreen,
  })),
);
const LegacyImportScreen = lazy(() =>
  import('./screens/LegacyImportScreen').then((module) => ({
    default: module.LegacyImportScreen,
  })),
);
import { LoginScreen } from './screens/LoginScreen';
const MenuScreen = lazy(() =>
  import('./screens/MenuScreen').then((module) => ({
    default: module.MenuScreen,
  })),
);
const OfflineSyncScreen = lazy(() =>
  import('./screens/OfflineSyncScreen').then((module) => ({
    default: module.OfflineSyncScreen,
  })),
);
const OperationalMessageScreen = lazy(() =>
  import('./screens/OperationalMessageScreen').then((module) => ({
    default: module.OperationalMessageScreen,
  })),
);
import { OwnerUsersScreen } from './screens/OwnerUsersScreen';
const ProductOperationsScreen = lazy(() =>
  import('./screens/ProductOperationsScreen').then((module) => ({
    default: module.ProductOperationsScreen,
  })),
);
const ProductionScreen = lazy(() =>
  import('./screens/ProductionScreen').then((module) => ({
    default: module.ProductionScreen,
  })),
);
const PurchaseScreen = lazy(() =>
  import('./screens/PurchaseScreen').then((module) => ({
    default: module.PurchaseScreen,
  })),
);
const ReconciliationScreen = lazy(() =>
  import('./screens/ReconciliationScreen').then((module) => ({
    default: module.ReconciliationScreen,
  })),
);
const ReportsScreen = lazy(() =>
  import('./screens/ReportsScreen').then((module) => ({
    default: module.ReportsScreen,
  })),
);
const SalesScreen = lazy(() =>
  import('./screens/SalesScreen').then((module) => ({
    default: module.SalesScreen,
  })),
);
const ShiftHistoryScreen = lazy(() =>
  import('./screens/ShiftHistoryScreen').then((module) => ({
    default: module.ShiftHistoryScreen,
  })),
);
const ShiftManagementScreen = lazy(() =>
  import('./screens/ShiftManagementScreen').then((module) => ({
    default: module.ShiftManagementScreen,
  })),
);
const SystemHealthScreen = lazy(() =>
  import('./screens/SystemHealthScreen').then((module) => ({
    default: module.SystemHealthScreen,
  })),
);
const TransactionHistoryScreen = lazy(() =>
  import('./screens/TransactionHistoryScreen').then((module) => ({
    default: module.TransactionHistoryScreen,
  })),
);

function AuthenticatedLayout() {
  const { state, retryVerification, switchUser } = useAuth();

  if (state.kind === 'loading') {
    return <main className="center-card">Memulihkan sesi…</main>;
  }

  if (state.kind === 'verification_failed') {
    return (
      <main className="center-card">
        <h1>Sesi tetap tersimpan</h1>
        <p className="muted">{state.message}</p>
        <p className="muted">
          Aplikasi tidak mengeluarkan akun karena gangguan koneksi sementara.
        </p>
        <div className="button-row">
          <button
            className="primary-button"
            type="button"
            onClick={() => void retryVerification()}
          >
            Coba Verifikasi Lagi
          </button>
          <button
            className="secondary-button"
            type="button"
            onClick={() => void switchUser()}
          >
            Ganti Pengguna
          </button>
        </div>
      </main>
    );
  }

  if (state.kind === 'anonymous') {
    return <Navigate to="/login" replace />;
  }

  return <AppShell />;
}

export function App() {
  return (
    <ActionDialogProvider>
      <OperationalHealthBanner />
      <Suspense
        fallback={
          <main className="center-card" role="status">
            Memuat halaman…
          </main>
        }
      >
        <Routes>
          <Route path="/login" element={<LoginScreen />} />

          <Route element={<AuthenticatedLayout />}>
            <Route path="/" element={<HomeScreen />} />
            <Route path="/perhatian" element={<AttentionScreen />} />
            <Route
              path="/pesan-operasional"
              element={
                <RequireAccess permission="OPERATIONAL_MESSAGE_MANAGE">
                  <OperationalMessageScreen />
                </RequireAccess>
              }
            />
            <Route path="/menu" element={<MenuScreen />} />
            <Route
              path="/pengaturan"
              element={
                <RequireAccess permission="SETTINGS_NONCRITICAL">
                  <ControlCenterScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/pengaturan/tampilan"
              element={
                <RequireAccess permission="SETTINGS_NONCRITICAL">
                  <AppearanceSettingsScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/pengaturan/backup"
              element={
                <RequireAccess ownerOnly>
                  <BackupRestoreScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/pengaturan/kesehatan"
              element={<SystemHealthScreen />}
            />
            <Route
              path="/pengaturan/offline-sync"
              element={<OfflineSyncScreen />}
            />
            <Route
              path="/pengaturan/diagnostik"
              element={<DiagnosticsScreen />}
            />
            <Route
              path="/laporan"
              element={
                <RequireAccess
                  anyPermissions={[
                    'REPORT_SALES_LIMITED',
                    'REPORT_INVENTORY',
                    'REPORT_PURCHASE',
                  ]}
                >
                  <ReportsScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/riwayat"
              element={
                <RequireAccess anyPermissions={['HISTORY_OWN', 'HISTORY_ALL']}>
                  <TransactionHistoryScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/jual"
              element={
                <RequireAccess permission="SALE_EXECUTE">
                  <SalesScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/stok"
              element={
                <RequireAccess permission="INVENTORY_READ">
                  <InventoryScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/stok/kontrol"
              element={
                <RequireAccess
                  anyPermissions={[
                    'INVENTORY_REQUEST',
                    'INVENTORY_TRANSFER',
                    'INVENTORY_COUNT',
                    'INVENTORY_ADJUST',
                  ]}
                >
                  <InventoryControlScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/stok/:stockItemId"
              element={
                <RequireAccess permission="INVENTORY_READ">
                  <InventoryItemScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/produk"
              element={
                <RequireAccess
                  anyPermissions={[
                    'INVENTORY_READ',
                    'PRODUCT_MANAGE',
                    'PRODUCTION_MANAGE',
                  ]}
                >
                  <ProductOperationsScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/produksi"
              element={
                <RequireAccess permission="PRODUCTION_MANAGE">
                  <ProductionScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/pembelian"
              element={
                <RequireAccess permission="PURCHASE_MANAGE">
                  <PurchaseScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/legacy-import"
              element={
                <RequireAccess ownerOnly>
                  <LegacyImportScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/keuangan"
              element={
                <RequireAccess ownerOnly>
                  <FinanceScreen />
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
            <Route
              path="/shift"
              element={
                <RequireAccess permission="SHIFT_OPEN_CLOSE">
                  <ShiftManagementScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/handover"
              element={
                <RequireAccess permission="SHIFT_OPEN_CLOSE">
                  <HandoverScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/shift-history"
              element={
                <RequireAccess permission="SHIFT_READ_OWN">
                  <ShiftHistoryScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/rekonsiliasi"
              element={
                <RequireAccess permission="SHIFT_READ_OWN">
                  <ReconciliationScreen />
                </RequireAccess>
              }
            />
            <Route
              path="/expense-approval"
              element={
                <RequireAccess ownerOnly>
                  <ExpenseApprovalScreen />
                </RequireAccess>
              }
            />
            <Route path="/akses-ditolak" element={<AccessDeniedScreen />} />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </ActionDialogProvider>
  );
}
