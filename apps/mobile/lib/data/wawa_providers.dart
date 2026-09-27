import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import 'wawa_client.dart';

final wawaClientProvider = Provider<WawaClient>((ref) {
  return WawaClient(ref.watch(supabaseClientProvider));
});
