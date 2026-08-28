import 'package:flutter/material.dart';

/// Palette Jelvo, en deux exemplaires : clair et sombre.
///
/// Source de vérité unique pour toutes les couleurs de l'application : aucun
/// `Color(0x…)` littéral ne doit apparaître ailleurs dans `lib/`.
///
///
/// POURQUOI UNE `ThemeExtension` ET NON DES CONSTANTES
///
/// Les jetons étaient des `static const`. Un thème sombre demande qu'ils
/// changent de valeur à l'exécution, et une constante ne le peut pas. Une
/// variable globale, elle, le pourrait — mais **elle ne rebâtirait pas les
/// écrans** : Flutter ne reconstruit que ce qui dépend d'un `InheritedWidget`
/// modifié, et un widget qui lit une globale n'en dépend d'aucun. Basculer le
/// réglage laisserait donc la moitié de l'écran dans l'ancienne palette
/// jusqu'à ce qu'autre chose la fasse reconstruire.
///
/// Passer par le thème résout les deux : la valeur change, et `Theme.of` crée
/// la dépendance qui déclenche la reconstruction.
///
/// L'accès se fait par `context.couleurs` — voir l'extension en fin de
/// fichier.
///
///
/// CE QUI A ÉTÉ MESURÉ
///
/// Les contrastes sont calculés, pas estimés. Sur fond sombre, tout ce qui
/// porte du **texte** dépasse 4,5:1 ; tout ce qui n'est qu'un **objet
/// graphique** — pastille, icône, trait — vise 3:1, seuil que WCAG retient
/// pour ce cas.
///
/// Le thème clair garde ses valeurs d'origine à une exception près, décrite
/// sous `successInk` : les teintes fonctionnelles y étaient illisibles en
/// texte, et l'étaient déjà avant ce chantier.
@immutable
class JelvoColors extends ThemeExtension<JelvoColors> {
  const JelvoColors({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryInk,
    required this.encre,
    required this.textSecondary,
    required this.background,
    required this.surface,
    required this.border,
    required this.success,
    required this.successSoft,
    required this.successInk,
    required this.warning,
    required this.warningSoft,
    required this.warningInk,
    required this.danger,
    required this.dangerSoft,
    required this.dangerInk,
    required this.onAccent,
    required this.scrim,
    required this.shadow,
    required this.bubbleMine,
    required this.onBubbleMine,
    required this.bubbleOther,
    required this.onBubbleOther,
    required this.groupAccents,
    required this.speakerAccents,
  });

  /// Violet de marque, actions principales.
  final Color primary;

  /// Variante profonde du violet : dégradés, état pressé.
  final Color primaryDark;

  /// Fond teinté des états sélectionnés et des vignettes.
  final Color primarySoft;

  /// Le violet **en texte**, sur `primarySoft` ou sur le fond général.
  final Color primaryInk;

  /// Texte principal et titres.
  ///
  /// Anciennement `midnight`. Le nom a changé avec le thème sombre, où la
  /// couleur est presque blanche : « minuit » y aurait décrit le contraire de
  /// ce qu'elle vaut, et un jeton qui ment est pire qu'un jeton mal nommé.
  final Color encre;

  /// Texte secondaire, légendes, libellés d'icônes.
  final Color textSecondary;

  /// Fond général des écrans.
  final Color background;

  /// Fond des cartes, feuilles et barres.
  ///
  /// En clair il est **plus clair** que le fond ; en sombre il est **plus
  /// clair** aussi — une carte s'élève vers la lumière dans les deux cas.
  final Color surface;

  /// Traits de séparation et contours de champs.
  final Color border;

  final Color success;
  final Color successSoft;

  /// La teinte fonctionnelle **en texte**.
  ///
  /// `success` sur `successSoft` ne donnait que 2,96:1 en clair, `warning`
  /// 1,81:1 — sous le seuil, et déjà avant ce chantier. Les variantes `…Ink`
  /// sont assombries en clair (4,6 à 5,5:1) et se confondent avec la teinte
  /// vive en sombre, où c'est le fond qui est foncé.
  final Color successInk;

  final Color warning;
  final Color warningSoft;
  final Color warningInk;

  final Color danger;
  final Color dangerSoft;
  final Color dangerInk;

  /// Encre à poser **sur un aplat saturé** — bouton violet, pastille pleine.
  ///
  /// Blanc en clair, encre sombre en sombre : les aplats y sont clairs, et du
  /// blanc dessus tomberait à 2:1.
  final Color onAccent;

