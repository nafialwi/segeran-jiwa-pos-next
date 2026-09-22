import { BACKUP_CHECKPOINT_EVIDENCE } from '../control/backup-evidence';

export function BackupRestoreScreen() {
  const evidence = BACKUP_CHECKPOINT_EVIDENCE;

  return (
    <main className="shell control-page">
      <header className="topbar control-page-header">
        <div>
          <p className="eyebrow">PENGATURAN · BACKUP</p>
          <h1>Backup & Restore</h1>
          <p className="muted">
            Status di layar ini berasal dari evidence checkpoint P5C, bukan
            asumsi konektivitas.
          </p>
        </div>
      </header>

      <section className="control-evidence-card neutral">
        <div>
          <span className="control-evidence-label">Bukti terakhir</span>
          <strong>{evidence.evidenceKind}</strong>
        </div>
        <dl>
          <div>
            <dt>Verifikasi</dt>
            <dd>{new Date(evidence.verifiedAt).toLocaleString('id-ID')}</dd>
          </div>
          <div>
            <dt>Backup gate saat checkpoint</dt>
            <dd>{evidence.backupGate}</dd>
          </div>
          <div>
            <dt>Restore</dt>
            <dd>{evidence.restoreStatus}</dd>
          </div>
          <div>
            <dt>Metode</dt>
            <dd>{evidence.restoreMethod}</dd>
          </div>
          <div>
            <dt>Archive TOC</dt>
            <dd>{evidence.archiveTocEntries}</dd>
          </div>
        </dl>
      </section>

      <section className="control-truth-note warning">
        <strong>Ini bukan status backup realtime.</strong>
        <span>{evidence.note}</span>
      </section>

      <section className="control-setting-card">
        <div>
          <p className="eyebrow">RESTORE</p>
          <h2>Restore Otomatis Tidak Tersedia</h2>
          <p className="muted">
            Restore database adalah tindakan berisiko tinggi dan tetap dilakukan
            melalui prosedur operator yang tervalidasi. Aplikasi tidak
            menyediakan tombol restore langsung ke database aktif.
          </p>
        </div>
      </section>
    </main>
  );
}
