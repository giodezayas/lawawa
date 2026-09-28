import '../../../../core/errors/domain_error.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<User> execute({required String login, required String password}) {
    final normalized = login.trim().toLowerCase();

    if (normalized.length < 3 || password.length < 6) {
      throw const DomainError(
        'Usuario o contraseña inválidos.',
        AuthErrorCodes.invalidInput,
      );
    }

    return _authRepository.signIn(email: normalized, password: password);
  }
}
