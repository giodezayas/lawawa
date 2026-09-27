import type { AuthSession } from '../entities/auth_session';
import type { User } from '../entities/user';

export type AuthStateListener = (session: AuthSession | null) => void;

export type Unsubscribe = () => void;

export interface AuthRepository {
  signIn(email: string, password: string): Promise<User>;
  signOut(): Promise<void>;
  getCurrentUser(): Promise<User | null>;
  observeAuthState(listener: AuthStateListener): Unsubscribe;
}
