import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/widgets/password_field.dart';
import '../models/resultat_suppression.dart';
import '../providers/profile_providers.dart';

/// Supprimer son compte soi-même, sans écrire à personne.
///
/// **Un écran et non une feuille.** Ce qui disparaît et ce qui reste tient en
/// une douzaine de lignes, et doit pouvoir être lu jusqu'au bout : une feuille
/// se referme d'un glissement, et sert aux gestes brefs. Celui-ci ne l'est pas.
///
/// **La ligne des paramètres ouvre cet écran, elle ne supprime rien.** Un
/// doigt qui glisse n'efface donc pas un compte, et la confirmation porte ce
/// qu'elle doit porter : la liste, puis le mot de passe.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _controleur = TextEditingController();

  String _motDePasse = '';
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: Text(t.profileSupprimerCompte),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: t.commonBack,
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.couleurs.dangerSoft,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.couleurs.dangerInk,
                    size: 20,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      t.profileSuppressionDefinitive,
                      style: context.typo.caption.copyWith(
                        color: context.couleurs.dangerInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.gapLg,
            _Liste(
              titre: t.profileSuppressionCeQuiDisparait,
              icone: Icons.remove_circle_outline_rounded,
              teinte: context.couleurs.dangerInk,
              lignes: <String>[
                t.profileSuppressionIdentite,
                t.profileSuppressionProfil,
                t.profileSuppressionContacts,
                t.profileSuppressionGroupes,
                t.profileSuppressionNotifications,
                t.profileSuppressionVocaux,
              ],
            ),

            AppSpacing.gapLg,
            _Liste(
              titre: t.profileSuppressionCeQuiReste,
              icone: Icons.check_circle_outline_rounded,
              teinte: context.couleurs.successInk,
              lignes: <String>[
                t.profileSuppressionMessages,
                t.profileSuppressionMedias,
                t.profileSuppressionGroupeContenu,
              ],
            ),

            AppSpacing.gapMd,
            Text(
              t.profileSuppressionReinscription,
              style: context.typo.bodyMuted,
            ),

            AppSpacing.gapXl,
            if (_erreur != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.couleurs.dangerSoft,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Text(
                  _erreur!,
                  style: context.typo.caption.copyWith(
                    color: context.couleurs.dangerInk,
                  ),
                ),
              ),
              AppSpacing.gapLg,
            ],

            PasswordField(
              controller: _controleur,
              label: t.profileSuppressionMotDePasse,
              hint: t.profileSuppressionMotDePasseAide,
              textInputAction: TextInputAction.done,
              onChanged: (String valeur) => setState(() {
                _motDePasse = valeur;
                _erreur = null;
              }),
              onSubmitted: (_) => _supprimer(),
            ),

            AppSpacing.gapXl,
            // `SecondaryButton` n'a pas d'état de chargement, et le lui
            // ajouter pour ici seul serait une option sans second lecteur :
            // la carte de déconnexion des paramètres échange déjà sa ligne
            // contre une roue de la même façon.
            if (_enCours)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              SecondaryButton(
                label: t.profileSuppressionConfirmer,
                isDestructive: true,
                // Vide, le bouton ne fait rien : le mot de passe est ce qui
                // confirme, et un bouton actif sans lui promettrait une
                // suppression que la vérification refuserait de toute façon.
                onPressed: _motDePasse.isEmpty ? null : _supprimer,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer() async {
    if (_motDePasse.isEmpty || _enCours) return;

    // Lus **avant** l'attente : la suppression ferme la session, et la garde
    // du routeur aura quitté cet écran quand il s'agira d'afficher le message.
    final AppTexts t = AppTexts.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final ResultatSuppression resultat = await ref
          .read(profileActionsProvider)
          .supprimerLeCompte(_motDePasse);

      switch (resultat) {
        case ResultatSuppression.supprime:
          // Aucune navigation ici : la session fermée, la garde du routeur
          // emmène vers la connexion d'elle-même. Dépiler en plus se battrait
          // avec elle.
          messager.showSnackBar(
            SnackBar(content: Text(t.profileSuppressionFaite)),
          );
        case ResultatSuppression.motDePasseIncorrect:
          if (!mounted) return;
          setState(() {
            _enCours = false;
            _erreur = t.profileSuppressionMotDePasseIncorrect;
          });
        case ResultatSuppression.echec:
          if (!mounted) return;
          setState(() {
            _enCours = false;
            _erreur = t.profileSuppressionEchec;
          });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = AuthFailure.from(error).message(AppTexts.of(context));
      });
    }
  }
}

/// Une liste à puces titrée. Les deux listes de l'écran se lisent en regard :
/// la même forme, deux teintes, pour que ce qui part et ce qui reste se
/// distinguent sans être lus deux fois.
class _Liste extends StatelessWidget {
  const _Liste({
    required this.titre,
    required this.icone,
    required this.teinte,
    required this.lignes,
  });

  final String titre;
  final IconData icone;
  final Color teinte;
  final List<String> lignes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icone, color: teinte, size: 20),
              AppSpacing.hGapSm,
              Flexible(
                child: Text(
                  titre,
                  style: context.typo.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          for (final String ligne in lignes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: teinte,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  Expanded(child: Text(ligne, style: context.typo.bodyMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
