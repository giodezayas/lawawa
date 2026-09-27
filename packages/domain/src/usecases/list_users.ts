import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import type { User } from '../entities/user';
import type { UserRepository } from '../repositories/user_repository';
import { User as UserEntity } from '../entities/user';

export class ListUsersUseCase {
  constructor(private readonly userRepository: UserRepository) {}

  execute(actor: User): Promise<User[]> {
    if (!UserEntity.canManageStaff(actor)) {
      throw new DomainError('No tienes permiso para ver el equipo.', AuthErrorCodes.forbidden);
    }
    return this.userRepository.list();
  }
}
