import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';

/// Modification du profil : prénom et nom.
///
/// Séparée de l'affichage depuis la refonte : l'écran de profil se lit d'un
/// coup d'œil, et n'est un formulaire que lorsqu'on demande à le modifier.
/// L'avatar ne s'y change pas — il se touche là où on le voit —, et **la bio
/// non plus** : elle se modifie sur place, sur la ligne où elle se lit. Ne
/// restent ici que les deux champs qui changent rarement.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final TextEditingController _prenom = TextEditingController();
  final TextEditingController _nom = TextEditingController();

  /// Profil dont les contrôleurs reflètent le contenu, pour ne pas écraser
  /// une saisie en cours à chaque reconstruction.
  String? _profilCharge;

  bool _enregistrement = false;
  String? _erreur;

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Profile? profil = ref.watch(currentProfileProvider).value;
    if (profil != null) _synchroniser(profil);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: profil == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
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

                  AppTextField(
                    label: 'Prénom',
                    controller: _prenom,
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _effacerErreur(),
                  ),
                  AppSpacing.gapLg,
                  AppTextField(
                    label: 'Nom',
                    controller: _nom,
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _effacerErreur(),
                  ),
                  AppSpacing.gapXl,
                  PrimaryButton(
                    label: 'Enregistrer',
                    isLoading: _enregistrement,
                    onPressed: _enregistrer,
                  ),
                ],
              ),
      ),
    );
  }

  void _synchroniser(Profile profil) {
    if (_profilCharge == profil.id) return;
    _profilCharge = profil.id;
    _prenom.text = profil.firstName;
    _nom.text = profil.lastName;
  }

  void _effacerErreur() {
    if (_erreur != null) setState(() => _erreur = null);
  }

  Future<void> _enregistrer() async {
    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      // `saveNames` relit la bio pour ne pas l'écraser : elle se modifie
      // ailleurs, sur la ligne où elle se lit.
      await ref
          .read(profileActionsProvider)
          .saveNames(
            firstName: _prenom.text.trim(),
            lastName: _nom.text.trim(),
          );
      // La feuille se referme sur le profil, qui montre aussitôt la nouvelle
      // valeur : rester sur le formulaire laisserait douter de l'effet.
      navigateur.maybePop();
      messager.showSnackBar(
        const SnackBar(content: Text('Profil enregistré.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = AuthFailure.from(error).message;
      });
    }
  }
}
