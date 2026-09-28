export const userRoles = ['admin', 'manager', 'trabajador'] as const;

export type UserRole = (typeof userRoles)[number];

export type UserProps = {
  readonly id: string;
  readonly email: string;
  readonly username: string;
  readonly fullName: string;
  readonly role: UserRole;
  readonly isActive: boolean;
  readonly createdAt: Date;
};

export type User = Readonly<UserProps>;

export const User = {
  create(props: UserProps): User {
    return Object.freeze({ ...props });
  },

  displayName(user: User): string {
    const trimmed = user.fullName.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
    return user.username || user.email;
  },

  canManageStaff(user: User): boolean {
    return user.role === 'admin' || user.role === 'manager';
  },

  roleLabel(role: UserRole): string {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'trabajador':
        return 'Trabajador';
    }
  },
};
