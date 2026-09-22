import { useEffect } from 'react';
import { Link, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { initializeControlPreferences } from '../control/preferences';
import {
  getPrimaryNavigation,
  isPrimaryNavigationActive,
} from '../navigation/appNavigation';
import { Icon } from '../ui/Icon';

function BrandBlock() {
  return (
    <Link className="app-brand" to="/" aria-label="Segeran Jiwa POS Next">
      <span className="app-brand-logo-frame" aria-hidden="true">
        <img
          className="app-brand-logo"
          src="/brand/segeran-jiwa-logo.png"
          alt=""
          loading="eager"
        />
      </span>
      <span className="app-brand-copy">
        <strong>Segeran Jiwa</strong>
        <small>POS Next</small>
      </span>
    </Link>
  );
}

export function AppShell() {
  const { authority } = useAuth();
  const location = useLocation();

  useEffect(() => {
    initializeControlPreferences();
  }, []);

  if (!authority) return <Outlet />;

  const navigation = getPrimaryNavigation(authority);

  return (
    <div className="app-frame">
      <aside className="app-sidebar">
        <BrandBlock />
        <nav className="app-sidebar-nav" aria-label="Navigasi utama">
          {navigation.map((item) => {
            const active = isPrimaryNavigationActive(item, location.pathname);
            return (
              <Link
                key={item.id}
                className={`app-sidebar-link${active ? ' active' : ''}`}
                to={item.to}
                aria-current={active ? 'page' : undefined}
              >
                <Icon name={item.icon} active={active} />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>
        <div className="app-sidebar-user">
          <span>{authority.display_name}</span>
          <small>{authority.role_code}</small>
        </div>
      </aside>

      <div className="app-main">
        <header className="app-mobile-header">
          <BrandBlock />
          <span className="role-badge">{authority.role_code}</span>
        </header>

        <div className="app-route-content">
          <Outlet />
        </div>
      </div>

      <nav className="app-bottom-nav" aria-label="Navigasi utama">
        {navigation.map((item) => {
          const active = isPrimaryNavigationActive(item, location.pathname);
          return (
            <Link
              key={item.id}
              className={`app-bottom-nav-link${active ? ' active' : ''}`}
              to={item.to}
              aria-current={active ? 'page' : undefined}
            >
              <Icon name={item.icon} active={active} size={22} />
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
