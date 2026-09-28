import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../../core/errors/domain_error.dart';
import '../../domain/entities/user.dart';
import '../mappers/user_mapper.dart';

class AuthRemoteDatasource {
  const AuthRemoteDatasource(this._client);

  final SupabaseClient _client;

  Future<String> signIn({required String email, required String password}) async {
    final resolved = await _client.rpc('resolve_login', params: {'p_login': email});
    final loginEmail = resolved is String ? resolved : null;
    if (loginEmail == null || loginEmail.isEmpty) {
      throw const DomainError(
        'Usuario o contraseña incorrectos.',
        AuthErrorCodes.invalidCredentials,
      );
    }

    final response = await _client.auth.signInWithPassword(
      email: loginEmail,
      password: password,
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw const DomainError(
        'Usuario o contraseña incorrectos.',
        AuthErrorCodes.invalidCredentials,
      );
    }

    return userId;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<String?> currentUserId() async {
    return _client.auth.currentUser?.id;
  }

  Stream<String?> authUserIdChanges() {
    return _client.auth.onAuthStateChange.map((state) => state.session?.user.id);
  }

  Future<User> fetchProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (row == null) {
      throw const DomainError(
        'No encontramos tu perfil. Pide a un administrador que te invite.',
        AuthErrorCodes.profileMissing,
      );
    }

    return UserMapper.fromProfile(row);
  }
}
