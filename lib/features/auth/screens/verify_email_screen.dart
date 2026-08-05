import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../models/auth_failure.dart';
import '../models/credentials_rules.dart';
import '../providers/auth_providers.dart';
import '../providers/signup_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/verification_code_field.dart';

/// Vérification de l'adresse e-mail par code à six chiffres.
///
/// Une fois le code validé, une session existe : c'est le premier moment où la
/// ligne `profiles` peut être créée et la photo téléversée sans se heurter aux
/// politiques RLS.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();

  Timer? _timer;
  int _secondsLeft = 0;
  bool _submitting = false;
  bool _resending = false;
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
    final SignUpDraft draft = ref.watch(signUpDraftProvider);
    final bool canResend = _secondsLeft <= 0 && !_resending && !_submitting;

    return AuthScaffold(
      title: 'Vérifiez votre e-mail',
      subtitle: draft.email.isEmpty
          ? 'Saisissez le code à six chiffres que nous venons de vous envoyer.'
          : 'Nous avons envoyé un code à six chiffres à ${draft.email}.',
      onBack: _submitting ? null : () => context.pop(),
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          AuthErrorBanner(message: _errorMessage!),
          AppSpacing.gapLg,
        ],
        if (_infoMessage != null) ...<Widget>[
          _InfoBanner(message: _infoMessage!),
          AppSpacing.gapLg,
        ],

        VerificationCodeField(
          controller: _codeController,
          hasError: _errorMessage != null,
          enabled: !_submitting,
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          onCompleted: (_) => _submit(),
        ),

        AppSpacing.gapXl,
        PrimaryButton(
          label: 'Vérifier',
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
    final SignUpDraft draft = ref.read(signUpDraftProvider);

    if (!CredentialsRules.isCodeComplete(code)) {
      setState(() => _errorMessage = 'Saisissez les six chiffres du code.');
      return;
    }

    // Capturé avant les `await` : la garde du routeur peut avoir quitté cet
    // écran d'ici là, alors que le messager, lui, vit à la racine.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .verifySignUpCode(email: draft.email, code: code);

      // La session existe désormais : on peut créer le profil et téléverser la
      // photo.
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
      // La garde du routeur bascule vers l'accueil dès que la session est là.
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
          .resendSignUpCode(ref.read(signUpDraftProvider).email);
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

/// Bandeau d'information neutre, pendant du bandeau d'erreur.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.mark_email_read_outlined,
            size: 20,
            color: AppColors.success,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
