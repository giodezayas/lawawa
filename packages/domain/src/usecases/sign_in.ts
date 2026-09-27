import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import type { AuthRepository } from '../repositories/auth_repository';
import { isValidEmail } from '../shared/email';
import type { User } from '../entities/user';

export type SignInInput = {
  email: string;
  password: string;
};

export class SignInUseCase {
  constructor(private readonly authRepository: AuthRepository) {}

  async execute(input: SignInInput): Promise<User> {
    const email = input.email.trim().toLowerCase();
    const password = input.password;

    if (!isValidEmail(email) || password.length < 6) {
      throw new DomainError(
        'Correo o contraseña inválidos.',
        AuthErrorCodes.invalidInput,
      );
    }

    return this.authRepository.signIn(email, password);
  }
}
