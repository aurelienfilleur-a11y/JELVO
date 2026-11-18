import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../contacts/widgets/qr_support.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_choice_sheet.dart';
import '../widgets/profile_about_card.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_stats_card.dart';

/// Écran « Mon profil » : trois cartes, qui se lisent sans rien remplir.
///
/// Il était un formulaire ; il ne l'est plus. La modification vit dans
/// `ProfileEditScreen`, ouverte par l'action « Modifier » — un profil se
/// consulte bien plus souvent qu'il ne se change.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> profilAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => context.pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: profilAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Profil indisponible',
            message: AuthFailure.from(error).message,
            actionLabel: 'Réessayer',
            onActionPressed: () => ref.invalidate(currentProfileProvider),
          ),
          data: (Profile? profil) => profil == null
              ? const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Profil introuvable',
                  message:
                      'Votre profil n’a pas encore été créé. Reconnectez-vous '
                      'pour le finaliser.',
                )
              : _contenu(context, ref, profil),
        ),
      ),
    );
  }

  Widget _contenu(BuildContext context, WidgetRef ref, Profile profil) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        ProfileHeaderCard(
          profile: profil,
          onChangeAvatar: () => AvatarChoiceSheet.ouvrir(
            context,
            aUnAvatar: profil.avatarAAfficher != null,
          ),
          onQrCode: () => context.pushNamed(AppRoutes.myQrCode),
          onEdit: () => context.pushNamed(AppRoutes.profileEdit),
          onShare: () => _partager(context, profil),
        ),

        AppSpacing.gapLg,
        // La bio se modifie **sur place**, sur la ligne où elle se lit : la
        // carte n'a donc plus de rappel d'ouverture d'écran à recevoir.
        ProfileAboutCard(
          bio: profil.bio,
          email: ref.watch(currentEmailProvider),
        ),

        AppSpacing.gapLg,
        ProfileStatsCard(
          stats: ref.watch(profileStatsProvider),
          onOpenGroups: () => context.goNamed(AppRoutes.groups),
          onOpenCalendar: () => context.goNamed(AppRoutes.calendar),
          onOpenTasks: () => context.pushNamed(AppRoutes.tasks),
        ),

        AppSpacing.gapLg,
        _LigneDisponibilites(
          onTap: () => context.pushNamed(AppRoutes.availability),
        ),
      ],
    );
  }

  /// Partage exactement ce que porte le QR code : le pseudo.
  ///
  /// Jelvo n'a pas d'adresse publique de profil ; inventer un lien qui
  /// n'ouvrirait rien serait pire que de partager le pseudo, avec lequel on
  /// se retrouve par la recherche.
  static Future<void> _partager(BuildContext context, Profile profil) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final String texte =
        'Retrouvez-moi sur Jelvo : ${profil.pseudoHandle}\n'
        '${QrContact.encode(profil.pseudo)}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: texte, subject: 'Mon profil Jelvo'),
      );
    } catch (_) {
      // Pas de feuille de partage (certains navigateurs) : le pseudo reste
      // copiable, ce qui couvre le même besoin.
      messager.showSnackBar(
        SnackBar(content: Text('Votre pseudo : ${profil.pseudoHandle}')),
      );
    }
  }
}

/// Entrée vers la saisie des disponibilités.
///
/// Elle vit dans le profil et non dans les paramètres : une disponibilité
/// décrit la personne, pas le fonctionnement de l'application. Absente de la
/// maquette, elle est gardée — c'est le seul chemin vers cet écran.
class _LigneDisponibilites extends StatelessWidget {
  const _LigneDisponibilites({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.couleurs.primarySoft,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 18,
                  color: context.couleurs.primary,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Mes disponibilités',
                      style: context.typo.body.copyWith(
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Les autres n’y voient qu’un mot : disponible, '
                      'indisponible ou inconnu.',
                      style: context.typo.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
    );
  }
}
