import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'status_dot.dart';

/// Ligne de tâche avec case à cocher personnalisée.
///
/// La case est dessinée à la main plutôt que via `Checkbox` : le `Checkbox`
/// Material impose sa propre zone de 48 px et son rayon, incompatibles avec la
/// densité voulue ici.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.title,
    this.subtitle,
    this.done = false,
    this.onToggle,
    this.onTap,
    this.dueLabel,
    this.dueTone,
    this.assignee,
    this.showDivider = true,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool done;

  /// Appelé avec le nouvel état souhaité de la case.
  final ValueChanged<bool>? onToggle;

  final VoidCallback? onTap;

  /// Échéance formatée, p. ex. « Demain », « 12 août ».
  final String? dueLabel;

  /// Teinte de l'échéance ; `warning` pour « bientôt », `danger` pour « en retard ».
  final StatusTone? dueTone;

  /// Initiales ou prénom du responsable.
  final String? assignee;

  final bool showDivider;

  /// Widget posé à droite de la ligne — une action de retrait, un chevron.
  ///
  /// Reste un `Widget` nu : `core/widgets` ne connaît pas le domaine, et
  /// chaque feature y met ce qui lui est propre.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.fieldRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Checkbox(
                    done: done,
                    onTap: onToggle == null ? null : () => onToggle!(!done),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: AppTypography.medium,
                            color: done
                                ? AppColors.textSecondary
                                : AppColors.midnight,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (dueLabel != null || assignee != null) ...<Widget>[
                          AppSpacing.gapSm,
                          Row(
                            children: <Widget>[
                              if (dueLabel != null)
                                StatusDot(
                                  tone: done
                                      ? StatusTone.neutral
                                      : (dueTone ?? StatusTone.info),
                                  label: dueLabel,
                                  filled: true,
                                ),
                              if (dueLabel != null && assignee != null)
                                AppSpacing.hGapSm,
                              if (assignee != null)
                                Flexible(
                                  child: Text(
                                    assignee!,
                                    style: AppTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    AppSpacing.hGapSm,
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.done, this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      label: 'Marquer la tâche comme terminée',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Élargit la zone tactile sans décaler visuellement la case.
          padding: const EdgeInsets.only(right: AppSpacing.xs, top: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? AppColors.success : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: done ? AppColors.success : AppColors.border,
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
