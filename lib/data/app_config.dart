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

  /// Bucket Storage des photos de groupe.
  static const String groupPhotosBucket = 'group-photos';

  /// Délai avant de pouvoir redemander un code de vérification.
  static const Duration resendCodeDelay = Duration(seconds: 45);

  /// Adresse publique de l'application, utilisée pour composer les liens
  /// d'invitation partagés hors de l'application (SMS, messagerie, e-mail).
  ///
  /// À surcharger pour un déploiement sur un autre domaine :
  /// `--dart-define=JELVO_WEB_URL=https://mon-domaine.fr`.
  static const String webBaseUrl = String.fromEnvironment(
    'JELVO_WEB_URL',
    defaultValue: 'https://aurelienfilleur-a11y.github.io/JELVO',
  );

  /// Durée de validité d'un lien d'invitation, alignée sur le défaut SQL.
  static const Duration inviteLinkLifetime = Duration(days: 30);

  /// Longueur du jeton d'invitation, en octets tirés au sort.
  static const int inviteTokenBytes = 16;

  /// Lien partageable menant à la page publique d'un groupe.
  static String inviteUrl(String token) => '$webBaseUrl/rejoindre/$token';
}
