import {
  AuthErrorCodes,
  AuthSession,
  DomainError,
  type AuthRepository,
  type AuthStateListener,
  type Unsubscribe,
  type User,
} from '@wawa/domain';
import type { AppSupabaseClient } from '../supabase/client';
import { mapProfileToUser } from '../mappers/user_mapper';

export class AuthRepositoryImpl implements AuthRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async signIn(email: string, password: string): Promise<User> {
    const { data, error } = await this.client.auth.signInWithPassword({
      email,
      password,
    });

    if (error || !data.user) {
      throw new DomainError(
        'Correo o contraseña incorrectos.',
        AuthErrorCodes.invalidCredentials,
      );
    }

    return this.requireUser(data.user.id);
  }

  async signOut(): Promise<void> {
    const { error } = await this.client.auth.signOut();
    if (error) {
      throw new DomainError(error.message, AuthErrorCodes.unauthenticated);
    }
  }

  async getCurrentUser(): Promise<User | null> {
    const { data } = await this.client.auth.getUser();
    if (!data.user) {
      return null;
    }

    return this.requireUser(data.user.id);
  }

  observeAuthState(listener: AuthStateListener): Unsubscribe {
    const { data } = this.client.auth.onAuthStateChange((_event, session) => {
      void this.emitSession(session?.user.id, listener);
    });

    return () => data.subscription.unsubscribe();
  }

  private async emitSession(
    userId: string | undefined,
    listener: AuthStateListener,
  ): Promise<void> {
    if (!userId) {
      listener(null);
      return;
    }

    try {
      const user = await this.requireUser(userId);
      listener(AuthSession.create(user));
    } catch {
      listener(null);
    }
  }

  private async requireUser(userId: string): Promise<User> {
    const { data, error } = await this.client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (error || !data) {
      throw new DomainError(
        'No encontramos tu perfil. Pide a un administrador que te invite.',
        AuthErrorCodes.profileMissing,
      );
    }

    const user = mapProfileToUser(data);
    if (!user.isActive) {
      await this.client.auth.signOut();
      throw new DomainError(
        'Tu acceso está desactivado. Contacta a un administrador.',
        AuthErrorCodes.inactiveUser,
      );
    }

    return user;
  }
}
