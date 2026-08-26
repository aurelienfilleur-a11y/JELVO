import 'package:flutter/material.dart';

/// État d'un lien d'invitation, tel que le renvoie `apercu_groupe_par_jeton`.
enum InviteLinkStatus {
  valide,
  invalide,
  expire,
  revoque,
  epuise;

  static InviteLinkStatus fromDb(String? value) => switch (value) {
    'valide' => InviteLinkStatus.valide,
    'expire' => InviteLinkStatus.expire,
    'revoque' => InviteLinkStatus.revoque,
    'epuise' => InviteLinkStatus.epuise,
    _ => InviteLinkStatus.invalide,
  };

  /// Message affiché sur la page publique quand le lien ne vaut plus.
  String get message => switch (this) {
    InviteLinkStatus.valide => '',
    InviteLinkStatus.invalide =>
      'Ce lien d’invitation n’existe pas ou n’est plus valable.',
    InviteLinkStatus.expire =>
      'Ce lien d’invitation a expiré. Demandez-en un nouveau au groupe.',
    InviteLinkStatus.revoque =>
      'Ce lien d’invitation a été révoqué par le groupe.',
    InviteLinkStatus.epuise => 'Ce lien a déjà servi au nombre de fois prévu.',
  };
}

/// Résultat d'une tentative d'adhésion, par lien ou par invitation nominative.
enum JoinOutcome {
  rejoint,
  dejaMembre,
  invalide,
  expire,
  revoque,
  epuise,
  nonConnecte;

  static JoinOutcome fromDb(String? value) => switch (value) {
    'rejoint' => JoinOutcome.rejoint,
    'deja_membre' => JoinOutcome.dejaMembre,
    'expire' => JoinOutcome.expire,
    'revoque' => JoinOutcome.revoque,
    'epuise' => JoinOutcome.epuise,
    'non_connecte' => JoinOutcome.nonConnecte,
    _ => JoinOutcome.invalide,
  };

  bool get isSuccess =>
      this == JoinOutcome.rejoint || this == JoinOutcome.dejaMembre;

  String get message => switch (this) {
    JoinOutcome.rejoint => 'Vous avez rejoint le groupe.',
    JoinOutcome.dejaMembre => 'Vous faites déjà partie de ce groupe.',
    JoinOutcome.invalide =>
      'Ce lien d’invitation n’existe pas ou n’est plus valable.',
    JoinOutcome.expire => 'Ce lien d’invitation a expiré.',
    JoinOutcome.revoque => 'Ce lien d’invitation a été révoqué.',
    JoinOutcome.epuise => 'Ce lien a déjà servi au nombre de fois prévu.',
    JoinOutcome.nonConnecte => 'Connectez-vous pour rejoindre ce groupe.',
  };
}

/// Ce que devient un groupe quand on le quitte.
enum LeaveOutcome {
  parti,
  adminTransmis,
  groupeSupprime,
  nonMembre;

  static LeaveOutcome fromDb(String? value) => switch (value) {
    'parti' => LeaveOutcome.parti,
    'admin_transmis' => LeaveOutcome.adminTransmis,
    'groupe_supprime' => LeaveOutcome.groupeSupprime,
    _ => LeaveOutcome.nonMembre,
  };

  String get message => switch (this) {
    LeaveOutcome.parti => 'Vous avez quitté le groupe.',
    LeaveOutcome.adminTransmis =>
      'Vous avez quitté le groupe. Le plus ancien membre en devient admin.',
    LeaveOutcome.groupeSupprime =>
      'Vous étiez le dernier membre : le groupe a été supprimé.',
    LeaveOutcome.nonMembre => 'Vous ne faites pas partie de ce groupe.',
  };
}

