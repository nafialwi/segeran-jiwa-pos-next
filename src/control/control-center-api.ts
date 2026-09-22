import { parseAuthoritySnapshot } from '../auth/authority';
import { supabase } from '../lib/supabase';

export type BackendAuthorityProbe = {
  kind: 'BACKEND_AUTHORITY';
  status: 'PASS' | 'FAIL';
  checkedAt: string;
  latencyMs: number;
  detail: string;
};

export async function probeBackendAuthority(): Promise<BackendAuthorityProbe> {
  const startedAt = performance.now();
  const checkedAt = new Date().toISOString();

  const { data, error } = await supabase.rpc('get_my_authority');
  const latencyMs = Math.max(0, Math.round(performance.now() - startedAt));

  if (error) {
    return {
      kind: 'BACKEND_AUTHORITY',
      status: 'FAIL',
      checkedAt,
      latencyMs,
      detail:
        error.message ||
        'Backend authority tidak merespons dengan kontrak yang valid.',
    };
  }

  try {
    const authority = parseAuthoritySnapshot(data);
    return {
      kind: 'BACKEND_AUTHORITY',
      status: 'PASS',
      checkedAt,
      latencyMs,
      detail:
        'Authority aktif untuk ' +
        authority.username +
        ' (' +
        authority.role_code +
        ').',
    };
  } catch {
    return {
      kind: 'BACKEND_AUTHORITY',
      status: 'FAIL',
      checkedAt,
      latencyMs,
      detail: 'Payload authority backend tidak valid.',
    };
  }
}
