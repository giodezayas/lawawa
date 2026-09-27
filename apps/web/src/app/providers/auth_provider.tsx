import { DomainError, type User } from '@wawa/domain';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { type AppContainer } from '../container';

type AuthStatus = 'booting' | 'anonymous' | 'authenticated';

type AuthContextValue = {
  container: AppContainer;
  status: AuthStatus;
  user: User | null;
  errorMessage: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

type AuthProviderProps = {
  container: AppContainer;
  children: ReactNode;
};

export function AuthProvider({ container, children }: AuthProviderProps) {
  const [status, setStatus] = useState<AuthStatus>('booting');
  const [user, setUser] = useState<User | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const unsubscribe = container.observeAuthState.execute((session) => {
      if (cancelled) {
        return;
      }
      setUser(session?.user ?? null);
      setStatus(session?.user ? 'authenticated' : 'anonymous');
    });

    void container.getCurrentUser.execute().then((current) => {
      if (cancelled) {
        return;
      }
      setUser(current);
      setStatus(current ? 'authenticated' : 'anonymous');
    });

    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [container]);

  const signIn = useCallback(
    async (email: string, password: string) => {
      setErrorMessage(null);
      try {
        const nextUser = await container.signIn.execute({ email, password });
        setUser(nextUser);
        setStatus('authenticated');
      } catch (error) {
        const message =
          error instanceof DomainError
            ? error.message
            : 'No pudimos iniciar sesión. Inténtalo de nuevo.';
        setErrorMessage(message);
        throw error;
      }
    },
    [container],
  );

  const signOut = useCallback(async () => {
    await container.signOut.execute();
    setUser(null);
    setStatus('anonymous');
  }, [container]);

  const value = useMemo(
    () => ({ container, status, user, errorMessage, signIn, signOut }),
    [container, status, user, errorMessage, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error('useAuth debe usarse dentro de AuthProvider.');
  }
  return value;
}
