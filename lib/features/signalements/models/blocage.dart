import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';

/// Ce que la base a fait d'un blocage ou d'un déblocage.
///
/// Un mot d'état plutôt qu'un `void` : « déjà bloqué » et « pas bloqué » ne
/// sont pas des pannes, ce sont les réponses à la question, et l'écran doit
/// pouvoir les dire au lieu d'annoncer un geste qui n'a pas eu lieu.
enum BlocageOutcome {
  bloque,
  dejaBloque,
  debloque,
  pasBloque,
  soiMeme,
  introuvable,
  nonConnecte,
  inconnu;

  static BlocageOutcome fromDb(String? value) => switch (value) {
    'bloque' => BlocageOutcome.bloque,
    'deja_bloque' => BlocageOutcome.dejaBloque,
    'debloque' => BlocageOutcome.debloque,
    'pas_bloque' => BlocageOutcome.pasBloque,
    'soi_meme' => BlocageOutcome.soiMeme,
    'introuvable' => BlocageOutcome.introuvable,
    'non_connecte' => BlocageOutcome.nonConnecte,
    _ => BlocageOutcome.inconnu,
  };

  bool get isSuccess =>
      this == BlocageOutcome.bloque || this == BlocageOutcome.debloque;

  String message(AppTexts t) => switch (this) {
    BlocageOutcome.bloque => t.blocageBloque,
    BlocageOutcome.dejaBloque => t.blocageDejaBloque,
    BlocageOutcome.debloque => t.blocageDebloque,
    BlocageOutcome.pasBloque => t.blocagePasBloque,
    BlocageOutcome.soiMeme => t.blocageSoiMeme,
    BlocageOutcome.introuvable => t.blocageIntrouvable,
    BlocageOutcome.nonConnecte => t.signalementNonConnecte,
    BlocageOutcome.inconnu => t.groupsActionAboutiReessayezInstant,
  };
}

/// Quelqu'un que l'on a bloqué, tel que `mes_blocages()` le rend.
///
/// Le profil est **joint par la fonction** : bloquer supprime le lien de
/// contact, et `profiles_select` vaut `id = auth.uid() or has_social_link(id)`
/// depuis la tranche 7 — relire la ligne côté client ne rendrait rien.
@immutable
class PersonneBloquee {
  const PersonneBloquee({
    required this.userId,
    required this.creeLe,
    this.pseudo,
    this.nom,
    this.avatarUrl,
  });

  factory PersonneBloquee.fromRow(Map<String, dynamic> row) {
    return PersonneBloquee(
      userId: row['user_id'] as String,
      creeLe:
          DateTime.tryParse((row['cree_le'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      pseudo: row['pseudo'] as String?,
      nom: row['nom'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  final String userId;
  final DateTime creeLe;

  /// `null` quand le compte a été supprimé depuis : la ligne reste, pour que
  /// le blocage puisse être retiré.
  final String? pseudo;

  final String? nom;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonneBloquee && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}
