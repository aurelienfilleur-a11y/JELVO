import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../providers/home_providers.dart';

/// Bandeau violet en dégradé résumant la journée.
class SummaryBanner extends StatelessWidget {
  const SummaryBanner({
    super.key,
    required this.summary,
    required this.dateLabel,
  });

  final HomeSummary summary;

  /// Date du jour déjà formatée.
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            dateLabel,
            style: AppTypography.caption.copyWith(
              // Blanc atténué : contraste suffisant sur le violet sans
              // concurrencer les chiffres.
              color: Colors.white70,
              fontWeight: AppTypography.medium,
            ),
          ),
          AppSpacing.gapLg,
          Row(
            children: <Widget>[
              _Metric(
                value: summary.todayEventCount,
                label: summary.todayEventCount > 1 ? 'événements' : 'événement',
              ),
              const _MetricDivider(),
              _Metric(
                value: summary.openTaskCount,
                label: summary.openTaskCount > 1 ? 'tâches' : 'tâche',
              ),
              const _MetricDivider(),
              _Metric(
                value: summary.groupCount,
                label: summary.groupCount > 1 ? 'groupes' : 'groupe',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value', style: AppTypography.h2.copyWith(color: Colors.white)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: Colors.white24,
    );
  }
}
