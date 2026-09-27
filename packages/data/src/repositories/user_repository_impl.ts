import {
  AuthErrorCodes,
  DomainError,
  type CreateStaffInput,
  type UpdateStaffInput,
  type User,
  type UserRepository,
} from '@wawa/domain';
import { mapProfileToUser } from '../mappers/user_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class UserRepositoryImpl implements UserRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async list(): Promise<User[]> {
    const { data, error } = await this.client.from('profiles').select('*').order('full_name');

    if (error) {
      throw new DomainError(error.message, AuthErrorCodes.invalidInput);
    }

    return (data ?? []).map(mapProfileToUser);
  }

  async getById(id: string): Promise<User | null> {
    const { data, error } = await this.client.from('profiles').select('*').eq('id', id).maybeSingle();

    if (error) {
      throw new DomainError(error.message, AuthErrorCodes.invalidInput);
    }

    return data ? mapProfileToUser(data) : null;
  }

  async create(input: CreateStaffInput): Promise<User> {
    const { data, error } = await this.client.rpc('invite_staff', {
      p_email: input.email,
      p_password: input.password,
      p_full_name: input.fullName,
      p_role: input.role,
    });

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo crear el usuario.', AuthErrorCodes.invalidInput);
    }

    return this.requireById(data);
  }

  async update(input: UpdateStaffInput): Promise<User> {
    const { error } = await this.client.rpc('update_staff', {
      p_id: input.id,
      p_full_name: input.fullName,
      p_role: input.role,
      p_is_active: input.isActive,
      p_password: input.password && input.password.length > 0 ? input.password : undefined,
    });

    if (error) {
      throw new DomainError(error.message, AuthErrorCodes.invalidInput);
    }

    return this.requireById(input.id);
  }

  async remove(id: string): Promise<void> {
    const { error } = await this.client.rpc('delete_staff', { p_id: id });
    if (error) {
      throw new DomainError(error.message, AuthErrorCodes.invalidInput);
    }
  }

  private async requireById(id: string): Promise<User> {
    const user = await this.getById(id);
    if (!user) {
      throw new DomainError('El usuario se guardó, pero no se pudo leer.', AuthErrorCodes.invalidInput);
    }
    return user;
  }
}
