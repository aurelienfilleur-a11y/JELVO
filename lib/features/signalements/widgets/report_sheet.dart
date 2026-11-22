import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/signalement.dart';
import '../providers/signalement_providers.dart';

/// La feuille qui dépose un signalement, pour les trois cibles.
///
/// **Une seule feuille, et non trois.** Ce qui change d'un message à un
/// groupe ou à un profil, c'est le titre : les motifs, le champ de précisions
/// et les deux phrases d'explication sont les mêmes. Trois feuilles auraient
/// fini par diverger, comme trois fonctions SQL pour poser une même date.
///
/// Une feuille et non un écran : signaler est un geste bref, et garder
/// derrière soi la conversation qu'on signale dit d'où l'on vient.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.cible,
    required this.cibleId,
    this.nomVise,
  });

  final SignalementCible cible;
  final String cibleId;

  /// Qui ou quoi est visé, pour que le titre ne soit pas abstrait. Facultatif :
  /// un profil sans nom reste signalable.
  final String? nomVise;

  static Future<void> ouvrir(
    BuildContext context, {
    required SignalementCible cible,
    required String cibleId,
    String? nomVise,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) =>
          ReportSheet(cible: cible, cibleId: cibleId, nomVise: nomVise),
    );
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final TextEditingController _precisions = EmojiTextEditingController();
  SignalementMotif? _motif;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _precisions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_titre(t), style: context.typo.h2),
              if (widget.nomVise != null) ...<Widget>[
                AppSpacing.gapXs,
                EmojiText(
                  widget.nomVise!,
                  style: context.typo.bodyMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              AppSpacing.gapMd,
              // **Les deux phrases qui décident si l'on ose signaler.** La
              // première répond à « va-t-il le savoir ? », qui est la
              // première question de quelqu'un qui hésite ; la seconde dit
              // que l'effacement ne sauvera personne, et évite d'avoir à
              // faire une capture d'écran avant de signaler.
              _Encart(
                texte: t.signalementConfidentiel,
                icone: Icons.lock_outline_rounded,
              ),
              if (widget.cible == SignalementCible.message) ...<Widget>[
                AppSpacing.gapSm,
                _Encart(
                  texte: t.signalementContenuGarde,
                  icone: Icons.bookmark_border_rounded,
                ),
              ],

              AppSpacing.gapLg,
              for (final SignalementMotif motif in SignalementMotif.values)
                _LigneMotif(
                  motif: motif,
                  choisi: _motif == motif,
                  onTap: _envoi
                      ? null
                      : () => setState(() {
                          _motif = motif;
                          _erreur = null;
                        }),
                ),

              AppSpacing.gapLg,
              AppTextField(
                controller: _precisions,
                label: t.signalementCommentaire,
                helperText: t.signalementCommentaireAide,
                maxLines: 3,
                maxLength: 2000,
                showCounter: true,
              ),

              if (_erreur != null) ...<Widget>[
                AppSpacing.gapSm,
                Text(
                  _erreur!,
                  style: context.typo.caption.copyWith(
                    color: context.couleurs.dangerInk,
                  ),
                ),
              ],

              AppSpacing.gapLg,
              PrimaryButton(
                label: t.signalementEnvoyer,
                isLoading: _envoi,
                onPressed: _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titre(AppTexts t) => switch (widget.cible) {
    SignalementCible.message => t.signalementTitreMessage,
    SignalementCible.group => t.signalementTitreGroupe,
    SignalementCible.profile => t.signalementTitreProfil,
  };

  Future<void> _envoyer() async {
    // Lus **avant** l'attente : la feuille peut avoir été refermée après.
    final AppTexts t = AppTexts.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final NavigatorState navigateur = Navigator.of(context);

    final SignalementMotif? motif = _motif;
    if (motif == null) {
      setState(() => _erreur = t.signalementChoisirMotif);
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      final SignalementOutcome issue = await ref
          .read(signalementActionsProvider)
          .signaler(
            cible: widget.cible,
            cibleId: widget.cibleId,
            motif: motif,
            commentaire: _precisions.text,
          );

      if (!mounted) return;

      // **Un refus reste dans la feuille**, avec son message : la refermer
      // sur une `SnackBar` furtive laisserait croire à un envoi. « Déjà
      // signalé » en fait partie — ce n'est pas une panne, c'est la réponse.
      if (!issue.isSuccess) {
        setState(() {
          _envoi = false;
          _erreur = issue.message(t);
        });
        return;
      }

      navigateur.maybePop();
      messager.showSnackBar(SnackBar(content: Text(issue.message(t))));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = AuthFailure.from(error).message(t);
      });
    }
  }
}

/// Un motif, son aide et sa coche.
class _LigneMotif extends StatelessWidget {
  const _LigneMotif({
    required this.motif,
    required this.choisi,
    required this.onTap,
  });

  final SignalementMotif motif;
  final bool choisi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(
              choisi
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: choisi
                  ? context.couleurs.primary
                  : context.couleurs.textSecondary,
              size: 22,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    motif.label(t),
                    style: context.typo.body.copyWith(
                      fontWeight: choisi
                          ? AppTypography.semiBold
                          : AppTypography.regular,
                    ),
                  ),
                  Text(
                    motif.aide(t),
                    style: context.typo.caption.copyWith(
                      color: context.couleurs.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un pavé teinté, pour une phrase qui explique plutôt qu'elle n'alerte.
class _Encart extends StatelessWidget {
  const _Encart({required this.texte, required this.icone});

  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.couleurs.primarySoft,
      borderColor: Colors.transparent,
      shadows: const <BoxShadow>[],
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icone, size: 18, color: context.couleurs.primary),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              texte,
              style: context.typo.caption.copyWith(
                color: context.couleurs.encre,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
