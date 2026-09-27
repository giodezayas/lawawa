import { AuthErrorCodes, DomainError } from '../errors/domain_error';
import { User, type UserRole, userRoles } from '../entities/user';
import type { UserRepository } from '../repositories/user_repository';
import { isValidEmail } from '../shared/email';

export class CreateUserUseCase {
  constructor(private readonly userRepository: UserRepository) {}

  execute(actor: User, input: {
    email: string;
    password: string;
    fullName: string;
    role: UserRole;
  }): Promise<User> {
    if (!User.canManageStaff(actor)) {
      throw new DomainError('No tienes permiso para crear usuarios.', AuthErrorCodes.forbidden);
    }

    const email = input.email.trim().toLowerCase();
    if (!isValidEmail(email)) {
      throw new DomainError('El correo no es válido.', AuthErrorCodes.invalidInput);
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
      email,
      password: input.password,
      fullName: input.fullName.trim(),
      role: input.role,
    });
  }
}
