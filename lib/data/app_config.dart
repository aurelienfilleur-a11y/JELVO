/// Configuration d'exécution, fournie à la compilation par `--dart-define`.
///
/// L'URL et la clé « publishable » de Supabase sont publiques par conception :
/// elles voyagent dans chaque requête du client et la sécurité repose sur les
/// politiques RLS, pas sur leur confidentialité. Les valeurs par défaut
/// permettent donc de lancer `flutter run` sans argument, tout en gardant la
/// possibilité de pointer vers un autre projet :
///
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
/// ```
abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xndvxxcknchanqpnrkjc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Z3fcuavUcuSYIRimt2T6iQ_OUbDRKj9',
  );

  /// Bucket Storage des photos de profil.
  static const String avatarsBucket = 'avatars';

  /// Délai avant de pouvoir redemander un code de vérification.
  static const Duration resendCodeDelay = Duration(seconds: 45);
}
