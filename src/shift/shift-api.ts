// CS-05-P3 SHIFT API CLIENT
// Wraps Supabase RPC calls to the CS-05-P3-API wrappers.

import { supabase } from '../lib/supabase';
import type { Handover, Shift, ShiftExpense } from './shift-core';

export type LocationOption = {
  id: string;
  label: string;
};

async function myProfileId(): Promise<string> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    throw new Error('SJ_AUTHORITY_DENIED: not authenticated');
  }
  const { data, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('auth_user_id', user.id)
    .single();
  if (error || !data) {
    throw new Error('SJ_AUTHORITY_DENIED: profile not found');
  }
  return (data as { id: string }).id;
}

function fail(error: { code?: string; message: string }): never {
  throw new Error(error.message || error.code || 'SJ_UNKNOWN');
}

export async function openShift(
  locationId: string,
  openingBalance: number,
  config: Record<string, unknown> = {},
): Promise<string> {
  if (openingBalance > 0) {
    const { data, error } = await supabase.rpc(
      'finance_open_shift_from_main_cash',
      {
        p_location: locationId,
        p_opening: openingBalance,
        p_config: config,
        p_idempotency_key: crypto.randomUUID(),
      },
    );
    if (error) fail(error);
    return data as string;
  }

  const { data, error } = await supabase.rpc('cs05_open_my_shift', {
    p_location: locationId,
    p_opening: 0,
    p_config: config,
  });
  if (error) fail(error);
  return data as string;
}

export async function closeShift(
  shiftId: string,
  actualCash: number,
  toProfileId: string | null = null,
): Promise<number> {
  const { data, error } = await supabase.rpc('cs05_close_my_shift', {
    p_shift: shiftId,
    p_actual: actualCash,
    p_to_profile: toProfileId,
  });
  if (error) fail(error);
  return data as number;
}

export async function resolveHandover(
  handoverId: string,
  accept: boolean,
): Promise<void> {
  const { error } = await supabase.rpc('cs05_resolve_handover', {
    p_handover: handoverId,
    p_accept: accept,
  });
  if (error) fail(error);
}

export async function handoverTarget(username: string): Promise<string> {
  const { data, error } = await supabase.rpc('cs05_handover_target', {
    p_username: username,
  });
  if (error) fail(error);
  return data as string;
}

export async function fetchMyOpenShift(): Promise<Shift | null> {
  const me = await myProfileId();
  const { data, error } = await supabase
    .from('shifts')
    .select('*')
    .eq('cashier_profile_id', me)
    .eq('status', 'OPEN')
    .maybeSingle();
  if (error) fail(error);
  return (data as Shift) ?? null;
}

export async function fetchMyShiftHistory(limit = 20): Promise<Shift[]> {
  const me = await myProfileId();
  const { data, error } = await supabase
    .from('shifts')
    .select('*')
    .eq('cashier_profile_id', me)
    .order('opened_at', { ascending: false })
    .limit(limit);
  if (error) fail(error);
  return (data as Shift[]) ?? [];
}

export async function fetchMyPendingHandovers(): Promise<Handover[]> {
  const me = await myProfileId();
  const { data, error } = await supabase
    .from('handovers')
    .select('*')
    .eq('to_cashier_profile_id', me)
    .eq('status', 'PENDING')
    .order('created_at', { ascending: false });
  if (error) fail(error);
  return (data as Handover[]) ?? [];
}

export async function fetchLocations(): Promise<LocationOption[]> {
  const { data, error } = await supabase.from('locations').select('*');
  if (error) fail(error);
  const rows = (data ?? []) as Record<string, unknown>[];
  return rows.map((row) => ({
    id: String(row.id),
    label: String(row.display_name ?? row.name ?? row.code ?? row.id),
  }));
}

export type ShiftExpenseSubmission = {
  status: 'POSTED' | 'PENDING' | 'APPROVED' | 'REJECTED';
  expense_id: string | null;
  request_id: string | null;
};

export type ShiftExpenseApproval = {
  request_id: string;
  shift_id: string;
  category_code: string;
  description: string;
  amount: number;
  requested_at: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  decision_reason: string | null;
};

export async function postShiftExpense(
  categoryCode: string,
  description: string,
  amount: number,
): Promise<ShiftExpenseSubmission> {
  const { data, error } = await supabase.rpc('finance_submit_shift_expense', {
    p_category_code: categoryCode,
    p_description: description,
    p_amount: amount,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as ShiftExpenseSubmission;
}

export async function fetchShiftExpenseApprovals(
  shiftId: string,
): Promise<ShiftExpenseApproval[]> {
  const { data, error } = await supabase
    .from('expense_approval_queue')
    .select(
      'request_id,shift_id,category_code,description,amount,requested_at,status,decision_reason',
    )
    .eq('shift_id', shiftId)
    .order('requested_at', { ascending: false });
  if (error) fail(error);
  return (data ?? []) as ShiftExpenseApproval[];
}

export async function fetchShiftExpenses(
  shiftId: string,
): Promise<ShiftExpense[]> {
  const { data, error } = await supabase
    .from('business_expenses')
    .select('*')
    .eq('shift_id', shiftId)
    .order('created_at', { ascending: false });
  if (error) fail(error);
  return (data as ShiftExpense[]) ?? [];
}

export async function fetchShiftReconciliation(
  shiftId: string,
): Promise<import('../shift/shift-core').Reconciliation> {
  const { data, error } = await supabase.rpc('cs05_shift_reconciliation', {
    p_shift: shiftId,
  });
  if (error) fail(error);
  const rows = data as import('../shift/shift-core').Reconciliation[];
  if (!rows || rows.length === 0) {
    throw new Error('Reconciliation data not found');
  }
  return rows[0];
}

export async function fetchMyClosedShifts(limit = 50): Promise<Shift[]> {
  const me = await myProfileId();
  const { data, error } = await supabase
    .from('shifts')
    .select('*')
    .eq('cashier_profile_id', me)
    .eq('status', 'CLOSED')
    .order('closed_at', { ascending: false })
    .limit(limit);
  if (error) fail(error);
  return (data as Shift[]) ?? [];
}
