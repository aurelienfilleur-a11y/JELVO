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
import '../../notifications/providers/notification_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/widgets/task_form_sheet.dart';
import '../../tasks/widgets/task_tile.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../models/group_member.dart';
import '../providers/group_providers.dart';

import '../widgets/group_header.dart';
import '../widgets/group_quick_actions.dart';
import '../widgets/group_stats_row.dart';
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

    final GroupStats stats = ref.watch(groupStatsProvider(group.id));
    final int nonLues = ref.watch(unreadCountProvider);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: GroupHeader(
            group: group,
            membres: members,
            notificationsNonLues: nonLues,
            onBack: () => _goBack(context),
            onNotifications: () => context.pushNamed(AppRoutes.notifications),
            menu: PopupMenuButton<_GroupAction>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (_GroupAction action) => switch (action) {
                _GroupAction.invite => _openInviteSheet(context),
                _GroupAction.link => _openLinkSheet(context),
                _GroupAction.edit => context.pushNamed(
                  AppRoutes.groupEdit,
                  pathParameters: <String, String>{'id': group.id},
                ),
                _GroupAction.leave => _confirmLeave(context, ref),
                _GroupAction.delete => _confirmDelete(context, ref),
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_GroupAction>>[
                    const PopupMenuItem<_GroupAction>(
                      value: _GroupAction.invite,
                      child: Text('Inviter quelqu’un'),
                    ),
                    const PopupMenuItem<_GroupAction>(
                      value: _GroupAction.link,
                      child: Text('Partager un lien'),
                    ),
                    if (group.isAdmin)
                      const PopupMenuItem<_GroupAction>(
                        value: _GroupAction.edit,
                        child: Text('Modifier le groupe'),
                      ),
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
                _Description(group: group),
                AppSpacing.gapLg,

                GroupStatsRow(
                  tachesEnRetard: stats.tachesEnRetard,
                  evenementsAVenir: stats.evenementsAVenir,
                  onTachesPressed: () => _ouvrirLesTaches(context, group),
                  onEvenementsPressed: () =>
                      _ouvrirLeCalendrier(context, ref, group),
                ),
                AppSpacing.gapMd,

                GroupQuickActions(
                  actions: <GroupQuickAction>[
                    GroupQuickAction(
                      icon: Icons.forum_outlined,
                      label: 'Discussion',
                      badge: ref.watch(unreadForGroupProvider(group.id)),
                      onPressed: () => context.pushNamed(
                        AppRoutes.groupChat,
                        pathParameters: <String, String>{'id': group.id},
                      ),
                    ),
                    GroupQuickAction(
                      icon: Icons.task_alt_rounded,
                      label: 'Tâches',
                      onPressed: () => _ouvrirLesTaches(context, group),
                    ),
                    GroupQuickAction(
                      icon: Icons.calendar_month_rounded,
                      label: 'Événements',
                      onPressed: () => _ouvrirLeCalendrier(context, ref, group),
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
      // « Voir tout » plutôt que « Ajouter » : c'est le lien de la maquette, et
      // il mène au calendrier filtré sur ce groupe — soit exactement la liste
      // complète que cette section abrège. Ajouter reste à une touche par le
      // « + » de la barre et par l'état vide.
      _header(
        title: 'À venir',
        subtitle: events.isEmpty
            ? 'Rien de prévu'
            : '${events.length} événement${events.length > 1 ? 's' : ''}',
        actionLabel: events.isEmpty ? null : 'Voir tout',
        onActionPressed: events.isEmpty
            ? null
            : () => _ouvrirLeCalendrier(context, ref, group),
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
      else ...<Widget>[
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
        _AjouterSliver(
          semantique: 'Ajouter un événement',
          onPressed: () =>
              ouvrirFormulaireDEvenement(context, groupId: group.id),
        ),
      ],
    ];
  }

  /// Section « Tâches à faire » : les tâches ouvertes du groupe.
  List<Widget> _tachesSlivers(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) {
    final DateTime now = ref.watch(nowProvider);

    // **Prioritaires, donc triées** : priorité décroissante, puis échéance la
    // plus proche, les tâches sans échéance en dernier. Sans ce tri, « Tâches
    // prioritaires » ne serait qu'un autre nom pour « toutes les tâches ».
    final List<Task> tasks =
        ref
            .watch(tasksForGroupProvider(group.id))
            .where((Task t) => !t.isDone)
            .toList()
          ..sort((Task a, Task b) {
            final int parPriorite = b.priority.index.compareTo(
              a.priority.index,
            );
            if (parPriorite != 0) return parPriorite;
            return switch ((a.dueDate, b.dueDate)) {
              (null, null) => 0,
              (null, _) => 1,
              (_, null) => -1,
              (final DateTime x, final DateTime y) => x.compareTo(y),
            };
          });

    return <Widget>[
      _header(
        title: 'Tâches prioritaires',
        subtitle: tasks.isEmpty
            ? 'Tout est à jour'
            : '${tasks.length} tâche${tasks.length > 1 ? 's' : ''} ouverte'
                  '${tasks.length > 1 ? 's' : ''}',
        actionLabel: tasks.isEmpty ? null : 'Voir tout',
        onActionPressed: tasks.isEmpty
            ? null
            : () => _ouvrirLesTaches(context, group),
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
      else ...<Widget>[
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  // Trois au plus : la section abrège, « Voir tout » ouvre la
                  // liste complète du groupe.
                  for (int i = 0; i < tasks.length && i < 3; i++)
                    TaskTile(
                      task: tasks[i],
                      now: now,
                      showPriority: true,
                      showDivider: i < tasks.length - 1 && i < 2,
                    ),
                ],
              ),
            ),
          ),
        ),
        _AjouterSliver(
          semantique: 'Ajouter une tâche',
          onPressed: () => ouvrirFormulaireDeTache(context, groupId: group.id),
        ),
      ],
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

  /// Ouvre la liste des tâches **de ce groupe**.
  ///
  /// `?groupe=…` plutôt que la liste entière : une section qui n'annonçait que
  /// les tâches de ce groupe ne doit pas ouvrir celles de tous les autres.
  static void _ouvrirLesTaches(BuildContext context, Group group) {
    context.pushNamed(
      AppRoutes.tasks,
      queryParameters: <String, String>{AppRoutes.tasksGroupParam: group.id},
    );
  }

  /// Ouvre le calendrier **filtré sur ce groupe**.
  ///
  /// Le filtre par groupe existait déjà : il n'y a qu'à le poser avant de
  /// naviguer, plutôt que d'inventer un écran d'événements par groupe.
  static void _ouvrirLeCalendrier(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) {
    ref.read(calendarFilterProvider.notifier).clear();
    ref.read(calendarFilterProvider.notifier).toggle(group.id);
    context.goNamed(AppRoutes.calendar);
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

enum _GroupAction { invite, link, edit, leave, delete }

/// Le « Ajouter » posé sous une section pleine.
///
/// **Le « + » de la barre n'est jamais le seul chemin.** Le lien de l'en-tête
/// dit « Voir tout » — c'est la maquette, et il ouvre la liste complète —, si
/// bien que sans cette ligne, créer depuis une section pleine ne passerait plus
/// que par un bouton d'icône. L'état vide, lui, porte déjà son action.
class _AjouterSliver extends StatelessWidget {
  const _AjouterSliver({required this.semantique, required this.onPressed});

  /// Ce qu'annonce un lecteur d'écran : « Ajouter » seul ne dirait pas quoi.
  final String semantique;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.sm,
        AppSpacing.screenMargin,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Semantics(
          button: true,
          label: semantique,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadii.fieldRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  AppSpacing.hGapXs,
                  Text(
                    'Ajouter',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La description du groupe, et le crayon qui mène à sa modification.
///
/// **Le crayon n'apparaît que pour un administrateur** : `groups` n'est
/// modifiable que par eux, et un crayon qui ouvrirait un formulaire refusé par
/// la base serait pire qu'une ligne inerte.
///
/// Sans description, la ligne invite à en écrire une plutôt que de disparaître
/// — un groupe sans description laisserait sinon un vide inexpliqué entre le
/// bandeau et les compteurs. Pour un membre non administrateur, en revanche,
/// elle s'efface : il n'y a ni texte à lire, ni geste à proposer.
class _Description extends StatelessWidget {
  const _Description({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final String? texte = group.description?.trim();
    final bool vide = texte == null || texte.isEmpty;
    if (vide && !group.isAdmin) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            vide ? 'Décrivez ce groupe en une phrase.' : texte,
            style: vide
                ? AppTypography.bodyMuted.copyWith(fontStyle: FontStyle.italic)
                : AppTypography.bodyMuted,
          ),
        ),
        if (group.isAdmin) ...<Widget>[
          AppSpacing.hGapSm,
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.primary,
            tooltip: 'Modifier le groupe',
            visualDensity: VisualDensity.compact,
            onPressed: () => context.pushNamed(
              AppRoutes.groupEdit,
              pathParameters: <String, String>{'id': group.id},
            ),
          ),
        ],
      ],
    );
  }
}

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
