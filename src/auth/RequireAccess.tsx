import { Navigate } from 'react-router-dom';
import { useAuth } from './AuthProvider';
import { canAccessOwnerArea, hasPermission } from './permission';
import type { PermissionCode } from './types';
import type { ReactNode } from 'react';

type RequireAccessProps =
  | {
      children: ReactNode;
      ownerOnly: true;
      permission?: never;
    }
  | {
      children: ReactNode;
      ownerOnly?: false;
      permission: PermissionCode;
    };

export function RequireAccess(props: RequireAccessProps) {
  const { state, authority } = useAuth();

  if (state.kind === 'loading') {
    return <main className="center-card">Memverifikasi akses…</main>;
  }

  if (!authority) {
    return <Navigate to="/login" replace />;
  }

  const allowed = props.ownerOnly
    ? canAccessOwnerArea(authority)
    : hasPermission(authority, props.permission);

  if (!allowed) {
    return <Navigate to="/akses-ditolak" replace />;
  }

  return <>{props.children}</>;
}
