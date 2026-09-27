import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_wawa_gestion/app/wawa_app.dart';
import 'package:la_wawa_gestion/core/config/app_env.dart';

void main() {
  testWidgets('muestra la guía de Supabase si el entorno no está configurado', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WawaApp(
          env: AppEnv(supabaseUrl: '', supabaseAnonKey: ''),
        ),
      ),
    );

    expect(find.text('Conecta Supabase para continuar'), findsOneWidget);
  });
}
