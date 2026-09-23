import { requireOnlineAction } from '../health/online-action';
import { supabase } from '../lib/supabase';

export type OperationalMessagePriority = 'NORMAL' | 'HIGH';
export type OperationalMessageTargetKind = 'ALL_CASHIERS' | 'PROFILE';

export type OperationalMessageInboxItem = {
  id: string;
  title: string;
  body: string;
  priority: OperationalMessagePriority;
  targetKind: OperationalMessageTargetKind;
  validFrom: string;
  validUntil: string;
  createdAt: string;
  authorName: string;
  readAt: string | null;
};

export type OperationalMessageManagedItem = OperationalMessageInboxItem & {
  targetProfileId: string | null;
  targetProfileName: string | null;
  cancelledAt: string | null;
  cancelReason: string | null;
  readCount: number;
  recipientCount: number;
};

export type OperationalMessageProfileOption = {
  id: string;
  displayName: string;
  username: string;
  roleCode: string;
};

function rpcMissing(error: {
  code?: string;
  message?: string;
  details?: string | null;
}) {
  const text = [error.message ?? '', error.details ?? '']
    .join(' ')
    .toLowerCase();
  return (
    error.code === '42883' ||
    error.code === 'PGRST202' ||
    text.includes('could not find the function') ||
    text.includes(
      'function public.operational_message_capability() does not exist',
    ) ||
    text.includes(
      'function public.my_operational_messages(integer) does not exist',
    )
  );
}

function fail(error: { code?: string; message?: string } | null): never {
  const message = (error?.message ?? '').toUpperCase();
  if (message.includes('SJ_OPERATIONAL_MESSAGE_MANAGE_DENIED')) {
    throw new Error(
      'Akun ini tidak memiliki izin untuk mengelola pesan operasional.',
    );
  }
  if (message.includes('SJ_OPERATIONAL_MESSAGE_TITLE_INVALID')) {
    throw new Error('Judul pesan wajib diisi dan maksimal 120 karakter.');
  }
  if (message.includes('SJ_OPERATIONAL_MESSAGE_BODY_INVALID')) {
    throw new Error('Isi pesan wajib diisi dan maksimal 1.200 karakter.');
  }
  if (message.includes('SJ_OPERATIONAL_MESSAGE_WINDOW_INVALID')) {
    throw new Error('Waktu berakhir harus setelah waktu mulai.');
  }
  if (message.includes('SJ_OPERATIONAL_MESSAGE_WINDOW_TOO_LONG')) {
    throw new Error('Masa berlaku pesan maksimal 30 hari.');
  }
  if (message.includes('SJ_OPERATIONAL_MESSAGE_PROFILE_INVALID')) {
    throw new Error('Penerima yang dipilih tidak tersedia.');
  }
  throw new Error(
    error?.message || error?.code || 'Pesan operasional gagal diproses.',
  );
}

export async function fetchOperationalMessageCapability(): Promise<boolean> {
  const { data, error } = await supabase.rpc('operational_message_capability');
  if (error) {
    if (rpcMissing(error)) return false;
    fail(error);
  }
  return data === true;
}

export async function fetchOperationalMessageOptions(): Promise<
  OperationalMessageProfileOption[]
> {
  const { data, error } = await supabase.rpc('operational_message_options');
  if (error) fail(error);

  const payload = (data ?? {}) as Record<string, unknown>;
  const rows = Array.isArray(payload.profiles) ? payload.profiles : [];
  return rows.flatMap((entry) => {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry))
      return [];
    const row = entry as Record<string, unknown>;
    if (
      typeof row.profile_id !== 'string' ||
      typeof row.display_name !== 'string' ||
      typeof row.username !== 'string' ||
      typeof row.role_code !== 'string'
    ) {
      return [];
    }
    return [
      {
        id: row.profile_id,
        displayName: row.display_name,
        username: row.username,
        roleCode: row.role_code,
      },
    ];
  });
}

function parseInbox(value: unknown): OperationalMessageInboxItem[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry))
      return [];
    const row = entry as Record<string, unknown>;
    if (
      typeof row.id !== 'string' ||
      typeof row.title !== 'string' ||
      typeof row.body !== 'string' ||
      !['NORMAL', 'HIGH'].includes(String(row.priority)) ||
      !['ALL_CASHIERS', 'PROFILE'].includes(String(row.target_kind)) ||
      typeof row.valid_from !== 'string' ||
      typeof row.valid_until !== 'string' ||
      typeof row.created_at !== 'string' ||
      typeof row.author_name !== 'string'
    ) {
      return [];
    }
    return [
      {
        id: row.id,
        title: row.title,
        body: row.body,
        priority: row.priority as OperationalMessagePriority,
        targetKind: row.target_kind as OperationalMessageTargetKind,
        validFrom: row.valid_from,
        validUntil: row.valid_until,
        createdAt: row.created_at,
        authorName: row.author_name,
        readAt: typeof row.read_at === 'string' ? row.read_at : null,
      },
    ];
  });
}

export async function fetchMyOperationalMessages(
  limit = 5,
): Promise<OperationalMessageInboxItem[]> {
  const { data, error } = await supabase.rpc('my_operational_messages', {
    p_limit: limit,
  });
  if (error) {
    if (rpcMissing(error)) return [];
    fail(error);
  }
  return parseInbox(data);
}

export async function fetchManagedOperationalMessages(
  limit = 30,
): Promise<OperationalMessageManagedItem[]> {
  const { data, error } = await supabase.rpc('manage_operational_messages', {
    p_limit: limit,
  });
  if (error) {
    if (rpcMissing(error)) return [];
    fail(error);
  }

  return parseInbox(data).map((base, index) => {
    const row = (Array.isArray(data) ? data[index] : {}) as Record<
      string,
      unknown
    >;
    return {
      ...base,
      targetProfileId:
        typeof row.target_profile_id === 'string'
          ? row.target_profile_id
          : null,
      targetProfileName:
        typeof row.target_profile_name === 'string'
          ? row.target_profile_name
          : null,
      cancelledAt:
        typeof row.cancelled_at === 'string' ? row.cancelled_at : null,
      cancelReason:
        typeof row.cancel_reason === 'string' ? row.cancel_reason : null,
      readCount: Number(row.read_count ?? 0),
      recipientCount: Number(row.recipient_count ?? 0),
    };
  });
}

export async function createOperationalMessage(args: {
  title: string;
  body: string;
  priority: OperationalMessagePriority;
  targetKind: OperationalMessageTargetKind;
  targetProfileId: string | null;
  validFrom: string;
  validUntil: string;
}) {
  requireOnlineAction('Kirim Pesan Operasional');
  const { data, error } = await supabase.rpc('create_operational_message', {
    p_title: args.title,
    p_body: args.body,
    p_priority: args.priority,
    p_target_kind: args.targetKind,
    p_target_profile_id: args.targetProfileId,
    p_valid_from: args.validFrom,
    p_valid_until: args.validUntil,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as { success: boolean; replay: boolean; message_id: string };
}

export async function cancelOperationalMessage(messageId: string, reason = '') {
  requireOnlineAction('Batalkan Pesan Operasional');
  const { data, error } = await supabase.rpc('cancel_operational_message', {
    p_message_id: messageId,
    p_reason: reason,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) fail(error);
  return data as { success: boolean; replay: boolean; message_id: string };
}

export async function markOperationalMessageRead(messageId: string) {
  requireOnlineAction('Tandai Pesan Dibaca');
  const { data, error } = await supabase.rpc('mark_operational_message_read', {
    p_message_id: messageId,
  });
  if (error) fail(error);
  return data as { success: boolean; message_id: string };
}
