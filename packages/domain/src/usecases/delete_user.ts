import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import { User } from '../entities/user';
import type { UserRepository } from '../repositories/user_repository';

export class DeleteUserUseCase {
  constructor(private readonly userRepository: UserRepository) {}

  execute(actor: User, id: string): Promise<void> {
    if (!User.canManageStaff(actor)) {
      throw new DomainError('No tienes permiso para borrar usuarios.', AuthErrorCodes.forbidden);
    }
    if (actor.id === id) {
      throw new DomainError('No puedes borrar tu propia cuenta.', AuthErrorCodes.invalidInput);
    }
    return this.userRepository.remove(id);
  }
}
