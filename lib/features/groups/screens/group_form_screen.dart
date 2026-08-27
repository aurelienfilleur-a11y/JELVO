import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../providers/group_providers.dart';
import '../widgets/group_member_picker.dart';
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
  final TextEditingController _nameController = EmojiTextEditingController();
  final TextEditingController _descriptionController =
      EmojiTextEditingController();

  Uint8List? _photoBytes;
  String? _photoExtension;
  bool _submitting = false;

  /// « Inviter par lien » choisi : la feuille s'ouvrira sur le groupe créé.
  bool _lienDemande = false;

  /// Personnes à inviter dès la création. Vide en modification : la liste des
  /// membres se gère depuis l'écran du groupe, qui sait aussi les retirer.
  Set<String> _invites = const <String>{};
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

            if (!_isEditing) ...<Widget>[
              Text(
                'Créez votre groupe et invitez les premiers membres.',
                style: AppTypography.bodyMuted,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapLg,
            ],

            Text(
              'Photo du groupe',
              style: AppTypography.caption.copyWith(
                fontWeight: AppTypography.medium,
                color: AppColors.midnight,
              ),
            ),
            AppSpacing.gapMd,
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
              label: 'Nom du groupe *',
              hint: 'Ex. : Famille Rousseau',
              controller: _nameController,
              errorText: _nameError,
              maxLength: _nameMaxLength,
              textCapitalization: TextCapitalization.sentences,
              suffixIcon: const Icon(
                Icons.groups_rounded,
                color: AppColors.primary,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearErrors(),
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: 'Description (optionnelle)',
              hint: 'Décrivez brièvement le but de ce groupe',
              controller: _descriptionController,
              maxLength: _descriptionMaxLength,
              showCounter: true,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _clearErrors(),
            ),
            AppSpacing.gapLg,

            const _ConfidentialiteCard(),

            if (!_isEditing) ...<Widget>[
              AppSpacing.gapXl,
              GroupMemberPicker(
                selected: _invites,
                enabled: !_submitting,
                lienDemande: _lienDemande,
                onLienChanged: (bool valeur) =>
                    setState(() => _lienDemande = valeur),
                onChanged: (Set<String> choisis) =>
                    setState(() => _invites = choisis),
              ),
            ],

            AppSpacing.gapXl,
            PrimaryButton(
              label: _isEditing ? 'Enregistrer' : 'Créer le groupe',
              icon: _isEditing ? null : Icons.group_add_rounded,
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
            );
        // Les invitations partent **après** la création, et leur échec ne
        // remet rien en cause : le groupe existe, on entre dedans, et on dit
        // ce qui n'est pas parti. Lever ici afficherait une erreur sur un
        // groupe pourtant bien créé.
        final int echecs = _invites.isEmpty
            ? 0
            : await ref
                  .read(groupActionsProvider)
                  .inviteAll(groupId: group.id, userIds: _invites);

        if (!mounted) return;
        // Capturé avant la navigation : la garde du routeur peut avoir quitté
        // cet écran au moment d'afficher la `SnackBar`.
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

        // Remplace l'écran de création par le groupe fraîchement créé : revenir
        // en arrière ne doit pas rouvrir un formulaire déjà validé.
        //
        // `?lien=1` porte le choix « Inviter par lien » jusqu'à l'écran qui
        // sait le satisfaire : un jeton se tire sur un groupe qui existe.
        context.pushReplacementNamed(
          AppRoutes.groupDetail,
          pathParameters: <String, String>{'id': group.id},
          queryParameters: <String, String>{
            if (_lienDemande) AppRoutes.groupLinkParam: '1',
          },
        );

        final int envoyees = _invites.length - echecs;
        if (_invites.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(content: Text(_bilanInvitations(envoyees, echecs))),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Ce que dit la `SnackBar` après la création.
///
/// Un échec partiel doit être **nommé** : sans cela, on croit avoir invité
/// cinq personnes alors que deux n'ont rien reçu, et rien ne le signale.
String _bilanInvitations(int envoyees, int echecs) {
  if (echecs == 0) {
    return envoyees == 1
        ? 'Groupe créé, 1 invitation envoyée.'
        : 'Groupe créé, $envoyees invitations envoyées.';
  }
  if (envoyees == 0) {
    return echecs == 1
        ? 'Groupe créé, mais l’invitation n’a pas pu partir.'
        : 'Groupe créé, mais aucune des $echecs invitations n’a pu partir.';
  }
  return 'Groupe créé, $envoyees invitation(s) envoyée(s), '
      '$echecs non parties.';
}

/// « Groupe privé » — un constat, et non un interrupteur.
///
/// **La colonne `groups.is_private` existe bel et bien**, `creer_groupe` la
/// renseigne, et l'application la lit. Mais **rien ne s'en sert** : aucune
/// politique RLS ne la cite, aucune fonction n'en dépend. `groups_select`
/// exige `is_group_member(id)` quelle qu'en soit la valeur, et Jelvo n'a ni
/// annuaire de groupes, ni page publique, ni recherche par nom.
///
/// Autrement dit **tout groupe Jelvo est privé**, et un interrupteur qui se
/// décoche promettrait un groupe public qui n'existe pas — exactement le genre
/// de ligne décorative qu'on écarte ailleurs. La ligne reste donc, parce
/// qu'elle dit quelque chose de vrai et de rassurant ; c'est le contrôle qui
/// s'en va. `creer_groupe` reçoit `true`, qui est déjà son défaut.
///
/// Le jour où un groupe public existerait — un annuaire, un lien
/// d'exploration —, l'interrupteur reviendrait ici sans rien changer en base.
class _ConfidentialiteCard extends StatelessWidget {
  const _ConfidentialiteCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const OptionIcon(icon: Icons.lock_outline_rounded),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Groupe privé',
                  style: AppTypography.body.copyWith(
                    fontWeight: AppTypography.medium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Seuls les membres invités pourront le rejoindre et voir '
                  'son contenu. Tous les groupes Jelvo le sont.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
