import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../calendar/widgets/event_form_sheet.dart';
import '../../chat/providers/chat_providers.dart';
import '../../contacts/models/contact.dart';
import '../../contacts/providers/contact_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/widgets/task_form_sheet.dart';
import '../../tasks/widgets/task_tile.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../models/group_member.dart';
import '../providers/group_providers.dart';

import '../widgets/invite_link_sheet.dart';
import '../widgets/member_tile.dart';
import '../widgets/membership_term_picker.dart';
import '../widgets/membership_term_sheet.dart';

/// Écran d'un groupe : bandeau photo, description, membres et actions.
///
/// Les actions dépendent du rôle : un membre peut inviter et quitter, un admin
/// peut en plus modifier, gérer les membres et supprimer.
/// Ouvre la feuille du lien d'invitation d'un groupe.
///
/// Hors de `_GroupView` parce que deux appelants la demandent : le bouton de
/// l'écran, et l'arrivée avec `?lien=1` juste après une création.
void ouvrirFeuilleDeLien(BuildContext context, Group group) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => InviteLinkSheet(group: group),
  );
}

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.ouvrirLeLien = false,
  });

  final String groupId;

  /// Ouvre la feuille du lien d'invitation dès l'arrivée.
  ///
  /// Posé par `?lien=1`, que l'écran de création ajoute quand on a choisi
  /// « Inviter par lien » : le lien se tire sur un groupe qui existe, donc
  /// après la création et pas avant.
  final bool ouvrirLeLien;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  /// Une seule fois : revenir sur cet écran ne doit pas rouvrir la feuille.
  bool _lienOuvert = false;

  @override
  Widget build(BuildContext context) {
    final String groupId = widget.groupId;
    final AsyncValue<Group?> groupAsync = ref.watch(
      groupDetailProvider(groupId),
    );

    final Group? charge = groupAsync.value;
    if (widget.ouvrirLeLien && !_lienOuvert && charge != null) {
      _lienOuvert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ouvrirFeuilleDeLien(context, charge);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => SafeArea(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Groupe indisponible',
            message: AuthFailure.from(error).message,
            actionLabel: 'Réessayer',
            onActionPressed: () => ref.invalidate(groupDetailProvider(groupId)),
          ),
        ),
        data: (Group? group) {
          if (group == null) {
            return SafeArea(
              child: EmptyState(
                icon: Icons.group_off_outlined,
                title: 'Groupe introuvable',
                message:
                    'Ce groupe a été supprimé, ou vous n’en faites plus '
                    'partie.',
                actionLabel: 'Revenir aux groupes',
                onActionPressed: () => context.goNamed(AppRoutes.groups),
              ),
            );
          }
          return _GroupView(group: group);
        },
      ),
    );
  }
}

