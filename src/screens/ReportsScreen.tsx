import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { hasPermission } from '../auth/permission';
import {
  runReport,
  type ReportCode,
  type ReportEnvelope,
  type ReportFormat,
} from '../reports/report-api';
import { exportReportExcel } from '../reports/report-excel';

const REPORTS: Array<{
  code: ReportCode;
  label: string;
  permission?: 'REPORT_SALES_LIMITED' | 'REPORT_INVENTORY' | 'REPORT_PURCHASE';
  ownerOnly?: boolean;
}> = [
  { code: 'SALES', label: 'Penjualan', permission: 'REPORT_SALES_LIMITED' },
  { code: 'PRODUCT', label: 'Produk', permission: 'REPORT_SALES_LIMITED' },
  { code: 'INVENTORY', label: 'Persediaan', permission: 'REPORT_INVENTORY' },
  { code: 'SHIFT', label: 'Shift', ownerOnly: true },
  { code: 'PURCHASE', label: 'Pembelian', permission: 'REPORT_PURCHASE' },
  { code: 'FINANCE', label: 'Keuangan', ownerOnly: true },
];

function isoDate(date: Date) {
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 10);
}

function defaultFrom() {
  const now = new Date();
  return isoDate(new Date(now.getFullYear(), now.getMonth(), 1));
}

function formatValue(value: unknown, format: ReportFormat) {
  if (value === null || value === undefined || value === '') return '—';
  if (format === 'money') {
    const n = Number(value);
    return Number.isFinite(n)
      ? new Intl.NumberFormat('id-ID', {
          style: 'currency',
          currency: 'IDR',
          maximumFractionDigits: 0,
        }).format(n)
      : String(value);
  }
  if (format === 'number') {
    const n = Number(value);
    return Number.isFinite(n)
      ? new Intl.NumberFormat('id-ID', { maximumFractionDigits: 3 }).format(n)
      : String(value);
  }
  if (format === 'datetime') {
    const date = new Date(String(value));
    return Number.isNaN(date.getTime())
      ? String(value)
      : new Intl.DateTimeFormat('id-ID', {
          dateStyle: 'medium',
          timeStyle: 'short',
        }).format(date);
  }
  return String(value);
}

export function ReportsScreen() {
  const { authority } = useAuth();
  const available = useMemo(
    () =>
      REPORTS.filter((report) => {
        if (!authority) return false;
        if (authority.owner) return true;
        if (report.ownerOnly || !report.permission) return false;
        return hasPermission(authority, report.permission);
      }),
    [authority],
  );

  const [code, setCode] = useState<ReportCode>(available[0]?.code ?? 'SALES');
  const [dateFrom, setDateFrom] = useState(defaultFrom());
  const [dateTo, setDateTo] = useState(isoDate(new Date()));
  const [report, setReport] = useState<ReportEnvelope | null>(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState('');
  const resultRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!report) return;
    window.requestAnimationFrame(() => {
      resultRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' });
    });
  }, [report]);

  async function load(event?: FormEvent) {
    event?.preventDefault();
    setLoading(true);
    setError('');
    try {
      setReport(await runReport(code, dateFrom, dateTo));
    } catch (cause) {
      setReport(null);
      setError(
        cause instanceof Error ? cause.message : 'Gagal memuat laporan.',
      );
    } finally {
      setLoading(false);
    }
  }

  async function exportExcel() {
    if (!report) return;
    setExporting(true);
    setError('');
    try {
      await exportReportExcel(report);
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Gagal membuat file Excel.',
      );
    } finally {
      setExporting(false);
    }
  }

  if (!authority) return null;

  return (
    <main className="shell secondary-screen reports-workspace">
      <header className="topbar secondary-hero">
        <div>
          <Link to="/">Beranda</Link>
          <p className="eyebrow">READ MODEL</p>
          <h1>Laporan</h1>
          <p className="muted">
            Laporan membaca fakta yang sama dengan operasional. Tidak ada ledger
            laporan terpisah.
          </p>
        </div>
      </header>

      {error && (
        <div className="error-banner" role="alert">
          {error}
        </div>
      )}

      <section className="identity-card secondary-filter-panel">
        <form className="compact-grid-form" onSubmit={load}>
          <label className="field-label">
            Jenis Laporan
            <select
              value={code}
              onChange={(event) => {
                setCode(event.target.value as ReportCode);
                setReport(null);
              }}
            >
              {available.map((item) => (
                <option value={item.code} key={item.code}>
                  {item.label}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Dari
            <input
              type="date"
              value={dateFrom}
              onChange={(event) => setDateFrom(event.target.value)}
            />
          </label>
          <label className="field-label">
            Sampai
            <input
              type="date"
              value={dateTo}
              onChange={(event) => setDateTo(event.target.value)}
            />
          </label>
          <div className="button-row">
            <button className="primary-button" type="submit" disabled={loading}>
              {loading ? 'Memuat...' : 'Tampilkan Laporan'}
            </button>
            <button
              className="secondary-button"
              type="button"
              disabled={!report || exporting}
              onClick={() => void exportExcel()}
            >
              {exporting ? 'Membuat Excel...' : 'Ekspor Excel'}
            </button>
          </div>
        </form>
      </section>

      {!report && !loading && (
        <section className="identity-card report-result-shell">
          <p className="empty-state">
            Pilih laporan dan periode, lalu tekan Tampilkan Laporan.
          </p>
        </section>
      )}

      {report && (
        <>
          <section
            className="identity-card report-result-shell"
            ref={resultRef}
            tabIndex={-1}
            aria-live="polite"
          >
            <div className="section-heading">
              <div>
                <h2>{report.report_title}</h2>
                <p className="muted">
                  {report.business_name} · {report.period.date_from} s.d.{' '}
                  {report.period.date_to}
                </p>
              </div>
            </div>
            <div className="report-summary-grid">
              {report.summary.map((item) => (
                <article className="report-summary-card" key={item.label}>
                  <span className="muted">{item.label}</span>
                  <strong>{formatValue(item.value, item.format)}</strong>
                </article>
              ))}
            </div>
            {report.warnings.map((warning) => (
              <div className="report-warning" key={warning}>
                {warning}
              </div>
            ))}
          </section>

          {report.sections.map((section) => (
            <section className="identity-card" key={section.key}>
              <div className="section-heading">
                <div>
                  <h2>{section.title}</h2>
                  {section.note && <p className="muted">{section.note}</p>}
                </div>
              </div>
              {section.rows.length === 0 ? (
                <p className="empty-state">Tidak ada data pada bagian ini.</p>
              ) : (
                <div className="data-table-wrap">
                  <table className="data-table">
                    <thead>
                      <tr>
                        {section.columns.map((column) => (
                          <th key={column.key}>{column.label}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {section.rows.map((row, index) => (
                        <tr key={section.key + '-' + index}>
                          {section.columns.map((column) => (
                            <td key={column.key}>
                              {formatValue(row[column.key], column.type)}
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              {(section.totals ?? []).map((total) => (
                <p key={total.label}>
                  <strong>{total.label}: </strong>
                  {formatValue(total.value, total.format)}
                </p>
              ))}
            </section>
          ))}
        </>
      )}
    </main>
  );
}
