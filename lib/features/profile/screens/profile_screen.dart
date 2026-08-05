import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/widgets/avatar_picker.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';

/// Écran Profil, branché sur la table `profiles`.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  /// Profil dont les contrôleurs reflètent le contenu, pour ne pas écraser une
  /// saisie en cours à chaque reconstruction.
  String? _loadedProfileId;

  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Profile?> profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Mon QR code',
            onPressed: () => context.pushNamed(AppRoutes.myQrCode),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => context.pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => _ErrorView(
            message: AuthFailure.from(error).message,
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (Profile? profile) {
            if (profile == null) {
              return const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profil introuvable',
                message:
                    'Votre profil n’a pas encore été créé. Reconnectez-vous '
                    'pour le finaliser.',
              );
            }
            _syncControllers(profile);
            return _form(profile);
          },
        ),
      ),
    );
  }

  void _syncControllers(Profile profile) {
    if (_loadedProfileId == profile.id) return;
    _loadedProfileId = profile.id;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _bioController.text = profile.bio ?? '';
  }

  Widget _form(Profile profile) {
    final String? email = ref.watch(currentEmailProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: AppRadii.fieldRadius,
            ),
            child: Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
          AppSpacing.gapLg,
        ],

        Center(
          child: AvatarPicker(
            bytes: null,
            imageUrl: profile.avatarUrl,
            initials: _initialsOf(profile),
            onPicked: _changeAvatar,
            onRemoved: () {},
          ),
        ),
        AppSpacing.gapMd,
        Center(child: Text(profile.displayName, style: AppTypography.h2)),
        Center(
          child: Text(profile.pseudoHandle, style: AppTypography.bodyMuted),
        ),

        AppSpacing.gapXl,
        const SectionHeader(title: 'Informations'),
        AppSpacing.gapLg,

        AppTextField(
          label: 'Prénom',
          controller: _firstNameController,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        AppSpacing.gapLg,
        AppTextField(
          label: 'Nom',
          controller: _lastNameController,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _clearError(),
        ),
        AppSpacing.gapLg,
        AppTextField(
          label: 'Bio',
          hint: 'Quelques mots sur vous',
          controller: _bioController,
          maxLines: 4,
          minLines: 3,
          maxLength: 280,
          helperText: 'Visible par vos contacts',
          onChanged: (_) => _clearError(),
        ),

        AppSpacing.gapLg,
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.alternate_email_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pseudo et e-mail', style: AppTypography.caption),
                    const SizedBox(height: 2),
                    Text(
                      email == null
                          ? profile.pseudoHandle
                          : '${profile.pseudoHandle} · $email',
                      style: AppTypography.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Enregistrer',
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  static String _initialsOf(Profile profile) {
    final String first = profile.firstName;
    final String last = profile.lastName;
    final String initials =
        (first.isEmpty ? '' : first[0]) + (last.isEmpty ? '' : last[0]);
    return initials.isEmpty
        ? profile.pseudo.characters.take(1).toString().toUpperCase()
        : initials.toUpperCase();
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _changeAvatar(Uint8List bytes, String extension) async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(profileActionsProvider).changeAvatar(bytes, extension);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = AuthFailure.from(error).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(profileActionsProvider)
          .save(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            bio: _bioController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Profil indisponible',
      message: message,
      actionLabel: 'Réessayer',
      onActionPressed: onRetry,
    );
  }
}
