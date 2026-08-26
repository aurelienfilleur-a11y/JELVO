import 'package:flutter/foundation.dart';

import '../../calendar/models/calendar_event.dart';
import '../../tasks/models/task.dart';

/// Ce qu'une carte de conversation porte, tel que `messages_du_groupe` le
/// renvoie dans son champ `carte`.
///
/// Un seul `jsonb` plutôt qu'une douzaine de colonnes : une carte de tâche et
/// une carte d'événement n'ont pas les mêmes champs, et deux jeux de colonnes
/// dont la moitié serait toujours nulle se liraient mal.
///
/// **L'état est celui de l'élément, jamais une copie.** Rien n'est recopié
/// dans `messages` au moment du dépôt, hormis le titre — que la contrainte
/// `messages_check` impose de toute façon — et le drapeau qui distingue une
/// tâche prise d'une tâche confiée.
@immutable
sealed class MessageCard {
  const MessageCard({required this.titre, required this.supprimee});

  static MessageCard? fromJson(Object? brut) {
    if (brut is! Map<String, dynamic>) return null;
    return switch (brut['sorte']) {
      'tache' => TaskCard.fromJson(brut),
      'evenement' => EventCardData.fromJson(brut),
      _ => null,
    };
  }

  final String titre;

  /// L'élément a été supprimé. **La carte reste**, et le dit : une carte
  /// morte, qui n'aurait plus ni titre ni réponse, ne dirait rien de ce qui
  /// s'est passé.
  final bool supprimee;
}

/// Une personne portée par une carte : un nom, un visage, une réponse.
@immutable
class CardPerson {
  const CardPerson({required this.name, this.avatarUrl, this.status});

  factory CardPerson.fromJson(Map<String, dynamic> json) => CardPerson(
    name: (json['nom'] as String?) ?? 'Un membre',
    avatarUrl: json['avatar_url'] as String?,
    status: json['status'] == null
        ? null
        : AssigneeStatus.fromDb(json['status'] as String?),
  );

  final String name;
  final String? avatarUrl;
  final AssigneeStatus? status;
}

/// La carte d'une tâche.
@immutable
class TaskCard extends MessageCard {
  const TaskCard({
    required super.titre,
    required super.supprimee,
    required this.prise,
    required this.terminee,
    this.dueAt,
    this.priorite = TaskPriority.medium,
    this.monStatut,
    this.assignes = const <CardPerson>[],
  });

  factory TaskCard.fromJson(Map<String, dynamic> json) {
    final Object? gens = json['assignes'];
    return TaskCard(
      titre: (json['titre'] as String?) ?? 'Tâche',
      supprimee: json['supprimee'] == true,
      prise: json['prise'] == true,
      terminee: json['terminee'] == true,
      dueAt: DateTime.tryParse((json['due_at'] as String?) ?? '')?.toLocal(),
      priorite: TaskPriority.fromDb(json['priorite'] as String?),
      monStatut: json['mon_statut'] == null
          ? null
          : AssigneeStatus.fromDb(json['mon_statut'] as String?),
      assignes: gens is List
          ? gens
                .whereType<Map<String, dynamic>>()
                .map(CardPerson.fromJson)
                .toList()
          : const <CardPerson>[],
    );
  }

  final DateTime? dueAt;
  final TaskPriority priorite;

  /// Prise **depuis la carte**, par opposition à confiée.
  ///
  /// Les deux situations sont identiques dans `task_assignees` — un assigné,
  /// pas plus — et seule l'histoire les sépare : « Thomas a pris la tâche »
  /// se rend, « Tâche attribuée à Thomas » se refuse. C'est
  /// `messages.tache_prise` qui retient laquelle des deux.
  final bool prise;

  final bool terminee;
  final AssigneeStatus? monStatut;
  final List<CardPerson> assignes;

  /// Personne n'a encore pris la tâche : elle est offerte à tout le groupe.
  bool get ouverte => assignes.isEmpty;

  /// Celui qui l'a prise, ou celui à qui elle a été confiée.
  CardPerson? get titulaire => assignes.isEmpty ? null : assignes.first;

  /// Vrai quand c'est **moi** qui l'ai prise : moi seul peux me désister.
  bool get priseParMoi => prise && monStatut != null;
}

/// La carte d'un événement.
///
/// Nommée `EventCardData` et non `EventCard` : `core/widgets` expose déjà un
/// `EventCard`, qui est une carte d'écran et non un modèle.
@immutable
class EventCardData extends MessageCard {
  const EventCardData({
    required super.titre,
    required super.supprimee,
    required this.debut,
    required this.fin,
    this.lieu,
    this.maReponse = EventResponse.pending,
    this.oui = 0,
    this.peutEtre = 0,
    this.non = 0,
  });

  factory EventCardData.fromJson(Map<String, dynamic> json) {
    final DateTime debut =
        DateTime.tryParse((json['starts_at'] as String?) ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return EventCardData(
      titre: (json['titre'] as String?) ?? 'Événement',
      supprimee: json['supprimee'] == true,
      debut: debut,
      fin:
          DateTime.tryParse((json['ends_at'] as String?) ?? '')?.toLocal() ??
          debut.add(const Duration(hours: 1)),
      lieu: json['lieu'] as String?,
      maReponse: EventResponse.fromDb(json['ma_reponse'] as String?),
      oui: (json['oui'] as num?)?.toInt() ?? 0,
      peutEtre: (json['peut_etre'] as num?)?.toInt() ?? 0,
      non: (json['non'] as num?)?.toInt() ?? 0,
    );
  }

  final DateTime debut;
  final DateTime fin;
  final String? lieu;
  final EventResponse maReponse;
  final int oui;
  final int peutEtre;
  final int non;

  /// Décompte affiché sur la carte : « 3 oui · 1 peut-être · 2 non », les
  /// zéros omis.
  String get decompte {
    final List<String> parts = <String>[
      if (oui > 0) '$oui oui',
      if (peutEtre > 0) '$peutEtre peut-être',
      if (non > 0) '$non non',
    ];
    return parts.isEmpty ? 'Aucune réponse' : parts.join(' · ');
  }
}
