import '../repositories/auth_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<void> execute() => _authRepository.signOut();
}
