import '../repositories/auth_repository.dart';

class ObserveAuthStateUseCase {
  const ObserveAuthStateUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Unsubscribe execute(AuthStateListener listener) {
    return _authRepository.observeAuthState(listener);
  }
}
