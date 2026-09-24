import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import {
  canAccessOwnerArea,
  hasAnyPermission,
  hasPermission,
} from '../auth/permission';
import {
  fetchCashierDashboard,
  fetchOwnerDashboard,
  type CashierDashboardData,
  type OwnerDashboardData,
} from '../dashboard/dashboard-api';
import { deriveOperationalHealth } from '../health/operational-health';
import {
  fetchMyOperationalMessages,
  markOperationalMessageRead,
  type OperationalMessageInboxItem,
} from '../operations/operational-message-api';
import { Icon } from '../ui/Icon';
import type { SegeranIconName } from '../ui/iconRegistry';

function formatIdr(value: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function currentOnlineState(): boolean {
  if (typeof navigator === 'undefined') return true;
  return navigator.onLine;
}

function useConnectivity() {
  const [online, setOnline] = useState(currentOnlineState);

  useEffect(() => {
    const refresh = () => setOnline(currentOnlineState());
    window.addEventListener('online', refresh);
    window.addEventListener('offline', refresh);
    return () => {
      window.removeEventListener('online', refresh);
      window.removeEventListener('offline', refresh);
    };
  }, []);

  return online;
}

function DashboardSkeleton() {
  return (
    <div className="dashboard-skeleton" aria-label="Memuat ringkasan">
      <span />
      <span />
      <span />
      <span />
    </div>
  );
}

function DashboardError({ message }: { message: string }) {
  return (
    <section className="dashboard-error-card">
      <Icon name="diagnostics" />
      <div>
        <strong>Ringkasan belum dapat dimuat</strong>
        <p>{message}</p>
      </div>
    </section>
  );
}

function DashboardCard({
  label,
  value,
  detail,
  icon,
}: {
  label: string;
  value: string;
  detail?: string;
  icon: SegeranIconName;
}) {
  return (
    <article className="dashboard-kpi-card">
      <span className="dashboard-kpi-icon">
        <Icon name={icon} />
      </span>
      <span className="dashboard-kpi-label">{label}</span>
      <strong>{value}</strong>
      {detail && <small>{detail}</small>}
    </article>
  );
}

function AttentionEntry() {
  const online = useConnectivity();
  const health = deriveOperationalHealth(online);
  const [messages, setMessages] = useState<OperationalMessageInboxItem[]>([]);

  useEffect(() => {
    let active = true;
    if (!online) {
      setMessages([]);
      return () => {
        active = false;
      };
    }

    void fetchMyOperationalMessages(10)
      .then((rows) => {
        if (active) setMessages(rows);
      })
      .catch(() => {
        if (active) setMessages([]);
      });

    return () => {
      active = false;
    };
  }, [online]);

  const unreadMessages = messages.filter((message) => !message.readAt);
  const highUnreadCount = unreadMessages.filter(
    (message) => message.priority === 'HIGH',
  ).length;
  const messageNeedsAttention = unreadMessages.length > 0;
  const needsAttention = health.needsAttention || messageNeedsAttention;

  const detail =
    highUnreadCount > 0
      ? highUnreadCount + ' pesan penting belum dibaca'
      : unreadMessages.length > 0
        ? unreadMessages.length + ' pesan operasional belum dibaca'
        : health.needsAttention
          ? health.title
          : 'Tidak ada perhatian aktif dari pemeriksaan tersedia';

  return (
    <Link
      className={'dashboard-attention' + (needsAttention ? ' warning' : '')}
      to="/perhatian"
    >
      <span className="dashboard-section-icon">
        <Icon name={needsAttention ? 'warning' : 'notification'} />
      </span>
      <span>
        <strong>Perlu Perhatian</strong>
        <small>{detail}</small>
      </span>
      <span aria-hidden="true">›</span>
    </Link>
  );
}

function QuickAction({
  to,
  icon,
  title,
  detail,
}: {
  to: string;
  icon: SegeranIconName;
  title: string;
  detail: string;
}) {
  return (
    <Link className="dashboard-quick-card" to={to}>
      <span className="dashboard-section-icon">
        <Icon name={icon} />
      </span>
      <span>
        <strong>{title}</strong>
        <small>{detail}</small>
      </span>
    </Link>
  );
}

function OwnerDashboard() {
  const { authority } = useAuth();
  const [data, setData] = useState<OwnerDashboardData | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    setError('');

    void fetchOwnerDashboard()
      .then((result) => {
        if (active) setData(result);
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error ? cause.message : 'DASHBOARD_OWNER_FAILED',
        );
      });

    return () => {
      active = false;
    };
  }, []);

  const maxTrend = useMemo(
    () => Math.max(1, ...(data?.trend.map((point) => point.value) ?? [1])),
    [data],
  );

  if (!authority) return null;

  return (
    <>
      {error && <DashboardError message={error} />}

      {!data ? (
        error ? null : (
          <DashboardSkeleton />
        )
      ) : (
        <>
          <section
            className="dashboard-kpi-grid"
            aria-label="Ringkasan bisnis hari ini"
          >
            <DashboardCard
              label="Penjualan Hari Ini"
              value={formatIdr(data.salesToday)}
              detail="Nilai bersih setelah refund & koreksi"
              icon="sales"
            />
            <DashboardCard
              label="Transaksi"
              value={String(data.transactionsToday)}
              detail="Transaksi penjualan hari ini"
              icon="receipt"
            />
            <DashboardCard
              label="Kas Tersedia"
              value={formatIdr(data.cashAvailable)}
              detail="Kas Utama + Kas Shift"
              icon="cash"
            />
            <DashboardCard
              label="QRIS Belum Cair"
              value={formatIdr(data.qrisPending)}
              detail="Saldo settlement tertunda"
              icon="qris"
            />
          </section>

          <div className="dashboard-owner-grid">
            <section className="dashboard-panel">
              <header className="dashboard-panel-header">
                <div>
                  <p className="eyebrow">PENJUALAN</p>
                  <h2>Tren 7 Hari</h2>
                </div>
                <Link to="/laporan">Lihat laporan</Link>
              </header>

              <div
                className="dashboard-trend-bars"
                aria-label="Tren penjualan tujuh hari"
              >
                {data.trend.map((point) => (
                  <div className="dashboard-trend-column" key={point.date}>
                    <div className="dashboard-trend-track">
                      <span
                        style={{
                          height: `${Math.max(
                            point.value > 0 ? 8 : 2,
                            (point.value / maxTrend) * 100,
                          )}%`,
                        }}
                        title={`${point.date}: ${formatIdr(point.value)}`}
                      />
                    </div>
                    <small>{point.label}</small>
                  </div>
                ))}
              </div>
            </section>

            <section className="dashboard-panel">
              <header className="dashboard-panel-header">
                <div>
                  <p className="eyebrow">HARI INI</p>
                  <h2>Produk Terlaris</h2>
                </div>
                <Link to="/laporan">Detail</Link>
              </header>

              {data.bestSellers.length === 0 ? (
                <p className="dashboard-empty">
                  Belum ada penjualan produk hari ini.
                </p>
              ) : (
                <ol className="dashboard-best-sellers">
                  {data.bestSellers.map((item, index) => (
                    <li key={`${item.product}-${item.variant ?? ''}`}>
                      <span className="dashboard-rank">{index + 1}</span>
                      <span>
                        <strong>{item.product}</strong>
                        {item.variant && <small>{item.variant}</small>}
                      </span>
                      <strong>{item.quantity}</strong>
                    </li>
                  ))}
                </ol>
              )}
            </section>
          </div>
        </>
      )}

      <section className="dashboard-section">
        <header className="dashboard-panel-header">
          <div>
            <p className="eyebrow">AKSI CEPAT</p>
            <h2>Kelola Bisnis</h2>
          </div>
        </header>
        <div className="dashboard-quick-grid">
          {hasPermission(authority, 'SALE_EXECUTE') && (
            <QuickAction
              to="/jual"
              icon="cart"
              title="Jual"
              detail="Mulai transaksi"
            />
          )}
          {hasAnyPermission(authority, ['HISTORY_OWN', 'HISTORY_ALL']) && (
            <QuickAction
              to="/riwayat"
              icon="receipt"
              title="Riwayat"
              detail="Cek transaksi"
            />
          )}
          {hasAnyPermission(authority, [
            'REPORT_SALES_LIMITED',
            'REPORT_INVENTORY',
            'REPORT_PURCHASE',
          ]) && (
            <QuickAction
              to="/laporan"
              icon="reports"
              title="Laporan"
              detail="Pantau performa"
            />
          )}
          <QuickAction
            to="/keuangan"
            icon="cash"
            title="Keuangan"
            detail="Kas, bank & QRIS"
          />
          {hasPermission(authority, 'OPERATIONAL_MESSAGE_MANAGE') && (
            <QuickAction
              to="/pesan-operasional"
              icon="notification"
              title="Pesan Kasir"
              detail="Kirim instruksi kerja"
            />
          )}
        </div>
      </section>

      <AttentionEntry />
    </>
  );
}

