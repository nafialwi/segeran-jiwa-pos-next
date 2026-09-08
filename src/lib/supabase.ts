import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as
  string | undefined;

if (!url || !publishableKey) {
  throw new Error('SJ_SUPABASE_PUBLIC_CONFIG_MISSING');
}

const serverSecretPrefix = ['sb', 'secret', ''].join('_');
if (publishableKey.startsWith(serverSecretPrefix)) {
  throw new Error('SJ_SUPABASE_SECRET_IN_BROWSER_CONFIG');
}

export const supabase = createClient(url, publishableKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});
