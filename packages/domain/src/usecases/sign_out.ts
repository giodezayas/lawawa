import type { AuthRepository } from '../repositories/auth_repository';

export class SignOutUseCase {
  constructor(private readonly authRepository: AuthRepository) {}

  execute(): Promise<void> {
    return this.authRepository.signOut();
  }
}
