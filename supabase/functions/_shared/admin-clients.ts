import { createClient } from 'npm:@supabase/supabase-js@2';

function defaultKey(jsonName: string): string {
  const raw = Deno.env.get(jsonName);
  if (!raw) throw new Error(`SJ_EDGE_CONFIG_MISSING:${jsonName}`);

  const parsed = JSON.parse(raw) as { default?: unknown };
  const key = parsed.default;
  if (typeof key !== 'string' || key.length === 0) {
    throw new Error(`SJ_EDGE_CONFIG_INVALID:${jsonName}`);
  }

  return key;
}

function supabaseUrl(): string {
  const value = Deno.env.get('SUPABASE_URL');
  if (!value) throw new Error('SJ_EDGE_CONFIG_MISSING:SUPABASE_URL');
  return value;
}

export function createAdminClient() {
  return createClient(supabaseUrl(), defaultKey('SUPABASE_SECRET_KEYS'), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export function createUserClient(authorization: string) {
  return createClient(supabaseUrl(), defaultKey('SUPABASE_PUBLISHABLE_KEYS'), {
    global: {
      headers: {
        Authorization: authorization,
      },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
