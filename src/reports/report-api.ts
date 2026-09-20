import { supabase } from '../lib/supabase';

export type ReportCode =
  'SALES' | 'PRODUCT' | 'INVENTORY' | 'SHIFT' | 'PURCHASE' | 'FINANCE';

export type ReportFormat = 'text' | 'number' | 'money' | 'date' | 'datetime';

export type ReportSummaryItem = {
  label: string;
  value: unknown;
  format: ReportFormat;
};

export type ReportColumn = {
  key: string;
  label: string;
  type: ReportFormat;
  width?: number;
};

export type ReportSection = {
  key: string;
  title: string;
  note?: string | null;
  columns: ReportColumn[];
  rows: Array<Record<string, unknown>>;
  totals?: ReportSummaryItem[];
};

export type ReportEnvelope = {
  report_code: ReportCode;
  report_title: string;
  business_name: string;
  period: { date_from: string; date_to: string };
  generated_at: string;
  summary: ReportSummaryItem[];
  warnings: string[];
  sections: ReportSection[];
};

export async function runReport(
  code: ReportCode,
  dateFrom: string,
  dateTo: string,
): Promise<ReportEnvelope> {
  const { data, error } = await supabase.rpc('report_run', {
    p_report_code: code,
    p_date_from: dateFrom || null,
    p_date_to: dateTo || null,
  });

  if (error)
    throw new Error(error.message || error.code || 'REPORT_RUN_FAILED');
  return data as ReportEnvelope;
}