/// Résultat d'une action d'administration sur un membre.
///
/// Les fonctions SQL renvoient un mot d'état plutôt que `void` : l'écran peut
/// alors dire ce qui s'est réellement passé. C'est la leçon de l'écriture
/// directe dans `group_members`, qui répondait 200 sans rien changer.
enum MemberOutcome {
  promu,
  retrograde,
  retire,
  termeDefini,
  termeRetire,
  inchange,
  termePasse,
  dejaAdmin,
  dernierAdmin,
  nonAdmin,
  nonAdminCible,
  nonMembre,
  soiMeme,
  inconnu;

  static MemberOutcome fromDb(String? value) => switch (value) {
    'promu' => MemberOutcome.promu,
    'retrograde' => MemberOutcome.retrograde,
    'retire' => MemberOutcome.retire,
    'terme_defini' => MemberOutcome.termeDefini,
    'terme_retire' => MemberOutcome.termeRetire,
    'inchange' => MemberOutcome.inchange,
    'terme_passe' => MemberOutcome.termePasse,
    'deja_admin' => MemberOutcome.dejaAdmin,
    'dernier_admin' => MemberOutcome.dernierAdmin,
    'non_admin' => MemberOutcome.nonAdmin,
    'non_admin_cible' => MemberOutcome.nonAdminCible,
    'non_membre' => MemberOutcome.nonMembre,
    'soi_meme' => MemberOutcome.soiMeme,
    _ => MemberOutcome.inconnu,
  };

  bool get isSuccess =>
      this == MemberOutcome.promu ||
      this == MemberOutcome.retrograde ||
      this == MemberOutcome.retire ||
      this == MemberOutcome.termeDefini ||
      this == MemberOutcome.termeRetire;

  /// [nom] est le prénom ou le nom affiché de la personne visée.
  ///
  /// [terme] n'est lu que par les issues qui parlent d'une date ; il vaut
  /// `null` partout ailleurs.
  String message(String nom, {String? terme}) => switch (this) {
    MemberOutcome.promu => '$nom est désormais administrateur.',
    MemberOutcome.retrograde => '$nom n’est plus administrateur.',
    MemberOutcome.retire => '$nom a été retiré du groupe.',
    MemberOutcome.termeDefini =>
      terme == null
          ? 'L’adhésion de $nom est désormais temporaire.'
          : '$nom fait partie du groupe jusqu’au $terme.',
    MemberOutcome.termeRetire => 'L’adhésion de $nom n’a plus de terme.',
    MemberOutcome.inchange => 'C’était déjà le cas, rien n’a changé.',
    MemberOutcome.termePasse =>
      'Cette date est déjà passée. Pour un départ immédiat, utilisez '
          '« Retirer du groupe ».',
    MemberOutcome.dejaAdmin => '$nom est déjà administrateur.',
    MemberOutcome.dernierAdmin =>
      'Un groupe doit garder au moins un administrateur. Nommez quelqu’un '
          'd’autre avant.',
    MemberOutcome.nonAdmin =>
      'Seul un administrateur du groupe peut faire cela.',
    MemberOutcome.nonAdminCible => '$nom n’est pas administrateur.',
    MemberOutcome.nonMembre => '$nom ne fait plus partie du groupe.',
    MemberOutcome.soiMeme =>
      'Pour partir vous-même, utilisez « Quitter le groupe ».',
    MemberOutcome.inconnu =>
      'L’action n’a pas abouti. Réessayez dans un instant.',
  };
}

/// Aperçu public d'un groupe, affiché avant d'accepter une invitation.
@immutable
class GroupInvitePreview {
  const GroupInvitePreview({
    required this.status,
    this.groupId,
    this.name,
    this.description,
    this.photoUrl,
    this.memberCount = 0,
    this.membershipExpiresAt,
  });