class _GroupView extends ConsumerWidget {
  const _GroupView({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupMember>> membersAsync = ref.watch(
      groupMembersProvider(group.id),
    );
    final List<GroupMember> members =
        membersAsync.value ?? const <GroupMember>[];
    final String? myId = ref.watch(currentUserIdProvider);

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          backgroundColor: AppColors.surface,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Retour',
            onPressed: () => _goBack(context),
          ),
          actions: <Widget>[
            if (group.isAdmin)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier le groupe',
                onPressed: () => context.pushNamed(
                  AppRoutes.groupEdit,
                  pathParameters: <String, String>{'id': group.id},
                ),
              ),
            PopupMenuButton<_GroupAction>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (_GroupAction action) => switch (action) {
                _GroupAction.leave => _confirmLeave(context, ref),
                _GroupAction.delete => _confirmDelete(context, ref),
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_GroupAction>>[
                    const PopupMenuItem<_GroupAction>(
                      value: _GroupAction.leave,
                      child: Text('Quitter le groupe'),
                    ),
                    if (group.isAdmin)
                      const PopupMenuItem<_GroupAction>(
                        value: _GroupAction.delete,
                        child: Text('Supprimer le groupe'),
                      ),
                  ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: CoverBanner(
              name: group.name,
              subtitle: group.memberLabel,
              accentColor: group.accent.color,
              icon: group.icon,
              photoUrl: group.photoUrl,
              height: 200,
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (group.description != null &&
                    group.description!.isNotEmpty) ...<Widget>[
                  Text(group.description!, style: AppTypography.bodyMuted),
                  AppSpacing.gapLg,
                ],
                _LigneDiscussion(groupId: group.id),
                AppSpacing.gapLg,
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PrimaryButton(
                        label: 'Inviter',
                        icon: Icons.person_add_alt_rounded,
                        onPressed: () => _openInviteSheet(context),
                      ),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: SecondaryButton(
                        label: 'Partager un lien',
                        icon: Icons.link_rounded,
                        onPressed: () => _openLinkSheet(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        ..._agendaSlivers(context, ref, group),
        ..._tachesSlivers(context, ref, group),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Membres',
              subtitle: group.isAdmin
                  ? '${group.memberLabel} · vous administrez ce groupe'
                  : group.memberLabel,
            ),
          ),
        ),

        if (membersAsync.isLoading && members.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (members.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'Aucun membre à afficher',
              message:
                  'La liste des membres n’a pas pu être chargée. Réessayez '
                  'dans un instant.',
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: members.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (BuildContext context, int index) {
                final GroupMember member = members[index];
                return MemberTile(
                  member: member,
                  isMe: member.userId == myId,
                  canManage: group.isAdmin,
                  onPromote: () => _administrer(
                    context,
                    ref,
                    member,
                    (GroupActions a) =>
                        a.promote(groupId: group.id, userId: member.userId),
                  ),
                  onDemote: () => _administrer(
                    context,
                    ref,
                    member,
                    (GroupActions a) =>
                        a.demote(groupId: group.id, userId: member.userId),
                  ),
                  onRemove: () => _confirmRemove(context, ref, member),
                  onEditTerm: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        MembershipTermSheet(groupId: group.id, member: member),
                  ),
                );
              },
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }

  /// Section « À venir » : les événements du groupe encore devant nous.
  List<Widget> _agendaSlivers(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) {
    final DateTime now = ref.watch(nowProvider);
    final List<CalendarEvent> events =
        ref
            .watch(eventsForGroupProvider(group.id))
            .where((CalendarEvent e) => e.end.isAfter(now))
            .toList()
          ..sort(
            (CalendarEvent a, CalendarEvent b) => a.start.compareTo(b.start),
          );

    return <Widget>[
      _header(
        title: 'À venir',
        subtitle: events.isEmpty
            ? 'Rien de prévu'
            : '${events.length} événement${events.length > 1 ? 's' : ''}',
        actionLabel: 'Ajouter',
        onActionPressed: () =>
            ouvrirFormulaireDEvenement(context, groupId: group.id),
      ),
      if (events.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Aucun événement',
            message:
                'Proposez une date au groupe : chacun répondra oui, '
                'peut-être ou non.',
            actionLabel: 'Proposer une date',
            onActionPressed: () =>
                ouvrirFormulaireDEvenement(context, groupId: group.id),
          ),
        )
      else
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverList.separated(
            itemCount: events.length > 3 ? 3 : events.length,
            separatorBuilder: (_, _) => AppSpacing.gapMd,
            itemBuilder: (BuildContext context, int index) {
              final CalendarEvent event = events[index];
              return EventCard(
                title: event.title,
                timeLabel:
                    '${AppDates.relativeDay(event.start, now: now)} · '
                    '${AppDates.timeRange(event.start, event.end)}',
                location: event.location,
                accentColor: group.accent.color,
                participants: event.avatars,
                statusTone: event.myResponse == EventResponse.yes
                    ? null
                    : event.myResponse.tone,
                statusLabel: event.myResponse.label,
                onTap: () => context.pushNamed(
                  AppRoutes.eventDetail,
                  pathParameters: <String, String>{'id': event.id},
                ),
              );
            },
          ),
        ),
    ];
  }

  /// Section « Tâches à faire » : les tâches ouvertes du groupe.
  List<Widget> _tachesSlivers(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) {
    final DateTime now = ref.watch(nowProvider);
    final List<Task> tasks = ref
        .watch(tasksForGroupProvider(group.id))
        .where((Task t) => !t.isDone)
        .toList();

    return <Widget>[
      _header(
        title: 'Tâches à faire',
        subtitle: tasks.isEmpty
            ? 'Tout est à jour'
            : '${tasks.length} tâche${tasks.length > 1 ? 's' : ''} ouverte'
                  '${tasks.length > 1 ? 's' : ''}',
        actionLabel: 'Ajouter',
        onActionPressed: () =>
            ouvrirFormulaireDeTache(context, groupId: group.id),
      ),
      if (tasks.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Aucune tâche ouverte',
            message: 'Répartissez ce qu’il y a à faire : chacun verra sa part.',
            actionLabel: 'Ajouter une tâche',
            onActionPressed: () =>
                ouvrirFormulaireDeTache(context, groupId: group.id),
          ),
        )
      else
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < tasks.length; i++)
                    TaskTile(
                      task: tasks[i],
                      now: now,
                      showDivider: i < tasks.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  static Widget _header({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.xl,
        AppSpacing.screenMargin,
        AppSpacing.md,
      ),
      sliver: SliverToBoxAdapter(
        child: SectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.groups);
    }
  }

  void _openLinkSheet(BuildContext context) =>
      ouvrirFeuilleDeLien(context, group);

  void _openInviteSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InviteMemberSheet(group: group),
    );
  }

  /// Toutes les actions d'administration passent par ici : elles renvoient un
  /// mot d'état, et c'est lui — non l'absence d'exception — qui dit si quelque
  /// chose a changé. L'écriture directe précédente répondait 200 sans rien
  /// faire, et l'écran annonçait une promotion qui n'avait pas eu lieu.
  Future<void> _administrer(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    Future<MemberOutcome> Function(GroupActions) action,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final MemberOutcome outcome = await action(
        ref.read(groupActionsProvider),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(outcome.message(member.shortName))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Retirer ce membre',
      message:
          '${member.displayName} n\u2019aura plus accès au groupe. Vous pourrez '
          'l\u2019inviter à nouveau plus tard.',
      confirmLabel: 'Retirer',
    );
    if (!confirmed || !context.mounted) return;

    await _administrer(
      context,
      ref,
      member,
      (GroupActions a) =>
          a.removeMember(groupId: group.id, userId: member.userId),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GoRouter router = GoRouter.of(context);
    final bool confirmed = await _confirm(
      context,
      title: 'Quitter le groupe',
      message:
          'Vous ne verrez plus « ${group.name} ». Si vous en êtes le dernier '
          'administrateur, le plus ancien membre prendra le relais.',
      confirmLabel: 'Quitter',
    );
    if (!confirmed) return;

    try {
      final LeaveOutcome outcome = await ref
          .read(groupActionsProvider)
          .leave(group.id);
      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
      router.goNamed(AppRoutes.groups);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GoRouter router = GoRouter.of(context);
    final bool confirmed = await _confirm(
      context,
      title: 'Supprimer le groupe',
      message:
          '« ${group.name} » disparaîtra pour tous ses membres. Cette action '
          'ne peut pas être annulée depuis l’application.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed) return;

    try {
      await ref.read(groupActionsProvider).delete(group.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Le groupe a été supprimé.')),
      );
      router.goNamed(AppRoutes.groups);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }
}

/// Entrée vers la conversation du groupe.
///
/// Elle est posée **au-dessus** des boutons d'invitation, et non reléguée dans
/// une section plus bas : c'est ce qu'on vient ouvrir le plus souvent, et un
/// groupe se vit d'abord par sa discussion.
class _LigneDiscussion extends ConsumerWidget {
  const _LigneDiscussion({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int nonLus = ref.watch(unreadForGroupProvider(groupId));

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoutes.groupChat,
          pathParameters: <String, String>{'id': groupId},
        ),
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              NavBadge(
                count: nonLus,
                child: const Icon(
                  Icons.forum_outlined,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Discussion', style: AppTypography.h3),
                    const SizedBox(height: 2),
                    Text(
                      nonLus == 0
                          ? 'La conversation du groupe'
                          : '$nonLus message${nonLus > 1 ? 's' : ''} non lu'
                                '${nonLus > 1 ? 's' : ''}',
                      style: AppTypography.caption.copyWith(
                        color: nonLus == 0
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GroupAction { leave, delete }

/// Invitation nominative : recherche d'un pseudo déjà inscrit.
class _InviteMemberSheet extends ConsumerStatefulWidget {
  const _InviteMemberSheet({required this.group});

  final Group group;

  @override
  ConsumerState<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<_InviteMemberSheet> {
  final TextEditingController _controller = TextEditingController();
  String _term = '';
  String? _message;

  /// Terme de l'adhésion proposée ; `null` = permanente, et c'est le défaut.
  DateTime? _terme;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Inviter un membre', style: AppTypography.h2),
          AppSpacing.gapSm,
          Text(
            'Cherchez la personne par son pseudo. Elle recevra une invitation '
            'à accepter.',
            style: AppTypography.bodyMuted,
          ),

          // Fixer une durée relève de l'administration du groupe, et la base
          // le refuse à quiconque n'est pas admin : autant ne pas proposer un
          // réglage qui serait rejeté.
          if (widget.group.isAdmin) ...<Widget>[
            AppSpacing.gapXl,
            MembershipTermPicker(
              now: ref.watch(nowProvider),
              value: _terme,
              onChanged: (DateTime? valeur) => setState(() {
                _terme = valeur;
                _message = null;
              }),
            ),
          ],

          AppSpacing.gapXl,
          AppTextField(
            controller: _controller,
            hint: 'pseudo',
            prefixIcon: Icons.alternate_email_rounded,
            autofocus: true,
            onChanged: (String value) => setState(() {
              _term = value;
              _message = null;
            }),
          ),
          AppSpacing.gapLg,
          if (_message != null)
            Text(
              _message!,
              style: AppTypography.caption.copyWith(color: AppColors.primary),
            ),
          _Results(term: _term, onPick: _invite),
        ],
      ),
    );
  }

  Future<void> _invite(String userId, String name) async {
    try {
      final String outcome = await ref
          .read(groupActionsProvider)
          .invite(
            groupId: widget.group.id,
            userId: userId,
            membershipExpiresAt: _terme,
          );
      if (!mounted) return;
      final DateTime? terme = _terme;
      setState(() {
        _message = switch (outcome) {
          'invite' when terme != null =>
            '$name a reçu votre invitation, jusqu’au '
                '${AppDates.shortDate(terme)}.',
          'invite' => '$name a reçu votre invitation.',
          'deja_membre' => '$name fait déjà partie du groupe.',
          'deja_invite' => '$name a déjà une invitation en attente.',
          'terme_passe' => 'La date de fin choisie est déjà passée.',
          'non_admin' =>
            'Seul un administrateur peut fixer une durée d’adhésion.',
          _ => 'Seuls les membres du groupe peuvent inviter.',
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = AuthFailure.from(error).message);
    }
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.term, required this.onPick});

  final String term;
  final Future<void> Function(String userId, String name) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (term.trim().length < 2) {
      return Text(
        'Saisissez au moins deux caractères.',
        style: AppTypography.caption,
      );
    }

    final AsyncValue<List<ProfileSummary>> results = ref.watch(
      pseudoSearchProvider(term),
    );

    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, _) => Text(
        AuthFailure.from(error).message,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
      data: (List<ProfileSummary> profiles) {
        if (profiles.isEmpty) {
          return Text(
            'Aucun pseudo ne commence par « $term ».',
            style: AppTypography.caption,
          );
        }
        return Column(
          children: <Widget>[
            for (final ProfileSummary profile in profiles) ...<Widget>[
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    AvatarStack(
                      avatars: <AvatarData>[
                        AvatarData(
                          name: profile.fullName,
                          imageUrl: profile.avatarUrl,
                        ),
                      ],
                      size: 36,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile.fullName,
                            style: AppTypography.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            profile.pseudoHandle,
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onPick(profile.id, profile.fullName),
                      child: const Text('Inviter'),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
            ],
          ],
        );
      },
    );
  }
}
