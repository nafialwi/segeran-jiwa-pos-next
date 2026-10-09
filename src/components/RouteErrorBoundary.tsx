import { Component, type ReactNode } from 'react';
import { Link } from 'react-router-dom';

type Props = {
  children: ReactNode;
};

type State = {
  hasError: boolean;
};

/**
 * A failed lazy screen must not take down the authenticated navigation shell.
 * Recovery is an explicit user action; this component never repeats a POS write.
 */
export class RouteErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return (
        <main className="center-card route-load-error" role="alert">
          <h1>Halaman belum dapat dibuka</h1>
          <p className="muted">
            Periksa koneksi internet Anda. Jika aplikasi baru saja diperbarui,
            coba muat ulang halaman.
          </p>
          <div className="button-row">
            <button
              className="primary-button"
              type="button"
              onClick={() => window.location.reload()}
            >
              Muat Ulang Halaman
            </button>
            <Link className="secondary-button" to="/">
              Kembali ke Beranda
            </Link>
          </div>
        </main>
      );
    }

    return this.props.children;
  }
}
