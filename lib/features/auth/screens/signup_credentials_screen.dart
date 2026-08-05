import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../models/credentials_rules.dart';
import '../providers/auth_providers.dart';
import '../providers/signup_providers.dart';
import '../repository/auth_repository.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';
import '../widgets/pseudo_field.dart';

/// Inscription, étape 1 : pseudo, adresse e-mail et mot de passe.
class SignUpCredentialsScreen extends ConsumerStatefulWidget {
  const SignUpCredentialsScreen({super.key});

  @override
  ConsumerState<SignUpCredentialsScreen> createState() =>
      _SignUpCredentialsScreenState();
}

class _SignUpCredentialsScreenState
    extends ConsumerState<SignUpCredentialsScreen> {
  final TextEditingController _pseudoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _pseudo = '';
  String _password = '';
  String? _emailError;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Restaure la saisie si l'utilisateur revient depuis l'étape suivante.
    final SignUpDraft draft = ref.read(signUpDraftProvider);
    _pseudoController.text = draft.pseudo;
    _emailController.text = draft.email;
    _passwordController.text = draft.password;
    _pseudo = draft.pseudo;
    _password = draft.password;
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Créer votre compte',
      subtitle: 'Choisissez un pseudo et sécurisez votre compte.',
      stepLabel: 'Étape 1 sur 2',
      onBack: () => context.pop(),
      children: <Widget>[
        PseudoField(
          controller: _pseudoController,
          pseudo: _pseudo,
          onChanged: (String value) => setState(() => _pseudo = value),
        ),
        AppSpacing.gapLg,

        AppTextField(
          label: 'Adresse e-mail',
          hint: 'camille.rousseau@example.com',
          controller: _emailController,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline_rounded,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        AppSpacing.gapLg,

        PasswordField(
          controller: _passwordController,
          hint: '8 caractères minimum',
          textInputAction: TextInputAction.done,
          errorText: _submitted
              ? CredentialsRules.passwordError(_password)
              : null,
          onChanged: (String value) => setState(() => _password = value),
          onSubmitted: (_) => _continue(),
        ),
        AppSpacing.gapMd,
        PasswordRulesChecklist(password: _password),

        AppSpacing.gapXl,
        PrimaryButton(label: 'Continuer', onPressed: _continue),

        AppSpacing.gapLg,
        Text(
          'En créant un compte, vous acceptez de recevoir un e-mail de '
          'vérification.',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      ],
    );
  }

  void _continue() {
    final String email = _emailController.text.trim();

    setState(() {
      _submitted = true;
      _emailError = CredentialsRules.emailError(email);
    });

    if (!CredentialsRules.isPseudoValid(_pseudo)) return;
    if (_emailError != null) return;
    if (!CredentialsRules.isPasswordValid(_password)) return;

    // Un pseudo déjà pris bloque ici plutôt qu'à la création du compte : mieux
    // vaut le signaler avant l'envoi de l'e-mail de vérification.
    final PseudoAvailability? availability = ref
        .read(pseudoAvailabilityProvider(_pseudo))
        .value;
    if (availability == PseudoAvailability.taken) return;

    ref
        .read(signUpDraftProvider.notifier)
        .setCredentials(pseudo: _pseudo, email: email, password: _password);
    context.pushNamed(AppRoutes.signUpIdentity);
  }
}
