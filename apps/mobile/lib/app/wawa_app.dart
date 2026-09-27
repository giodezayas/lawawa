import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/setup/presentation/screens/setup_screen.dart';
import '../shared/widgets/loading_state.dart';
import 'app_shell.dart';

class WawaApp extends ConsumerWidget {
  const WawaApp({super.key, required this.env});

  final AppEnv env;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'La Wawa Gestión',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: env.isConfigured ? const _SessionGate() : const SetupScreen(),
    );
  }
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return switch (authState) {
      AuthBooting() => const LoadingState(label: 'Cargando tu sesión...'),
      AuthAnonymous() => const LoginScreen(),
      AuthAuthenticated() => const AppShell(),
    };
  }
}
