import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../chat/providers/chat_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../providers/group_providers.dart';

/// Écran Groupes : invitations reçues, puis groupes de l'utilisateur.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final TextEditingController _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Group>> groupsAsync = ref.watch(myGroupsProvider);
    final List<Group> tous = ref.watch(activeGroupsProvider);
    final List<Group> groups = ref.watch(filteredGroupsProvider);
    final String terme = ref.watch(groupQueryProvider);
    final List<GroupInvitation> invitations =
        ref.watch(invitationsProvider).value ?? const <GroupInvitation>[];

    return AppScreen(
      title: AppTexts.of(context).homeMyGroups,
      headerAction: AppScreenAction(
        icon: Icons.add_rounded,
        tooltip: AppTexts.of(context).createNewGroup,
        accented: true,
        onPressed: () => context.pushNamed(AppRoutes.groupCreate),
      ),
      slivers: <Widget>[
        // La recherche n'apparaît qu'à partir de trois groupes : en deçà, la
        // liste tient à l'écran et un champ vide ne ferait que la repousser.
        if (tous.length >= 3)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              0,
              AppSpacing.screenMargin,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: AppTextField(
                hint: AppTexts.of(context).groupsRechercherGroupe,
                controller: _recherche,
                prefixIcon: Icons.search_rounded,
                suffixIcon: terme.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 20),
                        color: context.couleurs.textSecondary,
                        tooltip: AppTexts.of(context).groupsEffacerRecherche,
                        onPressed: () {
                          _recherche.clear();
                          ref.read(groupQueryProvider.notifier).set('');
                        },
                      ),
                onChanged: (String valeur) =>
                    ref.read(groupQueryProvider.notifier).set(valeur),
              ),
            ),
          ),

        if (invitations.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              0,
              AppSpacing.screenMargin,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: _InvitationsBanner(count: invitations.length),
            ),
          ),

        if (groupsAsync.isLoading && groups.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (groupsAsync.hasError && groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: AppTexts.of(context).groupsGroupesIndisponibles,
              message: AuthFailure.from(
                groupsAsync.error!,
              ).message(AppTexts.of(context)),
              actionLabel: 'Réessayer',
              onActionPressed: () =>
                  ref.read(myGroupsProvider.notifier).refresh(),
            ),
          )
        // **Deux vides, deux causes.** Aucun groupe appelle à en créer un ;
        // une recherche sans résultat appelle à la corriger. Confondre les
        // deux proposerait de créer « Corse » à quelqu'un qui l'a déjà.
        else if (tous.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.groups_rounded,
              title: AppTexts.of(context).groupsAucunGroupeMoment,
              message: AppTexts.of(context).groupsCreezGroupePartagerAgenda,
              actionLabel: AppTexts.of(context).groupsCreerGroupe2,
              onActionPressed: () => context.pushNamed(AppRoutes.groupCreate),
            ),
          )
        else if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: AppTexts.of(context).groupsAucunGroupeNom,
              message: AppTexts.of(
                context,
              ).groupsAucunGroupesCorrespondTerme(terme),
              actionLabel: AppTexts.of(context).groupsEffacerRecherche,
              onActionPressed: () {
                _recherche.clear();
                ref.read(groupQueryProvider.notifier).set('');
              },
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => AppSpacing.gapLg,
              itemBuilder: (BuildContext context, int index) {
                final AppTexts t = AppTexts.of(context);
                final Group group = groups[index];
                return GroupCard(
                  name: group.name,
                  icon: group.icon,
                  accentColor: group.accent.color(context.couleurs),
                  photoUrl: group.photoUrl,
                  members: group.memberPreviews,
                  hiddenMembers: group.hiddenMemberCount,
                  memberLabel: group.memberLabel(t),
                  // **Zéro ne se dit pas**, et une moitié vide s'efface :
                  // « 0 tâche · 0 événement » est vrai, inutile, et se lit
                  // comme un défaut de chargement. Le provider rend les deux
                  // nombres, la phrase se bâtit ici — un provider n'a pas de
                  // contexte, donc pas de langue.
                  activityLabel: _activite(
                    t,
                    ref.watch(groupOngoingProvider(group.id)),
                  ),
                  // Savoir *lequel* est actif, pas seulement qu'il se passe
                  // quelque chose quelque part.
                  unreadCount: ref.watch(unreadForGroupProvider(group.id)),
                  onTap: () => context.pushNamed(
                    AppRoutes.groupDetail,
                    pathParameters: <String, String>{'id': group.id},
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Bandeau menant aux invitations en attente.
class _InvitationsBanner extends StatelessWidget {
  const _InvitationsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.pushNamed(AppRoutes.invitations),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.couleurs.primarySoft,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Icon(
              Icons.mark_email_unread_outlined,
              size: 20,
              color: context.couleurs.primary,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTexts.of(context).groupsInvitationEnAttenteCount(count),
                  style: context.typo.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppTexts.of(context).groupsInviteRejoindreGroupe,
                  style: context.typo.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.couleurs.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// La ligne d'activité d'une carte : « 3 tâches en cours · 2 événements à
/// venir », ou l'aveu qu'il ne se passe rien.
String _activite(AppTexts t, GroupActivity activite) {
  final List<String> morceaux = <String>[
    if (activite.taches > 0) t.groupsTachesEnCours(activite.taches),
    if (activite.evenements > 0) t.groupsEvenementsAVenir(activite.evenements),
  ];
  return morceaux.isEmpty ? t.chatRienPrevuInstant : morceaux.join(' · ');
}
