import type { CellObject, SheetData } from 'write-excel-file/browser';
import type {
  ReportColumn,
  ReportEnvelope,
  ReportFormat,
  ReportSection,
} from './report-api';

function display(value: unknown, format: ReportFormat): string | number {
  if (value === null || value === undefined || value === '') return '—';
  if (format === 'money' || format === 'number') {
    const n = Number(value);
    return Number.isFinite(n) ? n : String(value);
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

function cell(
  value: unknown,
  format: ReportFormat,
  extra: Partial<CellObject> = {},
): CellObject {
  const shown = display(value, format);
  if (typeof shown === 'number') {
    return {
      value: shown,
      type: Number,
      format: format === 'money' ? '#,##0' : '#,##0.###',
      ...extra,
    };
  }
  return { value: shown, type: String, ...extra };
}

function sectionSheet(report: ReportEnvelope, section: ReportSection) {
  const columnCount = Math.max(section.columns.length, 1);
  const metadata: SheetData = [
    [
      {
        value: report.business_name,
        type: String,
        fontWeight: 'bold' as const,
        fontSize: 14,
        columnSpan: columnCount,
      },
    ],
    [
      {
        value: report.report_title + ' — ' + section.title,
        type: String,
        fontWeight: 'bold' as const,
        fontSize: 12,
        columnSpan: columnCount,
      },
    ],
    [
      {
        value:
          'Periode: ' +
          report.period.date_from +
          ' s.d. ' +
          report.period.date_to,
        type: String,
        columnSpan: columnCount,
      },
    ],
    [
      {
        value:
          'Diekspor: ' +
          new Intl.DateTimeFormat('id-ID', {
            dateStyle: 'medium',
            timeStyle: 'short',
          }).format(new Date(report.generated_at)),
        type: String,
        columnSpan: columnCount,
      },
    ],
    section.note
      ? [{ value: section.note, type: String, columnSpan: columnCount }]
      : [],
  ].filter((row) => row.length > 0);

  const header: SheetData[number] = section.columns.map((column) => ({
    value: column.label,
    type: String,
    fontWeight: 'bold' as const,
    backgroundColor: '#E8EFE9',
    borderStyle: 'thin' as const,
    wrap: true,
  }));

  const rows: SheetData = section.rows.map((row) =>
    section.columns.map((column) =>
      cell(row[column.key], column.type, {
        borderStyle: 'thin',
        wrap: column.type === 'text',
      }),
    ),
  );

  const totalRows: SheetData = (section.totals ?? []).map((total) => [
    {
      value: total.label,
      type: String,
      fontWeight: 'bold' as const,
      columnSpan: Math.max(columnCount - 1, 1),
    },
    cell(total.value, total.format, { fontWeight: 'bold' as const }),
  ]);

  return {
    sheet: section.title.slice(0, 31),
    data: [...metadata, header, ...rows, ...totalRows],
    stickyRowsCount: metadata.length + 1,
    columns: section.columns.map((column: ReportColumn) => ({
      width: column.width ?? 18,
    })),
    showGridLines: false,
  };
}

function summarySheet(report: ReportEnvelope) {
  const rows: SheetData = [
    [
      {
        value: report.business_name,
        type: String,
        fontWeight: 'bold' as const,
        fontSize: 15,
        columnSpan: 2,
      },
    ],
    [
      {
        value: report.report_title,
        type: String,
        fontWeight: 'bold' as const,
        fontSize: 13,
        columnSpan: 2,
      },
    ],
    [
      {
        value:
          'Periode: ' +
          report.period.date_from +
          ' s.d. ' +
          report.period.date_to,
        type: String,
        columnSpan: 2,
      },
    ],
    [
      {
        value:
          'Timestamp ekspor: ' +
          new Intl.DateTimeFormat('id-ID', {
            dateStyle: 'medium',
            timeStyle: 'short',
          }).format(new Date(report.generated_at)),
        type: String,
        columnSpan: 2,
      },
    ],
    [],
    [
      { value: 'Ringkasan', type: String, fontWeight: 'bold' as const },
      { value: 'Nilai', type: String, fontWeight: 'bold' as const },
    ],
    ...report.summary.map((item) => [
      { value: item.label, type: String },
      cell(item.value, item.format),
    ]),
  ];

  if (report.warnings.length) {
    rows.push([]);
    rows.push([
      {
        value: 'Perlu diperhatikan',
        type: String,
        fontWeight: 'bold' as const,
      },
      { value: '', type: String },
    ]);
    for (const warning of report.warnings) {
      rows.push([
        { value: warning, type: String, columnSpan: 2, wrap: true },
        { value: '', type: String },
      ]);
    }
  }

  return {
    sheet: 'Ringkasan',
    data: rows,
    stickyRowsCount: 6,
    columns: [{ width: 34 }, { width: 28 }],
    showGridLines: false,
  };
}

export async function exportReportExcel(report: ReportEnvelope) {
  const { default: writeXlsxFile } = await import('write-excel-file/browser');
  const sheets = [
    summarySheet(report),
    ...report.sections.map((section) => sectionSheet(report, section)),
  ];

  const safeTitle = report.report_title
    .replace(/[^a-z0-9]+/gi, '-')
    .replace(/^-|-$/g, '');
  const fileName =
    safeTitle +
    '_' +
    report.period.date_from +
    '_' +
    report.period.date_to +
    '.xlsx';

  await writeXlsxFile(sheets).toFile(fileName);
}
