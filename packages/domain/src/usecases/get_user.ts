import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import type { User } from '../entities/user';
import type { UserRepository } from '../repositories/user_repository';

export class GetUserUseCase {
  constructor(private readonly userRepository: UserRepository) {}

  async execute(id: string): Promise<User> {
    const user = await this.userRepository.getById(id);
    if (!user) {
      throw new DomainError('No encontramos ese usuario.', AuthErrorCodes.profileMissing);
    }
    return user;
  }
}
