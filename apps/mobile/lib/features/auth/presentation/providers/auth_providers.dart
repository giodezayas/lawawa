import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/observe_auth_state.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(AuthRemoteDatasource(ref.watch(supabaseClientProvider)));
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

final observeAuthStateUseCaseProvider = Provider<ObserveAuthStateUseCase>((ref) {
  return ObserveAuthStateUseCase(ref.watch(authRepositoryProvider));
});

sealed class AuthUiState {
  const AuthUiState();
}

class AuthBooting extends AuthUiState {
  const AuthBooting();
}

class AuthAnonymous extends AuthUiState {
  const AuthAnonymous({this.errorMessage});

  final String? errorMessage;
}

class AuthAuthenticated extends AuthUiState {
  const AuthAuthenticated(this.user);

  final User user;
}

class AuthController extends Notifier<AuthUiState> {
  @override
  AuthUiState build() {
    final observe = ref.read(observeAuthStateUseCaseProvider);
    final unsubscribe = observe.execute((session) {
      state = session == null ? const AuthAnonymous() : AuthAuthenticated(session.user);
    });
    ref.onDispose(unsubscribe);

    Future.microtask(_hydrate);
    return const AuthBooting();
  }

  Future<void> _hydrate() async {
    final user = await ref.read(getCurrentUserUseCaseProvider).execute();
    state = user == null ? const AuthAnonymous() : AuthAuthenticated(user);
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final user = await ref.read(signInUseCaseProvider).execute(
        email: email,
        password: password,
      );
      state = AuthAuthenticated(user);
    } catch (error) {
      state = AuthAnonymous(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    await ref.read(signOutUseCaseProvider).execute();
    state = const AuthAnonymous();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthUiState>(AuthController.new);
