import 'package:flutter/material.dart';

import '../core/core.dart';

/// Description d'un onglet de la barre inférieure.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
  });

  /// Index de l'onglet actif, de 0 à 3 (le bouton « + » n'en a pas).
  final int currentIndex;

  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreatePressed;

  static const List<NavDestination> destinations = <NavDestination>[
    NavDestination(
      label: 'Accueil',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    NavDestination(
      label: 'Groupes',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
    ),
    NavDestination(
      label: 'Calendrier',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    NavDestination(
      label: 'Contacts',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.overlay,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _tab(0),
              _tab(1),
              Expanded(child: _CreateButton(onPressed: onCreatePressed)),
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
        onTap: () => onDestinationSelected(index),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.buttonRadius,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
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
  const _CreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Créer',
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(AppRadii.button + 2),
              boxShadow: AppShadows.accent,
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