function CashierOperationalMessages() {
  const [messages, setMessages] = useState<OperationalMessageInboxItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState('');
  const [error, setError] = useState('');

  const unreadCount = messages.filter((message) => !message.readAt).length;
  const highUnreadCount = messages.filter(
    (message) => !message.readAt && message.priority === 'HIGH',
  ).length;

  useEffect(() => {
    let active = true;
    void fetchMyOperationalMessages(3)
      .then((rows) => {
        if (active) setMessages(rows);
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error
            ? cause.message
            : 'Pesan operasional gagal dimuat.',
        );
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  async function markRead(messageId: string) {
    setBusyId(messageId);
    setError('');
    try {
      await markOperationalMessageRead(messageId);
      setMessages((current) =>
        current.map((message) =>
          message.id === messageId
            ? { ...message, readAt: new Date().toISOString() }
            : message,
        ),
      );
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Pesan belum dapat ditandai dibaca.',
      );
    } finally {
      setBusyId('');
    }
  }

  if (loading) {
    return (
      <section id="pesan-operasional" className="dashboard-owner-message dashboard-message-loading">
        <span className="dashboard-section-icon">
          <Icon name="notification" />
        </span>
        <div>
          <strong>Pesan Operasional</strong>
          <p>Memeriksa instruksi terbaru…</p>
        </div>
      </section>
    );
  }

  if (messages.length === 0) {
    return (
      <section id="pesan-operasional" className="dashboard-owner-message">
        <span className="dashboard-section-icon">
          <Icon name="check" />
        </span>
        <div>
          <strong>Pesan Operasional</strong>
          <p>Belum ada instruksi aktif untuk Anda.</p>
          <small>Pesan baru akan tampil otomatis saat tersedia.</small>
        </div>
      </section>
    );
  }

  return (
    <section id="pesan-operasional" className="dashboard-cashier-messages">
      <header className="dashboard-panel-header">
        <div>
          <p className="eyebrow">DARI PENGELOLA</p>
          <h2>Pesan Operasional</h2>
        </div>
        <span
          className={
            highUnreadCount > 0
              ? 'dashboard-message-status high'
              : 'dashboard-message-status'
          }
        >
          {unreadCount > 0 ? unreadCount + ' belum dibaca' : 'Semua dibaca'}
        </span>
      </header>
      {error && <p className="form-error">{error}</p>}
      <div className="dashboard-message-list">
        {messages.map((message) => (
          <article
            className={[
              'dashboard-owner-message',
              message.priority === 'HIGH' ? 'high' : '',
              !message.readAt ? 'unread' : '',
            ]
              .filter(Boolean)
              .join(' ')}
            key={message.id}
          >
            <span className="dashboard-section-icon">
              <Icon
                name={message.priority === 'HIGH' ? 'warning' : 'notification'}
              />
            </span>
            <div>
              <strong>{message.title}</strong>
              <p>{message.body}</p>
              <small>
                {message.authorName} · dibuat {formatDateTime(message.createdAt)}
                {' · '}sampai {formatDateTime(message.validUntil)}
              </small>
            </div>
            <button
              className={
                message.readAt
                  ? 'message-read-button read'
                  : 'message-read-button'
              }
              type="button"
              disabled={Boolean(message.readAt) || busyId === message.id}
              onClick={() => void markRead(message.id)}
            >
              <Icon name={message.readAt ? 'check' : 'receipt'} size={16} />
              <span>
                {message.readAt
                  ? 'Sudah dibaca'
                  : busyId === message.id
                    ? 'Menyimpan…'
                    : 'Sudah Dibaca'}
              </span>
            </button>
          </article>
        ))}
      </div>
    </section>
  );
}

function CashierDashboard() {
  const { authority } = useAuth();
  const [data, setData] = useState<CashierDashboardData | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    setError('');

    void fetchCashierDashboard()
      .then((result) => {
        if (active) setData(result);
      })
      .catch((cause: unknown) => {
        if (!active) return;
        setError(
          cause instanceof Error ? cause.message : 'DASHBOARD_CASHIER_FAILED',
        );
      });

    return () => {
      active = false;
    };
  }, []);

  if (!authority) return null;

  return (
    <>
      {error && <DashboardError message={error} />}

      {!data ? (
        error ? null : (
          <DashboardSkeleton />
        )
      ) : data.shift ? (
        <>
          <section className="dashboard-shift-card active">
            <div className="dashboard-shift-copy">
              <span className="dashboard-status-pill">Shift Aktif</span>
              <h2>Gerai siap melayani</h2>
              <p>
                Dibuka {formatDateTime(data.shift.opened_at)} · Shift{' '}
                {data.shift.id.slice(0, 8)}
              </p>
            </div>
            {hasPermission(authority, 'SALE_EXECUTE') && (
              <Link className="dashboard-sale-cta" to="/jual">
                <Icon name="cart" />
                <span>Jual Sekarang</span>
              </Link>
            )}
          </section>

          <section
            className="dashboard-kpi-grid dashboard-kpi-grid-cashier"
            aria-label="Ringkasan shift aktif"
          >
            <DashboardCard
              label="Saldo Awal"
              value={formatIdr(data.openingCash)}
              icon="cash"
            />
            <DashboardCard
              label="Penjualan Shift"
              value={formatIdr(data.salesTotal)}
              icon="sales"
            />
            <DashboardCard
              label="Kas Diharapkan"
              value={formatIdr(data.expectedCash)}
              detail={
                data.refundTotal > 0
                  ? `Refund ${formatIdr(data.refundTotal)}`
                  : 'Berdasarkan fakta shift'
              }
              icon="cash-payment"
            />
          </section>
        </>
      ) : (
        <section className="dashboard-shift-card">
          <div className="dashboard-shift-copy">
            <span className="dashboard-status-pill neutral">
              Shift Belum Aktif
            </span>
            <h2>Buka shift sebelum mulai berjualan</h2>
            <p>
              Transaksi kasir tetap dibatasi oleh authority shift yang sudah
              ada.
            </p>
          </div>
          {hasPermission(authority, 'SHIFT_OPEN_CLOSE') && (
            <Link className="dashboard-sale-cta" to="/shift">
              <Icon name="activity" />
              <span>Buka Shift</span>
            </Link>
          )}
        </section>
      )}

      <section className="dashboard-section">
        <header className="dashboard-panel-header">
          <div>
            <p className="eyebrow">AKSI CEPAT</p>
            <h2>Aksi Cepat</h2>
          </div>
        </header>
        <div className="dashboard-quick-grid">
          {hasPermission(authority, 'SALE_EXECUTE') && (
            <QuickAction
              to="/jual"
              icon="cart"
              title="Jual"
              detail="Transaksi baru"
            />
          )}
          {hasAnyPermission(authority, ['HISTORY_OWN', 'HISTORY_ALL']) && (
            <QuickAction
              to="/riwayat"
              icon="receipt"
              title="Riwayat"
              detail="Transaksi saya"
            />
          )}
          {hasPermission(authority, 'SHIFT_OPEN_CLOSE') && (
            <QuickAction
              to="/shift"
              icon="calendar"
              title="Shift Saya"
              detail="Kelola shift"
            />
          )}
          {hasPermission(authority, 'SHIFT_OPEN_CLOSE') && (
            <QuickAction
              to="/handover"
              icon="security-sync"
              title="Serah Terima"
              detail="Alihkan shift"
            />
          )}
        </div>
      </section>

      <CashierOperationalMessages />

      <AttentionEntry />
    </>
  );
}

