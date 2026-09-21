import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAccess } from './auth/RequireAccess';
import { useAuth } from './auth/AuthProvider';
import { AppShell } from './components/AppShell';
import { OperationalHealthBanner } from './components/OperationalHealthBanner';
import { AccessDeniedScreen } from './screens/AccessDeniedScreen';
import { AttentionScreen } from './screens/AttentionScreen';
import { ExpenseApprovalScreen } from './screens/ExpenseApprovalScreen';
import { FinanceScreen } from './screens/FinanceScreen';
import { HandoverScreen } from './screens/HandoverScreen';
import { HomeScreen } from './screens/HomeScreen';
import { InventoryScreen } from './screens/InventoryScreen';
import { LegacyImportScreen } from './screens/LegacyImportScreen';
import { LoginScreen } from './screens/LoginScreen';
import { MenuScreen } from './screens/MenuScreen';
import { OwnerUsersScreen } from './screens/OwnerUsersScreen';
import { PurchaseScreen } from './screens/PurchaseScreen';
import { ReconciliationScreen } from './screens/ReconciliationScreen';
import { ReportsScreen } from './screens/ReportsScreen';
import { SalesScreen } from './screens/SalesScreen';
import { ShiftHistoryScreen } from './screens/ShiftHistoryScreen';
import { ShiftManagementScreen } from './screens/ShiftManagementScreen';
import { TransactionHistoryScreen } from './screens/TransactionHistoryScreen';

function AuthenticatedLayout() {
  const { state } = useAuth();

  if (state.kind === 'loading') {
    return <main className="center-card">Memverifikasi sesi…</main>;
  }

  if (state.kind === 'anonymous') {
    return <Navigate to="/login" replace />;
  }

  return <AppShell />;
}

export function App() {
  return (
    <>
      <OperationalHealthBanner />
      <Routes>
        <Route path="/login" element={<LoginScreen />} />

        <Route element={<AuthenticatedLayout />}>
          <Route path="/" element={<HomeScreen />} />
          <Route path="/perhatian" element={<AttentionScreen />} />
          <Route path="/menu" element={<MenuScreen />} />
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
    </>
  );
}
