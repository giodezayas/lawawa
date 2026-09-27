import '../../../../core/errors/domain_error.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._authRepository);

  final AuthRepository _authRepository;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<User> execute({required String email, required String password}) {
    final normalizedEmail = email.trim().toLowerCase();

    if (!_emailPattern.hasMatch(normalizedEmail) || password.length < 6) {
      throw const DomainError(
        'Correo o contraseña inválidos.',
        AuthErrorCodes.invalidInput,
      );
    }

    return _authRepository.signIn(email: normalizedEmail, password: password);
  }
}
