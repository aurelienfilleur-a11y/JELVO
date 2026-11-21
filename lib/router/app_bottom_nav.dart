import 'package:flutter/material.dart';

import '../core/core.dart';

/// Les quatre onglets, dans l'ordre de la barre.
enum NavTab { accueil, groupes, calendrier, contacts }

/// Description d'un onglet de la barre inférieure.
///
/// **Elle dit quel onglet c'est, pas comment il s'appelle.** La liste des
/// destinations est `static const`, donc construite là où aucun `BuildContext`
/// n'existe — le libellé ne peut pas y être lu, et l'écrire en dur a laissé
/// les quatre onglets en français tout un chantier de migration. C'est la
/// règle des couleurs appliquée au vocabulaire : le modèle porte un rang,
/// l'appelant en tire le mot.
class NavDestination {
  const NavDestination({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
  });

  final NavTab tab;
  final IconData icon;
  final IconData selectedIcon;

  String label(AppTexts t) => switch (tab) {
    NavTab.accueil => t.navHome,
    NavTab.groupes => t.navGroups,
    NavTab.calendrier => t.navCalendar,
    NavTab.contacts => t.navContacts,
  };
}

/// Barre de navigation inférieure : Accueil · Groupes · [+] · Calendrier ·
/// Contacts.
///
/// `NavigationBar` de Material n'est pas utilisé ici : le bouton central n'est
/// pas un onglet sélectionnable mais une action qui empile un écran, ce qui ne
/// rentre pas dans son modèle « un index par destination ».
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onCreatePressed,
    this.badges = const <int>[0, 0, 0, 0],
    this.createLabel,
  });

  /// Index de l'onglet actif, de 0 à 3 (le bouton « + » n'en a pas).
  final int currentIndex;

  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreatePressed;

  /// Nombre d'éléments non lus par onglet, dans l'ordre de [destinations].
  ///
  /// Une valeur nulle ou négative n'affiche aucune pastille : un compteur à
  /// zéro ne doit pas laisser de rond vide derrière lui.
  final List<int> badges;

  /// Ce que crée le bouton central depuis l'onglet courant. Sert d'infobulle et
  /// d'étiquette d'accessibilité : l'icône seule ne dit pas ce qui va s'ouvrir.
  ///
  /// `null` plutôt qu'un libellé par défaut : **une valeur par défaut ne peut
  /// pas lire le contexte**, et c'est au `build` de résoudre le mot — même
  /// arbitrage que les couleurs d'`AppCard`.
  final String? createLabel;

  static const List<NavDestination> destinations = <NavDestination>[
    NavDestination(
      tab: NavTab.accueil,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    NavDestination(
      tab: NavTab.groupes,
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
    ),
    NavDestination(
      tab: NavTab.calendrier,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    NavDestination(
      tab: NavTab.contacts,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.couleurs.surface,
        border: Border(top: BorderSide(color: context.couleurs.border)),
        boxShadow: context.ombres.overlay,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _tab(0),
              _tab(1),
              Expanded(
                child: _CreateButton(
                  onPressed: onCreatePressed,
                  label: createLabel ?? AppTexts.of(context).createTitle,
                ),
              ),
              _tab(2),
              _tab(3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int index) {
    return Expanded(
      child: _NavTab(
        destination: destinations[index],
        selected: index == currentIndex,
        badge: index < badges.length ? badges[index] : 0,
        onTap: () => onDestinationSelected(index),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.destination,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    final String libelle = destination.label(t);
    final Color color = selected
        ? context.couleurs.primary
        : context.couleurs.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0 ? t.navBadgeNonLus(libelle, badge) : libelle,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.buttonRadius,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            NavBadge(
              count: badge,
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.caption.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: selected
                    ? AppTypography.semiBold
                    : AppTypography.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton d'action central, en dégradé violet.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  context.couleurs.primary,
                  context.couleurs.primaryDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.button + 2),
              boxShadow: context.ombres.accent,
            ),
            child: Icon(
              Icons.add_rounded,
              color: context.couleurs.onAccent,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
