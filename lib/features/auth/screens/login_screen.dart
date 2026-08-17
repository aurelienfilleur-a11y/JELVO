import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../groups/providers/group_providers.dart';
import '../models/auth_failure.dart';
import '../providers/auth_providers.dart';
import '../providers/signup_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

/// Écran de connexion : pseudo ou adresse e-mail, plus mot de passe.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;

  /// Cochée par défaut : c'est le comportement que l'application avait, et
  /// celui qu'on attend d'un téléphone personnel.
  bool _seSouvenir = true;

  String? _errorMessage;
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Content de vous revoir',
      subtitle: 'Connectez-vous pour retrouver vos groupes et votre agenda.',
      children: <Widget>[
        if (_errorMessage != null) ...<Widget>[
          AuthErrorBanner(message: _errorMessage!),
          AppSpacing.gapLg,
        ],

        AppTextField(
          label: 'Pseudo ou adresse e-mail',
          hint: 'camille.rousseau',
          controller: _identifierController,
          errorText: _identifierError,
          prefixIcon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.username],
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
          onChanged: (_) => _clearErrors(),
        ),
        AppSpacing.gapLg,

        PasswordField(
          controller: _passwordController,
          errorText: _passwordError,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearErrors(),
          onSubmitted: (_) => _submit(),
        ),

        AppSpacing.gapSm,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _submitting
                ? null
                : () => context.pushNamed(AppRoutes.forgotPassword),
            child: const Text('Mot de passe oublié ?'),
          ),
        ),

        _caseSeSouvenir(),

        AppSpacing.gapLg,
        PrimaryButton(
          label: 'Se connecter',
          isLoading: _submitting,
          onPressed: _submit,
        ),

        AppSpacing.gapXl,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                'Pas encore de compte ?',
                style: AppTypography.bodyMuted,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _submitting ? null : _goToSignUp,
              child: const Text("S'inscrire"),
            ),
          ],
        ),
      ],
    );
  }

  /// « Se souvenir de moi », et la précision qui évite un faux bug.
  ///
  /// Sans elle, quelqu'un qui coche la case dans Safari puis ouvre
  /// l'application installée se retrouve devant l'écran de connexion et en
  /// conclut, très raisonnablement, que la case ne marche pas. Une application
  /// posée sur l'écran d'accueil a son propre stockage : c'est une session
  /// distincte, et rien dans le code ne peut y changer quoi que ce soit.
  Widget _caseSeSouvenir() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: _submitting
              ? null
              : () => setState(() => _seSouvenir = !_seSouvenir),
          borderRadius: AppRadii.fieldRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: _seSouvenir,
                  onChanged: _submitting
                      ? null
                      : (bool? coche) =>
                            setState(() => _seSouvenir = coche ?? true),
                ),
                Flexible(
                  child: Text('Se souvenir de moi', style: AppTypography.body),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Text(
            _seSouvenir
                ? 'Vous resterez connecté jusqu’à la déconnexion.'
                : 'Vous serez déconnecté à la fermeture de l’application.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),

        if (ref.watch(estSurLeWebProvider)) ...<Widget>[
          AppSpacing.gapSm,
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadii.fieldRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: Text(
                    'Jelvo installé sur l’écran d’accueil a sa propre '
                    'session : s’y connecter est une étape distincte de '
                    'Safari, même avec cette case cochée.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.midnight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _clearErrors() {
    if (_errorMessage == null &&
        _identifierError == null &&
        _passwordError == null) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _identifierError = null;
      _passwordError = null;
    });
  }

  void _goToSignUp() {
    // Un parcours d'inscription abandonné ne doit pas repartir à mi-chemin.
    ref.read(signUpDraftProvider.notifier).reset();
    context.pushNamed(AppRoutes.signUp);
  }

  Future<void> _submit() async {
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text;

    setState(() {
      _identifierError = identifier.isEmpty
          ? 'Renseignez votre pseudo ou votre adresse e-mail.'
          : null;
      _passwordError = password.isEmpty
          ? 'Renseignez votre mot de passe.'
          : null;
      _errorMessage = null;
    });
    if (_identifierError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    try {
      // **Avant** la connexion, pas après : gotrue écrit la session dans la
      // foulée de `signIn`, et le réglage doit déjà être en place quand il le
      // fait. L'inverse persisterait la session que l'on vient de refuser.
      await ref
          .read(sessionPersistenceProvider)
          .definir(seSouvenir: _seSouvenir);

      await ref
          .read(authRepositoryProvider)
          .signIn(identifier: identifier, password: password);
      // Connexion venue d'un lien d'invitation : le jeton mis de côté avant le
      // détour par la connexion est consommé maintenant.
      await ref.read(groupActionsProvider).joinPendingInvite();
      // La redirection est prise en charge par la garde du routeur, déclenchée
      // par le changement de session.
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
