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
  autre('autre');

  const NotificationType(this.dbValue);

  final String dbValue;

  static NotificationType fromDb(String? value) => switch (value) {
    'group_invitation' => NotificationType.groupInvitation,
    'contact_request' => NotificationType.contactRequest,
    _ => NotificationType.autre,
  };

  /// Onglet de la barre inférieure dont la pastille compte ce type.
  ///
  /// 0 Accueil · 1 Groupes · 2 Calendrier · 3 Contacts.
  int get navIndex => switch (this) {
    NotificationType.groupInvitation => 1,
    NotificationType.contactRequest => 3,
    NotificationType.autre => 0,
  };

  IconData get icon => switch (this) {
    NotificationType.groupInvitation => Icons.groups_rounded,
    NotificationType.contactRequest => Icons.person_add_alt_rounded,
    NotificationType.autre => Icons.notifications_none_rounded,
  };

  Color get accent => switch (this) {
    NotificationType.groupInvitation => AppColors.primary,
    NotificationType.contactRequest => AppColors.success,
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
    NotificationType.autre => 'Jelvo',
  };

  String? get avatarUrl => switch (type) {
    NotificationType.groupInvitation => _text('inviter_avatar'),
    NotificationType.contactRequest => _text('avatar_url'),
    NotificationType.autre => null,
  };

  String? get invitationId => _text('invitation_id');

  String? get groupId => _text('group_id');

  String? get requesterId => _text('requester_id');

  String get title => switch (type) {
    NotificationType.groupInvitation => 'Invitation à rejoindre $groupName',
    NotificationType.contactRequest => 'Demande de contact',
    NotificationType.autre => 'Notification',
  };

  String get message => switch (type) {
    NotificationType.groupInvitation =>
      '$senderName vous invite à rejoindre « $groupName ».',
    NotificationType.contactRequest =>
      '$senderName souhaite vous ajouter à ses contacts.',
    NotificationType.autre => 'Vous avez une nouvelle notification.',
  };

  /// Libellé de l'action, ou `null` si la notification n'en propose pas.
  String? get actionLabel => switch (type) {
    NotificationType.groupInvitation => 'Voir l’invitation',
    NotificationType.contactRequest => 'Voir la demande',
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
