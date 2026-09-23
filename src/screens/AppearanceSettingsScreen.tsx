import { useState } from 'react';
import { Icon } from '../ui/Icon';
import {
  loadControlPreferences,
  saveControlPreferences,
  type ControlPreferences,
} from '../control/preferences';

export function AppearanceSettingsScreen() {
  const [preferences, setPreferences] = useState<ControlPreferences>(() =>
    loadControlPreferences(),
  );
  const [message, setMessage] = useState('');

  function save(next: ControlPreferences) {
    setPreferences(next);
    saveControlPreferences(next);
    setMessage('Preferensi perangkat ini disimpan.');
  }

  return (
    <main className="shell control-page">
      <header className="topbar control-page-header">
        <div>
          <p className="eyebrow">PENGATURAN · TAMPILAN</p>
          <h1>Tampilan & Dashboard</h1>
          <p className="muted">
            Preferensi perangkat ini bersifat non-kritis dan tidak mengubah
            aturan bisnis, stok, uang, atau audit.
          </p>
        </div>
      </header>

      {message && <p className="success-banner">{message}</p>}

      <section className="control-settings-grid">
        <article className="control-setting-card">
          <div>
            <p className="eyebrow">KEPADATAN</p>
            <h2>Jarak Tampilan</h2>
            <p className="muted">
              Pilih Nyaman untuk ruang lebih lega atau Ringkas untuk menampilkan
              lebih banyak informasi.
            </p>
          </div>
          <div className="control-choice-row">
            <button
              type="button"
              className={
                preferences.density === 'comfortable'
                  ? 'control-choice active'
                  : 'control-choice'
              }
              onClick={() => save({ ...preferences, density: 'comfortable' })}
            >
              <Icon name="appearance" size={22} />
              <strong>Nyaman</strong>
              <span>Ruang kartu dan panel lebih lega.</span>
            </button>
            <button
              type="button"
              className={
                preferences.density === 'compact'
                  ? 'control-choice active'
                  : 'control-choice'
              }
              onClick={() => save({ ...preferences, density: 'compact' })}
            >
              <Icon name="category" size={22} />
              <strong>Ringkas</strong>
              <span>Lebih banyak informasi dalam satu layar.</span>
            </button>
          </div>
        </article>

        <article className="control-setting-card">
          <div>
            <p className="eyebrow">AKSESIBILITAS</p>
            <h2>Ukuran Teks</h2>
            <p className="muted">
              Ubah ukuran dasar teks tanpa mengubah data atau permission.
            </p>
          </div>
          <div className="control-choice-row">
            <button
              type="button"
              className={
                preferences.fontScale === 'normal'
                  ? 'control-choice active'
                  : 'control-choice'
              }
              onClick={() => save({ ...preferences, fontScale: 'normal' })}
            >
              <Icon name="settings" size={22} />
              <strong>Normal</strong>
              <span>Ukuran standar Segeran Jiwa.</span>
            </button>
            <button
              type="button"
              className={
                preferences.fontScale === 'large'
                  ? 'control-choice active'
                  : 'control-choice'
              }
              onClick={() => save({ ...preferences, fontScale: 'large' })}
            >
              <Icon name="appearance" size={22} />
              <strong>Teks Besar</strong>
              <span>Lebih mudah dibaca pada layar kecil.</span>
            </button>
          </div>
        </article>
      </section>

      <section className="control-truth-note">
        <strong>Preferensi perangkat ini</strong>
        <span>
          Disimpan lokal pada browser/perangkat. Tidak diperlakukan sebagai
          pengaturan bisnis global dan tidak menggantikan authority server.
        </span>
      </section>
    </main>
  );
}
