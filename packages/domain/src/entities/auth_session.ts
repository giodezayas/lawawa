import type { User } from './user';

export type AuthSession = Readonly<{
  user: User;
}>;

export const AuthSession = {
  create(user: User): AuthSession {
    return Object.freeze({ user });
  },
};
