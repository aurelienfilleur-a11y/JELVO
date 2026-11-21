import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../availability/models/availability.dart';
import '../models/profil_consultable.dart';
import 'profile_action_row.dart';

/// En-tête du profil de quelqu'un d'autre : avatar, identité, et les actions
/// que la relation autorise.
///
/// Même allure que `ProfileHeaderCard` — c'est ce qui fait reconnaître
/// l'écran — moins deux choses qui n'ont pas de sens ici : la pastille
/// d'appareil photo, qui changerait la photo de quelqu'un d'autre, et les
/// trois actions, qui sont remplacées et non retirées.
class PublicProfileHeaderCard extends StatelessWidget {
  const PublicProfileHeaderCard({
    super.key,
    required this.profil,
    required this.actions,
  });

  final ProfilConsultable profil;
  final List<ProfileAction> actions;

  static const double _tailleAvatar = 116;

  @override
  Widget build(BuildContext context) {
    final PeerAvailability? dispo = profil.disponibilite;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          AvatarImage(
            data: AvatarData(
              name: profil.profil.displayName,
              imageUrl: profil.profil.avatarAAfficher,
            ),
            size: _tailleAvatar,
          ),

          AppSpacing.gapMd,
          EmojiText(
            profil.profil.displayName,
            style: context.typo.h2,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          EmojiText(
            profil.profil.pseudoHandle,
            style: context.typo.body.copyWith(color: context.couleurs.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // La disponibilité **déclarée**, et seulement si elle dit quelque
          // chose. `unknown` couvre aussi bien « rien de déclaré » que « vous
          // n'avez pas à le savoir » : l'afficher ferait passer les deux pour
          // une donnée, comme « Non précisé » sur un lieu d'événement.
          //
          // Ce n'est pas une pastille de présence : celle de la maquette a été
          // écartée partout, `profiles.last_seen_at` n'étant écrit nulle part.
          // Celle-ci repose sur des créneaux que la personne a saisis.
          if (dispo != null && dispo != PeerAvailability.unknown) ...<Widget>[
            AppSpacing.gapSm,
            _Pastille(dispo: dispo),
          ],

          ProfileActionRow(actions: actions),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.dispo});

  final PeerAvailability dispo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: dispo.tone.color(context.couleurs).withValues(alpha: 0.12),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatusDot(tone: dispo.tone, filled: true),
          AppSpacing.gapXs,
          Text(
            dispo.label,
            style: context.typo.caption.copyWith(
              color: dispo.tone.ink(context.couleurs),
              fontWeight: AppTypography.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

/// « À propos » en lecture seule : la bio et l'anniversaire.
///
/// **Aucune adresse e-mail.** Elle figure sur son propre profil, où elle vient
/// de la session ; elle n'est lisible nulle part pour quelqu'un d'autre, et
/// `profil_consultable` ne la rend pas — elle vit dans `auth.users`, que la
/// fonction ne lit pas.
///
/// La carte **disparaît** quand les deux lignes sont vides. Sur son propre
/// profil, une bio vide invite à la remplir ; ici il n'y a ni texte à lire ni
/// geste à proposer — c'est la règle du crayon de description d'un groupe,
/// absent pour un membre simple.
class PublicAboutCard extends StatelessWidget {
  const PublicAboutCard({super.key, required this.profil});

  final ProfilConsultable profil;

  @override
  Widget build(BuildContext context) {
    final String? bio = profil.profil.bio?.trim();
    final bool aBio = bio != null && bio.isNotEmpty;
    final String? anniversaire = profil.profil.anniversaire?.libelle;
    if (!aBio && anniversaire == null) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              AppTexts.of(context).calendarPropos,
              style: context.typo.h3,
            ),
          ),
          AppSpacing.gapMd,
          if (aBio)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: EmojiText(bio, style: context.typo.body),
            ),
          if (aBio && anniversaire != null) AppSpacing.gapMd,
          if (anniversaire != null)
            Row(
              children: <Widget>[
                const OptionIcon(icon: Icons.cake_outlined),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Anniversaire', style: context.typo.bodyMuted),
                      Text(
                        anniversaire,
                        style: context.typo.body.copyWith(
                          fontWeight: AppTypography.semiBold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Les groupes que l'on a en commun.
///
/// Visible de tout le monde, et sans règle d'accès à poser : ce sont **nos**
/// groupes, dont on peut déjà lire la liste des membres. Ce que la carte
/// apprend, c'est l'intersection — pas l'existence d'un groupe qu'on ne
/// connaîtrait pas.
///
/// **Zéro se dit**, comme la pastille du carnet : « on se connaît sans rien
/// organiser ensemble » est une information, là où une carte absente se lirait
/// comme un chargement qui a échoué.
class CommonGroupsCard extends StatelessWidget {
  const CommonGroupsCard({
    super.key,
    required this.groupes,
    required this.onOuvrir,
  });

  final List<GroupeCommun> groupes;
  final void Function(String groupeId) onOuvrir;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              AppTexts.of(context).profileGroupesCommunsCount(groupes.length),
              style: context.typo.h3,
            ),
          ),
          if (groupes.isEmpty) ...<Widget>[
            AppSpacing.gapSm,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                AppTexts.of(context).profileOrganisezRienEnsembleInstant,
                style: context.typo.bodyMuted,
              ),
            ),
          ],
          for (final GroupeCommun groupe in groupes) ...<Widget>[
            AppSpacing.gapSm,
            InkWell(
              onTap: () => onOuvrir(groupe.id),
              borderRadius: AppRadii.fieldRadius,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    AvatarImage(
                      data: AvatarData(
                        name: groupe.nom,
                        imageUrl: groupe.photoUrl,
                      ),
                      size: 40,
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: EmojiText(
                        groupe.nom,
                        style: context.typo.body.copyWith(
                          fontWeight: AppTypography.semiBold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.couleurs.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
