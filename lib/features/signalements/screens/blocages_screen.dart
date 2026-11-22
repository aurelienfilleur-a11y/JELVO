import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/blocage.dart';
import '../providers/signalement_providers.dart';

/// La liste des personnes bloquées — `/parametres/bloques`.
///
/// **Elle est nécessaire, pas confortable.** `profil_consultable` ne rend plus
/// rien sur une personne bloquée : sans cet écran, il n'y aurait aucun chemin
/// pour débloquer quelqu'un, et l'on se serait enfermé dans son propre
/// réglage. C'est la même raison qui fait exister `mes_blocages()` côté base.
class BlocagesScreen extends ConsumerStatefulWidget {
  const BlocagesScreen({super.key});

  @override
  ConsumerState<BlocagesScreen> createState() => _BlocagesScreenState();
}

class _BlocagesScreenState extends ConsumerState<BlocagesScreen> {
  String? _enCours;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    final AsyncValue<List<PersonneBloquee>> lecture = ref.watch(
      bloquesProvider,
    );
    final List<PersonneBloquee> bloques =
        lecture.value ?? const <PersonneBloquee>[];

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(title: Text(t.profileBloques)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(bloquesProvider.notifier).refresh(),
        child: ListView(
          padding: AppSpacing.screenAll,
          children: <Widget>[
            if (lecture.hasError)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: t.profileBloques,
                message: AuthFailure.from(lecture.error!).message(t),
              )
            else if (lecture.isLoading && bloques.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (bloques.isEmpty)
              // Elle dit **où** l'on bloque : cet écran ne le permet pas, et
              // un état vide qui ne mène nulle part laisserait chercher.
              EmptyState(
                icon: Icons.block_outlined,
                title: t.blocageVideTitre,
                message: t.blocageVideMessage,
              )
            else
              for (final PersonneBloquee p in bloques) ...<Widget>[
                _Ligne(
                  personne: p,
                  occupee: _enCours == p.userId,
                  onDebloquer: () => _confirmerDeblocage(p),
                ),
                AppSpacing.gapSm,
              ],
          ],
        ),
      ),
    );
  }

  /// **Le déblocage se confirme**, et la confirmation dit ce qui ne revient
  /// pas : le lien de contact supprimé au blocage ne se reconstitue pas.
  Future<void> _confirmerDeblocage(PersonneBloquee personne) async {
    final AppTexts t = AppTexts.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    final bool? confirme = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogue) => AlertDialog(
        title: Text(t.profileDebloquer),
        content: Text(t.blocageDebloquerConfirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(true),
            child: Text(t.profileDebloquer),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _enCours = personne.userId);
    try {
      final BlocageOutcome issue = await ref
          .read(signalementActionsProvider)
          .debloquer(personne.userId);
      if (!mounted) return;
      setState(() => _enCours = null);
      messager.showSnackBar(SnackBar(content: Text(issue.message(t))));
    } catch (error) {
      if (!mounted) return;
      setState(() => _enCours = null);
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message(t))),
      );
    }
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.personne,
    required this.occupee,
    required this.onDebloquer,
  });

  final PersonneBloquee personne;
  final bool occupee;
  final VoidCallback onDebloquer;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          AvatarImage(
            data: AvatarData(
              name: personne.nom ?? t.coreCompteSupprime,
              imageUrl: personne.avatarUrl,
            ),
            size: 40,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EmojiText(
                  personne.nom ?? t.coreCompteSupprime,
                  style: context.typo.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.blocageDepuis(AppDates.timeAgo(personne.creeLe, t)),
                  style: context.typo.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          if (occupee)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            SecondaryButton(
              label: t.profileDebloquer,
              expanded: false,
              onPressed: onDebloquer,
            ),
        ],
      ),
    );
  }
}
