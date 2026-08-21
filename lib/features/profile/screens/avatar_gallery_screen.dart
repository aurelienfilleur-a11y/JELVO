import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/avatar_catalog.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';

/// Galerie des avatars prédéfinis.
///
/// **La sélection et la confirmation sont deux gestes distincts.** Un appui
/// met en évidence, un second bouton enregistre : sur une grille dense, un
/// enregistrement au premier contact ferait poser un avatar par erreur à
/// chaque défilement maladroit.
class AvatarGalleryScreen extends ConsumerStatefulWidget {
  const AvatarGalleryScreen({super.key});

  @override
  ConsumerState<AvatarGalleryScreen> createState() =>
      _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends ConsumerState<AvatarGalleryScreen> {
  String? _choisi;
  bool _enregistrement = false;
  String? _erreur;

  /// Vrai tant que l'écran n'a pas encore lu l'avatar du profil : sans ce
  /// drapeau, la relecture du profil écraserait un choix en cours.
  bool _initialise = false;

  @override
  Widget build(BuildContext context) {
    final Profile? profil = ref.watch(currentProfileProvider).value;
    if (!_initialise && profil != null) {
      _initialise = true;
      _choisi = profil.avatarPreset;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choisir un avatar'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
          onPressed: _enregistrement
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.md,
                  AppSpacing.screenMargin,
                  0,
                ),
                child: Container(
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
              ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                // Les tuiles ne sont construites — donc les images chargées —
                // qu'à mesure du défilement. Les quatre-vingt-treize fichiers
                // ne partent jamais d'un coup.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                ),
                itemCount: avatarsPredefinis.length,
                itemBuilder: (BuildContext context, int index) {
                  final String id = avatarsPredefinis[index];
                  return _Vignette(
                    id: id,
                    choisi: id == _choisi,
                    onTap: _enregistrement
                        ? null
                        : () => setState(() => _choisi = id),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.md,
                AppSpacing.screenMargin,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: AppShadows.overlay,
              ),
              child: PrimaryButton(
                label: 'Utiliser cet avatar',
                icon: Icons.check_rounded,
                isLoading: _enregistrement,
                onPressed: _choisi == null ? null : _enregistrer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    final String? id = _choisi;
    if (id == null) return;

    final NavigatorState navigateur = Navigator.of(context);
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await ref.read(profileActionsProvider).choisirAvatar(id);
      navigateur.maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _erreur = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }
}

/// Une case de la grille : l'avatar, et un anneau quand il est retenu.
class _Vignette extends StatelessWidget {
  const _Vignette({
    required this.id,
    required this.choisi,
    required this.onTap,
  });

  final String id;
  final bool choisi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choisi,
      label: 'Avatar $id',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: choisi
                ? Border.all(color: AppColors.primary, width: 3)
                : Border.all(color: AppColors.border),
            boxShadow: choisi ? AppShadows.accent : null,
          ),
          child: ClipOval(
            child: Padding(
              // Le trait de sélection ne doit pas mordre sur l'illustration,
              // qui est déjà détourée au bord du cercle.
              padding: EdgeInsets.all(choisi ? 3 : 1),
              child: Image.asset(
                cheminAvatar(id),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.primarySoft,
                  child: Center(
                    child: Icon(Icons.person_rounded, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
