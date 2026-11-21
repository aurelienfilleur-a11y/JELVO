import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/anniversaire.dart';
import '../providers/profile_providers.dart';

/// Feuille de saisie de l'anniversaire : **un jour et un mois, pas d'année**.
///
/// ### Pourquoi pas `showDatePicker`
///
/// Il demande une année, et il n'y a pas de façon de la lui retirer. La
/// collecter pour la jeter serait déjà l'avoir collectée ; la collecter et
/// l'enregistrer donnerait une date de naissance complète associée à un nom —
/// exactement ce que la consigne écarte, et ce qui sert couramment de question
/// de sécurité ailleurs. Deux listes déroulantes suffisent, et elles ne
/// peuvent pas demander ce qu'on ne veut pas savoir.
///
/// La feuille **montre l'état courant avant de le changer**, comme celle du
/// terme d'adhésion : on ouvre pour voir autant que pour modifier.
class AnniversaireSheet extends ConsumerStatefulWidget {
  const AnniversaireSheet({super.key, required this.actuel});

  final Anniversaire? actuel;

  static Future<void> ouvrir(BuildContext context, Anniversaire? actuel) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => AnniversaireSheet(actuel: actuel),
    );
  }

  @override
  ConsumerState<AnniversaireSheet> createState() => _AnniversaireSheetState();
}

class _AnniversaireSheetState extends ConsumerState<AnniversaireSheet> {
  int? _jour;
  int? _mois;
  bool _enregistrement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    // **Rien n'est présélectionné sans valeur enregistrée.** Ouvrir sur
    // « 1 janvier » donnerait une date qui a l'air choisie, et il suffirait
    // de toucher « Enregistrer » pour la poser sans l'avoir voulue.
    _jour = widget.actuel?.jour;
    _mois = widget.actuel?.mois;
  }

  bool get _complet => _jour != null && _mois != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppTexts.of(context).coreAnniversaire, style: context.typo.h3),
          AppSpacing.gapXs,
          Text(
            AppTexts.of(context).profileJourMoisSeulementJelvo,
            style: context.typo.caption,
          ),
          AppSpacing.gapMd,
          Text(
            AppTexts.of(context).profileContactsVoientPrevenusJour,
            style: context.typo.caption.copyWith(
              color: context.couleurs.textSecondary,
            ),
          ),
          AppSpacing.gapLg,

          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _Choix<int>(
                  libelle: AppTexts.of(context).coreJour,
                  valeur: _jour,
                  valeurs: <int>[
                    for (
                      int j = 1;
                      j <= Anniversaire.joursDansLeMois(_mois ?? 1);
                      j++
                    )
                      j,
                  ],
                  texte: (int j) => '$j',
                  onChange: (int? j) => setState(() => _jour = j),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                flex: 3,
                child: _Choix<int>(
                  libelle: AppTexts.of(context).coreMois,
                  valeur: _mois,
                  valeurs: <int>[for (int m = 1; m <= 12; m++) m],
                  texte: _nomDuMois,
                  onChange: _changerDeMois,
                ),
              ),
            ],
          ),

          if (_mois == 2 && _jour == 29) ...<Widget>[
            AppSpacing.gapMd,
            _Avertissement(
              texte: AppTexts.of(context).profileAnneesNonBissextilesSera,
            ),
          ],

          if (_erreur != null) ...<Widget>[
            AppSpacing.gapMd,
            Text(
              _erreur!,
              style: context.typo.caption.copyWith(
                color: context.couleurs.dangerInk,
              ),
            ),
          ],

          AppSpacing.gapLg,
          Row(
            children: <Widget>[
              // Le retrait n'est proposé que s'il y a quelque chose à retirer.
              if (widget.actuel != null) ...<Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: AppTexts.of(context).coreRetirer,
                    onPressed: _enregistrement ? null : () => _ecrire(null),
                    isDestructive: true,
                  ),
                ),
                AppSpacing.hGapMd,
              ],
              Expanded(
                child: PrimaryButton(
                  label: AppTexts.of(context).commonSave,
                  isLoading: _enregistrement,
                  // Une moitié de date ne s'enregistre pas : la base la
                  // refuserait, et le bouton grisé le dit avant l'erreur.
                  onPressed: _complet
                      ? () => _ecrire(Anniversaire(jour: _jour!, mois: _mois!))
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Changer de mois peut rendre le jour impossible — 31 janvier puis
  /// février. On le ramène au dernier jour du mois plutôt que de le vider :
  /// vider obligerait à ressaisir ce qu'on n'a pas voulu changer.
  void _changerDeMois(int? mois) {
    setState(() {
      _mois = mois;
      final int? jour = _jour;
      if (mois != null && jour != null) {
        final int max = Anniversaire.joursDansLeMois(mois);
        if (jour > max) _jour = max;
      }
    });
  }

  Future<void> _ecrire(Anniversaire? valeur) async {
    final NavigatorState navigateur = Navigator.of(context);
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await ref.read(profileActionsProvider).saveAnniversaire(valeur);
      navigateur.pop();
    } catch (error) {
      if (!mounted) return;
      // **Un échec reste dans la feuille**, avec son message : la refermer
      // ferait disparaître l'erreur et laisserait croire à un enregistrement.
      setState(() {
        _enregistrement = false;
        _erreur = AuthFailure.from(error).message(AppTexts.of(context));
      });
    }
  }

  static String _nomDuMois(int mois) => const <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ][mois - 1];
}

/// Une liste déroulante encadrée, au gabarit des champs de l'application.
class _Choix<T> extends StatelessWidget {
  const _Choix({
    required this.libelle,
    required this.valeur,
    required this.valeurs,
    required this.texte,
    required this.onChange,
  });

  final String libelle;
  final T? valeur;
  final List<T> valeurs;
  final String Function(T) texte;
  final ValueChanged<T?> onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(libelle, style: context.typo.caption),
        AppSpacing.gapXs,
        DropdownButtonFormField<T>(
          initialValue: valeur,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(borderRadius: AppRadii.fieldRadius),
          ),
          hint: Text('—', style: context.typo.body),
          items: <DropdownMenuItem<T>>[
            for (final T v in valeurs)
              DropdownMenuItem<T>(value: v, child: Text(texte(v))),
          ],
          onChanged: onChange,
        ),
      ],
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.couleurs.warningSoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: context.couleurs.warningInk,
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              texte,
              style: context.typo.caption.copyWith(
                color: context.couleurs.warningInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
