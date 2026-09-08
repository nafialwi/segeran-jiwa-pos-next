import { useMemo, useState, type FormEvent } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import {
  getDeviceKind,
  getRememberedUsernames,
  type DeviceKind,
} from '../auth/device';

export function LoginScreen() {
  const { state, login } = useAuth();
  const remembered = useMemo(
    () => getRememberedUsernames(window.localStorage),
    [],
  );
  const [username, setUsername] = useState(remembered[0] ?? '');
  const [password, setPassword] = useState('');
  const [deviceKind, setDeviceKindState] = useState<DeviceKind>(() =>
    getDeviceKind(window.localStorage),
  );
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);

  if (state.kind === 'authenticated') {
    return <Navigate to="/" replace />;
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;

    setSubmitting(true);
    setMessage('');
    try {
      await login(username, password, deviceKind);
    } catch (error) {
      const code = error instanceof Error ? error.message : '';
      setMessage(
        code === 'SJ_LOGIN_INVALID'
          ? 'Username atau password salah.'
          : code || 'Tidak dapat masuk. Coba lagi.',
      );
    } finally {
      setPassword('');
      setSubmitting(false);
    }
  }

  return (
    <main className="auth-page">
      <section className="auth-card" aria-labelledby="login-title">
        <p className="eyebrow">SEGERAN JIWA POS NEXT</p>
        <h1 id="login-title">Masuk</h1>
        <p className="muted">
          Gunakan username dan password yang diberikan Owner.
        </p>

        {remembered.length > 0 && (
          <div className="remembered-users">
            <span className="field-label">Username tersimpan</span>
            <div className="chip-row">
              {remembered.map((item) => (
                <button
                  type="button"
                  className="chip"
                  key={item}
                  onClick={() => setUsername(item)}
                >
                  {item}
                </button>
              ))}
            </div>
          </div>
        )}

        <form onSubmit={submit} className="stack">
          <label>
            <span className="field-label">Username</span>
            <input
              autoComplete="username"
              name="username"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              required
            />
          </label>

          <label>
            <span className="field-label">Password</span>
            <input
              autoComplete="current-password"
              name="password"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>

          <fieldset>
            <legend className="field-label">Jenis perangkat</legend>
            <label className="radio-row">
              <input
                type="radio"
                name="device-kind"
                value="PERSONAL"
                checked={deviceKind === 'PERSONAL'}
                onChange={() => setDeviceKindState('PERSONAL')}
              />
              Perangkat Pribadi
            </label>
            <label className="radio-row">
              <input
                type="radio"
                name="device-kind"
                value="SHARED"
                checked={deviceKind === 'SHARED'}
                onChange={() => setDeviceKindState('SHARED')}
              />
              Perangkat Bersama
            </label>
          </fieldset>

          {message && (
            <p className="form-error" role="alert">
              {message}
            </p>
          )}

          <button
            className="primary-button"
            type="submit"
            disabled={submitting}
          >
            {submitting ? 'Memverifikasi…' : 'Masuk'}
          </button>
        </form>
      </section>
    </main>
  );
}
