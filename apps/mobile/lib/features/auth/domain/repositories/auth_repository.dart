import '../entities/auth_session.dart';
import '../entities/user.dart';

typedef AuthStateListener = void Function(AuthSession? session);
typedef Unsubscribe = void Function();

abstract interface class AuthRepository {
  Future<User> signIn({required String email, required String password});
  Future<void> signOut();
  Future<User?> getCurrentUser();
  Unsubscribe observeAuthState(AuthStateListener listener);
}
