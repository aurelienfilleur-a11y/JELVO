import 'package:flutter/material.dart';

/// Palette Jelvo.
///
/// Source de vérité unique pour toutes les couleurs de l'application :
/// aucun `Color(0x...)` littéral ne doit apparaître ailleurs dans `lib/`.
abstract final class AppColors {
  /// Violet de marque, utilisé pour les actions principales.
  static const Color primary = Color(0xFF5B2EFF);

  /// Variante foncée du violet (états pressés, dégradés).
  static const Color primaryDark = Color(0xFF3D1DB8);

  /// Bleu nuit : couleur du texte principal et des titres.
  static const Color midnight = Color(0xFF12122B);

  /// Texte secondaire, légendes, libellés d'icônes.
  static const Color textSecondary = Color(0xFF6B6B85);

  /// Fond général des écrans.
  static const Color background = Color(0xFFF7F7FB);

  /// Fond des cartes, feuilles et barres.
  static const Color surface = Color(0xFFFFFFFF);

  /// Succès : tâche terminée, disponibilité confirmée.
  static const Color success = Color(0xFF22A06B);

  /// Avertissement : échéance proche, réponse en attente.
  static const Color warning = Color(0xFFF5A623);

  /// Erreur : conflit d'agenda, action destructive.
  static const Color danger = Color(0xFFE5484D);

  /// Traits de séparation et contours de champs.
  static const Color border = Color(0xFFECECF4);

  /// Fond très léger dérivé du violet, pour les états sélectionnés.
  static const Color primarySoft = Color(0xFFEFEAFF);

  /// Fond léger de succès.
  static const Color successSoft = Color(0xFFE6F5EE);

  /// Fond léger d'avertissement.
  static const Color warningSoft = Color(0xFFFDF1DC);

  /// Fond léger de danger.
  static const Color dangerSoft = Color(0xFFFCE9EA);
}
