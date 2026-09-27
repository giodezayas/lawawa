import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import { User, type UserRole, userRoles } from '../entities/user';
import type { UserRepository } from '../repositories/user_repository';

export class UpdateUserUseCase {
  constructor(private readonly userRepository: UserRepository) {}

  execute(actor: User, input: {
    id: string;
    fullName: string;
    role: UserRole;
    isActive: boolean;
    password?: string;
  }): Promise<User> {
    if (!User.canManageStaff(actor)) {
      throw new DomainError('No tienes permiso para editar usuarios.', AuthErrorCodes.forbidden);
    }
    if (!userRoles.includes(input.role)) {
      throw new DomainError('El rol no es válido.', AuthErrorCodes.invalidInput);
    }
    if (input.role === 'admin' && actor.role !== 'admin') {
      throw new DomainError('Solo un admin puede asignar el rol admin.', AuthErrorCodes.forbidden);
    }
    if (input.password && input.password.length < 6) {
      throw new DomainError('La contraseña debe tener al menos 6 caracteres.', AuthErrorCodes.invalidInput);
    }

    return this.userRepository.update({
      id: input.id,
      fullName: input.fullName.trim(),
      role: input.role,
      isActive: input.isActive,
      password: input.password,
    });
  }
}
