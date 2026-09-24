const STATUS_LABELS: Record<string, string> = {
  DRAFT: 'Draf',
  POSTED: 'Diposting',
  RECEIVED: 'Diterima',
  OPEN: 'Terbuka',
  PAID: 'Lunas',
  PARTIALLY_PAID: 'Dibayar Sebagian',
  PENDING: 'Menunggu',
  APPROVED: 'Disetujui',
  REJECTED: 'Ditolak',
  SUBMITTED: 'Diajukan',
  SHIPPED: 'Dikirim',
  COUNTED: 'Sudah Dihitung',
  CLOSED: 'Selesai',
  ACTIVE: 'Aktif',
  INACTIVE: 'Nonaktif',
  CANCELLED: 'Dibatalkan',
  CANCELED: 'Dibatalkan',
  VOIDED: 'Dibatalkan',
  FAILED: 'Gagal',
  SETTLED: 'Selesai',
};

const WARNING_STATUSES = new Set([
  'RECEIVED',
  'OPEN',
  'PARTIALLY_PAID',
  'PENDING',
  'SUBMITTED',
  'SHIPPED',
  'COUNTED',
]);

const NEUTRAL_STATUSES = new Set(['DRAFT', 'INACTIVE']);

const DANGER_STATUSES = new Set([
  'REJECTED',
  'CANCELLED',
  'CANCELED',
  'VOIDED',
  'FAILED',
]);

function normalizeStatus(value: string): string {
  return value.trim().toUpperCase();
}

export function statusLabel(value: string): string {
  const normalized = normalizeStatus(value);
  if (STATUS_LABELS[normalized]) return STATUS_LABELS[normalized];

  return normalized
    .toLowerCase()
    .replaceAll('_', ' ')
    .replace(/(^|\s)\S/g, (letter) => letter.toUpperCase());
}

export function statusToneClass(value: string): string {
  const normalized = normalizeStatus(value);
  if (DANGER_STATUSES.has(normalized)) return 'danger';
  if (WARNING_STATUSES.has(normalized)) return 'warning';
  if (NEUTRAL_STATUSES.has(normalized)) return 'neutral';
  return '';
}

export function operationalStatusClass(value: string): string {
  return ['operations-status', statusToneClass(value)].filter(Boolean).join(' ');
}
