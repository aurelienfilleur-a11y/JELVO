import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_providers.dart';

/// Ce que le bouton « filtres » de l'en-tête ouvre.
///
/// Le filtre par groupe **existait déjà** — il occupait une rangée de puces
/// sous la bande des jours. Il passe derrière une icône, comme sur la
/// maquette, et gagne le seul réglage d'affichage qui manquait : montrer ou
/// non les créneaux de disponibilité.
///
/// Les créneaux ne dépendent d'aucun groupe : ils restent **hors** du filtre
/// par groupe, et c'est un interrupteur distinct qui les concerne — les
/// mêler ferait disparaître le fond de la journée dès qu'on choisit un
/// groupe.
class CalendarFilterSheet extends ConsumerWidget {
  const CalendarFilterSheet({super.key});

  static Future<void> ouvrir(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const CalendarFilterSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> selection = ref.watch(calendarFilterProvider);
    final bool creneaux = ref.watch(showAvailabilityProvider);
    final List<Group> groupes = ref.watch(activeGroupsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('Filtres', style: context.typo.h2)),
                if (selection.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        ref.read(calendarFilterProvider.notifier).clear(),
                    child: const Text('Tout voir'),
                  ),
              ],
            ),
            AppSpacing.gapLg,

            Text('Afficher', style: context.typo.h3),
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _Puce(
                  label: 'Personnel',
                  couleur: context.couleurs.primary,
                  choisie:
                      selection.isEmpty ||
                      selection.contains(CalendarGroupFilter.personal),
                  onTap: () => ref
                      .read(calendarFilterProvider.notifier)
                      .toggle(CalendarGroupFilter.personal),
                ),
                for (final Group groupe in groupes)
                  _Puce(
                    label: groupe.name,
                    couleur: groupe.accent.color(context.couleurs),
                    choisie: selection.isEmpty || selection.contains(groupe.id),
                    onTap: () => ref
                        .read(calendarFilterProvider.notifier)
                        .toggle(groupe.id),
                  ),
              ],
            ),

            AppSpacing.gapLg,
            Divider(height: 1, color: context.couleurs.border),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: creneaux,
              onChanged: (_) =>
                  ref.read(showAvailabilityProvider.notifier).toggle(),
              title: Text('Mes disponibilités', style: context.typo.body),
              subtitle: Text(
                'Les créneaux déclarés, en fond de journée. Ils ne dépendent '
                'd’aucun groupe.',
                style: context.typo.caption.copyWith(
                  color: context.couleurs.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recherche dans l'agenda.
///
/// **Elle n'existait pas.** Elle cherche par titre dans les événements et les
/// tâches datées — tout l'agenda, pas seulement le jour affiché : c'est
/// justement quand on ne sait plus *quand* a lieu quelque chose qu'on
/// cherche. Toucher un résultat ouvre le calendrier à sa date.
///
/// Rien de nouveau n'est lu : `mon_agenda` et `mes_taches` sont déjà chargées
/// sans bornes de dates, la recherche se fait donc sur ce que l'écran a en
/// mémoire.
class CalendarSearchSheet extends ConsumerStatefulWidget {
  const CalendarSearchSheet({super.key});

  static Future<void> ouvrir(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const CalendarSearchSheet(),
      );

  @override
  ConsumerState<CalendarSearchSheet> createState() =>
      _CalendarSearchSheetState();
}

class _CalendarSearchSheetState extends ConsumerState<CalendarSearchSheet> {
  final TextEditingController _controleur = TextEditingController();
  String _terme = '';

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_Resultat> resultats = _chercher();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Rechercher', style: context.typo.h2),
            AppSpacing.gapLg,
            AppTextField(
              controller: _controleur,
              hint: 'Un événement, une tâche…',
              prefixIcon: Icons.search_rounded,
              autofocus: true,
              onChanged: (String valeur) => setState(() => _terme = valeur),
            ),
            AppSpacing.gapLg,

            if (_terme.trim().length < 2)
              Text(
                'Deux lettres suffisent à chercher.',
                style: context.typo.caption,
              )
            else if (resultats.isEmpty)
              Text(
                'Rien ne correspond à « ${_terme.trim()} ».',
                style: context.typo.caption,
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: resultats.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.couleurs.border),
                  itemBuilder: (BuildContext context, int index) {
                    final _Resultat r = resultats[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(r.icone, size: 20, color: r.couleur),
                      title: Text(
                        r.titre,
                        style: context.typo.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        AppDates.fullDate(r.jour),
                        style: context.typo.caption,
                      ),
                      onTap: () {
                        ref.read(selectedDayProvider.notifier).select(r.jour);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_Resultat> _chercher() {
    final String terme = _terme.trim().toLowerCase();
    if (terme.length < 2) return const <_Resultat>[];

    final List<_Resultat> trouves = <_Resultat>[
      for (final CalendarEvent e
          in ref.watch(eventsProvider).value ?? const <CalendarEvent>[])
        if (e.title.toLowerCase().contains(terme))
          _Resultat(
            titre: e.title,
            jour: e.start,
            icone: Icons.event_rounded,
            couleur: context.couleurs.primary,
          ),
      for (final Task t in ref.watch(tasksProvider).value ?? const <Task>[])
        if (t.dueDate != null && t.title.toLowerCase().contains(terme))
          _Resultat(
            titre: t.title,
            jour: t.dueDate!,
            icone: Icons.task_alt_rounded,
            couleur: context.couleurs.success,
          ),
    ]..sort((_Resultat a, _Resultat b) => a.jour.compareTo(b.jour));

    return trouves;
  }
}

@immutable
class _Resultat {
  const _Resultat({
    required this.titre,
    required this.jour,
    required this.icone,
    required this.couleur,
  });

  final String titre;
  final DateTime jour;
  final IconData icone;
  final Color couleur;
}

class _Puce extends StatelessWidget {
  const _Puce({
    required this.label,
    required this.couleur,
    required this.choisie,
    required this.onTap,
  });

  final String label;
  final Color couleur;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.pillRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: choisie
              ? couleur.withValues(alpha: 0.12)
              : context.couleurs.surface,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(
            color: choisie ? couleur : context.couleurs.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            AppSpacing.hGapSm,
            Text(
              label,
              style: context.typo.caption.copyWith(
                color: choisie
                    ? context.couleurs.encre
                    : context.couleurs.textSecondary,
                fontWeight: choisie ? AppTypography.semiBold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
