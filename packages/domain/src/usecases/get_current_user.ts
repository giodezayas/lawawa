import type { AuthRepository } from '../repositories/auth_repository';
import type { User } from '../entities/user';

export class GetCurrentUserUseCase {
  constructor(private readonly authRepository: AuthRepository) {}

  execute(): Promise<User | null> {
    return this.authRepository.getCurrentUser();
  }
}
