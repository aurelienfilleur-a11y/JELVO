import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../models/auth_failure.dart';
import '../models/credentials_rules.dart';
import '../providers/auth_providers.dart';
import '../providers/password_reset_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';
import '../widgets/verification_code_field.dart';

/// Saisie du code reçu puis du nouveau mot de passe.
///
/// Les deux étapes tiennent dans le même écran : le code ouvre une session de
/// récupération, immédiatement utilisée pour changer le mot de passe.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Timer? _timer;
  int _secondsLeft = 0;
  bool _submitting = false;
  bool _resending = false;
  bool _submitted = false;
  String _password = '';
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConfig.resendCodeDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String email = ref.watch(passwordResetEmailProvider);
    final bool canResend = _secondsLeft <= 0 && !_resending && !_submitting;

    return AuthScaffold(
      title: 'Nouveau mot de passe',
      subtitle: email.isEmpty
          ? 'Saisissez le code reçu, puis choisissez un nouveau mot de passe.'
          : 'Saisissez le code envoyé à $email, puis choisissez un nouveau '
                'mot de passe.',
      onBack: _submitting ? null : () => context.pop(),
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          AuthErrorBanner(message: _errorMessage!),
          AppSpacing.gapLg,
        ],
        if (_infoMessage != null) ...<Widget>[
          Text(
            _infoMessage!,
            style: AppTypography.caption.copyWith(color: AppColors.success),
          ),
          AppSpacing.gapLg,
        ],

        Text('Code de vérification', style: AppTypography.caption),
        AppSpacing.gapSm,
        VerificationCodeField(
          controller: _codeController,
          hasError: _errorMessage != null,
          enabled: !_submitting,
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
        ),

        AppSpacing.gapLg,
        PasswordField(
          controller: _passwordController,
          label: 'Nouveau mot de passe',
          hint: '8 caractères minimum',
          textInputAction: TextInputAction.done,
          errorText: _submitted
              ? CredentialsRules.passwordError(_password)
              : null,
          onChanged: (String value) => setState(() => _password = value),
          onSubmitted: (_) => _submit(),
        ),
        AppSpacing.gapMd,
        PasswordRulesChecklist(password: _password),

        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Changer le mot de passe',
          isLoading: _submitting,
          onPressed: _submit,
        ),

        AppSpacing.gapLg,
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _resend,
                  child: const Text('Renvoyer le code'),
                )
              : Text(
                  _resending
                      ? 'Envoi en cours…'
                      : 'Nouveau code possible dans $_secondsLeft s',
                  style: AppTypography.caption,
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final String code = _codeController.text;
    final String email = ref.read(passwordResetEmailProvider);

    setState(() {
      _submitted = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    if (!CredentialsRules.isCodeComplete(code)) {
      setState(() => _errorMessage = 'Saisissez les six chiffres du code.');
      return;
    }
    if (!CredentialsRules.isPasswordValid(_password)) return;

    setState(() => _submitting = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.verifyPasswordResetCode(email: email, code: code);
      await auth.updatePassword(_password);

      if (!mounted) return;
      ref.read(passwordResetEmailProvider.notifier).clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre mot de passe a été mis à jour.')),
      );
      // La session ouverte par le code de récupération suffit : la garde du
      // routeur emmène directement à l'accueil.
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetCode(ref.read(passwordResetEmailProvider));
      if (!mounted) return;
      setState(() => _infoMessage = 'Un nouveau code vient d’être envoyé.');
      _startResendCountdown();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }
}
