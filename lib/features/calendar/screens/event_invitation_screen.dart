import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_providers.dart';
import '../widgets/response_buttons.dart';

/// Écran d'une invitation à un événement.
///
/// Même motif que l'invitation à un groupe : **qui convie** en haut,
/// **l'événement** au milieu, **la réponse** en bas. Il est distinct de
/// `EventDetailScreen`, qui répond à une autre question : celui-ci sert à
/// décider si l'on vient, celui-là à retrouver ce à quoi on a dit oui.
///
/// La réponse a **trois** valeurs et non deux : `event_response` connaît
/// `maybe`, et le « peut-être » de la maquette existe donc pour de bon en
/// base.
class EventInvitationScreen extends ConsumerStatefulWidget {
  const EventInvitationScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventInvitationScreen> createState() =>
      _EventInvitationScreenState();
}

class _EventInvitationScreenState extends ConsumerState<EventInvitationScreen> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final CalendarEvent? evenement = ref.watch(
      eventByIdProvider(widget.eventId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: _enCours ? null : () => _revenir(context),
        ),
      ),
      body: SafeArea(
        child: evenement == null
            ? EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Événement introuvable',
                message:
                    'Il a été supprimé, ou vous n’y avez plus accès. Il n’y a '
                    'plus rien à confirmer.',
                actionLabel: 'Revenir au calendrier',
                onActionPressed: () => context.goNamed(AppRoutes.calendar),
              )
            : _corps(evenement),
      ),
    );
  }

  Widget _corps(CalendarEvent evenement) {
    final DateTime now = ref.watch(nowProvider);
    final Group? groupe = evenement.groupId == null
        ? null
        : ref.watch(groupByIdProvider(evenement.groupId!));
    // `mon_agenda` renvoie le nom du groupe ; la liste locale ne sert que de
    // repli, car un convive n'est pas forcément membre.
    final String? nomDuGroupe = evenement.groupName ?? groupe?.name;
    final bool passe = evenement.end.isBefore(now);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        // **L'image propre à l'événement l'emporte**, puis la couverture du
        // groupe, puis le repli d'accent — le même ordre de préférence qu'un
        // avatar prédéfini, une photo, des initiales. Aucune illustration
        // n'est choisie par l'application.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.lg),
          ),
          child: CoverBanner(
            name: nomDuGroupe ?? 'Personnel',
            subtitle: AppDates.fullDate(evenement.start),
            accentColor: GroupAccent.forId(
              evenement.groupId ?? evenement.id,
            ).color,
            icon: Icons.event_rounded,
            photoUrl:
                evenement.imageUrl ??
                evenement.groupPhotoUrl ??
                groupe?.photoUrl,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InvitationHeader(
                author: AvatarData(
                  name: evenement.authorName ?? 'Un membre',
                  imageUrl: evenement.authorAvatarUrl,
                ),
                action: 'vous convie à un événement',
                // Pas d'ancienneté : `event_participants` ne retient pas
                // **quand** quelqu'un a été convié, seulement quand il a
                // répondu. Une date inventée ici serait fausse pour tout
                // participant ajouté après coup.
                now: now,
              ),

              AppSpacing.gapXl,
              Text(evenement.title, style: AppTypography.h2),

              AppSpacing.gapLg,
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InvitationDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: AppDates.fullDate(evenement.start),
                    ),
                    InvitationDetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Horaires',
                      value: AppDates.timeRange(evenement.start, evenement.end),
                      dernier:
                          evenement.location == null && nomDuGroupe == null,
                    ),
                    // Ligne omise, jamais remplie d'un tiret : `location` est
                    // facultatif, et « Non précisé » ferait passer un champ
                    // vide pour une donnée.
                    if (evenement.location != null &&
                        evenement.location!.isNotEmpty)
                      InvitationDetailRow(
                        icon: Icons.place_outlined,
                        label: 'Lieu',
                        value: evenement.location!,
                        dernier: nomDuGroupe == null,
                      ),
                    if (nomDuGroupe != null)
                      InvitationDetailRow(
                        icon: Icons.groups_outlined,
                        label: 'Groupe',
                        value: nomDuGroupe,
                        dernier: true,
                      ),
                  ],
                ),
              ),

              if (evenement.notes != null &&
                  evenement.notes!.isNotEmpty) ...<Widget>[
                AppSpacing.gapXl,
                const SectionHeader(title: 'À propos'),
                AppSpacing.gapSm,
                Text(evenement.notes!, style: AppTypography.bodyMuted),
              ],

              if (evenement.participants.isNotEmpty) ...<Widget>[
                AppSpacing.gapXl,
                SectionHeader(
                  title: 'Participants',
                  subtitle: '${evenement.yesCount} oui',
                ),
                AppSpacing.gapMd,
                Row(
                  children: <Widget>[
                    AvatarStack(avatars: evenement.avatars, size: 36),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        evenement.participants
                            .map((EventParticipant p) => p.displayName)
                            .join(', '),
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Un événement passé se dit, mais ne se verrouille pas : la base
              // accepte encore la réponse, et griser les boutons poserait une
              // règle qu'elle n'a pas.
              if (passe) ...<Widget>[
                AppSpacing.gapXl,
                _Bandeau(
                  icone: Icons.history_rounded,
                  couleur: AppColors.textSecondary,
                  fond: AppColors.border,
                  texte: 'Cet événement a déjà eu lieu.',
                ),
              ],

              if (evenement.myResponse != EventResponse.pending) ...<Widget>[
                AppSpacing.gapXl,
                _Bandeau(
                  icone: Icons.how_to_reg_rounded,
                  couleur: AppColors.success,
                  fond: AppColors.successSoft,
                  texte:
                      'Vous avez répondu : ${evenement.myResponse.label}. '
                      'Vous pouvez encore changer d’avis.',
                ),
              ],

              AppSpacing.gapXl,
              Text('Serez-vous là ?', style: AppTypography.h3),
              AppSpacing.gapMd,
              ResponseButtons(
                courante: evenement.myResponse,
                onRepondre: _enCours ? (_) {} : (r) => _repondre(evenement, r),
              ),

              AppSpacing.gapLg,
              SecondaryButton(
                label: 'Voir le détail de l’événement',
                icon: Icons.open_in_new_rounded,
                onPressed: () => context.pushNamed(
                  AppRoutes.eventDetail,
                  pathParameters: <String, String>{'id': evenement.id},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static void _revenir(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.calendar);
    }
  }

  Future<void> _repondre(CalendarEvent evenement, EventResponse reponse) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() => _enCours = true);
    try {
      await ref.read(eventActionsProvider).respond(evenement.id, reponse);
      messager.showSnackBar(
        SnackBar(content: Text('Réponse enregistrée : ${reponse.label}.')),
      );
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}

/// Un pavé teinté : icône et texte.
class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.icone,
    required this.couleur,
    required this.fond,
    required this.texte,
  });

  final IconData icone;
  final Color couleur;
  final Color fond;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icone, size: 18, color: couleur),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              texte,
              style: AppTypography.caption.copyWith(color: AppColors.midnight),
            ),
          ),
        ],
      ),
    );
  }
}
