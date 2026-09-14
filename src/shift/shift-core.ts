// CS-05-P3 SHIFT CORE
// Pure rules + error mapping for shift UI. No DOM, no RPC, fully testable.

export type ShiftStatus = 'OPEN' | 'CLOSED';

export type Shift = {
  id: string;
  business_id: string;
  location_id: string;
  cashier_profile_id: string;
  opened_at: string;
  closed_at: string | null;
  opening_balance: number;
  closing_balance: number | null;
  status: ShiftStatus;
  config_snapshot: Record<string, unknown>;
  expected_cash: number | null;
  actual_cash: number | null;
  variance: number | null;
};

export type Handover = {
  id: string;
  business_id: string;
  location_id: string;
  from_shift_id: string;
  to_shift_id: string | null;
  from_cashier_profile_id: string;
  to_cashier_profile_id: string | null;
  expected_balance: number;
  actual_balance: number;
  discrepancy: number;
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED';
  created_at: string;
};

export function toShiftErrorMessage(error: unknown): string {
  if (
    error instanceof Error &&
    (error.message.startsWith('SJ_') || error.message.startsWith('CS05:'))
  ) {
    const code = error.message.split(':')[0];
    switch (code) {
      case 'CS05':
        return 'Operasi shift gagal: aturan bisnis dilanggar.';
      case 'SJ_PERMISSION_DENIED':
        return 'Anda tidak memiliki izin untuk operasi shift ini.';
      case 'SJ_AUTHORITY_DENIED':
        return 'Sesi Anda tidak valid. Silakan masuk ulang.';
      case 'SJ_HANDOVER_TARGET_INVALID':
        return 'Target serah-terima tidak valid atau bukan rekan satu bisnis.';
      case 'SJ_HANDOVER_NOT_PENDING':
        return 'Serah-terima ini sudah diproses sebelumnya.';
      default:
        return `Operasi gagal (${code}).`;
    }
  }
  if (error instanceof Error) {
    return error.message;
  }
  return 'Terjadi kesalahan tidak diketahui.';
}

export function canCloseShift(shift: Shift | null): boolean {
  return shift !== null && shift.status === 'OPEN';
}

export function canAcceptHandover(handover: Handover | null): boolean {
  return handover !== null && handover.status === 'PENDING';
}

export function formatVariance(variance: number | null): string {
  if (variance === null) return '—';
  const prefix = variance > 0 ? '+' : '';
  return `${prefix}${variance.toLocaleString('id-ID', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}
