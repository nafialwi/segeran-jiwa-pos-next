import { Link } from 'react-router-dom';

export function AccessDeniedScreen() {
  return (
    <main className="center-card">
      <p className="eyebrow">AKSES DIBATASI</p>
      <h1>Anda tidak memiliki izin untuk halaman ini.</h1>
      <p className="muted">
        Hak akses mengikuti role dan izin terbaru yang ditetapkan Owner.
      </p>
      <Link className="primary-link" to="/">
        Kembali ke Beranda
      </Link>
    </main>
  );
}