  factory GroupInvitePreview.fromRow(Map<String, dynamic> row) {
    return GroupInvitePreview(
      status: InviteLinkStatus.fromDb(row['statut'] as String?),
      groupId: row['group_id'] as String?,
      name: row['nom'] as String?,
      description: row['description'] as String?,
      photoUrl: row['photo_url'] as String?,
      memberCount: (row['nombre_membres'] as int?) ?? 0,
      membershipExpiresAt: DateTime.tryParse(
        (row['membership_expires_at'] as String?) ?? '',
      ),
    );
  }

  final InviteLinkStatus status;
  final String? groupId;
  final String? name;
  final String? description;
  final String? photoUrl;
  final int memberCount;

  /// Terme de l'adhésion que ce lien accorde ; `null` = sans terme.
  ///
  /// Annoncé **avant** d'accepter : une adhésion qui s'arrête dans dix jours
  /// n'est pas la même offre qu'une adhésion sans fin, et le découvrir après
  /// coup serait une mauvaise surprise.
  final DateTime? membershipExpiresAt;

  bool get isJoinable => status == InviteLinkStatus.valide && groupId != null;
}

/// Un lien de partage créé par un membre.
@immutable
class GroupInviteLink {
  const GroupInviteLink({
    required this.id,
    required this.groupId,
    required this.token,
    required this.expiresAt,
    this.maxUses,
    this.usesCount = 0,
    this.revokedAt,
    this.createdAt,
    this.membershipExpiresAt,
  });

  factory GroupInviteLink.fromRow(Map<String, dynamic> row) {
    return GroupInviteLink(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      token: row['token'] as String,
      expiresAt:
          DateTime.tryParse((row['expires_at'] as String?) ?? '') ??
          DateTime.now(),
      maxUses: row['max_uses'] as int?,
      usesCount: (row['uses_count'] as int?) ?? 0,
      revokedAt: DateTime.tryParse((row['revoked_at'] as String?) ?? ''),
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
      membershipExpiresAt: DateTime.tryParse(
        (row['membership_expires_at'] as String?) ?? '',
      ),
    );
  }

  final String id;
  final String groupId;
  final String token;
  final DateTime expiresAt;
  final int? maxUses;
  final int usesCount;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  /// Terme de l'adhésion accordée par ce lien ; `null` = sans terme.
  ///
  /// À ne pas confondre avec [expiresAt], qui dit jusqu'à quand **le lien**
  /// peut servir. Les deux dates n'ont ni la même portée ni, en général, la
  /// même valeur.
  final DateTime? membershipExpiresAt;

  bool get isTemporaryMembership => membershipExpiresAt != null;

  bool isActive(DateTime now) =>
      revokedAt == null &&
      expiresAt.isAfter(now) &&
      (membershipExpiresAt == null || membershipExpiresAt!.isAfter(now)) &&
      (maxUses == null || usesCount < maxUses!);

