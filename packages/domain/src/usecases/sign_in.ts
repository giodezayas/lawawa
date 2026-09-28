import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import type { AuthRepository } from '../repositories/auth_repository';
import type { User } from '../entities/user';

export type SignInInput = {
  login: string;
  password: string;
};

export class SignInUseCase {
  constructor(private readonly authRepository: AuthRepository) {}

  async execute(input: SignInInput): Promise<User> {
    const login = input.login.trim().toLowerCase();
    const password = input.password;

    if (login.length < 3 || password.length < 6) {
      throw new DomainError(
        'Usuario o contraseña inválidos.',
        AuthErrorCodes.invalidInput,
      );
    }

    return this.authRepository.signIn(login, password);
  }
}
