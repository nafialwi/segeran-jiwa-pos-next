import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { supabase } from '../lib/supabase';
import {
  bootstrapAuthority,
  loadAuthority,
  mapAuthorityError,
} from './authority';
import {
  getDeviceKind,
  getOrCreateDeviceId,
  rememberUsername,
  setDeviceKind,
  type DeviceKind,
} from './device';
import type { AuthoritySnapshot } from './types';
import { toInternalAuthEmail } from './username';

type AuthState =
  | { kind: 'loading' }
  | { kind: 'anonymous' }
  | { kind: 'authenticated'; authority: AuthoritySnapshot };

interface AuthContextValue {
  state: AuthState;
  authority: AuthoritySnapshot | null;
  login: (
    username: string,
    password: string,
    deviceKind: DeviceKind,
  ) => Promise<void>;
  refreshAuthority: () => Promise<void>;
  switchUser: () => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function currentDeviceInput() {
  const storage = window.localStorage;
  return {
    deviceId: getOrCreateDeviceId(storage),
    deviceKind: getDeviceKind(storage),
    friendlyName: 'Browser',
    platformLabel: navigator.platform || 'WEB',
  };
}

async function revokeAndLocalSignOut(): Promise<void> {
  await supabase.rpc('revoke_my_session');
  await supabase.auth.signOut({ scope: 'local' });
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ kind: 'loading' });

  const clearAndSignOut = useCallback(async () => {
    setState({ kind: 'anonymous' });
    await supabase.auth.signOut({ scope: 'local' });
  }, []);

  useEffect(() => {
    let active = true;

    void (async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!active) return;

      if (!session) {
        setState({ kind: 'anonymous' });
        return;
      }

      try {
        const authority = await bootstrapAuthority(currentDeviceInput());
        if (active) setState({ kind: 'authenticated', authority });
      } catch {
        if (active) {
          setState({ kind: 'anonymous' });
          await supabase.auth.signOut({ scope: 'local' });
        }
      }
    })();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (!active) return;
      if (event === 'SIGNED_OUT' || !session) {
        setState({ kind: 'anonymous' });
      }
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  const login = useCallback(
    async (
      username: string,
      password: string,
      deviceKind: DeviceKind,
    ): Promise<void> => {
      const email = toInternalAuthEmail(username);
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw new Error('SJ_LOGIN_INVALID');

      rememberUsername(window.localStorage, username);
      setDeviceKind(window.localStorage, deviceKind);

      try {
        const authority = await bootstrapAuthority(currentDeviceInput());
        setState({ kind: 'authenticated', authority });
      } catch (error) {
        await clearAndSignOut();
        throw error;
      }
    },
    [clearAndSignOut],
  );

  const refreshAuthority = useCallback(async (): Promise<void> => {
    try {
      const authority = await loadAuthority();
      setState({ kind: 'authenticated', authority });
    } catch (error) {
      await clearAndSignOut();
      throw mapAuthorityError(error);
    }
  }, [clearAndSignOut]);

  const switchUser = useCallback(async (): Promise<void> => {
    await revokeAndLocalSignOut();
    setState({ kind: 'anonymous' });
  }, []);

  const logout = useCallback(async (): Promise<void> => {
    await revokeAndLocalSignOut();
    setState({ kind: 'anonymous' });
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      state,
      authority: state.kind === 'authenticated' ? state.authority : null,
      login,
      refreshAuthority,
      switchUser,
      logout,
    }),
    [state, login, refreshAuthority, switchUser, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('SJ_AUTH_PROVIDER_REQUIRED');
  return context;
}
