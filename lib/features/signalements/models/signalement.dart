import 'package:flutter/foundation.dart';

import '../../../core/widgets/status_dot.dart';
import '../../../l10n/app_localizations.dart';

/// Ce qu'on signale. Reflète le type `signalement_cible`.
enum SignalementCible {
  message,
  group,
  profile;

  static SignalementCible fromDb(String? value) => switch (value) {
    'message' => SignalementCible.message,
    'group' => SignalementCible.group,
    _ => SignalementCible.profile,
  };

  String get dbValue => name;
}

/// Pourquoi on le signale. Reflète le type `signalement_motif`.
///
/// Six valeurs, et pas davantage : une liste longue se lit mal au moment où
/// l'on signale, et `commentaire` recueille ce qu'aucune n'exprime.
enum SignalementMotif {
  spam,
  harcelement,
  haine,
  sexuel,
  violence,
  autre;

  static SignalementMotif fromDb(String? value) => switch (value) {
    'spam' => SignalementMotif.spam,
    'harcelement' => SignalementMotif.harcelement,
    'haine' => SignalementMotif.haine,
    'sexuel' => SignalementMotif.sexuel,
    'violence' => SignalementMotif.violence,
    _ => SignalementMotif.autre,
  };

  String get dbValue => name;

  /// Le libellé est **demandé**, pas porté : la leçon des quatre-vingt-onze
  /// chaînes que le détecteur laissait passer est fraîche, et un `switch` qui
  /// renverrait du français en dur ici la referait exactement.
  String label(AppTexts t) => switch (this) {
    SignalementMotif.spam => t.signalementMotifSpam,
    SignalementMotif.harcelement => t.signalementMotifHarcelement,
    SignalementMotif.haine => t.signalementMotifHaine,
    SignalementMotif.sexuel => t.signalementMotifSexuel,
    SignalementMotif.violence => t.signalementMotifViolence,
    SignalementMotif.autre => t.signalementMotifAutre,
  };

  /// Ce que le motif recouvre, sous son libellé : « Haine » seul laisserait
  /// deviner, et quelqu'un qui hésite entre deux motifs n'en choisit aucun.
  String aide(AppTexts t) => switch (this) {
    SignalementMotif.spam => t.signalementAideSpam,
    SignalementMotif.harcelement => t.signalementAideHarcelement,
    SignalementMotif.haine => t.signalementAideHaine,
    SignalementMotif.sexuel => t.signalementAideSexuel,
    SignalementMotif.violence => t.signalementAideViolence,
    SignalementMotif.autre => t.signalementAideAutre,
  };
}

/// Ce que la base a fait de l'envoi.
///
/// Un mot d'état plutôt qu'un `void`, comme `prendre_tache` : « déjà
/// signalé » n'est pas une panne, c'est la réponse à la question, et l'écran
/// doit pouvoir le dire au lieu de laisser croire à un second envoi.
enum SignalementOutcome {
  signale,
  dejaSignale,
  introuvable,
  nonMembre,
  soiMeme,
  motifInconnu,
  nonConnecte,
  nonModerateur,
  traite,
  rouvert,
  supprime,
  dejaSupprime,
  inconnu;

  static SignalementOutcome fromDb(String? value) => switch (value) {
    'signale' => SignalementOutcome.signale,
    'deja_signale' => SignalementOutcome.dejaSignale,
    'introuvable' => SignalementOutcome.introuvable,
    'non_membre' => SignalementOutcome.nonMembre,
    'soi_meme' => SignalementOutcome.soiMeme,
    'motif_inconnu' => SignalementOutcome.motifInconnu,
    'non_connecte' => SignalementOutcome.nonConnecte,
    'non_moderateur' => SignalementOutcome.nonModerateur,
    'traite' => SignalementOutcome.traite,
    'rouvert' => SignalementOutcome.rouvert,
    'supprime' => SignalementOutcome.supprime,
    'deja_supprime' => SignalementOutcome.dejaSupprime,
    _ => SignalementOutcome.inconnu,
  };

  bool get isSuccess =>
      this == SignalementOutcome.signale ||
      this == SignalementOutcome.traite ||
      this == SignalementOutcome.rouvert ||
      this == SignalementOutcome.supprime;

