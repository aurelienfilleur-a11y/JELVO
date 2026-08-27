import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/task_tile.dart';

/// Toutes les tâches visibles, ouvertes d'abord puis terminées.
///
/// Les tâches n'ont pas d'onglet : elles vivent dans l'accueil et dans les
/// groupes. Cet écran est la vue d'ensemble, ouverte depuis le compteur du
/// récapitulatif d'accueil.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, this.groupId});

  /// Restreint la liste à un groupe, via `?groupe=…`.
  ///
  /// C'est ce qui donne une destination au « Voir tout » de l'écran d'un
  /// groupe : ouvrir la liste de **toutes** les tâches depuis une section qui
  /// n'annonçait que celles d'un groupe serait un chemin qui ment.
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> toutes = ref.watch(tasksProvider);
    final DateTime now = ref.watch(nowProvider);
    final Group? groupe = groupId == null
        ? null
        : ref.watch(groupByIdProvider(groupId!));

    bool retenue(Task t) => groupId == null || t.groupId == groupId;

    final List<Task> ouvertes = ref
        .watch(openTasksProvider)
        .where(retenue)
        .toList();
    final List<Task> terminees = (toutes.value ?? const <Task>[])
        .where((Task t) => t.isDone && retenue(t))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: EmojiText(groupe?.name ?? 'Tâches'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoutes.home),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nouvelle tâche',
            onPressed: () => ouvrirFormulaireDeTache(context, groupId: groupId),
          ),
        ],
      ),
      body: toutes.hasError && (toutes.value?.isEmpty ?? true)
          ? SafeArea(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Tâches indisponibles',
                message: AuthFailure.from(toutes.error!).message,
                actionLabel: 'Réessayer',
                onActionPressed: () =>
                    ref.read(tasksProvider.notifier).refresh(),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(tasksProvider.notifier).refresh(),
              child: ouvertes.isEmpty && terminees.isEmpty
                  ? _vide(context, toutes.isLoading, groupId)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenMargin,
                        AppSpacing.lg,
                        AppSpacing.screenMargin,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        if (ouvertes.isNotEmpty) ...<Widget>[
                          SectionHeader(
                            title: 'À faire',
                            subtitle:
                                '${ouvertes.length} tâche'
                                '${ouvertes.length > 1 ? 's' : ''}',
                          ),
                          AppSpacing.gapMd,
                          _Carte(taches: ouvertes, now: now),
                        ],
                        if (terminees.isNotEmpty) ...<Widget>[
                          AppSpacing.gapXl,
                          SectionHeader(
                            title: 'Terminées',
                            subtitle:
                                '${terminees.length} tâche'
                                '${terminees.length > 1 ? 's' : ''}',
                          ),
                          AppSpacing.gapMd,
                          _Carte(taches: terminees, now: now),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _vide(BuildContext context, bool chargement, String? groupId) {
    if (chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    // `ListView` et non `Center` : sans défilement, le geste de traction du
    // `RefreshIndicator` ne partirait pas.
    return ListView(
      children: <Widget>[
        EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'Aucune tâche',
          message: groupId == null
              ? 'Tout est fait — ou rien n’a encore été noté.'
              : 'Ce groupe n’a aucune tâche pour l’instant.',
          actionLabel: 'Nouvelle tâche',
          onActionPressed: () =>
              ouvrirFormulaireDeTache(context, groupId: groupId),
        ),
      ],
    );
  }
}

class _Carte extends ConsumerWidget {
  const _Carte({required this.taches, required this.now});

  final List<Task> taches;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < taches.length; i++)
            TaskTile(
              task: taches[i],
              now: now,
              groupName: _nomDuGroupe(ref, taches[i]),
              showDivider: i < taches.length - 1,
            ),
        ],
      ),
    );
  }

  static String? _nomDuGroupe(WidgetRef ref, Task task) {
    if (task.groupId == null) return null;
    final Group? group = ref.watch(groupByIdProvider(task.groupId!));
    return group?.name;
  }
}