export function HomeScreen() {
  const { authority } = useAuth();
  const location = useLocation();

  useEffect(() => {
    if (location.hash !== '#pesan-operasional') return;
    const frame = window.requestAnimationFrame(() => {
      document.getElementById('pesan-operasional')?.scrollIntoView({
        block: 'start',
        behavior: 'smooth',
      });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [location.hash]);

  if (!authority) return null;

  const owner = canAccessOwnerArea(authority);
  const firstName = authority.display_name.trim().split(/\s+/)[0] || 'Pengguna';

  return (
    <main
      className={`shell dashboard-shell ${
        owner ? 'dashboard-owner' : 'dashboard-cashier'
      }`}
    >
      <header className="dashboard-hero">
        <div className="dashboard-hero-copy">
          <p className="eyebrow">SEGERAN JIWA POS NEXT</p>
          <h1>Selamat datang, {firstName}</h1>
          <p>
            {owner
              ? 'Ringkasan bisnis dan tindakan penting hari ini.'
              : 'Ringkasan shift dan akses kerja yang Anda perlukan.'}
          </p>
        </div>
        <div className="dashboard-hero-brand" aria-hidden="true">
          <img src="/brand/segeran-jiwa-logo.png" alt="" />
        </div>
        <span className="role-badge">{authority.role_code}</span>
      </header>

      {owner ? <OwnerDashboard /> : <CashierDashboard />}
    </main>
  );
}
