import '../../../../core/errors/domain_error.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);

  final AuthRemoteDatasource _datasource;

  @override
  Future<User> signIn({required String email, required String password}) async {
    try {
      final userId = await _datasource.signIn(email: email, password: password);
      return _requireActiveUser(userId);
    } on DomainError {
      rethrow;
    } catch (_) {
      throw const DomainError(
        'Usuario o contraseña incorrectos.',
        AuthErrorCodes.invalidCredentials,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _datasource.signOut();
    } catch (error) {
      throw DomainError(error.toString(), AuthErrorCodes.unauthenticated);
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    final userId = await _datasource.currentUserId();
    if (userId == null) {
      return null;
    }

    try {
      return await _requireActiveUser(userId);
    } on DomainError {
      return null;
    }
  }

  @override
  Unsubscribe observeAuthState(AuthStateListener listener) {
    final subscription = _datasource.authUserIdChanges().listen((userId) async {
      if (userId == null) {
        listener(null);
        return;
      }

      try {
        final user = await _requireActiveUser(userId);
        listener(AuthSession(user: user));
      } on DomainError {
        listener(null);
      }
    });

    return subscription.cancel;
  }

  Future<User> _requireActiveUser(String userId) async {
    final user = await _datasource.fetchProfile(userId);
    if (!user.isActive) {
      await _datasource.signOut();
      throw const DomainError(
        'Tu acceso está desactivado. Contacta a un administrador.',
        AuthErrorCodes.inactiveUser,
      );
    }
    return user;
  }
}
