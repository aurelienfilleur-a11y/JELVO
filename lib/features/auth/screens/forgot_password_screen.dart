import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../models/auth_failure.dart';
import '../models/credentials_rules.dart';
import '../providers/auth_providers.dart';
import '../providers/password_reset_providers.dart';
import '../widgets/auth_scaffold.dart';

/// Demande d'un code de réinitialisation de mot de passe.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  bool _submitting = false;
  String? _emailError;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Mot de passe oublié',
      subtitle:
          'Indiquez votre adresse e-mail : nous vous enverrons un code à six '
          'chiffres pour en choisir un nouveau.',
      onBack: _submitting ? null : () => context.pop(),
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          AuthErrorBanner(message: _errorMessage!),
          AppSpacing.gapLg,
        ],

        AppTextField(
          label: 'Adresse e-mail',
          hint: 'camille.rousseau@example.com',
          controller: _emailController,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline_rounded,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.email],
          onChanged: (_) {
            if (_emailError != null || _errorMessage != null) {
              setState(() {
                _emailError = null;
                _errorMessage = null;
              });
            }
          },
          onSubmitted: (_) => _submit(),
        ),

        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Envoyer le code',
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();

    setState(() {
      _emailError = CredentialsRules.emailError(email);
      _errorMessage = null;
    });
    if (_emailError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetCode(email);
      if (!mounted) return;
      ref.read(passwordResetEmailProvider.notifier).set(email);
      context.pushNamed(AppRoutes.resetPassword);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
