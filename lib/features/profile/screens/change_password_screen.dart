import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/models/credentials_rules.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/widgets/password_field.dart';

/// Changer son mot de passe depuis les paramètres.
///
/// L'écriture existait déjà — `updatePassword`, écrite pour la fin du parcours
/// « mot de passe oublié ». Ce qui manquait, c'était le chemin : on ne pouvait
/// changer son mot de passe qu'en prétendant l'avoir oublié.
///
/// **L'ancien mot de passe n'est pas redemandé.** gotrue ne le vérifie pas :
/// `updateUser` s'appuie sur la session, pas sur une confirmation. Le champ
/// existerait donc sans rien contrôler — et un champ qui ne contrôle rien
/// donne un faux sentiment de sécurité.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final TextEditingController _controleur = TextEditingController();

  String _motDePasse = '';
  bool _soumis = false;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Changer de mot de passe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: _enCours ? null : () => Navigator.of(context).maybePop(),
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
            if (_erreur != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Text(
                  _erreur!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
              AppSpacing.gapLg,
            ],

            PasswordField(
              controller: _controleur,
              label: 'Nouveau mot de passe',
              hint: '8 caractères minimum',
              textInputAction: TextInputAction.done,
              errorText: _soumis
                  ? CredentialsRules.passwordError(_motDePasse)
                  : null,
              onChanged: (String valeur) => setState(() {
                _motDePasse = valeur;
                _erreur = null;
              }),
              onSubmitted: (_) => _enregistrer(),
            ),
            AppSpacing.gapMd,
            PasswordRulesChecklist(password: _motDePasse),

            AppSpacing.gapXl,
            PrimaryButton(
              label: 'Changer le mot de passe',
              isLoading: _enCours,
              onPressed: _enregistrer,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    setState(() => _soumis = true);
    if (!CredentialsRules.isPasswordValid(_motDePasse)) return;

    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_motDePasse);
      navigateur.maybePop();
      messager.showSnackBar(
        const SnackBar(content: Text('Mot de passe changé.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = AuthFailure.from(error).message;
      });
    }
  }
}
