import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent,
} from 'react';
import { Link } from 'react-router-dom';
import { SearchablePicker } from '../components/SearchablePicker';
import { useActionDialog } from '../components/ActionDialogProvider';
import {
  cancelOperationalMessage,
  createOperationalMessage,
  fetchManagedOperationalMessages,
  fetchOperationalMessageCapability,
  fetchOperationalMessageOptions,
  type OperationalMessageManagedItem,
  type OperationalMessagePriority,
  type OperationalMessageProfileOption,
  type OperationalMessageTargetKind,
} from '../operations/operational-message-api';
import { Icon } from '../ui/Icon';

function toLocalInput(date: Date): string {
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 16);
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function defaultStart() {
  return toLocalInput(new Date());
}

function defaultEnd() {
  return toLocalInput(new Date(Date.now() + 8 * 60 * 60 * 1000));
}

function targetLabel(message: OperationalMessageManagedItem): string {
  if (message.targetKind === 'PROFILE') {
    return message.targetProfileName || 'Kasir tertentu';
  }
  return 'Semua kasir';
}

export function OperationalMessageScreen() {
  const { confirmAction } = useActionDialog();
  const [capability, setCapability] = useState<boolean | null>(null);
  const [profiles, setProfiles] = useState<OperationalMessageProfileOption[]>(
    [],
  );
  const [messages, setMessages] = useState<OperationalMessageManagedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [priority, setPriority] =
    useState<OperationalMessagePriority>('NORMAL');
  const [targetKind, setTargetKind] =
    useState<OperationalMessageTargetKind>('ALL_CASHIERS');
  const [targetProfileId, setTargetProfileId] = useState('');
  const [validFrom, setValidFrom] = useState(defaultStart);
  const [validUntil, setValidUntil] = useState(defaultEnd);

  const profileOptions = useMemo(
    () =>
      profiles.map((profile) => ({
        id: profile.id,
        label: profile.displayName,
        meta: '@' + profile.username + ' · ' + profile.roleCode,
        keywords: profile.roleCode,
      })),
    [profiles],
  );

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const ready = await fetchOperationalMessageCapability();
      setCapability(ready);
      if (!ready) {
        setProfiles([]);
        setMessages([]);
        return;
      }
      const [nextProfiles, nextMessages] = await Promise.all([
        fetchOperationalMessageOptions(),
        fetchManagedOperationalMessages(),
      ]);
      setProfiles(nextProfiles);
      setMessages(nextMessages);
      setTargetProfileId((current) =>
        nextProfiles.some((item) => item.id === current)
          ? current
          : (nextProfiles[0]?.id ?? ''),
      );
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Pesan operasional gagal dimuat.',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!capability) return;
    setBusy(true);
    setError('');
    setSuccess('');
    try {
      await createOperationalMessage({
        title,
        body,
        priority,
        targetKind,
        targetProfileId:
          targetKind === 'PROFILE' ? targetProfileId || null : null,
        validFrom: new Date(validFrom).toISOString(),
        validUntil: new Date(validUntil).toISOString(),
      });
      setSuccess('Pesan operasional berhasil dikirim.');
      setTitle('');
      setBody('');
      setPriority('NORMAL');
      setTargetKind('ALL_CASHIERS');
      setValidFrom(defaultStart());
      setValidUntil(defaultEnd());
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Pesan gagal dikirim.');
    } finally {
      setBusy(false);
    }
  }

  async function cancel(message: OperationalMessageManagedItem) {
    const confirmed = await confirmAction({
      title: 'Batalkan pesan operasional?',
      description:
        'Pesan "' +
        message.title +
        '" tidak akan muncul lagi di dashboard kasir.',
      confirmLabel: 'Batalkan Pesan',
      tone: 'danger',
    });
    if (!confirmed) return;
    setBusy(true);
    setError('');
    setSuccess('');
    try {
      await cancelOperationalMessage(message.id, 'Dibatalkan dari Pusat Pesan');
      setSuccess('Pesan berhasil dibatalkan.');
      await load();
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Pesan gagal dibatalkan.',
      );
    } finally {
      setBusy(false);
    }
  }

  const now = Date.now();

  return (
    <main className="shell secondary-screen operational-message-screen">
      <header className="topbar secondary-hero operational-message-hero">
        <div>
          <Link to="/">Beranda</Link>
          <p className="eyebrow">PESAN OPERASIONAL</p>
          <h1>Instruksi Kasir</h1>
          <p className="muted">
            Kirim catatan kerja yang singkat, bertarget, dan berbatas waktu. Ini
            bukan ruang chat.
          </p>
        </div>
        <span className="operational-message-hero-icon" aria-hidden="true">
          <Icon name="notification" size={28} />
        </span>
      </header>

      {error && <div className="error-banner">{error}</div>}
      {success && <div className="success-banner">{success}</div>}

      {loading ? (
        <div className="operations-card-skeleton operational-message-loading">
          <span />
          <span />
        </div>
      ) : capability === false ? (
        <section className="identity-card secondary-panel">
          <strong>Fitur pesan operasional belum aktif pada backend ini.</strong>
          <p className="muted">
            Preview tetap aman dan hanya akan membuka editor setelah authority
            server tersedia.
          </p>
        </section>
      ) : (
        <>
          <section className="identity-card secondary-panel operational-message-compose">
            <div className="section-heading">
              <div>
                <p className="eyebrow">BUAT INSTRUKSI</p>
                <h2>Pesan Baru</h2>
              </div>
              <span className="operations-status">Maks. 30 hari</span>
            </div>

            <form className="stack-form" onSubmit={submit}>
              <label>
                Judul
                <input
                  value={title}
                  onChange={(event) => setTitle(event.target.value)}
                  maxLength={120}
                  placeholder="Contoh: Prioritas pelayanan hari ini"
                  required
                />
              </label>

              <label>
                Instruksi
                <textarea
                  value={body}
                  onChange={(event) => setBody(event.target.value)}
                  maxLength={1200}
                  rows={5}
                  placeholder="Tulis instruksi singkat dan jelas untuk kasir."
                  required
                />
                <small className="field-hint">
                  {body.length}/1200 karakter
                </small>
              </label>

              <div className="compact-grid-form">
                <label>
                  Prioritas
                  <select
                    value={priority}
                    onChange={(event) =>
                      setPriority(
                        event.target.value as OperationalMessagePriority,
                      )
                    }
                  >
                    <option value="NORMAL">Normal</option>
                    <option value="HIGH">Penting</option>
                  </select>
                </label>

                <label>
                  Penerima
                  <select
                    value={targetKind}
                    onChange={(event) =>
                      setTargetKind(
                        event.target.value as OperationalMessageTargetKind,
                      )
                    }
                  >
                    <option value="ALL_CASHIERS">Semua kasir</option>
                    <option value="PROFILE">Kasir tertentu</option>
                  </select>
                </label>

                <label>
                  Mulai berlaku
                  <input
                    type="datetime-local"
                    value={validFrom}
                    onChange={(event) => setValidFrom(event.target.value)}
                    required
                  />
                </label>

                <label>
                  Berlaku sampai
                  <input
                    type="datetime-local"
                    value={validUntil}
                    onChange={(event) => setValidUntil(event.target.value)}
                    required
                  />
                </label>
              </div>

              {targetKind === 'PROFILE' && (
                <SearchablePicker
                  label="Kasir penerima"
                  value={targetProfileId}
                  options={profileOptions}
                  onChange={setTargetProfileId}
                  placeholder="Pilih kasir"
                  eyebrow="PILIH KASIR"
                  searchPlaceholder="Cari nama atau username…"
                  emptyLabel="Kasir tidak ditemukan."
                  noun="kasir"
                />
              )}

              <button
                className="primary-button operational-message-send"
                type="submit"
                disabled={
                  busy ||
                  !title.trim() ||
                  !body.trim() ||
                  (targetKind === 'PROFILE' && !targetProfileId)
                }
              >
                <Icon name="share" size={18} />
                <span>{busy ? 'Mengirim…' : 'Kirim Instruksi'}</span>
              </button>
            </form>
          </section>

          <section className="identity-card secondary-panel operational-message-history">
            <div className="section-heading">
              <div>
                <p className="eyebrow">RIWAYAT PESAN</p>
                <h2>Pesan Terbaru</h2>
              </div>
              <span className="operations-status">{messages.length} pesan</span>
            </div>

            {messages.length === 0 ? (
              <p className="empty-state">Belum ada pesan operasional.</p>
            ) : (
              <div className="operational-message-list">
                {messages.map((message) => {
                  const expired = new Date(message.validUntil).getTime() <= now;
                  const cancelled = message.cancelledAt !== null;
                  return (
                    <article
                      className={[
                        'operational-message-card',
                        message.priority === 'HIGH' ? 'high' : '',
                        expired || cancelled ? 'inactive' : '',
                      ]
                        .filter(Boolean)
                        .join(' ')}
                      key={message.id}
                    >
                      <header>
                        <span className="operational-message-card-icon">
                          <Icon
                            name={
                              message.priority === 'HIGH'
                                ? 'warning'
                                : 'notification'
                            }
                            size={20}
                          />
                        </span>
                        <span>
                          <strong>{message.title}</strong>
                          <small>
                            {targetLabel(message)} · oleh {message.authorName}
                          </small>
                        </span>
                        <span className="operational-message-state">
                          {cancelled
                            ? 'Dibatalkan'
                            : expired
                              ? 'Berakhir'
                              : message.priority === 'HIGH'
                                ? 'Penting'
                                : 'Aktif'}
                        </span>
                      </header>
                      <p>{message.body}</p>
                      <footer>
                        <span>Sampai {formatDateTime(message.validUntil)}</span>
                        <span>
                          Dibaca {message.readCount}/{message.recipientCount}
                        </span>
                        {!expired && !cancelled && (
                          <button
                            className="secondary-button danger-lite"
                            type="button"
                            disabled={busy}
                            onClick={() => void cancel(message)}
                          >
                            Batalkan
                          </button>
                        )}
                      </footer>
                    </article>
                  );
                })}
              </div>
            )}
          </section>
        </>
      )}
    </main>
  );
}
