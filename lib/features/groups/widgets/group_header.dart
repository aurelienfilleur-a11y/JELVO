import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/group.dart';
import '../models/group_member.dart';

/// Bandeau d'en-tête de l'écran d'un groupe.
///
/// Photo de couverture pleine largeur, les trois commandes en pastilles
/// blanches par-dessus, puis la vignette du groupe, son nom, son nombre de
/// membres et la rangée d'avatars — le tout posé sur le bas du bandeau.
///
/// **Les pastilles blanches ne sont pas décoratives** : une icône blanche seule
/// disparaît sur une photo claire, et une icône sombre sur une photo de nuit.
/// Le disque opaque tranche dans les deux cas — c'est le même problème que
/// résout le dégradé sombre de `CoverBanner` pour le texte.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.group,
    required this.membres,
    required this.notificationsNonLues,
    required this.onBack,
    required this.onNotifications,
    required this.menu,
  });

  final Group group;
  final List<GroupMember> membres;

  /// Compteur de la cloche. **Il est global**, et non propre au groupe :
  /// `notifications` n'a pas de colonne de groupe, et son `payload` ne porte
  /// pas l'identifiant pour tous les types. Compter « les notifications de ce
  /// groupe » demanderait une lecture que la base ne sait pas faire.
  final int notificationsNonLues;

  final VoidCallback onBack;
  final VoidCallback onNotifications;

  /// Le menu « … », construit par l'écran : lui seul sait quelles actions le
  /// rôle autorise.
  final Widget menu;

  /// Hauteur du bandeau, vignette et avatars compris.
  static const double hauteur = 260;

  @override
  Widget build(BuildContext context) {
    final List<AvatarData> avatars = <AvatarData>[
      for (final GroupMember membre in membres)
        AvatarData(name: membre.displayName, imageUrl: membre.avatarUrl),
    ];

    return SizedBox(
      height: hauteur,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Le nom vit plus bas, avec les avatars : le bandeau ne porte ici
          // que l'image et son dégradé.
          CoverBanner(
            name: '',
            accentColor: group.accent.color(context.couleurs),
            icon: group.icon,
            photoUrl: group.photoUrl,
            height: hauteur,
            // La vignette ronde porte déjà cette icône, plus bas : la laisser
            // aussi au centre du repli la donnerait deux fois.
            showFallbackIcon: false,
          ),

          Positioned(
            left: AppSpacing.screenMargin,
            right: AppSpacing.screenMargin,
            top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
            child: Row(
              children: <Widget>[
                _Pastille(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Retour',
                  onPressed: onBack,
                ),
                const Spacer(),
                _Pastille(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  badge: notificationsNonLues,
                  onPressed: onNotifications,
                ),
                AppSpacing.hGapMd,
                _PastilleEnveloppe(child: menu),
              ],
            ),
          ),

          Positioned(
            left: AppSpacing.screenMargin,
            right: AppSpacing.screenMargin,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _Vignette(group: group),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            group.name,
                            style: context.typo.h1.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            group.memberLabel,
                            style: context.typo.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Les avatars ne s'affichent qu'une fois les membres chargés :
                // une rangée vide qui se remplit d'un coup ferait sauter la
                // mise en page, mais une rangée factice mentirait.
                if (avatars.isNotEmpty) ...<Widget>[
                  AppSpacing.gapMd,
                  AvatarStack(avatars: avatars, size: 40, maxVisible: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La vignette ronde du groupe, posée à gauche du nom.
///
/// Elle ne répète pas la photo de couverture : celle-ci est déjà derrière. Ce
/// qu'elle porte, c'est l'**icône** dérivée de l'identifiant, sur l'accent du
/// groupe — le même repère coloré que dans la liste des groupes.
class _Vignette extends StatelessWidget {
  const _Vignette({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: group.accent.color(context.couleurs),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.center,
      child: Icon(group.icon, size: 32, color: Colors.white),
    );
  }
}

/// Un bouton d'icône dans son disque blanc.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return _PastilleEnveloppe(
      child: IconButton(
        icon: NavBadge(count: badge, child: Icon(icon)),
        color: _encre,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Le disque blanc lui-même, pour envelopper aussi le menu de l'écran.
///
/// **Blanc dans les deux apparences, et c'est délibéré.** Le disque est posé
/// sur une **photographie**, qui n'a pas d'apparence : ce qu'il faut, c'est
/// qu'il tranche aussi bien sur un ciel d'été que sur une photo de nuit.
/// Le suivre du thème l'aurait rendu sombre en mode sombre — invisible sur
/// une photo sombre, exactement le défaut qu'il existe pour éviter.
class _PastilleEnveloppe extends StatelessWidget {
  const _PastilleEnveloppe({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _fond,
        shape: BoxShape.circle,
        boxShadow: context.ombres.card,
      ),
      child: IconTheme(
        data: const IconThemeData(color: _encre, size: 22),
        child: Center(child: child),
      ),
    );
  }
}

/// Le blanc du disque et l'encre de son icône, tous deux fixes.
const Color _fond = Colors.white;
const Color _encre = Color(0xFF12122B);
