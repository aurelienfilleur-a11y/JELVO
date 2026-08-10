import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../calendar/widgets/response_buttons.dart';
import '../models/app_notification.dart';
import '../providers/notification_providers.dart';

/// Boîte de notifications : invitations de groupe, demandes de contact et
/// invitations à un événement.
///
/// La liste est **relue à chaque ouverture**. `notificationsProvider` n'est pas
/// `autoDispose` — il garde son état d'une visite à l'autre —, et plusieurs
/// déclencheurs referment des notifications côté base sans que l'application en
/// soit avertie : une invitation acceptée ailleurs, un événement auquel on a
/// répondu depuis son écran de détail. Sans cette relecture, la boîte affiche
/// ce qui était vrai la première fois qu'on l'a ouverte.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Riverpod 3 interdit d'écrire dans un provider pendant un cycle de vie du
    // widget : la relecture est reportée après la première image.
    Future<void>.microtask(() {
      if (mounted) ref.read(notificationsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> notificationsAsync = ref.watch(
      notificationsProvider,
    );
    final List<AppNotification> notifications =
        notificationsAsync.value ?? const <AppNotification>[];
    final int unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context),
              child: const Text('Tout marquer comme lu'),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
          child: _body(context, ref, notificationsAsync, notifications),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AppNotification>> async,
    List<AppNotification> notifications,
  ) {
    if (async.isLoading && notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (async.hasError && notifications.isEmpty) {
      return _scrollable(
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Notifications indisponibles',
          message: AuthFailure.from(async.error!).message,
          actionLabel: 'Réessayer',
          onActionPressed: () =>
              ref.read(notificationsProvider.notifier).refresh(),
        ),
      );
    }
    if (notifications.isEmpty) {
      return _scrollable(
        const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Aucune notification',
          message:
              'Les invitations à un groupe et les demandes de contact '
              'apparaîtront ici.',
        ),
      );
    }

    final DateTime now = ref.watch(nowProvider);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => AppSpacing.gapSm,
      itemBuilder: (BuildContext context, int index) {
        final AppNotification notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          now: now,
          onTap: () => _open(context, notification),
          // Répondre à un événement se fait ici : c'est dans la notification
          // qu'on apprend l'invitation, et l'obligation d'ouvrir le détail
          // pour dire « oui » était un détour de trop.
          reponse:
              notification.type == NotificationType.eventInvitation &&
                  notification.eventId != null
              ? _ReponseEvenement(eventId: notification.eventId!)
              : null,
        );
      },
    );
  }

  /// Enveloppe un état vide dans une zone défilante, sans quoi le geste de
  /// rafraîchissement n'aurait rien à quoi s'accrocher.
  Widget _scrollable(Widget child) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
  );

  Future<void> _markAllRead(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationActionsProvider).markAllRead();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  Future<void> _open(BuildContext context, AppNotification notification) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GoRouter router = GoRouter.of(context);

    if (notification.isUnread) {
      try {
        await ref.read(notificationActionsProvider).markRead(notification.id);
      } catch (error) {
        // Le marquage n'est pas le but du geste : on prévient sans bloquer la
        // navigation vers l'élément concerné.
        messenger.showSnackBar(
          SnackBar(content: Text(AuthFailure.from(error).message)),
        );
      }
    }

    switch (notification.type) {
      case NotificationType.groupInvitation:
        final String? invitationId = notification.invitationId;
        if (invitationId == null) {
          router.pushNamed(AppRoutes.invitations);
        } else {
          router.pushNamed(
            AppRoutes.invitation,
            pathParameters: <String, String>{'id': invitationId},
          );
        }
      case NotificationType.contactRequest:
        router.goNamed(AppRoutes.contacts);
      case NotificationType.eventInvitation:
        final String? eventId = notification.eventId;
        if (eventId != null) {
          router.pushNamed(
            AppRoutes.eventDetail,
            pathParameters: <String, String>{'id': eventId},
          );
        }
      case NotificationType.autre:
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.now,
    required this.onTap,
    this.reponse,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  /// Bloc de réponse affiché sous la ligne, pour les types qui en attendent
  /// une. `null` partout ailleurs.
  final Widget? reponse;

  @override
  Widget build(BuildContext context) {
    final NotificationType type = notification.type;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: type.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Icon(type.icon, size: 20, color: type.accent),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notification.title,
                      style: AppTypography.body.copyWith(
                        fontWeight: notification.isUnread
                            ? AppTypography.semiBold
                            : AppTypography.medium,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification.createdAt != null) ...<Widget>[
                      AppSpacing.gapXs,
                      Text(
                        AppDates.relativeDay(notification.createdAt!, now: now),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (notification.isUnread) ...<Widget>[
                AppSpacing.hGapSm,
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          if (reponse != null) ...<Widget>[AppSpacing.gapMd, reponse!],
        ],
      ),
    );
  }
}

/// Les trois réponses posées directement dans la notification.
class _ReponseEvenement extends ConsumerWidget {
  const _ReponseEvenement({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarEvent? event = ref.watch(eventByIdProvider(eventId));

    return ResponseButtons(
      compact: true,
      courante: event?.myResponse ?? EventResponse.pending,
      onRepondre: (EventResponse reponse) async {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(eventActionsProvider).respond(eventId, reponse);
          messenger.showSnackBar(
            SnackBar(content: Text('Réponse enregistrée : ${reponse.label}.')),
          );
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text(AuthFailure.from(error).message)),
          );
        }
      },
    );
  }
}
