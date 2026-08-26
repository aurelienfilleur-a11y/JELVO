import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Nature d'une notification.
///
/// `notifications.type` est du texte libre côté base : l'énumération se charge
/// de ne rien casser si un type inconnu apparaît — il tombe dans [autre] et
/// reste affichable.
enum NotificationType {
  groupInvitation('group_invitation'),
  contactRequest('contact_request'),
  eventInvitation('event_invitation'),
  taskAssigned('task_assigned'),
  autre('autre');

  const NotificationType(this.dbValue);

  final String dbValue;

  static NotificationType fromDb(String? value) => switch (value) {
    'group_invitation' => NotificationType.groupInvitation,
    'contact_request' => NotificationType.contactRequest,
    'event_invitation' => NotificationType.eventInvitation,
    'task_assigned' => NotificationType.taskAssigned,
    _ => NotificationType.autre,
  };

  /// Onglet de la barre inférieure dont la pastille compte ce type.
  ///
  /// 0 Accueil · 1 Groupes · 2 Calendrier · 3 Contacts.
  int get navIndex => switch (this) {
    NotificationType.groupInvitation => 1,
    NotificationType.contactRequest => 3,
    NotificationType.eventInvitation => 2,
    // Les tâches n'ont pas d'onglet : elles vivent dans l'accueil, d'où la
    // liste complète s'ouvre.
    NotificationType.taskAssigned => 0,
    NotificationType.autre => 0,
  };

  IconData get icon => switch (this) {
    NotificationType.groupInvitation => Icons.groups_rounded,
    NotificationType.contactRequest => Icons.person_add_alt_rounded,
    NotificationType.eventInvitation => Icons.event_rounded,
    NotificationType.taskAssigned => Icons.task_alt_rounded,
    NotificationType.autre => Icons.notifications_none_rounded,
  };

  Color get accent => switch (this) {
    NotificationType.groupInvitation => AppColors.primary,
    NotificationType.contactRequest => AppColors.success,
    NotificationType.eventInvitation => AppColors.warning,
    NotificationType.taskAssigned => AppColors.primaryDark,
    NotificationType.autre => AppColors.textSecondary,
  };
}

/// Une ligne de la table `notifications`.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    this.payload = const <String, dynamic>{},
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      type: NotificationType.fromDb(row['type'] as String?),
      payload:
          (row['payload'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      readAt: DateTime.tryParse((row['read_at'] as String?) ?? ''),
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
    );
  }

  final String id;
  final NotificationType type;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  String? _text(String key) {
    final Object? value = payload[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  String get groupName => _text('group_name') ?? 'un groupe';

  String get senderName => switch (type) {
    NotificationType.groupInvitation => _text('inviter_name') ?? 'Un membre',
    NotificationType.contactRequest => _text('name') ?? 'Quelqu’un',
    NotificationType.eventInvitation => _text('auteur') ?? 'Un membre',
    NotificationType.taskAssigned => _text('auteur') ?? 'Un membre',
    NotificationType.autre => 'Jelvo',
  };

  String? get avatarUrl => switch (type) {
    NotificationType.groupInvitation => _text('inviter_avatar'),
    NotificationType.contactRequest => _text('avatar_url'),
    NotificationType.eventInvitation => null,
    NotificationType.taskAssigned => null,
    NotificationType.autre => null,
  };

  String? get invitationId => _text('invitation_id');

  String? get groupId => _text('group_id');

  String? get requesterId => _text('requester_id');

  /// Événement concerné, pour les invitations d'agenda.
  String? get eventId => _text('event_id');

  String get eventTitle => _text('titre') ?? 'un événement';

  /// Début de l'événement, déjà remis à l'heure locale.
  DateTime? get eventStart =>
      DateTime.tryParse(_text('starts_at') ?? '')?.toLocal();

  DateTime? get eventEnd =>
      DateTime.tryParse(_text('ends_at') ?? '')?.toLocal();

  String? get eventLocation => _text('lieu');

  /// Tâche concernée, pour une attribution.
  String? get taskId => _text('task_id');

  String get taskTitle => _text('titre') ?? 'une tâche';

  /// Échéance de la tâche, déjà remise à l'heure locale.
  DateTime? get taskDueAt =>
      DateTime.tryParse(_text('due_at') ?? '')?.toLocal();

  String get title => switch (type) {
    NotificationType.groupInvitation => 'Invitation à rejoindre $groupName',
    NotificationType.contactRequest => 'Demande de contact',
    NotificationType.eventInvitation => eventTitle,
    NotificationType.taskAssigned => taskTitle,
    NotificationType.autre => 'Notification',
  };

  String get message => switch (type) {
    NotificationType.groupInvitation =>
      '$senderName vous invite à rejoindre « $groupName ».',
    NotificationType.contactRequest =>
      '$senderName souhaite vous ajouter à ses contacts.',
    NotificationType.eventInvitation =>
      '$senderName vous convie${_text('group_name') == null ? '' : ' avec « $groupName »'}.',
    NotificationType.taskAssigned => '$senderName vous a confié cette tâche.',
    NotificationType.autre => 'Vous avez une nouvelle notification.',
  };

  /// Libellé de l'action, ou `null` si la notification n'en propose pas.
  String? get actionLabel => switch (type) {
    NotificationType.groupInvitation => 'Voir l’invitation',
    NotificationType.contactRequest => 'Voir la demande',
    NotificationType.eventInvitation => 'Voir l’événement',
    NotificationType.taskAssigned => 'Voir la tâche',
    NotificationType.autre => null,
  };

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    type: type,
    payload: payload,
    readAt: readAt ?? this.readAt,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
