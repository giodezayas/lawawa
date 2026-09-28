import { User, type UserRole } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type ProfileRow = Database['public']['Tables']['profiles']['Row'];

const roles: readonly UserRole[] = ['admin', 'manager', 'trabajador'];

function toUserRole(value: string): UserRole {
  if (value === 'owner') {
    return 'admin';
  }
  if (value === 'staff') {
    return 'trabajador';
  }
  return roles.includes(value as UserRole) ? (value as UserRole) : 'trabajador';
}

export function mapProfileToUser(row: ProfileRow): User {
  return User.create({
    id: row.id,
    email: row.email,
    username: row.username || row.email.split('@')[0] || row.email,
    fullName: row.full_name,
    role: toUserRole(row.role),
    isActive: row.is_active,
    createdAt: new Date(row.created_at),
  });
}
