import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import { User, type UserRole, userRoles } from '../entities/user';
import type { UserRepository } from '../repositories/user_repository';
import { isValidUsername } from '../shared/username';

export class CreateUserUseCase {
  constructor(private readonly userRepository: UserRepository) {}

  execute(actor: User, input: {
    username: string;
    password: string;
    fullName: string;
    role: UserRole;
  }): Promise<User> {
    if (!User.canManageStaff(actor)) {
      throw new DomainError('No tienes permiso para crear usuarios.', AuthErrorCodes.forbidden);
    }

    const username = input.username.trim().toLowerCase();
    if (!isValidUsername(username)) {
      throw new DomainError(
        'El usuario debe tener de 3 a 32 caracteres: letras, números, punto, guion o guion bajo.',
        AuthErrorCodes.invalidInput,
      );
    }
    if (input.password.length < 6) {
      throw new DomainError('La contraseña debe tener al menos 6 caracteres.', AuthErrorCodes.invalidInput);
    }
    if (!userRoles.includes(input.role)) {
      throw new DomainError('El rol no es válido.', AuthErrorCodes.invalidInput);
    }
    if (input.role === 'admin' && actor.role !== 'admin') {
      throw new DomainError('Solo un admin puede crear otro admin.', AuthErrorCodes.forbidden);
    }

    return this.userRepository.create({
      username,
      password: input.password,
      fullName: input.fullName.trim(),
      role: input.role,
    });
  }
}
