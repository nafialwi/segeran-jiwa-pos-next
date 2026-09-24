import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { OperationalState } from '../components/OperationalState';
import { hasPermission } from '../auth/permission';
import {
  runReport,
  type ReportCode,
  type ReportEnvelope,
  type ReportFormat,
  type ReportSection,
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

type ReportPeriodPreset = 'TODAY' | 'LAST_7_DAYS' | 'MONTH' | 'CUSTOM';

const PERIOD_PRESETS: Array<{
  id: ReportPeriodPreset;
  label: string;
}> = [
  { id: 'TODAY', label: 'Hari ini' },
  { id: 'LAST_7_DAYS', label: '7 hari' },
  { id: 'MONTH', label: 'Bulan ini' },
  { id: 'CUSTOM', label: 'Custom' },
];

function presetRange(preset: Exclude<ReportPeriodPreset, 'CUSTOM'>) {
  const to = new Date();
  let from = new Date(to);

  if (preset === 'LAST_7_DAYS') {
    from.setDate(to.getDate() - 6);
  } else if (preset === 'MONTH') {
    from = new Date(to.getFullYear(), to.getMonth(), 1);
  }

  return { dateFrom: isoDate(from), dateTo: isoDate(to) };
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
  if (format === 'date') {
    const raw = String(value);
    const date = /^\d{4}-\d{2}-\d{2}$/.test(raw)
      ? new Date(`${raw}T00:00:00`)
      : new Date(raw);
    return Number.isNaN(date.getTime())
      ? raw
      : new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium' }).format(date);
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

function normalizedLabel(label: string) {
  return label.trim().toLocaleLowerCase('id-ID');
}

function findColumn(section: ReportSection, labels: string[]) {
  const wanted = new Set(labels.map(normalizedLabel));
  return section.columns.find((column) =>
    wanted.has(normalizedLabel(column.label)),
  );
}

function rowSearchText(section: ReportSection, row: Record<string, unknown>) {
  return section.columns
    .map((column) => String(row[column.key] ?? ''))
    .join(' ')
    .toLocaleLowerCase('id-ID');
}

type ReportSortMode = 'DEFAULT' | 'QTY_DESC' | 'VALUE_DESC';

function displayFilterColumn(reportCode: ReportCode, section: ReportSection) {
  if (reportCode === 'PRODUCT') return findColumn(section, ['Kategori']);
  if (reportCode === 'SALES') return findColumn(section, ['Metode']);
  return undefined;
}

function displaySortColumn(
  reportCode: ReportCode,
  section: ReportSection,
  sort: ReportSortMode,
) {
  if (sort === 'QTY_DESC' && reportCode === 'PRODUCT') {
    return findColumn(section, ['Qty Bersih', 'Qty Terjual']);
  }
  if (sort === 'VALUE_DESC') {
    return reportCode === 'PRODUCT'
      ? findColumn(section, ['Nilai Bersih Item', 'Nilai Bersih'])
      : findColumn(section, ['Nominal', 'Penjualan Bersih', 'Nilai']);
  }
  return undefined;
}

const REPORT_PAGE_SIZE = 20;

type CompactRowPresentation = {
  title: string;
  supporting: string[];
  metric: string;
  status?: string;
  statusTone?: 'neutral' | 'attention';
};

const COMPACT_ENUM_LABELS: Record<string, string> = {
  SALE: 'Penjualan',
  SALES: 'Penjualan',
  PENJUALAN: 'Penjualan',
  INCOME: 'Kas Masuk',
  CASH_IN: 'Kas Masuk',
  EXPENSE: 'Pengeluaran',
  CASH_OUT: 'Kas Keluar',
  REFUND: 'Refund',
  CORRECTION: 'Koreksi',
  ADJUSTMENT: 'Penyesuaian',
  CUSTOMER_PAYMENT: 'Pembayaran Pelanggan',
  CUSTOMER_DEBT_PAYMENT: 'Pelunasan Hutang Pelanggan',
  SUPPLIER_PAYMENT: 'Pembayaran Pemasok',
  OWNER_CAPITAL: 'Modal Pemilik',
  OWNER_WITHDRAWAL: 'Penarikan Pemilik',
  CASH: 'Tunai',
  TRANSFER: 'Transfer',
  CREDIT: 'Kredit',
  QRIS: 'QRIS',
  OPEN: 'Open',
  CLOSED: 'Tutup',
  COMPLETED: 'Selesai',
  POSTED: 'Tercatat',
  RECEIVED: 'Diterima',
  PAID: 'Lunas',
};

function compactEnum(value: unknown) {
  const raw = String(value ?? '').trim();
  if (!raw) return '';
  const upper = raw.toUpperCase();
  if (COMPACT_ENUM_LABELS[upper]) return COMPACT_ENUM_LABELS[upper];
  return raw
    .replace(/[_-]+/g, ' ')
    .toLocaleLowerCase('id-ID')
    .replace(/\b\w/g, (letter) => letter.toLocaleUpperCase('id-ID'));
}

function columnByKey(section: ReportSection, key: string) {
  return section.columns.find((column) => column.key === key);
}

function formattedKey(
  section: ReportSection,
  row: Record<string, unknown>,
  key: string,
) {
  const column = columnByKey(section, key);
  if (!column) return '';
  const value = row[key];
  if (value === null || value === undefined || value === '') return '';
  return formatValue(value, column.type);
}

function rawKey(row: Record<string, unknown>, key: string) {
  const value = row[key];
  return value === null || value === undefined ? '' : String(value).trim();
}

function firstNonEmpty(...values: Array<string | undefined>) {
  return values.find((value) => value?.trim())?.trim() ?? '';
}

function moneyKey(
  section: ReportSection,
  row: Record<string, unknown>,
  ...keys: string[]
) {
  for (const key of keys) {
    const value = formattedKey(section, row, key);
    if (value) return value;
  }
  return '';
}

function statusPresentation(
  section: ReportSection,
  row: Record<string, unknown>,
  options: { always?: boolean; normal?: string[] } = {},
) {
  if (!columnByKey(section, 'status')) return {};
  const raw = rawKey(row, 'status');
  if (!raw) return {};
  const upper = raw.toUpperCase();
  const normal = new Set(
    (
      options.normal ?? ['COMPLETED', 'CLOSED', 'POSTED', 'PAID', 'RECEIVED']
    ).map((value) => value.toUpperCase()),
  );
  if (!options.always && normal.has(upper)) return {};
  return {
    status: compactEnum(raw),
    statusTone: normal.has(upper)
      ? ('neutral' as const)
      : ('attention' as const),
  };
}

function reportSectionTitle(reportCode: ReportCode, section: ReportSection) {
  if (reportCode === 'FINANCE' && section.key === 'customer_debts') {
    return 'Piutang Pelanggan';
  }
  return section.title;
}

function reportSectionEmptyMessage(
  reportCode: ReportCode,
  section: ReportSection,
) {
  const identity = `${reportCode}:${section.key}`;
  const messages: Record<string, string> = {
    'FINANCE:expenses': 'Tidak ada pengeluaran usaha pada periode ini.',
    'FINANCE:customer_debts': 'Tidak ada piutang pelanggan yang masih terbuka.',
    'FINANCE:supplier_payables': 'Tidak ada utang pemasok yang masih terbuka.',
    'FINANCE:kasbon': 'Tidak ada kasbon karyawan yang masih terbuka.',
    'PURCHASE:payables': 'Tidak ada utang pemasok dari periode ini.',
    'INVENTORY:movements': 'Tidak ada pergerakan persediaan pada periode ini.',
    'SALES:transactions': 'Tidak ada transaksi pada periode ini.',
    'SALES:products': 'Tidak ada produk terjual pada periode ini.',
    'PRODUCT:products': 'Tidak ada kinerja produk pada periode ini.',
  };
  return messages[identity] ?? 'Belum ada data untuk bagian ini.';
}

function semanticCompactRow(
  reportCode: ReportCode,
  section: ReportSection,
  row: Record<string, unknown>,
): CompactRowPresentation {
  const identity = `${reportCode}:${section.key}`;

  if (identity === 'SALES:transactions') {
    const kind = compactEnum(rawKey(row, 'jenis')) || 'Transaksi';
    const method = compactEnum(rawKey(row, 'metode'));
    const reference = rawKey(row, 'nomor_transaksi');
    const date = formattedKey(section, row, 'tanggal');
    const user = rawKey(row, 'pengguna');
    return {
      title: [kind, method].filter(Boolean).join(' · '),
      supporting: [reference, [date, user].filter(Boolean).join(' · ')].filter(
        Boolean,
      ),
      metric: moneyKey(section, row, 'nominal'),
      ...statusPresentation(section, row, { normal: ['COMPLETED'] }),
    };
  }

  if (section.key === 'products') {
    const product = firstNonEmpty(rawKey(row, 'produk'), 'Produk');
    const variant = rawKey(row, 'varian');
    const category = rawKey(row, 'kategori');
    const cleanQty = formattedKey(section, row, 'qty_bersih');
    const soldQty = formattedKey(section, row, 'qty_terjual');
    return {
      title: product,
      supporting: [
        firstNonEmpty(variant, category),
        cleanQty ? `Bersih ${cleanQty}` : soldQty ? `Terjual ${soldQty}` : '',
      ].filter(Boolean),
      metric: moneyKey(
        section,
        row,
        'nilai_bersih_item',
        'nilai_bruto_item',
        'harga_jual',
      ),
    };
  }

  if (identity === 'SALES:payments') {
    const method = compactEnum(rawKey(row, 'metode')) || 'Pembayaran';
    const refund = moneyKey(section, row, 'pengembalian_dana');
    const cancelled = moneyKey(section, row, 'piutang_dibatalkan');
    return {
      title: method,
      supporting: [
        refund && rawKey(row, 'pengembalian_dana') !== '0'
          ? `Pengembalian ${refund}`
          : '',
        cancelled && rawKey(row, 'piutang_dibatalkan') !== '0'
          ? `Piutang dibatalkan ${cancelled}`
          : '',
      ].filter(Boolean),
      metric: moneyKey(section, row, 'penerimaan_penjualan'),
    };
  }

  if (identity === 'INVENTORY:balances') {
    const quantity = formattedKey(section, row, 'quantity');
    const unit = rawKey(row, 'satuan');
    return {
      title: firstNonEmpty(rawKey(row, 'produk'), 'Barang'),
      supporting: [
        rawKey(row, 'lokasi'),
        [compactEnum(rawKey(row, 'jenis')), unit].filter(Boolean).join(' · '),
      ].filter(Boolean),
      metric: [quantity, unit].filter(Boolean).join(' '),
    };
  }

  if (identity === 'INVENTORY:movements') {
    const changeRaw = Number(row.perubahan ?? 0);
    const change = formattedKey(section, row, 'perubahan');
    return {
      title: firstNonEmpty(rawKey(row, 'produk'), 'Pergerakan Stok'),
      supporting: [
        [formattedKey(section, row, 'tanggal'), rawKey(row, 'lokasi')]
          .filter(Boolean)
          .join(' · '),
        [compactEnum(rawKey(row, 'jenis')), compactEnum(rawKey(row, 'alasan'))]
          .filter(Boolean)
          .join(' · '),
      ].filter(Boolean),
      metric: change
        ? `${Number.isFinite(changeRaw) && changeRaw > 0 ? '+' : ''}${change}`
        : '',
    };
  }

  if (identity === 'SHIFT:shifts') {
    return {
      title: firstNonEmpty(rawKey(row, 'kasir'), 'Shift'),
      supporting: [
        [formattedKey(section, row, 'opened_at'), rawKey(row, 'lokasi')]
          .filter(Boolean)
          .join(' · '),
      ].filter(Boolean),
      metric: moneyKey(section, row, 'expected_cash', 'sale_total'),
      ...statusPresentation(section, row, { normal: ['CLOSED'] }),
    };
  }

  if (identity === 'PURCHASE:orders') {
    return {
      title: firstNonEmpty(rawKey(row, 'pemasok'), 'Pesanan Pembelian'),
      supporting: [
        rawKey(row, 'order_number'),
        [formattedKey(section, row, 'ordered_at'), rawKey(row, 'lokasi')]
          .filter(Boolean)
          .join(' · '),
      ].filter(Boolean),
      metric: moneyKey(section, row, 'total'),
      ...statusPresentation(section, row, {
        normal: ['COMPLETED', 'CLOSED', 'RECEIVED'],
      }),
    };
  }

  if (identity === 'PURCHASE:receipts') {
    const baseQty = formattedKey(section, row, 'jumlah_dasar');
    return {
      title: firstNonEmpty(rawKey(row, 'pemasok'), 'Barang Diterima'),
      supporting: [
        rawKey(row, 'receipt_number'),
        [formattedKey(section, row, 'received_at'), rawKey(row, 'lokasi')]
          .filter(Boolean)
          .join(' · '),
      ].filter(Boolean),
      metric: baseQty ? `${baseQty} unit dasar` : '',
      ...statusPresentation(section, row, {
        normal: ['POSTED', 'RECEIVED', 'COMPLETED'],
      }),
    };
  }

  if (
    identity === 'PURCHASE:payables' ||
    identity === 'FINANCE:supplier_payables'
  ) {
    return {
      title: firstNonEmpty(rawKey(row, 'pemasok'), 'Pemasok'),
      supporting: [
        rawKey(row, 'referensi'),
        formattedKey(section, row, 'paid_amount')
          ? `Dibayar ${formattedKey(section, row, 'paid_amount')}`
          : '',
      ].filter(Boolean),
      metric: moneyKey(section, row, 'balance', 'original_amount'),
      ...statusPresentation(section, row, { always: true }),
    };
  }

  if (identity === 'FINANCE:accounts') {
    return {
      title: firstNonEmpty(rawKey(row, 'akun'), 'Akun'),
      supporting: [
        rawKey(row, 'code'),
        compactEnum(rawKey(row, 'jenis')),
      ].filter(Boolean),
      metric: moneyKey(section, row, 'saldo'),
    };
  }

  if (identity === 'FINANCE:money') {
    const source = compactEnum(rawKey(row, 'sumber'));
    const reason = compactEnum(rawKey(row, 'alasan'));
    const kind = compactEnum(rawKey(row, 'jenis'));
    const from = rawKey(row, 'dari_akun');
    const to = rawKey(row, 'ke_akun');
    const flow =
      from && to
        ? `${from} → ${to}`
        : to
          ? `Masuk ke ${to}`
          : from
            ? `Dari ${from}`
            : '';
    return {
      title: firstNonEmpty(source, reason, kind, 'Arus Uang'),
      supporting: [
        firstNonEmpty(rawKey(row, 'referensi'), flow),
        [formattedKey(section, row, 'created_at'), kind]
          .filter(Boolean)
          .join(' · '),
      ].filter(Boolean),
      metric: moneyKey(section, row, 'amount'),
    };
  }

  if (identity === 'FINANCE:expenses') {
    return {
      title: firstNonEmpty(
        rawKey(row, 'description'),
        compactEnum(rawKey(row, 'kategori')),
        'Pengeluaran Usaha',
      ),
      supporting: [
        [
          compactEnum(rawKey(row, 'kategori')),
          formattedKey(section, row, 'created_at'),
        ]
          .filter(Boolean)
          .join(' · '),
        rawKey(row, 'sumber_dana') ? `Dari ${rawKey(row, 'sumber_dana')}` : '',
      ].filter(Boolean),
      metric: moneyKey(section, row, 'amount'),
    };
  }

  if (identity === 'FINANCE:customer_debts') {
    return {
      title: firstNonEmpty(rawKey(row, 'pelanggan'), 'Pelanggan belum diisi'),
      supporting: [
        formattedKey(section, row, 'paid_amount')
          ? `Dibayar ${formattedKey(section, row, 'paid_amount')}`
          : '',
        formattedKey(section, row, 'original_amount')
          ? `Nilai awal ${formattedKey(section, row, 'original_amount')}`
          : '',
      ].filter(Boolean),
      metric: moneyKey(section, row, 'balance', 'original_amount'),
      ...statusPresentation(section, row, { always: true }),
    };
  }

  if (identity === 'FINANCE:kasbon') {
    return {
      title: firstNonEmpty(rawKey(row, 'karyawan'), 'Karyawan'),
      supporting: [
        rawKey(row, 'note'),
        formattedKey(section, row, 'paid_amount')
          ? `Dibayar ${formattedKey(section, row, 'paid_amount')}`
          : '',
      ].filter(Boolean),
      metric: moneyKey(section, row, 'balance', 'original_amount'),
      ...statusPresentation(section, row, { always: true }),
    };
  }

  const textColumns = section.columns.filter(
    (column) =>
      column.type === 'text' &&
      !['kode', 'code', 'status'].includes(
        column.key.toLocaleLowerCase('id-ID'),
      ),
  );
  const titleColumn = textColumns[0] ?? section.columns[0];
  const metricColumn =
    [...section.columns].reverse().find((column) => column.type === 'money') ??
    [...section.columns].reverse().find((column) => column.type === 'number');
  const supportColumns = section.columns
    .filter(
      (column) =>
        column.key !== titleColumn?.key &&
        column.key !== metricColumn?.key &&
        !normalizedLabel(column.label).includes('kode') &&
        normalizedLabel(column.label) !== 'status',
    )
    .slice(0, 2);

  return {
    title: firstNonEmpty(
      titleColumn
        ? formatValue(row[titleColumn.key], titleColumn.type)
        : undefined,
      section.title,
    ),
    supporting: supportColumns
      .map((column) => {
        const value = formatValue(row[column.key], column.type);
        return value === '—' ? '' : `${column.label}: ${value}`;
      })
      .filter(Boolean),
    metric: metricColumn
      ? formatValue(row[metricColumn.key], metricColumn.type)
      : '',
    ...statusPresentation(section, row),
  };
}

function ReportCompactRow({
  reportCode,
  section,
  row,
  onOpen,
}: {
  reportCode: ReportCode;
  section: ReportSection;
  row: Record<string, unknown>;
  onOpen: () => void;
}) {
  const presentation = semanticCompactRow(reportCode, section, row);

  return (
    <button
      className="report-compact-row"
      type="button"
      aria-haspopup="dialog"
      onClick={onOpen}
    >
      <span className="report-compact-row-copy">
        <strong>{presentation.title}</strong>
        {presentation.supporting.length > 0 && (
          <small>
            {presentation.supporting.slice(0, 2).map((value, index) => (
              <span key={`${index}-${value}`}>{value}</span>
            ))}
          </small>
        )}
      </span>
      <span className="report-compact-row-trailing">
        {presentation.status && (
          <span
            className={`report-compact-status ${presentation.statusTone ?? 'neutral'}`}
          >
            {presentation.status}
          </span>
        )}
        {presentation.metric && <strong>{presentation.metric}</strong>}
        <span className="report-compact-chevron" aria-hidden="true">
          ›
        </span>
      </span>
    </button>
  );
}

function ReportDetailDialog({
  reportCode,
  section,
  row,
  onClose,
}: {
  reportCode: ReportCode;
  section: ReportSection;
  row: Record<string, unknown>;
  onClose: () => void;
}) {
  const presentation = semanticCompactRow(reportCode, section, row);

  useEffect(() => {
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => {
      document.body.style.overflow = originalOverflow;
      window.removeEventListener('keydown', closeOnEscape);
    };
  }, [onClose]);

  return (
    <div
      className="report-detail-backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (event.currentTarget === event.target) onClose();
      }}
    >
      <section
        className="report-detail-dialog"
        role="dialog"
        aria-modal="true"
        aria-label={`Detail ${reportSectionTitle(reportCode, section)}`}
      >
        <header className="report-detail-header">
          <div>
            <p className="eyebrow">DETAIL LAPORAN</p>
            <h2>{presentation.title}</h2>
            <p className="muted">{reportSectionTitle(reportCode, section)}</p>
          </div>
          <button
            className="icon-button"
            type="button"
            aria-label="Tutup detail laporan"
            onClick={onClose}
          >
            ×
          </button>
        </header>
        <div className="report-detail-grid">
          {section.columns.map((column) => (
            <div className="report-detail-field" key={column.key}>
              <span>{column.label}</span>
              <strong>{formatValue(row[column.key], column.type)}</strong>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function ReportSectionView({
  reportCode,
  section,
  resetKey,
}: {
  reportCode: ReportCode;
  section: ReportSection;
  resetKey: string;
}) {
  const [page, setPage] = useState(0);
  const [selectedRow, setSelectedRow] = useState<Record<
    string,
    unknown
  > | null>(null);

  useEffect(() => {
    setPage(0);
    setSelectedRow(null);
  }, [resetKey]);

  const pageCount = Math.max(
    1,
    Math.ceil(section.rows.length / REPORT_PAGE_SIZE),
  );
  const safePage = Math.min(page, pageCount - 1);
  const pageStart = safePage * REPORT_PAGE_SIZE;
  const pageRows = section.rows.slice(pageStart, pageStart + REPORT_PAGE_SIZE);
  const pageEnd = Math.min(pageStart + pageRows.length, section.rows.length);

  return (
    <section className="identity-card report-section-card">
      <div className="section-heading report-section-heading">
        <div>
          <h2>{reportSectionTitle(reportCode, section)}</h2>
          {section.note && <p className="muted">{section.note}</p>}
        </div>
        {section.rows.length > 0 && (
          <span className="report-row-count">{section.rows.length} data</span>
        )}
      </div>
      {section.rows.length === 0 ? (
        <p className="empty-state report-section-empty">
          {reportSectionEmptyMessage(reportCode, section)}
        </p>
      ) : (
        <>
          <div className="report-mobile-list">
            {pageRows.map((row, index) => (
              <ReportCompactRow
                reportCode={reportCode}
                section={section}
                row={row}
                onOpen={() => setSelectedRow(row)}
                key={`${section.key}-mobile-${pageStart + index}`}
              />
            ))}
          </div>
          <div className="data-table-wrap report-desktop-table-wrap">
            <table className="data-table report-desktop-table">
              <thead>
                <tr>
                  {section.columns.map((column) => (
                    <th key={column.key}>{column.label}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {pageRows.map((row, index) => (
                  <tr
                    className="report-desktop-row"
                    role="button"
                    tabIndex={0}
                    onClick={() => setSelectedRow(row)}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault();
                        setSelectedRow(row);
                      }
                    }}
                    key={`${section.key}-desktop-${pageStart + index}`}
                  >
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
          {section.rows.length > REPORT_PAGE_SIZE && (
            <nav
              className="report-pagination"
              aria-label={`Halaman ${reportSectionTitle(reportCode, section)}`}
            >
              <span>
                {pageStart + 1}–{pageEnd} dari {section.rows.length}
              </span>
              <div>
                <button
                  className="secondary-button"
                  type="button"
                  disabled={safePage === 0}
                  onClick={() => setPage((current) => Math.max(0, current - 1))}
                >
                  Sebelumnya
                </button>
                <button
                  className="secondary-button"
                  type="button"
                  disabled={safePage >= pageCount - 1}
                  onClick={() =>
                    setPage((current) => Math.min(pageCount - 1, current + 1))
                  }
                >
                  Berikutnya
                </button>
              </div>
            </nav>
          )}
        </>
      )}
      {(section.totals ?? []).map((total) => (
        <p className="report-section-total" key={total.label}>
          <strong>{total.label}: </strong>
          {formatValue(total.value, total.format)}
        </p>
      ))}
      {selectedRow && (
        <ReportDetailDialog
          reportCode={reportCode}
          section={section}
          row={selectedRow}
          onClose={() => setSelectedRow(null)}
        />
      )}
    </section>
  );
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

  const today = isoDate(new Date());
  const [code, setCode] = useState<ReportCode>(available[0]?.code ?? 'SALES');
  const [periodPreset, setPeriodPreset] = useState<ReportPeriodPreset>('TODAY');
  const [dateFrom, setDateFrom] = useState(today);
  const [dateTo, setDateTo] = useState(today);
  const [report, setReport] = useState<ReportEnvelope | null>(null);
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState('');
  const [reportQuery, setReportQuery] = useState('');
  const [reportFilter, setReportFilter] = useState('ALL');
  const [reportSort, setReportSort] = useState<ReportSortMode>('DEFAULT');
  const resultRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!report) return;
    window.requestAnimationFrame(() => {
      resultRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' });
    });
  }, [report]);

  const reportFilterOptions = useMemo(() => {
    if (!report) return [];
    const values = new Set<string>();
    report.sections.forEach((section) => {
      const column = displayFilterColumn(report.report_code, section);
      if (!column) return;
      section.rows.forEach((row) => {
        const value = String(row[column.key] ?? '').trim();
        if (value) values.add(value);
      });
    });
    return Array.from(values).sort((a, b) => a.localeCompare(b, 'id-ID'));
  }, [report]);

  const displaySections = useMemo(() => {
    if (!report) return [];
    const query = reportQuery.trim().toLocaleLowerCase('id-ID');

    return report.sections.map((section) => {
      const filterColumn = displayFilterColumn(report.report_code, section);
      const sortColumn = displaySortColumn(
        report.report_code,
        section,
        reportSort,
      );
      const rows = section.rows
        .filter((row) => !query || rowSearchText(section, row).includes(query))
        .filter((row) => {
          if (reportFilter === 'ALL' || !filterColumn) return true;
          return String(row[filterColumn.key] ?? '') === reportFilter;
        });

      if (sortColumn) {
        rows.sort((left, right) => {
          const a = Number(left[sortColumn.key] ?? 0);
          const b = Number(right[sortColumn.key] ?? 0);
          return (Number.isFinite(b) ? b : 0) - (Number.isFinite(a) ? a : 0);
        });
      }

      return { ...section, rows };
    });
  }, [report, reportFilter, reportQuery, reportSort]);

  function resetDisplayControls() {
    setReportQuery('');
    setReportFilter('ALL');
    setReportSort('DEFAULT');
  }

  function applyPeriodPreset(preset: ReportPeriodPreset) {
    setPeriodPreset(preset);
    setReport(null);
    resetDisplayControls();
    setError('');
    if (preset === 'CUSTOM') return;

    const range = presetRange(preset);
    setDateFrom(range.dateFrom);
    setDateTo(range.dateTo);
  }

  async function load(event?: FormEvent) {
    event?.preventDefault();
    setLoading(true);
    setError('');
    resetDisplayControls();
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
        <form className="compact-grid-form report-filter-form" onSubmit={load}>
          <div
            className="report-period-presets"
            role="group"
            aria-label="Periode cepat"
          >
            {PERIOD_PRESETS.map((preset) => (
              <button
                key={preset.id}
                type="button"
                className={
                  periodPreset === preset.id
                    ? 'report-period-chip active'
                    : 'report-period-chip'
                }
                aria-pressed={periodPreset === preset.id}
                onClick={() => applyPeriodPreset(preset.id)}
              >
                {preset.label}
              </button>
            ))}
          </div>
          <label className="field-label">
            Jenis Laporan
            <select
              value={code}
              onChange={(event) => {
                setCode(event.target.value as ReportCode);
                setReport(null);
                resetDisplayControls();
                setError('');
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
              onChange={(event) => {
                setDateFrom(event.target.value);
                setPeriodPreset('CUSTOM');
                setReport(null);
                resetDisplayControls();
                setError('');
              }}
            />
          </label>
          <label className="field-label">
            Sampai
            <input
              type="date"
              value={dateTo}
              onChange={(event) => {
                setDateTo(event.target.value);
                setPeriodPreset('CUSTOM');
                setReport(null);
                resetDisplayControls();
                setError('');
              }}
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

      {loading && !report && (
        <section className="identity-card report-result-shell">
          <OperationalState
            kind="loading"
            message="Memuat laporan"
            skeletonItems={2}
          />
        </section>
      )}

      {!report && !loading && (
        <section className="identity-card report-result-shell">
          <OperationalState
            kind="empty"
            title="Laporan belum ditampilkan"
            message="Pilih jenis laporan dan periode, lalu tekan Tampilkan Laporan."
          />
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
                  {report.business_name} ·{' '}
                  {formatValue(report.period.date_from, 'date')} s.d.{' '}
                  {formatValue(report.period.date_to, 'date')}
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

          <section className="identity-card report-display-tools">
            <label className="report-search-field">
              <span>Cari dalam laporan</span>
              <input
                type="search"
                value={reportQuery}
                placeholder={
                  report.report_code === 'PRODUCT'
                    ? 'Cari produk, kode, atau kategori…'
                    : report.report_code === 'SALES'
                      ? 'Cari transaksi, pengguna, atau metode…'
                      : 'Cari data laporan…'
                }
                onChange={(event) => setReportQuery(event.target.value)}
              />
            </label>

            {reportFilterOptions.length > 0 && (
              <div
                className="report-display-chips"
                role="group"
                aria-label="Filter tampilan"
              >
                <button
                  type="button"
                  className={
                    reportFilter === 'ALL'
                      ? 'report-display-chip active'
                      : 'report-display-chip'
                  }
                  aria-pressed={reportFilter === 'ALL'}
                  onClick={() => setReportFilter('ALL')}
                >
                  Semua
                </button>
                {reportFilterOptions.map((option) => (
                  <button
                    type="button"
                    className={
                      reportFilter === option
                        ? 'report-display-chip active'
                        : 'report-display-chip'
                    }
                    aria-pressed={reportFilter === option}
                    onClick={() => setReportFilter(option)}
                    key={option}
                  >
                    {option}
                  </button>
                ))}
              </div>
            )}

            {(report.report_code === 'PRODUCT' ||
              report.report_code === 'SALES') && (
              <div
                className="report-display-chips"
                role="group"
                aria-label="Urutan tampilan"
              >
                <button
                  type="button"
                  className={
                    reportSort === 'DEFAULT'
                      ? 'report-display-chip active'
                      : 'report-display-chip'
                  }
                  aria-pressed={reportSort === 'DEFAULT'}
                  onClick={() => setReportSort('DEFAULT')}
                >
                  Urutan asli
                </button>
                {report.report_code === 'PRODUCT' && (
                  <button
                    type="button"
                    className={
                      reportSort === 'QTY_DESC'
                        ? 'report-display-chip active'
                        : 'report-display-chip'
                    }
                    aria-pressed={reportSort === 'QTY_DESC'}
                    onClick={() => setReportSort('QTY_DESC')}
                  >
                    Qty terbanyak
                  </button>
                )}
                <button
                  type="button"
                  className={
                    reportSort === 'VALUE_DESC'
                      ? 'report-display-chip active'
                      : 'report-display-chip'
                  }
                  aria-pressed={reportSort === 'VALUE_DESC'}
                  onClick={() => setReportSort('VALUE_DESC')}
                >
                  Nilai terbesar
                </button>
              </div>
            )}

            {(reportQuery ||
              reportFilter !== 'ALL' ||
              reportSort !== 'DEFAULT') && (
              <p className="muted report-display-note">
                Filter dan urutan hanya mengubah tampilan. Ringkasan dan ekspor
                tetap memuat seluruh data laporan.
              </p>
            )}
          </section>

          {displaySections.map((section) => (
            <ReportSectionView
              reportCode={report.report_code}
              section={section}
              resetKey={`${report.report_code}|${reportQuery}|${reportFilter}|${reportSort}`}
              key={section.key}
            />
          ))}
        </>
      )}
    </main>
  );
}
