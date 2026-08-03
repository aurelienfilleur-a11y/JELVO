import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Bande de sept jours sélectionnables, centrée sur la semaine du jour choisi.
///
/// Une pastille sous la date indique qu'au moins un événement y est planifié.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.onDaySelected,
    this.eventCountByDay = const <DateTime, int>{},
  });

  final DateTime selectedDay;
  final DateTime today;
  final ValueChanged<DateTime> onDaySelected;

  /// Nombre d'événements par jour, clé normalisée à minuit.
  final Map<DateTime, int> eventCountByDay;

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
              eventCount:
                  eventCountByDay[_key(monday.add(Duration(days: i)))] ?? 0,
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
    required this.eventCount,
    required this.onTap,
  });

  final DateTime day;
  final DateTime selectedDay;
  final DateTime today;
  final int eventCount;
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
              child: eventCount == 0
                  ? null
                  : Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
