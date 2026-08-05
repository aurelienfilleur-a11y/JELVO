import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../providers/group_providers.dart';
import '../widgets/group_photo_picker.dart';

/// Limites de saisie, alignées sur ce que l'écran de groupe peut afficher sans
/// tronquer.
const int _nameMaxLength = 50;
const int _descriptionMaxLength = 120;

/// Création et modification d'un groupe.
///
/// Un seul écran pour les deux : les champs, les limites et la validation sont
/// identiques ; seuls le titre et l'action de fin changent.
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.groupId});

  /// `null` en création.
  final String? groupId;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Uint8List? _photoBytes;
  String? _photoExtension;
  bool _isPrivate = true;
  bool _submitting = false;
  String? _nameError;
  String? _errorMessage;

  /// Groupe dont les champs sont déjà chargés, pour ne pas écraser une saisie
  /// en cours à chaque reconstruction.
  String? _loadedId;

  bool get _isEditing => widget.groupId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Group? existing = _isEditing
        ? ref.watch(groupDetailProvider(widget.groupId!)).value
        : null;
    if (existing != null) _syncControllers(existing);

    final Color accent = existing?.accent.color ?? AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le groupe' : 'Nouveau groupe'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            if (_errorMessage != null) ...<Widget>[
              _ErrorBanner(message: _errorMessage!),
              AppSpacing.gapLg,
            ],

            GroupPhotoPicker(
              bytes: _photoBytes,
              imageUrl: existing?.photoUrl,
              accentColor: accent,
              onPicked: (Uint8List bytes, String extension) => setState(() {
                _photoBytes = bytes;
                _photoExtension = extension;
              }),
              onRemoved: () => setState(() {
                _photoBytes = null;
                _photoExtension = null;
              }),
            ),
            AppSpacing.gapXl,

            AppTextField(
              label: 'Nom du groupe',
              hint: 'Famille Rousseau',
              controller: _nameController,
              errorText: _nameError,
              maxLength: _nameMaxLength,
              textCapitalization: TextCapitalization.sentences,
              prefixIcon: Icons.groups_rounded,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearErrors(),
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: 'Description',
              hint: 'À quoi sert ce groupe ?',
              controller: _descriptionController,
              maxLength: _descriptionMaxLength,
              maxLines: 3,
              minLines: 2,
              helperText: 'Facultative',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _clearErrors(),
            ),
            AppSpacing.gapLg,

            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: SwitchListTile.adaptive(
                value: _isPrivate,
                onChanged: _isEditing || _submitting
                    ? null
                    : (bool value) => setState(() => _isPrivate = value),
                contentPadding: EdgeInsets.zero,
                title: Text('Groupe privé', style: AppTypography.body),
                subtitle: Text(
                  'On n’y entre que par invitation ou par lien de partage.',
                  style: AppTypography.caption,
                ),
              ),
            ),

            AppSpacing.gapXl,
            PrimaryButton(
              label: _isEditing ? 'Enregistrer' : 'Créer le groupe',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  void _syncControllers(Group group) {
    if (_loadedId == group.id) return;
    _loadedId = group.id;
    _nameController.text = group.name;
    _descriptionController.text = group.description ?? '';
    _isPrivate = group.isPrivate;
  }

  void _clearErrors() {
    if (_nameError == null && _errorMessage == null) return;
    setState(() {
      _nameError = null;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();

    setState(() {
      _nameError = switch (name) {
        '' => 'Donnez un nom à votre groupe.',
        final String n when n.length > _nameMaxLength =>
          'Le nom ne doit pas dépasser $_nameMaxLength caractères.',
        _ => null,
      };
      _errorMessage = null;
    });
    if (_nameError != null) return;

    setState(() => _submitting = true);
    try {
      if (_isEditing) {
        await ref
            .read(groupActionsProvider)
            .update(
              groupId: widget.groupId!,
              name: name,
              description: description,
              photoBytes: _photoBytes,
              photoExtension: _photoExtension,
            );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        final Group group = await ref
            .read(groupActionsProvider)
            .create(
              name: name,
              description: description,
              photoBytes: _photoBytes,
              photoExtension: _photoExtension,
              isPrivate: _isPrivate,
            );
        if (!mounted) return;
        // Remplace l'écran de création par le groupe fraîchement créé : revenir
        // en arrière ne doit pas rouvrir un formulaire déjà validé.
        context.pushReplacementNamed(
          AppRoutes.groupDetail,
          pathParameters: <String, String>{'id': group.id},
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppColors.danger,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
