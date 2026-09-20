import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAccess } from './auth/RequireAccess';
import { useAuth } from './auth/AuthProvider';
import { AccessDeniedScreen } from './screens/AccessDeniedScreen';
import { HomeScreen } from './screens/HomeScreen';
import { LoginScreen } from './screens/LoginScreen';
import { OwnerUsersScreen } from './screens/OwnerUsersScreen';
import { ShiftManagementScreen } from './screens/ShiftManagementScreen';
import { HandoverScreen } from './screens/HandoverScreen';
import { ShiftHistoryScreen } from './screens/ShiftHistoryScreen';
import { ReconciliationScreen } from './screens/ReconciliationScreen';
import { ExpenseApprovalScreen } from './screens/ExpenseApprovalScreen';
import { SalesScreen } from './screens/SalesScreen';
import { InventoryScreen } from './screens/InventoryScreen';
import { PurchaseScreen } from './screens/PurchaseScreen';
import { LegacyImportScreen } from './screens/LegacyImportScreen';
import { FinanceScreen } from './screens/FinanceScreen';
import { TransactionHistoryScreen } from './screens/TransactionHistoryScreen';

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

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginScreen />} />
      <Route path="/" element={<RootRoute />} />
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
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
