import { describe, expect, it, vi } from 'vitest';
import type { ReportEnvelope } from '../src/reports/report-api';

const toFile = vi.fn(async () => undefined);
const writeXlsxFile = vi.fn(() => ({ toFile, toBlob: vi.fn() }));

vi.mock('write-excel-file/browser', () => ({
  default: writeXlsxFile,
}));

import { exportReportExcel } from '../src/reports/report-excel';

describe('HRR-P3 Excel exporter', () => {
  it('builds a presentation-ready multi-sheet xlsx', async () => {
    const report: ReportEnvelope = {
      report_code: 'SALES',
      report_title: 'Laporan Penjualan',
      business_name: 'Segeran Jiwa',
      period: { date_from: '2026-09-01', date_to: '2026-09-20' },
      generated_at: '2026-09-20T16:00:00.000Z',
      summary: [{ label: 'Penjualan Bersih', value: 125000, format: 'money' }],
      warnings: [],
      sections: [
        {
          key: 'transactions',
          title: 'Transaksi',
          note: 'Contoh detail',
          columns: [
            { key: 'tanggal', label: 'Tanggal', type: 'date', width: 14 },
            { key: 'nominal', label: 'Nominal', type: 'money', width: 18 },
          ],
          rows: [{ tanggal: '2026-09-20', nominal: 5000 }],
          totals: [{ label: 'Penjualan Bersih', value: 5000, format: 'money' }],
        },
      ],
    };

    await exportReportExcel(report);

    expect(writeXlsxFile).toHaveBeenCalledTimes(1);
    const sheets = writeXlsxFile.mock.calls[0][0] as Array<{
      sheet: string;
      stickyRowsCount: number;
      columns: Array<{ width: number }>;
      data: unknown[][];
    }>;

    expect(sheets).toHaveLength(2);
    expect(sheets[0].sheet).toBe('Ringkasan');
    expect(sheets[0].stickyRowsCount).toBe(6);
    expect(sheets[1].sheet).toBe('Transaksi');
    expect(sheets[1].stickyRowsCount).toBeGreaterThanOrEqual(5);
    expect(sheets[1].columns).toEqual([{ width: 14 }, { width: 18 }]);
    expect(sheets[1].data.length).toBeGreaterThan(6);

    expect(toFile).toHaveBeenCalledWith(
      'Laporan-Penjualan_2026-09-01_2026-09-20.xlsx',
    );
  });
});
