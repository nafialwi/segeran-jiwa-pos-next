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
  isTerminalAuthorityError,
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
  | { kind: 'verification_failed'; message: string }
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
  retryVerification: () => Promise<void>;
  switchUser: () => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const TRANSIENT_VERIFICATION_MESSAGE =
  'Tidak dapat memverifikasi akses. Sambungkan internet lalu coba lagi.';

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

async function resolveStoredSession(): Promise<{
  state: AuthState;
  clearLocalSession: boolean;
}> {
  const {
    data: { session },
    error,
  } = await supabase.auth.getSession();

  if (error) {
    return {
      state: {
        kind: 'verification_failed',
        message: TRANSIENT_VERIFICATION_MESSAGE,
      },
      clearLocalSession: false,
    };
  }

  if (!session) {
    return { state: { kind: 'anonymous' }, clearLocalSession: false };
  }

  try {
    const authority = await bootstrapAuthority(currentDeviceInput());
    return {
      state: { kind: 'authenticated', authority },
      clearLocalSession: false,
    };
  } catch (caught) {
    if (isTerminalAuthorityError(caught)) {
      return {
        state: { kind: 'anonymous' },
        clearLocalSession: true,
      };
    }

    return {
      state: {
        kind: 'verification_failed',
        message:
          caught instanceof Error
            ? caught.message
            : TRANSIENT_VERIFICATION_MESSAGE,
      },
      clearLocalSession: false,
    };
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ kind: 'loading' });

  const clearAndSignOut = useCallback(async () => {
    setState({ kind: 'anonymous' });
    await supabase.auth.signOut({ scope: 'local' });
  }, []);

  const retryVerification = useCallback(async (): Promise<void> => {
    setState({ kind: 'loading' });
    const resolved = await resolveStoredSession();
    if (resolved.clearLocalSession) {
      await supabase.auth.signOut({ scope: 'local' });
    }
    setState(resolved.state);
  }, []);

  useEffect(() => {
    let active = true;

    void (async () => {
      const resolved = await resolveStoredSession();
      if (!active) return;

      if (resolved.clearLocalSession) {
        await supabase.auth.signOut({ scope: 'local' });
        if (!active) return;
      }
      setState(resolved.state);
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
      } catch (caught) {
        if (isTerminalAuthorityError(caught)) {
          await clearAndSignOut();
        } else {
          setState({
            kind: 'verification_failed',
            message:
              caught instanceof Error
                ? caught.message
                : TRANSIENT_VERIFICATION_MESSAGE,
          });
        }
        throw caught;
      }
    },
    [clearAndSignOut],
  );

  const refreshAuthority = useCallback(async (): Promise<void> => {
    try {
      const authority = await loadAuthority();
      setState({ kind: 'authenticated', authority });
    } catch (caught) {
      const mapped = mapAuthorityError(caught);
      if (isTerminalAuthorityError(mapped)) {
        await clearAndSignOut();
      } else {
        setState({ kind: 'verification_failed', message: mapped.message });
      }
      throw mapped;
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
      retryVerification,
      switchUser,
      logout,
    }),
    [
      state,
      login,
      refreshAuthority,
      retryVerification,
      switchUser,
      logout,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error('SJ_AUTH_PROVIDER_REQUIRED');
  return context;
}
