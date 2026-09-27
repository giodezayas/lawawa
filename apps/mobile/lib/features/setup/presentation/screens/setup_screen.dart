import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storage_rounded, color: AppColors.primary, size: 36),
                SizedBox(height: 16),
                Text(
                  'Conecta Supabase para continuar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 12),
                Text('1. Crea un proyecto gratis en supabase.com'),
                Text('2. Copia la URL y la anon key'),
                Text('3. Crea apps/mobile/.env con SUPABASE_URL y SUPABASE_ANON_KEY'),
                Text('4. Ejecuta: flutter run --dart-define-from-file=.env'),
                Text('5. Corre el SQL de supabase/migrations e invita al primer usuario'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