  /// Voile des vues plein écran (photo agrandie, barrière de feuille).
  final Color scrim;

  /// Couleur des ombres portées. Voir `AppShadows` : en sombre, une ombre
  /// noire sur un fond noir ne se voit pas, et c'est la carte plus claire qui
  /// porte seule la séparation.
  final Color shadow;

  /// Bulles de conversation.
  ///
  /// **L'encre ne s'inverse pas.** La bulle de l'utilisateur reste un violet
  /// profond avec du texte blanc dans les deux thèmes : c'est ce qui permet à
  /// l'heure et à la coche de lecture de garder leur blanc translucide, et
  /// c'est la seule pièce de l'interface où l'on tient à ce que la couleur ne
  /// bouge pas — elle dit « c'est moi qui parle ».
  final Color bubbleMine;
  final Color onBubbleMine;

  /// La bulle des autres se détache de la carte : en sombre elle est un cran
  /// plus claire que `surface`, sans quoi une conversation ressemblerait à un
  /// aplat uniforme.
  final Color bubbleOther;
  final Color onBubbleOther;

  /// Six aplats d'identité de groupe, dérivés de l'identifiant.
  ///
  /// Ils portent une **icône blanche**, ce qui fixe deux bornes à la fois :
  /// assez foncés pour que le blanc s'y lise (≥ 3,5:1), assez clairs pour se
  /// détacher du fond sombre (≥ 2,5:1). Le sixième était `midnight` en
  /// clair — sur fond sombre, la tuile aurait disparu ; il devient une
  /// ardoise.
  final List<Color> groupAccents;

  /// Huit teintes pour le nom d'un expéditeur au-dessus de ses bulles.
  ///
  /// Du **texte** de 13 : le seuil est 4,5:1, et la palette sombre monte de
  /// 6,19 à 10,10:1. Celle du clair, inchangée, va de 5,48 à 9,51:1.
  final List<Color> speakerAccents;

