import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/theme/jelvo_colors.dart';
import '../../groups/models/group.dart' show GroupAccent;
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/status_dot.dart';

/// Ce qu'une ligne de la journée représente.
///
/// Le calendrier agrège quatre sources qui n'ont ni la même table ni la même
/// forme ; les réduire à un type commun est ce qui permet de les trier ensemble
/// par heure, ce qu'une liste par source ne saurait pas faire.
enum AgendaEntryKind {
  /// Événement d'un groupe.
  groupEvent,

  /// Rendez-vous personnel : sans groupe, visible de son seul propriétaire.
  personalEvent,

  /// Tâche datée, placée à l'heure de son échéance.
  task,

  /// Créneau de disponibilité déclaré, en fond de journée.
  availability,

  /// Anniversaire d'un contact : annuel, sur toute la journée.
  ///
  /// Placé en dernier à dessein — l'ordre de cette énumération sert de
  /// départage à heure égale, et déplacer une valeur existante changerait
  /// l'ordre d'affichage de lignes qui n'ont rien à voir avec ce chantier.
  birthday,
}

/// Ce que la couleur d'une ligne **veut dire**.
///
/// Le provider dit la nature de la ligne, le widget en tire la teinte. C'est
/// nécessaire depuis le thème sombre : une `Color` figée dans le modèle serait
/// choisie hors de tout `BuildContext`, donc dans une seule des deux palettes.
/// `anniversaire` **n'ajoute aucune couleur à la palette** : elle prend
/// `warning`, l'ambre déjà défini, qui était le seul jeton fonctionnel que le
/// calendrier n'employait pas. Le code couleur de l'écran gagne donc une
/// quatrième entrée sans qu'une teinte ait été inventée — c'était déjà la
/// règle quand le vert, le rouge et le violet de la maquette sont tombés sur
/// `success`, `danger` et `primary`.
enum AgendaAccent { evenement, tache, indisponible, anniversaire }

/// Une ligne de la timeline du jour.
@immutable
class AgendaEntry {
  const AgendaEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    required this.end,
    required this.accent,
    this.groupAccent,
    this.subtitle,
    this.timeLabel,
    this.statusTone,
    this.statusLabel,
    this.groupId,
    this.avatars = const <AvatarData>[],
    this.participantCount = 0,
  });

  final String id;
  final AgendaEntryKind kind;
  final String title;

  /// Instants réels ; pour une tâche, début et fin valent l'échéance.
  final DateTime start;
  final DateTime end;

  final AgendaAccent accent;

  /// L'accent du groupe, quand la ligne en vient un. Il l'emporte : c'est
  /// déjà la règle ailleurs, et perdre l'identité du groupe ferait se
  /// ressembler tous les groupes entre eux.
  final GroupAccent? groupAccent;

  Color accentColor(JelvoColors c) =>
      groupAccent?.color(c) ??
      switch (accent) {
        AgendaAccent.evenement => c.primary,
        AgendaAccent.tache => c.success,
        AgendaAccent.indisponible => c.danger,
        AgendaAccent.anniversaire => c.warning,
      };

  /// Groupe, lieu, ou ce qui situe la ligne. Jamais obligatoire.
  final String? subtitle;

  /// Heure affichée dans la gouttière. Calculée à la construction pour que le
  /// widget n'ait pas à connaître `AppDates`.
  final String? timeLabel;

  final StatusTone? statusTone;
  final String? statusLabel;

  final String? groupId;

  /// Convives d'un événement de groupe, déjà convertis pour `AvatarStack`.
  ///
  /// Vides ailleurs : une tâche n'a pas de participants au sens de l'agenda,
  /// et un créneau encore moins.
  final List<AvatarData> avatars;

  final int participantCount;

  /// Un créneau de disponibilité n'ouvre rien : il n'a pas d'écran de détail,
  /// et le toucher ne doit donc pas laisser croire le contraire.
  ///
  /// Un anniversaire non plus, et pour une raison précise : **Jelvo n'a pas
  /// d'écran de profil d'autrui.** Le faire ouvrir la fiche du contact
  /// demanderait cet écran, qui n'existe nulle part aujourd'hui ; le faire
  /// ouvrir autre chose serait un chemin qui ne mène pas où il annonce.
  bool get isOpenable =>
      kind != AgendaEntryKind.availability && kind != AgendaEntryKind.birthday;

  /// Fond teinté des créneaux, qui doivent rester en retrait des événements.
  Color background(JelvoColors c) => switch (kind) {
    AgendaEntryKind.availability => c.background,
    _ => c.surface,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgendaEntry && other.id == id && other.kind == kind);

  @override
  int get hashCode => Object.hash(id, kind);
}
