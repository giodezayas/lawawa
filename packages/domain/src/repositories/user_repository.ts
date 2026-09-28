import type { User, UserRole } from '../entities/user';

export type CreateStaffInput = {
  username: string;
  password: string;
  fullName: string;
  role: UserRole;
};

export type UpdateStaffInput = {
  id: string;
  fullName: string;
  role: UserRole;
  isActive: boolean;
  password?: string;
};

export interface UserRepository {
  list(): Promise<User[]>;
  getById(id: string): Promise<User | null>;
  create(input: CreateStaffInput): Promise<User>;
  update(input: UpdateStaffInput): Promise<User>;
  remove(id: string): Promise<void>;
}