  String message(AppTexts t) => switch (this) {
    SignalementOutcome.signale => t.signalementEnvoye,
    SignalementOutcome.dejaSignale => t.signalementDejaEnvoye,
    SignalementOutcome.introuvable => t.signalementIntrouvable,
    SignalementOutcome.nonMembre => t.signalementNonMembre,
    SignalementOutcome.soiMeme => t.signalementSoiMeme,
    SignalementOutcome.motifInconnu => t.signalementMotifInconnu,
    SignalementOutcome.nonConnecte => t.signalementNonConnecte,
    SignalementOutcome.nonModerateur => t.signalementNonModerateur,
    SignalementOutcome.traite => t.signalementMarqueTraite,
    SignalementOutcome.rouvert => t.signalementRouvert,
    SignalementOutcome.supprime => t.signalementMessageSupprime,
    SignalementOutcome.dejaSupprime => t.signalementMessageDejaSupprime,
    SignalementOutcome.inconnu => t.groupsActionAboutiReessayezInstant,
  };
}

/// Un signalement, tel que l'écran de modération le lit.
///
/// Les champs viennent de `signalements_a_traiter()`, qui joint déjà les
/// profils et le nom du groupe : `profiles` est fermé aux étrangers depuis la
/// tranche 7, et un modérateur n'a aucun lien social avec les gens qu'il
/// modère.
@immutable
class Signalement {
  const Signalement({
    required this.id,
    required this.cible,
    required this.motif,
    required this.creeLe,
    this.commentaire,
    this.contexte = const <String, dynamic>{},
    this.traiteLe,
    this.note,
    this.messageId,
    this.groupId,
    this.profilId,
    this.auteurNom,
    this.auteurAvatar,
    this.viseNom,
    this.viseAvatar,
    this.groupeNom,
    this.messageEfface,
  });

  factory Signalement.fromRow(Map<String, dynamic> row) {
    final Object? brut = row['contexte'];
    return Signalement(
      id: row['id'] as String,
      cible: SignalementCible.fromDb(row['cible_type'] as String?),
      motif: SignalementMotif.fromDb(row['motif'] as String?),
      creeLe:
          DateTime.tryParse((row['cree_le'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      commentaire: row['commentaire'] as String?,
      contexte: brut is Map<String, dynamic> ? brut : const <String, dynamic>{},
      traiteLe: DateTime.tryParse(
        (row['traite_le'] as String?) ?? '',
      )?.toLocal(),
      note: row['note'] as String?,
      messageId: row['message_id'] as String?,
      groupId: row['group_id'] as String?,
      profilId: row['profil_id'] as String?,
      auteurNom: row['auteur_nom'] as String?,
      auteurAvatar: row['auteur_avatar'] as String?,
      viseNom: row['vise_nom'] as String?,
      viseAvatar: row['vise_avatar'] as String?,
      groupeNom: row['groupe_nom'] as String?,
      messageEfface: row['message_efface'] as bool?,
    );
  }

  final String id;
  final SignalementCible cible;
  final SignalementMotif motif;
  final DateTime creeLe;
  final String? commentaire;

  /// La recopie du contenu visé, au moment du signalement.
  ///
  /// C'est elle qui rend le signalement jugeable : celui qu'on signale est
  /// précisément celui qui peut effacer son message, et le modérateur n'est
  /// pas membre du groupe — `msg_select` ne lui laisserait rien lire.
  final Map<String, dynamic> contexte;

  final DateTime? traiteLe;
  final String? note;
  final String? messageId;
  final String? groupId;
  final String? profilId;

  /// `null` quand le compte de l'auteur a été supprimé : le dossier survit,
  /// son auteur devient anonyme.
  final String? auteurNom;

  final String? auteurAvatar;
  final String? viseNom;
  final String? viseAvatar;
  final String? groupeNom;

  /// Vrai si le message visé n'existe plus ou a été effacé **depuis** le
  /// signalement. `null` pour un groupe ou un profil.
  ///
  /// C'est l'écart entre cet état et la recopie qui dit « il a effacé ».
  final bool? messageEfface;

  bool get estTraite => traiteLe != null;

  /// Le texte du message signalé, tel qu'il était.
  String? get contenuRecopie => contexte['contenu'] as String?;

  /// Le type de média du message signalé — `image`, `video`, `audio`.
  String? get mediaRecopie => contexte['media_kind'] as String?;

  String? get pseudoRecopie => contexte['pseudo'] as String?;

  String? get bioRecopie => contexte['bio'] as String?;

  String? get descriptionRecopie => contexte['groupe_description'] as String?;

  /// Teinte de la pastille d'état. Le traité est neutre et non vert : ce n'est
  /// pas une réussite, c'est une ligne rangée.
  StatusTone get tone => estTraite ? StatusTone.neutral : StatusTone.warning;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Signalement && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