  /// Palette claire — les valeurs d'origine de Jelvo.
  static const JelvoColors clair = JelvoColors(
    primary: Color(0xFF5B2EFF),
    primaryDark: Color(0xFF3D1DB8),
    primarySoft: Color(0xFFEFEAFF),
    primaryInk: Color(0xFF4A22D6),
    encre: Color(0xFF12122B),
    textSecondary: Color(0xFF6B6B85),
    background: Color(0xFFF7F7FB),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFECECF4),
    success: Color(0xFF22A06B),
    successSoft: Color(0xFFE6F5EE),
    successInk: Color(0xFF147A4E),
    warning: Color(0xFFF5A623),
    warningSoft: Color(0xFFFDF1DC),
    warningInk: Color(0xFF9A6100),
    danger: Color(0xFFE5484D),
    dangerSoft: Color(0xFFFCE9EA),
    dangerInk: Color(0xFFB3282C),
    onAccent: Color(0xFFFFFFFF),
    scrim: Color(0xDD000000),
    shadow: Color(0xFF12122B),
    bubbleMine: Color(0xFF5B2EFF),
    onBubbleMine: Color(0xFFFFFFFF),
    bubbleOther: Color(0xFFFFFFFF),
    onBubbleOther: Color(0xFF12122B),
    groupAccents: <Color>[
      Color(0xFF5B2EFF),
      Color(0xFF3D1DB8),
      Color(0xFF22A06B),
      // L'ambre est plus profond que `warning` : la teinte vive ne donnait
      // que 2,03:1 sous une icône blanche, et le défaut existait déjà avant
      // le thème sombre. C'est le seul accent clair qui a bougé.
      Color(0xFFC27D0C),
      Color(0xFFE5484D),
      Color(0xFF12122B),
    ],
    speakerAccents: <Color>[
      Color(0xFF5B2EFF),
      Color(0xFF3D1DB8),
      Color(0xFF15734B),
      Color(0xFF8A5A00),
      Color(0xFFB3282C),
      Color(0xFF0F6E7A),
      Color(0xFFA62A6E),
      Color(0xFF6B4423),
    ],
  );

  /// Palette sombre.
  static const JelvoColors sombre = JelvoColors(
    primary: Color(0xFF9E86FF),
    primaryDark: Color(0xFF7A5FE8),
    primarySoft: Color(0xFF241D45),
    primaryInk: Color(0xFF9E86FF),
    encre: Color(0xFFECECF5),
    textSecondary: Color(0xFFA6A6C4),
    background: Color(0xFF0E0E1A),
    surface: Color(0xFF1B1B30),
    border: Color(0xFF33334F),
    success: Color(0xFF3ECF8E),
    successSoft: Color(0xFF0F2E22),
    successInk: Color(0xFF3ECF8E),
    warning: Color(0xFFF2B544),
    warningSoft: Color(0xFF33260D),
    warningInk: Color(0xFFF2B544),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3A1A20),
    dangerInk: Color(0xFFF87171),
    onAccent: Color(0xFF12122B),
    scrim: Color(0xEE000000),
    // Une ombre noire sur un fond presque noir ne se voit pas : elle est
    // rendue quasi transparente, et c'est l'écart de clarté entre la carte et
    // le fond qui porte seul la séparation.
    shadow: Color(0xFF000000),
    bubbleMine: Color(0xFF4B2BD6),
    onBubbleMine: Color(0xFFFFFFFF),
    bubbleOther: Color(0xFF242440),
    onBubbleOther: Color(0xFFECECF5),
    groupAccents: <Color>[
      Color(0xFF6B45E6),
      Color(0xFF4A5FD0),
      Color(0xFF1E8F5F),
      Color(0xFFB07A12),
      Color(0xFFC44045),
      Color(0xFF46557A),
    ],
    speakerAccents: <Color>[
      Color(0xFFA78BFA),
      Color(0xFF8B9DFF),
      Color(0xFF4ADE80),
      Color(0xFFFBBF24),
      Color(0xFFFB7185),
      Color(0xFF2DD4BF),
      Color(0xFFF472B6),
      Color(0xFFD6A87C),
    ],
  );

  @override
  JelvoColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? primaryInk,
    Color? encre,
    Color? textSecondary,
    Color? background,
    Color? surface,
    Color? border,
    Color? success,
    Color? successSoft,
    Color? successInk,
    Color? warning,
    Color? warningSoft,
    Color? warningInk,
    Color? danger,
    Color? dangerSoft,
    Color? dangerInk,
    Color? onAccent,
    Color? scrim,
    Color? shadow,
    Color? bubbleMine,
    Color? onBubbleMine,
    Color? bubbleOther,
    Color? onBubbleOther,
    List<Color>? groupAccents,
    List<Color>? speakerAccents,
  }) {
    return JelvoColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryInk: primaryInk ?? this.primaryInk,
      encre: encre ?? this.encre,
      textSecondary: textSecondary ?? this.textSecondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      successInk: successInk ?? this.successInk,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      warningInk: warningInk ?? this.warningInk,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerInk: dangerInk ?? this.dangerInk,
      onAccent: onAccent ?? this.onAccent,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
      bubbleMine: bubbleMine ?? this.bubbleMine,
      onBubbleMine: onBubbleMine ?? this.onBubbleMine,
      bubbleOther: bubbleOther ?? this.bubbleOther,
      onBubbleOther: onBubbleOther ?? this.onBubbleOther,
      groupAccents: groupAccents ?? this.groupAccents,
      speakerAccents: speakerAccents ?? this.speakerAccents,
    );
  }

  @override
  JelvoColors lerp(covariant JelvoColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => <Color>[
      for (int i = 0; i < a.length; i++) c(a[i], b[i]),
    ];

    return JelvoColors(
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryInk: c(primaryInk, other.primaryInk),
      encre: c(encre, other.encre),
      textSecondary: c(textSecondary, other.textSecondary),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      border: c(border, other.border),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      successInk: c(successInk, other.successInk),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      warningInk: c(warningInk, other.warningInk),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      dangerInk: c(dangerInk, other.dangerInk),
      onAccent: c(onAccent, other.onAccent),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
      bubbleMine: c(bubbleMine, other.bubbleMine),
      onBubbleMine: c(onBubbleMine, other.onBubbleMine),
      bubbleOther: c(bubbleOther, other.bubbleOther),
      onBubbleOther: c(onBubbleOther, other.onBubbleOther),
      groupAccents: l(groupAccents, other.groupAccents),
      speakerAccents: l(speakerAccents, other.speakerAccents),
    );
  }
}

/// `context.couleurs.primary` — l'accès unique à la palette.
extension CouleursDuContexte on BuildContext {
  /// La palette du thème courant.
  ///
  /// Le repli sur la palette claire n'est pas de la complaisance : un widget
  /// isolé dans un `MaterialApp` de test, sans notre thème, doit se rendre
  /// plutôt que lever. Le vrai thème, lui, pose toujours l'extension.
  JelvoColors get couleurs =>
      Theme.of(this).extension<JelvoColors>() ?? JelvoColors.clair;
}
