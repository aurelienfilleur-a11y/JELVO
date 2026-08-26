import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../providers/onboarding_providers.dart';

/// Écran de bienvenue, montré **une seule fois**, à la première ouverture.
///
/// Il s'adresse à quelqu'un qui ne connaît pas Jelvo et n'a pas de compte :
/// il précède donc l'écran de connexion, et non l'inscription. « Commencer »
/// mène à `/connexion`, d'où l'on crée un compte ou l'on se connecte.
///
/// **Une seule page, pas de carrousel** : ni points de pagination, ni
/// « Passer ». Trois arguments tiennent sur un écran, et un « Passer » à côté
/// d'un « Commencer » demande de choisir entre deux boutons qui font la même
/// chose — sortir de là.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.xxl,
                  AppSpacing.screenMargin,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: <Widget>[
                    // Pas d'emoji dans le titre : le projet n'embarque aucune
                    // police emoji, et le 👋 de la maquette s'afficherait en
                    // carré « tofu » sur les machines qui n'en ont pas. Même
                    // arbitrage que le titre de l'accueil.
                    Text(
                      'Bienvenue sur Jelvo',
                      style: AppTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapSm,
                    Text(
                      'L’app qui rassemble vos groupes, vos projets et vos '
                      'proches.',
                      style: AppTypography.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapXl,

                    const _Illustration(),
                    AppSpacing.gapXl,

                    const _ArgumentsCard(),
                  ],
                ),
              ),
            ),

            // Hors du défilement : le seul moyen de sortir de cet écran ne
            // doit jamais demander de faire défiler pour être atteint.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.sm,
                AppSpacing.screenMargin,
                AppSpacing.xl,
              ),
              child: PrimaryButton(
                label: 'Commencer',
                onPressed: () {
                  ref.read(welcomeSeenProvider.notifier).marquerVu();
                  context.goNamed(AppRoutes.login);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'illustration, et son emplacement quand le fichier n'est pas là.
///
/// **Le repli ne dessine pas une illustration de remplacement.** C'est la même
/// règle que le logo : une image fournie ne se reconstruit pas, et une
/// approximation vaudrait moins que rien. Ce qui s'affiche est visiblement un
/// emplacement en attente — un aplat teinté et un pictogramme —, pas un
/// substitut qui se ferait passer pour l'œuvre.
///
/// `errorBuilder` couvre les deux cas d'un coup : fichier absent du dépôt, et
/// fichier présent mais illisible.
class _Illustration extends StatelessWidget {
  const _Illustration();

  /// Chemin attendu. Voir `assets/illustrations/README.md` pour le format.
  static const String chemin = 'assets/illustrations/bienvenue.png';

  /// Hauteur réservée, dans tous les cas.
  ///
  /// Fixe et non proportionnelle : avec le fichier ou sans lui, la carte des
  /// arguments doit commencer à la même hauteur. `BoxFit.contain` s'accommode
  /// ensuite de tout rapport de forme sans jamais rogner.
  static const double hauteur = 240;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      width: double.infinity,
      child: Image.asset(
        chemin,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _IllustrationAbsente(),
      ),
    );
  }
}

class _IllustrationAbsente extends StatelessWidget {
  const _IllustrationAbsente();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadii.cardRadius,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.groups_2_rounded,
        size: 64,
        color: AppColors.primary.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Les trois arguments, dans une seule carte séparée par des filets.
class _ArgumentsCard extends StatelessWidget {
  const _ArgumentsCard();

  /// Les trois teintes viennent du design system — `primary`, `success`,
  /// `warning` — et non des couleurs de la maquette : violet, vert et orange
  /// y tombent exactement. Aucune couleur nouvelle n'a été introduite.
  static const List<_Argument> arguments = <_Argument>[
    _Argument(
      icon: Icons.groups_2_rounded,
      color: AppColors.primary,
      background: AppColors.primarySoft,
      // La maquette écrit « Tout vos groupes » ; c'est une faute d'accord.
      titre: 'Tous vos groupes au même endroit',
      texte: 'Organisez vos projets, activités et échanges facilement.',
    ),
    _Argument(
      icon: Icons.calendar_month_rounded,
      color: AppColors.success,
      background: AppColors.successSoft,
      titre: 'Un agenda partagé et synchronisé',
      texte: 'Ne manquez plus aucun événement important.',
    ),
    _Argument(
      icon: Icons.task_alt_rounded,
      color: AppColors.warning,
      background: AppColors.warningSoft,
      titre: 'Des tâches claires et efficaces',
      texte: 'Attribuez, suivez et accomplissez ensemble vos objectifs.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          for (final (int index, _Argument argument) in arguments.indexed) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.border),
            _ArgumentRow(argument: argument),
          ],
        ],
      ),
    );
  }
}

@immutable
class _Argument {
  const _Argument({
    required this.icon,
    required this.color,
    required this.background,
    required this.titre,
    required this.texte,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String titre;
  final String texte;
}

class _ArgumentRow extends StatelessWidget {
  const _ArgumentRow({required this.argument});

  final _Argument argument;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: argument.background,
              borderRadius: AppRadii.fieldRadius,
            ),
            alignment: Alignment.center,
            child: Icon(argument.icon, size: 24, color: argument.color),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(argument.titre, style: AppTypography.h3),
                const SizedBox(height: 2),
                Text(argument.texte, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
