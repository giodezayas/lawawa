import type {
  AuthRepository,
  AuthStateListener,
  Unsubscribe,
} from '../repositories/auth_repository';

export class ObserveAuthStateUseCase {
  constructor(private readonly authRepository: AuthRepository) {}

  execute(listener: AuthStateListener): Unsubscribe {
    return this.authRepository.observeAuthState(listener);
  }
}
