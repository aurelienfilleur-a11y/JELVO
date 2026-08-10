import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../calendar/widgets/event_form_sheet.dart';
import '../../tasks/widgets/task_form_sheet.dart';
import '../models/creation_kind.dart';
import '../widgets/creation_kind_selector.dart';

/// Écran de création, ouvert par le bouton central « + » et par l'URL
/// `/creer?type=…&groupe=…`.
///
/// Il ne porte plus de formulaire : les formulaires vivent en **feuille**, et
/// deux mises en page pour la même saisie seraient deux choses à maintenir et
/// deux apparences à expliquer. Cet écran ne fait donc plus que deux choses —
/// demander ce que l'on veut créer quand l'URL ne le dit pas, et ouvrir la
/// feuille correspondante.
///
/// La route reste, parce qu'elle est adressable : sur le web, `/creer?type=task`
/// doit survivre à un rafraîchissement.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key, this.groupId, this.kind});

  final String? groupId;
  final CreationKind? kind;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  bool _ouverte = false;

  @override
  void initState() {
    super.initState();
    // Le type est déjà connu : on n'a rien à demander. La feuille ne peut pas
    // s'ouvrir depuis `initState` — il n'y a pas encore de `Navigator` monté —
    // d'où le report à la fin de la première image.
    final CreationKind? kind = widget.kind;
    if (kind != null && kind != CreationKind.group) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ouvrir(kind);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Créer'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
          onPressed: () => _fermer(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.sm,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text('Que voulez-vous créer ?', style: AppTypography.h1),
            AppSpacing.gapSm,
            Text(
              'Choisissez un type : le formulaire s’ouvre juste en dessous.',
              style: AppTypography.bodyMuted,
            ),
            AppSpacing.gapXl,
            CreationKindSelector(
              selected: widget.kind ?? CreationKind.event,
              onSelected: _ouvrir,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ouvrir(CreationKind kind) async {
    if (_ouverte) return;
    _ouverte = true;

    if (kind == CreationKind.group) {
      // La création d'un groupe a son propre écran, plus riche : photo,
      // description, confidentialité.
      context.pushReplacementNamed(AppRoutes.groupCreate);
      return;
    }

    if (kind == CreationKind.task) {
      await ouvrirFormulaireDeTache(context, groupId: widget.groupId);
    } else {
      await ouvrirFormulaireDEvenement(context, groupId: widget.groupId);
    }

    // La feuille refermée, cet écran n'a plus rien à montrer : on le retire
    // pour que le retour arrière ne le fasse pas réapparaître vide.
    _ouverte = false;
    if (mounted) _fermer();
  }

  void _fermer() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.home);
    }
  }
}
