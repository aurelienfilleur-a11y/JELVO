import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/ouvrir_profil.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/calendar_event.dart';
import '../models/recurrence.dart';
import '../providers/calendar_providers.dart';
import '../widgets/event_form_sheet.dart';
import '../widgets/response_buttons.dart';

/// Détail d'un événement : ce qu'il est, qui vient, et la réponse à donner.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarEvent? event = ref.watch(eventByIdProvider(eventId));
    final String? moi = ref.watch(currentUserIdProvider);
    final Group? group = event?.groupId == null
        ? null
        : ref.watch(groupByIdProvider(event!.groupId!));

    // Modifier et supprimer engagent tous les participants : réservé au
    // propriétaire et aux admins du groupe, comme côté SQL.
    final bool jePeuxModifier =
        event != null && (event.ownerId == moi || (group?.isAdmin ?? false));

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: Text(AppTexts.of(context).createEvenement),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppTexts.of(context).commonBack,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoutes.calendar),
        ),
        actions: <Widget>[
          if (jePeuxModifier)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: AppTexts.of(context).calendarModifierEvenement,
              onPressed: () =>
                  ouvrirFormulaireDEvenement(context, event: event),
            ),
          if (jePeuxModifier)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: AppTexts.of(context).calendarSupprimerEvenement,
              onPressed: () => _confirmerSuppression(context, ref, event),
            ),
        ],
      ),
      body: event == null
          ? SafeArea(
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: AppTexts.of(context).calendarEvenementIntrouvable,
                message: AppTexts.of(context).calendarEteSupprimeAvezAcces,
                actionLabel: AppTexts.of(context).commonBack,
                onActionPressed: () => context.canPop()
                    ? context.pop()
                    : context.goNamed(AppRoutes.calendar),
              ),
            )
          : _Corps(event: event, group: group, moi: moi),
    );
  }

  Future<void> _confirmerSuppression(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    // Lu **avant** l’attente : le contexte peut avoir disparu après.
    final AppTexts t = AppTexts.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirme = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppTexts.of(context).calendarSupprimerEvenement),
        content: Text(
          AppTexts.of(context).calendarSupprimerConfirmation(event.title),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.couleurs.danger,
            ),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await ref.read(eventActionsProvider).remove(event.id);
      messenger.showSnackBar(
        SnackBar(content: Text(t.calendarEvenementSupprime(event.title))),
      );
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message(t))),
      );
    }
  }
}

class _Corps extends ConsumerWidget {
  const _Corps({required this.event, required this.group, required this.moi});

  final CalendarEvent event;
  final Group? group;
  final String? moi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTexts t = AppTexts.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              EmojiText(event.title, style: context.typo.h2),
              AppSpacing.gapSm,
              Text(
                t.coreJourEtHeure(
                  AppDates.fullDate(event.start, t),
                  AppDates.timeRange(event.start, event.end, t),
                ),
                style: context.typo.bodyMuted,
              ),
              if (event.notes != null && event.notes!.isNotEmpty) ...<Widget>[
                AppSpacing.gapMd,
                EmojiText(event.notes!, style: context.typo.bodyMuted),
              ],
            ],
          ),
        ),

        AppSpacing.gapLg,
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: <Widget>[
              _Ligne(
                icon: Icons.place_outlined,
                label: t.coreLieu,
                value:
                    event.location ?? AppTexts.of(context).calendarNonPrecise,
              ),
              _Ligne(
                icon: Icons.groups_outlined,
                label: t.createGroupField,
                value:
                    group?.name ??
                    (event.isPersonal ? t.calendarPersonnel : '—'),
              ),
              if (event.reminderMinutes != null)
                _Ligne(
                  icon: Icons.notifications_none_rounded,
                  label: t.calendarRappel,
                  value: ReminderOffset.fromMinutes(
                    event.reminderMinutes,
                  ).label(AppTexts.of(context)),
                ),
              if (event.isRecurring)
                _Ligne(
                  icon: Icons.repeat_rounded,
                  label: t.coreRepetition,
                  value: Recurrence.fromRrule(
                    event.rrule,
                  ).label(AppTexts.of(context)),
                  dernier: true,
                ),
            ],
          ),
        ),

        // Un rendez-vous personnel n'a personne à convier : ni réponse à
        // donner, ni liste à afficher.
        if (!event.isPersonal) ...<Widget>[
          AppSpacing.gapLg,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTexts.of(context).calendarReponse,
                  style: context.typo.h3,
                ),
                AppSpacing.gapMd,
                ResponseButtons(
                  courante: event.myResponse,
                  onRepondre: (EventResponse reponse) =>
                      _repondre(context, ref, reponse),
                ),
              ],
            ),
          ),

          AppSpacing.gapLg,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        t.calendarParticipants,
                        style: context.typo.h3,
                      ),
                    ),
                    Text(
                      t.calendarOuiCount(event.yesCount),
                      style: context.typo.caption,
                    ),
                  ],
                ),
                AppSpacing.gapMd,
                if (event.participants.isEmpty)
                  Text(
                    AppTexts.of(context).calendarPersonneEncoreEteConvie,
                    style: context.typo.bodyMuted,
                  )
                else
                  for (final EventParticipant p in event.participants)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      // L'avatar et le nom ouvrent le profil du convive ; la
                      // pastille de réponse, à droite, n'est pas une cible.
                      child: Row(
                        children: <Widget>[
                          GestureDetector(
                            onTap: () => context.ouvrirProfilDe(p.userId),
                            child: AvatarStack(
                              avatars: <AvatarData>[
                                AvatarData(
                                  name: p.displayName(t),
                                  imageUrl: p.avatarUrl,
                                ),
                              ],
                              size: 32,
                            ),
                          ),
                          AppSpacing.hGapMd,
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.ouvrirProfilDe(p.userId),
                              child: EmojiText(
                                p.userId == moi
                                    ? t.coreVous(p.displayName(t))
                                    : p.displayName(t),
                                style: context.typo.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          AppSpacing.hGapSm,
                          StatusDot(
                            tone: p.response.tone,
                            label: p.response.label(AppTexts.of(context)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _repondre(
    BuildContext context,
    WidgetRef ref,
    EventResponse reponse,
  ) async {
    // Lu **avant** l’attente : le contexte peut avoir disparu après.
    final AppTexts t = AppTexts.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(eventActionsProvider).respond(event.id, reponse);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message(t))),
      );
    }
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icon,
    required this.label,
    required this.value,
    this.dernier = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: context.couleurs.textSecondary),
              AppSpacing.hGapMd,
              Expanded(child: Text(label, style: context.typo.body)),
              AppSpacing.hGapSm,
              Flexible(
                child: EmojiText(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.body.copyWith(
                    color: context.couleurs.primary,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!dernier) Divider(height: 1, color: context.couleurs.border),
      ],
    );
  }
}