  /// Résumé affiché sous le lien : « 2 utilisations sur 5 ».
  String get usesLabel {
    final int? max = maxUses;
    if (max == null) {
      return usesCount == 0
          ? 'Jamais utilisé'
          : '$usesCount utilisation${usesCount > 1 ? 's' : ''}';
    }
    return '$usesCount utilisation${usesCount > 1 ? 's' : ''} sur $max';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GroupInviteLink && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Ce que l'écran d'une invitation nominative a le droit de proposer.
///
/// C'est un **mot d'état**, renvoyé par `invitation_par_id`, et non l'absence
/// de ligne. Une invitation refusée n'est pas une invitation qui n'existe
/// pas : dire « introuvable » dans les cinq cas envoyait chercher le défaut du
/// mauvais côté, et laissait surtout deux boutons sans effet.
enum InvitationScreenStatus {
  valide,
  acceptee,
  refusee,
  expiree,
  dejaMembre,
  groupeSupprime,
  introuvable;

  static InvitationScreenStatus fromDb(String? value) => switch (value) {
    'valide' => InvitationScreenStatus.valide,
    'acceptee' => InvitationScreenStatus.acceptee,
    'refusee' => InvitationScreenStatus.refusee,
    'expiree' => InvitationScreenStatus.expiree,
    'deja_membre' => InvitationScreenStatus.dejaMembre,
    'groupe_supprime' => InvitationScreenStatus.groupeSupprime,
    _ => InvitationScreenStatus.introuvable,
  };

  /// Seul cet état laisse répondre. Partout ailleurs l'écran explique.
  bool get peutRepondre => this == InvitationScreenStatus.valide;

  /// L'invitation a bien existé, et son groupe est toujours là : l'écran peut
  /// donc montrer la carte du groupe sous le message.
  bool get gardeLeContexte =>
      this != InvitationScreenStatus.introuvable &&
      this != InvitationScreenStatus.groupeSupprime;

  String get titre => switch (this) {
    InvitationScreenStatus.valide => '',
    InvitationScreenStatus.acceptee => 'Invitation déjà acceptée',
    InvitationScreenStatus.refusee => 'Invitation déjà refusée',
    InvitationScreenStatus.expiree => 'Invitation expirée',
    InvitationScreenStatus.dejaMembre => 'Vous êtes déjà membre',
    InvitationScreenStatus.groupeSupprime => 'Groupe supprimé',
    InvitationScreenStatus.introuvable => 'Invitation introuvable',
  };

  String get message => switch (this) {
    InvitationScreenStatus.valide => '',
    InvitationScreenStatus.acceptee =>
      'Vous avez déjà rejoint ce groupe. Ouvrez-le pour y retrouver ses '
          'événements, ses tâches et sa conversation.',
    InvitationScreenStatus.refusee =>
      'Vous avez décliné cette invitation. Demandez-en une nouvelle si vous '
          'changez d’avis.',
    InvitationScreenStatus.expiree =>
      'Cette invitation a passé sa date limite. Demandez-en une nouvelle au '
          'groupe.',
    InvitationScreenStatus.dejaMembre =>
      'Vous faites déjà partie de ce groupe, sans doute par un lien de '
          'partage.',
    InvitationScreenStatus.groupeSupprime =>
      'Le groupe qui vous invitait a été supprimé. Il n’y a plus rien à '
          'rejoindre.',
    InvitationScreenStatus.introuvable =>
      'Cette invitation n’existe pas, ou elle ne vous était pas destinée.',
  };

  IconData get icone => switch (this) {
    InvitationScreenStatus.valide => Icons.mail_outline_rounded,
    InvitationScreenStatus.acceptee => Icons.check_circle_outline_rounded,
    InvitationScreenStatus.refusee => Icons.do_not_disturb_on_outlined,
    InvitationScreenStatus.expiree => Icons.hourglass_disabled_rounded,
    InvitationScreenStatus.dejaMembre => Icons.groups_rounded,
    InvitationScreenStatus.groupeSupprime => Icons.folder_off_outlined,
    InvitationScreenStatus.introuvable => Icons.help_outline_rounded,
  };
}

/// Un membre du groupe tel que l'écran d'invitation le montre : un prénom et
/// un visage, rien de plus.
@immutable
class InvitationMember {
  const InvitationMember({required this.name, this.avatarUrl});

  factory InvitationMember.fromJson(Map<String, dynamic> json) =>
      InvitationMember(
        name: (json['nom'] as String?) ?? 'Membre',
        avatarUrl: json['avatar_url'] as String?,
      );

  final String name;
  final String? avatarUrl;
}

/// Une invitation nominative, **dans l'état où elle se trouve**.
///
/// À distinguer de [GroupInvitation], que `mes_invitations` ne renvoie que
/// tant qu'elle est en attente : celle-ci se lit encore une fois acceptée,
/// refusée, expirée ou son groupe supprimé — c'est tout son objet.
@immutable
class GroupInvitationDetail {
  const GroupInvitationDetail({
    required this.status,
    this.id,
    this.groupId,
    this.groupName,
    this.description,
    this.photoUrl,
    this.senderName,
    this.senderAvatarUrl,
    this.memberCount = 0,
    this.members = const <InvitationMember>[],
    this.groupCreatedAt,
    this.createdAt,
    this.expiresAt,
    this.membershipExpiresAt,
  });

  factory GroupInvitationDetail.fromRow(Map<String, dynamic> row) {
    final Object? membres = row['membres'];
    return GroupInvitationDetail(
      status: InvitationScreenStatus.fromDb(row['statut_ecran'] as String?),
      id: row['id'] as String?,
      groupId: row['group_id'] as String?,
      groupName: row['nom'] as String?,
      description: row['description'] as String?,
      photoUrl: row['photo_url'] as String?,
      senderName: row['emetteur'] as String?,
      senderAvatarUrl: row['emetteur_avatar'] as String?,
      memberCount: (row['nombre_membres'] as int?) ?? 0,
      members: membres is List
          ? membres
                .whereType<Map<String, dynamic>>()
                .map(InvitationMember.fromJson)
                .toList()
          : const <InvitationMember>[],
      groupCreatedAt: DateTime.tryParse(
        (row['groupe_cree_le'] as String?) ?? '',
      )?.toLocal(),
      createdAt: DateTime.tryParse(
        (row['created_at'] as String?) ?? '',
      )?.toLocal(),
      expiresAt: DateTime.tryParse(
        (row['expires_at'] as String?) ?? '',
      )?.toLocal(),
      membershipExpiresAt: DateTime.tryParse(
        (row['membership_expires_at'] as String?) ?? '',
      )?.toLocal(),
    );
  }

  final InvitationScreenStatus status;
  final String? id;
  final String? groupId;
  final String? groupName;
  final String? description;
  final String? photoUrl;
  final String? senderName;
  final String? senderAvatarUrl;
  final int memberCount;
  final List<InvitationMember> members;

  /// Date de création **du groupe**, à ne pas confondre avec [createdAt], qui
  /// est celle de l'invitation.
  final DateTime? groupCreatedAt;

  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? membershipExpiresAt;

  String get displaySender => senderName ?? 'Un membre';

  String get displayGroupName => groupName ?? 'ce groupe';

  String get memberLabel => '$memberCount membre${memberCount > 1 ? 's' : ''}';
}

/// Invitation nominative reçue, prête à être affichée.
@immutable
class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.senderName,
    this.description,
    this.photoUrl,
    this.senderAvatarUrl,
    this.memberCount = 0,
    this.memberNames = const <String>[],
    this.createdAt,
    this.expiresAt,
    this.membershipExpiresAt,
  });

  factory GroupInvitation.fromRow(Map<String, dynamic> row) {
    return GroupInvitation(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      groupName: (row['nom'] as String?) ?? 'Groupe',
      senderName: (row['emetteur'] as String?) ?? 'Un membre',
      description: row['description'] as String?,
      photoUrl: row['photo_url'] as String?,
      senderAvatarUrl: row['emetteur_avatar'] as String?,
      memberCount: (row['nombre_membres'] as int?) ?? 0,
      memberNames:
          (row['membres_apercu'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
      expiresAt: DateTime.tryParse((row['expires_at'] as String?) ?? ''),
      membershipExpiresAt: DateTime.tryParse(
        (row['membership_expires_at'] as String?) ?? '',
      ),
    );
  }

  final String id;
  final String groupId;
  final String groupName;
  final String senderName;
  final String? description;
  final String? photoUrl;
  final String? senderAvatarUrl;
  final int memberCount;

  /// Quelques prénoms, pour situer le groupe avant d'accepter.
  final List<String> memberNames;

  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Terme de l'adhésion proposée ; `null` = adhésion permanente.
  final DateTime? membershipExpiresAt;

  String get memberLabel => '$memberCount membre${memberCount > 1 ? 's' : ''}';

  bool isExpired(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GroupInvitation && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
