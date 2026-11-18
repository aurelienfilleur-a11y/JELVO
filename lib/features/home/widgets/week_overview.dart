import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Ce qu'une journée porte, réduit à ce qui s'affiche.
@immutable
class DaySummary {
  const DaySummary({
    required this.day,
    this.eventCount = 0,
    this.taskCount = 0,
  });

  final DateTime day;
  final int eventCount;
  final int taskCount;

  bool get isEmpty => eventCount == 0 && taskCount == 0;
}

/// Semaine en cours, sous le bandeau récapitulatif de l'accueil.
///
/// **Compacte et dense à la fois** : sept colonnes tiennent en une centaine de
/// pixels de haut, mais chaque jour porte son initiale, son quantième, et deux
/// marqueurs — violet pour les événements, vert pour les tâches. Le jour
/// courant est plein ; le reste ne l'est pas.
///
/// Les marqueurs sont des pastilles et non des chiffres : à cette taille, un
/// « 3 » et un « 8 » ne se distinguent pas d'un coup d'œil, alors qu'une
/// pastille présente ou absente, si. Le compte exact est à une touche, sur le
/// calendrier.
class WeekOverview extends StatelessWidget {
  const WeekOverview({
    super.key,
    required this.days,
    required this.today,
    required this.onDaySelected,
  });

  /// Sept jours, du lundi au dimanche.
  final List<DaySummary> days;

  final DateTime today;

  /// Ouvre le calendrier à la date touchée.
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          for (final DaySummary jour in days)
            Expanded(
              child: _Jour(
                summary: jour,
                estAujourdHui: _memeJour(jour.day, today),
                onTap: () => onDaySelected(jour.day),
              ),
            ),
        ],
      ),
    );
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Jour extends StatelessWidget {
  const _Jour({
    required this.summary,
    required this.estAujourdHui,
    required this.onTap,
  });

  final DaySummary summary;
  final bool estAujourdHui;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color couleurTexte = estAujourdHui
        ? context.couleurs.onAccent
        : context.couleurs.encre;

    return Semantics(
      button: true,
      label: _etiquette(),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.fieldRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppDates.weekdayInitial(summary.day),
                style: context.typo.caption.copyWith(
                  color: context.couleurs.textSecondary,
                  fontWeight: AppTypography.medium,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: estAujourdHui
                      ? context.couleurs.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${summary.day.day}',
                  style: context.typo.body.copyWith(
                    color: couleurTexte,
                    fontWeight: estAujourdHui
                        ? AppTypography.semiBold
                        : AppTypography.medium,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Hauteur réservée même sans marqueur : sans cela, les colonnes
              // chargées et les colonnes vides n'auraient pas la même hauteur
              // et la ligne des quantièmes danserait.
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (summary.eventCount > 0)
                      _Marqueur(couleur: context.couleurs.primary),
                    if (summary.eventCount > 0 && summary.taskCount > 0)
                      const SizedBox(width: 3),
                    if (summary.taskCount > 0)
                      _Marqueur(couleur: context.couleurs.success),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Les pastilles ne disent rien à un lecteur d'écran : l'étiquette porte le
  /// compte réel.
  String _etiquette() {
    final StringBuffer texte = StringBuffer(AppDates.shortDate(summary.day));
    if (estAujourdHui) texte.write(", aujourd'hui");
    if (summary.eventCount > 0) {
      texte.write(', ${summary.eventCount} événement');
      if (summary.eventCount > 1) texte.write('s');
    }
    if (summary.taskCount > 0) {
      texte.write(', ${summary.taskCount} tâche');
      if (summary.taskCount > 1) texte.write('s');
    }
    if (summary.isEmpty) texte.write(', rien de prévu');
    return texte.toString();
  }
}

class _Marqueur extends StatelessWidget {
  const _Marqueur({required this.couleur});

  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
    );
  }
}
