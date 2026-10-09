import type {
  ReportCode,
  ReportEnvelope,
  ReportSection,
} from '../../../src/reports/report-api';

export async function runReport(
  code: ReportCode,
  dateFrom: string,
  dateTo: string,
): Promise<ReportEnvelope> {
  const columns: ReportSection['columns'] = [
    { key: 'invoice_number', label: 'Nomor Transaksi', type: 'text' },
    { key: 'business_date', label: 'Tanggal', type: 'date' },
    { key: 'payment_method', label: 'Metode', type: 'text' },
    { key: 'amount', label: 'Nominal', type: 'money' },
  ];
  const rows = Array.from({ length: 31 }, (_, i) => ({
    invoice_number: `CONTOH-${String(i + 1).padStart(4, '0')}`,
    business_date: '2026-10-09',
    payment_method: i % 3 === 0 ? 'QRIS' : 'CASH',
    amount: (i + 1) * 1500,
  }));
  return {
    report_code: code,
    report_title: 'Laporan Penjualan Contoh',
    business_name: 'Segeran Jiwa — Data Contoh',
    period: { date_from: dateFrom, date_to: dateTo },
    generated_at: '2026-10-09T14:00:00+07:00',
    warnings: [],
    summary: [
      { label: 'Omzet', value: 250000, format: 'money' },
      { label: 'Transaksi', value: 31, format: 'number' },
      { label: 'Rata-rata', value: 8064, format: 'money' },
    ],
    sections: [
      {
        key: 'sales',
        title: 'Daftar Penjualan',
        columns,
        rows,
        totals: [{ label: 'Jumlah', value: 250000, format: 'money' }],
      },
      {
        key: 'payment',
        title: 'Metode Pembayaran',
        columns: [
          { key: 'method', label: 'Metode', type: 'text' },
          { key: 'amount', label: 'Nominal', type: 'money' },
        ],
        rows: [
          { method: 'Tunai', amount: 180000 },
          { method: 'QRIS', amount: 70000 },
        ],
      },
    ],
  };
}
