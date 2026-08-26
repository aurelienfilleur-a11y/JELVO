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

  /// Bucket Storage des médias du chat. **Privé** : contrairement aux deux
  /// précédents, on n'en tire jamais d'URL publique — la lecture passe par une
  /// URL signée, et les politiques la réservent aux membres du groupe.
  static const String chatMediaBucket = 'chat-media';

  /// Validité d'une URL signée de média. Assez longue pour tenir le temps
  /// d'une conversation, assez courte pour qu'un lien recopié ailleurs cesse
  /// vite de fonctionner.
  static const Duration chatMediaUrlValidity = Duration(hours: 2);

  /// Poids maximal d'une vidéo. Sans ré-encodage côté application, c'est la
  /// seule borne dont on dispose : mieux vaut refuser clairement à la
  /// sélection qu'échouer au téléversement.
  static const int chatMediaMaxVideoBytes = 25 * 1024 * 1024;

  /// Durée maximale demandée au sélecteur pour une vidéo.
  static const Duration chatMediaMaxVideoDuration = Duration(seconds: 60);

  /// Clé VAPID **publique**, nécessaire au navigateur pour s'abonner aux
  /// notifications système.
  ///
  /// Publique par conception, comme la clé « publishable » : elle peut figurer
  /// dans un dépôt public. Sa jumelle privée, elle, ne vit que dans les
  /// secrets de la fonction Edge et ne doit **jamais** entrer ici.
  ///
  /// Vide par défaut : tant qu'elle n'est pas fournie, l'application dit que
  /// les notifications ne sont pas configurées plutôt que d'offrir un bouton
  /// qui échouerait.
  static const String vapidPublicKey = String.fromEnvironment(
    'VAPID_PUBLIC_KEY',
  );

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
  ///
  /// Le `#` n'est pas décoratif : l'application n'appelle pas
  /// `usePathUrlStrategy()`, donc Flutter web place la route **après le
  /// fragment**. Sans lui, GitHub Pages ne trouve pas `/JELVO/rejoindre/<jeton>`,
  /// sert `404.html` — une copie d'`index.html` — et l'application démarre avec
  /// un fragment vide : GoRouter voit `/` et affiche l'accueil, sans message ni
  /// erreur. Le jeton est perdu en silence.
  ///
  /// À revoir le jour où le site aura son propre domaine : la stratégie par
  /// chemin donnera des liens plus propres, et ce `#` disparaîtra.
  static String inviteUrl(String token) => '$webBaseUrl/#/rejoindre/$token';

  /// Valeur **par défaut** du mode diagnostic, fixée à la compilation :
  ///
  /// ```bash
  /// flutter run -d chrome --dart-define=JELVO_DIAGNOSTIC=true
  /// ```
  ///
  /// L'état réellement consulté est `DiagnosticMode.isActive`, que le paramètre
  /// d'URL `?diag=1` peut activer sans recompiler ni redéployer. Ne pas lire ce
  /// drapeau directement : il ne connaît pas l'URL.
  ///
  /// Il est délibérément absent de `kDebugMode` : les tests de widget
  /// tournent en debug et assertent sur les messages exacts.
  /// Version affichée dans « À propos ».
  ///
  /// Recopiée de `pubspec.yaml` à la main : lire le pubspec à l'exécution
  /// demanderait `package_info_plus`, une dépendance de plus pour une chaîne.
  /// `test/app_version_test.dart` confronte les deux — une version qui
  /// diverge fait échouer les tests plutôt que de mentir à l'écran.
  static const String version = '1.0.0';

  static const bool diagnosticErrors = bool.fromEnvironment('JELVO_DIAGNOSTIC');
}
