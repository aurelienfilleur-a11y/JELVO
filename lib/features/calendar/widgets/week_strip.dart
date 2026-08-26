import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../providers/calendar_providers.dart';

/// Bande de sept jours sélectionnables, centrée sur la semaine du jour choisi.
///
/// Sous chaque date, **jusqu'à trois pastilles** disent ce qui s'y passe :
/// violet pour un événement, vert pour une tâche, rouge pour une
/// indisponibilité déclarée — le même code couleur que la chronologie.
///
/// Des pastilles et non des chiffres : à cette taille, un « 3 » et un « 8 »
/// ne se distinguent pas d'un coup d'œil, alors qu'une pastille présente ou
/// absente, si. Le compte exact est à une touche.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.onDaySelected,
    this.markersByDay = const <DateTime, Set<DayMarker>>{},
  });

  final DateTime selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDaySelected;

  /// Ce que porte chaque jour, clé normalisée à minuit.
  final Map<DateTime, Set<DayMarker>> markersByDay;

  @override
  Widget build(BuildContext context) {
    // Lundi de la semaine du jour sélectionné (`weekday` vaut 1 le lundi).
    final DateTime monday = selectedDay.subtract(
      Duration(days: selectedDay.weekday - 1),
    );

    return Row(
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              day: monday.add(Duration(days: i)),
              selectedDay: selectedDay,
              today: today,
              marqueurs:
                  markersByDay[_key(monday.add(Duration(days: i)))] ??
                  const <DayMarker>{},
              onTap: onDaySelected,
            ),
          ),
      ],
    );
  }

  static DateTime _key(DateTime day) => DateTime(day.year, day.month, day.day);
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selectedDay,
    required this.today,
    required this.marqueurs,
    required this.onTap,
  });

  final DateTime day;
  final DateTime selectedDay;
  final DateTime today;
  final Set<DayMarker> marqueurs;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = AppDates.isSameDay(day, selectedDay);
    final bool isToday = AppDates.isSameDay(day, today);

    final Color background = isSelected
        ? AppColors.primary
        : Colors.transparent;
    final Color dayColor = isSelected
        ? Colors.white
        : (isToday ? AppColors.primary : AppColors.midnight);

    return GestureDetector(
      onTap: () => onTap(day),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          children: <Widget>[
            Text(
              AppDates.weekdayInitial(day),
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: AppTypography.medium,
              ),
            ),
            AppSpacing.gapSm,
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadii.fieldRadius,
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: AppTypography.body.copyWith(
                  color: dayColor,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),
            AppSpacing.gapXs,
            // Hauteur réservée en permanence : sans cela, la bande se décale
            // verticalement selon la présence d'événements.
            SizedBox(
              height: 6,
              child: marqueurs.isEmpty
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // L'ordre de l'énumération, pour que la même journée
                        // présente toujours ses pastilles dans le même ordre.
                        for (final DayMarker m in DayMarker.values)
                          if (marqueurs.contains(m))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: m.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
