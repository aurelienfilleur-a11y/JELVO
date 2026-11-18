import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Choix de la durée d'une adhésion : sans terme, ou jusqu'à une date.
///
/// **« Sans terme » est l'état d'ouverture**, et le restera : une adhésion
/// permanente est le cas courant, et une durée est le cas qu'on choisit. Le
/// contraire ferait poser des termes par inadvertance.
///
/// Les trois raccourcis couvrent ce pour quoi l'adhésion temporaire existe —
/// un séjour, un voyage, une saison. Le quatrième bouton ouvre le calendrier
/// pour tout le reste ; sans lui, la fonctionnalité ne servirait qu'aux
/// durées qu'on a devinées.
class MembershipTermPicker extends StatelessWidget {
  const MembershipTermPicker({
    super.key,
    required this.now,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Durée de l’adhésion',
  });

  /// Instant de référence, pris de `nowProvider` : jamais `DateTime.now()`.
  final DateTime now;

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final String label;

  /// Fin de journée du jour visé — 23 h 59.
  ///
  /// Une adhésion « jusqu'au 31 août » vaut **tout** le 31 août. Retenir
  /// minuit ferait expirer la veille au soir, ce que personne n'attend d'une
  /// date choisie dans un calendrier.
  static DateTime finDeJournee(DateTime jour) =>
      DateTime(jour.year, jour.month, jour.day, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final DateTime? choisi = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.typo.caption.copyWith(
            fontWeight: AppTypography.semiBold,
            color: context.couleurs.encre,
          ),
        ),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Choix(
              label: 'Sans terme',
              selected: choisi == null,
              onTap: enabled ? () => onChanged(null) : null,
            ),
            for (final (String libelle, Duration duree) in _raccourcis)
              _Choix(
                label: libelle,
                selected: choisi != null && _estLeRaccourci(choisi, duree),
                onTap: enabled
                    ? () => onChanged(finDeJournee(now.add(duree)))
                    : null,
              ),
            _Choix(
              label: choisi != null && !_estUnRaccourci(choisi)
                  ? AppDates.shortDate(choisi)
                  : 'Date…',
              icon: Icons.event_rounded,
              selected: choisi != null && !_estUnRaccourci(choisi),
              onTap: enabled ? () => _choisirDate(context) : null,
            ),
          ],
        ),
        if (choisi != null) ...<Widget>[
          AppSpacing.gapSm,
          Text(
            'Adhésion jusqu’au ${AppDates.fullDate(choisi)}, puis le groupe '
            'disparaîtra de son application.',
            style: context.typo.caption,
          ),
        ],
      ],
    );
  }

  static const List<(String, Duration)> _raccourcis = <(String, Duration)>[
    ('1 semaine', Duration(days: 7)),
    ('1 mois', Duration(days: 30)),
    ('3 mois', Duration(days: 90)),
  ];

  /// Deux dates sont « le même raccourci » si elles tombent le même jour : la
  /// comparaison à la seconde ne survivrait pas à un aller-retour par la base.
  bool _estLeRaccourci(DateTime choisi, Duration duree) {
    final DateTime attendu = now.add(duree);
    return choisi.year == attendu.year &&
        choisi.month == attendu.month &&
        choisi.day == attendu.day;
  }

  bool _estUnRaccourci(DateTime choisi) =>
      _raccourcis.any(((String, Duration) r) => _estLeRaccourci(choisi, r.$2));

  Future<void> _choisirDate(BuildContext context) async {
    final DateTime? jour = await showDatePicker(
      context: context,
      locale: const Locale('fr'),
      initialDate: value ?? now.add(const Duration(days: 30)),
      // Pas de terme dans le passé : il ferait disparaître le groupe avant
      // même que l'intéressé l'ait vu. La base le refuse aussi, mais mieux
      // vaut ne pas laisser la date se choisir.
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5, now.month, now.day),
      helpText: 'Fin de l’adhésion',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
    );
    if (jour != null) onChanged(finDeJournee(jour));
  }
}

/// Pastille de choix. Un `ChoiceChip` aurait apporté la palette de Material
/// plutôt que celle du design system.
class _Choix extends StatelessWidget {
  const _Choix({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? context.couleurs.primarySoft
                : context.couleurs.surface,
            borderRadius: AppRadii.pillRadius,
            border: Border.all(
              color: selected
                  ? context.couleurs.primary
                  : context.couleurs.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? context.couleurs.primary
                      : context.couleurs.textSecondary,
                ),
                AppSpacing.hGapXs,
              ],
              Text(
                label,
                style: context.typo.caption.copyWith(
                  color: selected
                      ? context.couleurs.primary
                      : context.couleurs.encre,
                  fontWeight: selected
                      ? AppTypography.semiBold
                      : AppTypography.regular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
