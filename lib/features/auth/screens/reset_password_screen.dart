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
      title: AppTexts.of(context).authNouveauMotPasse,
      subtitle: email.isEmpty
          ? AppTexts.of(context).authSaisissezCodeRecuPuis
          : AppTexts.of(context).authSaisissezCodeEnvoyeEmail(email),
      onBack: _submitting ? null : () => context.pop(),
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          AuthErrorBanner(message: _errorMessage!),
          AppSpacing.gapLg,
        ],
        if (_infoMessage != null) ...<Widget>[
          Text(
            _infoMessage!,
            style: context.typo.caption.copyWith(
              color: context.couleurs.success,
            ),
          ),
          AppSpacing.gapLg,
        ],

        Text(
          AppTexts.of(context).authCodeVerification,
          style: context.typo.caption,
        ),
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
          label: AppTexts.of(context).authNouveauMotPasse,
          hint: AppTexts.of(context).auth8CaracteresMinimum,
          textInputAction: TextInputAction.done,
          errorText: _submitted
              ? CredentialsRules.passwordError(_password, AppTexts.of(context))
              : null,
          onChanged: (String value) => setState(() => _password = value),
          onSubmitted: (_) => _submit(),
        ),
        AppSpacing.gapMd,
        PasswordRulesChecklist(password: _password),

        AppSpacing.gapXl,
        PrimaryButton(
          label: AppTexts.of(context).authChangerMotPasse,
          isLoading: _submitting,
          onPressed: _submit,
        ),

        AppSpacing.gapLg,
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _resend,
                  child: Text(AppTexts.of(context).authRenvoyerCode),
                )
              : Text(
                  _resending
                      ? AppTexts.of(context).authEnvoiCours
                      : AppTexts.of(
                          context,
                        ).authNouveauCodePossibleSecondsLeft(_secondsLeft),
                  style: context.typo.caption,
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
      setState(
        () => _errorMessage = AppTexts.of(context).authSaisissezSixChiffresCode,
      );
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
        SnackBar(content: Text(AppTexts.of(context).authMotPasseEteMis)),
      );
      // La session ouverte par le code de récupération suffit : la garde du
      // routeur emmène directement à l'accueil.
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = AuthFailure.from(
          error,
        ).message(AppTexts.of(context)),
      );
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
      setState(
        () => _infoMessage = AppTexts.of(context).authNouveauCodeVientEtre,
      );
      _startResendCountdown();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = AuthFailure.from(
          error,
        ).message(AppTexts.of(context)),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }
}
