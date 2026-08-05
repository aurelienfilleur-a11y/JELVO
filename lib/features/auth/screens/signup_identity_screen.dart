import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../models/auth_failure.dart';
import '../providers/auth_providers.dart';
import '../providers/signup_providers.dart';
import '../repository/auth_repository.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/avatar_picker.dart';

/// Inscription, étape 2 : prénom, nom et photo facultative.
///
/// C'est ici que le compte est réellement créé : l'e-mail de vérification
/// n'est envoyé qu'une fois toutes les informations réunies.
class SignUpIdentityScreen extends ConsumerStatefulWidget {
  const SignUpIdentityScreen({super.key});

  @override
  ConsumerState<SignUpIdentityScreen> createState() =>
      _SignUpIdentityScreenState();
}

class _SignUpIdentityScreenState extends ConsumerState<SignUpIdentityScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;
  String? _firstNameError;
  String? _lastNameError;

  @override
  void initState() {
    super.initState();
    final SignUpDraft draft = ref.read(signUpDraftProvider);
    _firstNameController.text = draft.firstName;
    _lastNameController.text = draft.lastName;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SignUpDraft draft = ref.watch(signUpDraftProvider);

    return AuthScaffold(
      title: 'Vous vous appelez comment ?',
      subtitle: 'Vos proches vous reconnaîtront plus facilement.',
      stepLabel: 'Étape 2 sur 2',
      onBack: _submitting ? null : () => context.pop(),
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          AuthErrorBanner(message: _errorMessage!),
          AppSpacing.gapLg,
        ],

        AvatarPicker(
          bytes: draft.avatarBytes,
          initials: _initials,
          onPicked: (Uint8List bytes, String extension) => ref
              .read(signUpDraftProvider.notifier)
              .setAvatar(bytes, extension),
          onRemoved: ref.read(signUpDraftProvider.notifier).removeAvatar,
        ),
        AppSpacing.gapXl,

        AppTextField(
          label: 'Prénom',
          hint: 'Camille',
          controller: _firstNameController,
          errorText: _firstNameError,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.givenName],
          onChanged: (_) => _clearErrors(),
        ),
        AppSpacing.gapLg,

        AppTextField(
          label: 'Nom',
          hint: 'Rousseau',
          controller: _lastNameController,
          errorText: _lastNameError,
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.familyName],
          onChanged: (_) => _clearErrors(),
          onSubmitted: (_) => _submit(),
        ),

        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Créer mon compte',
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  String get _initials {
    final String first = _firstNameController.text.trim();
    final String last = _lastNameController.text.trim();
    final String initials =
        (first.isEmpty ? '' : first[0]) + (last.isEmpty ? '' : last[0]);
    return initials.toUpperCase();
  }

  void _clearErrors() {
    if (_errorMessage == null &&
        _firstNameError == null &&
        _lastNameError == null) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _firstNameError = null;
      _lastNameError = null;
    });
  }

  Future<void> _submit() async {
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();

    setState(() {
      _firstNameError = firstName.isEmpty ? 'Renseignez votre prénom.' : null;
      _lastNameError = lastName.isEmpty ? 'Renseignez votre nom.' : null;
      _errorMessage = null;
    });
    if (_firstNameError != null || _lastNameError != null) return;

    ref
        .read(signUpDraftProvider.notifier)
        .setIdentity(firstName: firstName, lastName: lastName);
    final SignUpDraft draft = ref.read(signUpDraftProvider);

    // Capturé avant les `await` : la garde du routeur peut avoir quitté cet
    // écran d'ici là, alors que le messager, lui, vit à la racine.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      final SignUpOutcome outcome = await ref
          .read(authRepositoryProvider)
          .signUp(
            email: draft.email,
            password: draft.password,
            pseudo: draft.pseudo,
            firstName: firstName,
            lastName: lastName,
          );

      if (outcome == SignUpOutcome.codeSent) {
        if (!mounted) return;
        context.pushNamed(AppRoutes.verifyEmail);
        return;
      }

      // Confirmation d'e-mail désactivée : la session est déjà ouverte, on
      // enchaîne sur le profil et la garde du routeur mène à l'accueil.
      final String? warning = await ref
          .read(signUpActionsProvider)
          .completeProfile();
      if (warning != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Compte créé, mais le profil n’a pas pu être enregistré : '
              '$warning',
            ),
          ),
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
