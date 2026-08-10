import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../calendar/widgets/event_form_sheet.dart';
import '../../create/models/creation_kind.dart';
import '../../tasks/widgets/task_form_sheet.dart';
import '../models/group.dart';
import '../providers/group_providers.dart';

/// Paramètres d'URL de `/creer` pour un groupe et un type donnés.
///
/// Ils passent par l'URL : `/creer?type=task&groupe=<id>` reste rechargeable
/// sur le web, ce qu'un `extra` ne permettrait pas.
Map<String, String> _parametresDeCreation(String groupId, CreationKind kind) {
  return <String, String>{
    AppRoutes.createKindParam: kind.name,
    AppRoutes.createGroupParam: groupId,
  };
}

/// Ouvre l'écran de création avec le type et le groupe déjà renseignés.
void ouvrirCreation(
  BuildContext context, {
  required String groupId,
  required CreationKind kind,
}) {
  context.pushNamed(
    AppRoutes.create,
    queryParameters: _parametresDeCreation(groupId, kind),
  );
}

/// Feuille du bouton « + » depuis l'écran d'un groupe.
///
/// Deux entrées seulement : dans un groupe déjà créé, il n'y a plus de groupe à
/// créer — reste ce qu'on y met.
Future<void> ouvrirFeuilleDeCreation(
  BuildContext context, {
  required String groupId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => GroupCreationSheet(groupId: groupId),
  );
}

class GroupCreationSheet extends ConsumerWidget {
  const GroupCreationSheet({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le nom vient de la liste déjà chargée : la feuille ne déclenche aucune
    // lecture réseau pour un titre.
    final Group? group = ref.watch(groupByIdProvider(groupId));

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
            Text('Ajouter au groupe', style: AppTypography.h2),
            AppSpacing.gapSm,
            Text(
              group == null
                  ? 'Ce que vous créez ici sera partagé avec le groupe.'
                  : 'Ce que vous créez ici sera partagé avec « ${group.name} ».',
              style: AppTypography.bodyMuted,
            ),
            AppSpacing.gapXl,
            _Choix(
              kind: CreationKind.event,
              title: 'Nouvel événement',
              subtitle: 'Une date à proposer aux membres',
              onTap: () => _choisir(context, CreationKind.event),
            ),
            AppSpacing.gapMd,
            _Choix(
              kind: CreationKind.task,
              title: 'Nouvelle tâche',
              subtitle: 'Quelque chose à faire, à répartir',
              onTap: () => _choisir(context, CreationKind.task),
            ),
          ],
        ),
      ),
    );
  }

  /// Referme la feuille de choix avant d'ouvrir le formulaire : deux feuilles
  /// empilées obligeraient à fermer deux fois.
  ///
  /// Le `Navigator` racine est capturé avant le `pop` — ensuite, le contexte
  /// de cette feuille n'est plus rattaché à l'arbre.
  void _choisir(BuildContext context, CreationKind kind) {
    final NavigatorState racine = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();

    if (kind == CreationKind.task) {
      ouvrirFormulaireDeTache(racine.context, groupId: groupId);
    } else {
      ouvrirFormulaireDEvenement(racine.context, groupId: groupId);
    }
  }
}

class _Choix extends StatelessWidget {
  const _Choix({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final CreationKind kind;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kind.color.withValues(alpha: 0.12),
              borderRadius: AppRadii.fieldRadius,
            ),
            child: Icon(kind.icon, color: kind.color),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
