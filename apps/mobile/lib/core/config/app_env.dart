class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.length > 20;
}
