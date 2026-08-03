import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/creation_kind.dart';
import '../providers/create_providers.dart';
import '../widgets/creation_kind_selector.dart';

/// Écran de création, ouvert par le bouton central « + ».
///
/// Le formulaire est encore une maquette : la validation vérifie le titre, mais
/// l'enregistrement n'écrit pas encore dans les dépôts.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  String? _titleError;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreationKind kind = ref.watch(selectedCreationKindProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Créer'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).maybePop(),
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
              'Choisissez un type, puis renseignez l’essentiel. Vous pourrez '
              'compléter les détails plus tard.',
              style: AppTypography.bodyMuted,
            ),

            AppSpacing.gapXl,
            CreationKindSelector(
              selected: kind,
              onSelected: (CreationKind value) {
                ref.read(selectedCreationKindProvider.notifier).select(value);
                // Une erreur affichée pour un autre type n'a plus de sens.
                setState(() => _titleError = null);
              },
            ),

            AppSpacing.gapXl,
            SectionHeader(
              title: 'Détails',
              subtitle: 'Pour votre ${kind.label.toLowerCase()}',
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: _titleLabel(kind),
              hint: _titleHint(kind),
              controller: _titleController,
              errorText: _titleError,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: _detailLabel(kind),
              hint: _detailHint(kind),
              controller: _detailController,
              maxLines: 3,
              minLines: 3,
              helperText: 'Optionnel',
            ),

            AppSpacing.gapXl,
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Text(
                      'Le partage avec un groupe et le choix des participants '
                      'arriveront dans une prochaine version.',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.gapXxl,
            PrimaryButton(
              label: 'Créer ${_articleFor(kind)}${kind.label.toLowerCase()}',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
            AppSpacing.gapMd,
            SecondaryButton(
              label: 'Annuler',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Ce champ est obligatoire.');
      return;
    }

    final CreationKind kind = ref.read(selectedCreationKindProvider);
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${kind.label} « $title » : l’enregistrement arrive bientôt.',
        ),
      ),
    );
  }

  static String _titleLabel(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Titre de l’événement',
    CreationKind.task => 'Intitulé de la tâche',
    CreationKind.group => 'Nom du groupe',
  };

  static String _titleHint(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Déjeuner avec Camille',
    CreationKind.task => 'Réserver le restaurant',
    CreationKind.group => 'Famille Rousseau',
  };

  static String _detailLabel(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Lieu et notes',
    CreationKind.task => 'Notes',
    CreationKind.group => 'Description',
  };

  static String _detailHint(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Le Petit Comptoir, réserver pour 4',
    CreationKind.task => 'Penser à confirmer la veille',
    CreationKind.group => 'Anniversaires, vacances et rendez-vous',
  };

  /// Article défini élidé selon le genre du type créé.
  static String _articleFor(CreationKind kind) => switch (kind) {
    CreationKind.event => 'l’',
    CreationKind.task => 'la ',
    CreationKind.group => 'le ',
  };
}
