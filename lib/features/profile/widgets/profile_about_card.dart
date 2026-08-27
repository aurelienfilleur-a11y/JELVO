import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../providers/profile_providers.dart';

/// Carte « À propos » : une ligne par information, icône à gauche, libellé,
/// valeur dessous.
///
/// **Deux lignes seulement**, contrairement à la maquette : Jelvo ne collecte
/// ni numéro de téléphone ni localisation. Les afficher vides aurait suggéré
/// qu'il manque quelque chose à remplir.
class ProfileAboutCard extends ConsumerStatefulWidget {
  const ProfileAboutCard({super.key, required this.bio, required this.email});

  final String? bio;
  final String? email;

  @override
  ConsumerState<ProfileAboutCard> createState() => _ProfileAboutCardState();
}

class _ProfileAboutCardState extends ConsumerState<ProfileAboutCard> {
  final TextEditingController _controleur = EmojiTextEditingController();
  final FocusNode _focus = FocusNode();

  bool _enEdition = false;
  bool _enregistrement = false;
  String? _erreur;

  /// Valeur de départ de la saisie en cours, pour n'écrire que si elle a
  /// changé : perdre le focus sur un texte intact ne doit pas envoyer une
  /// requête.
  String _valeurInitiale = '';

  @override
  void initState() {
    super.initState();
    _controleur.text = widget.bio?.trim() ?? '';
    _focus.addListener(_auChangementDeFocus);
  }

  @override
  void didUpdateWidget(ProfileAboutCard ancien) {
    super.didUpdateWidget(ancien);
    // Le profil se relit après chaque écriture : sans cette garde, la valeur
    // du serveur écraserait une saisie en cours.
    if (!_enEdition && widget.bio != ancien.bio) {
      _controleur.text = widget.bio?.trim() ?? '';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_auChangementDeFocus);
    _focus.dispose();
    _controleur.dispose();
    super.dispose();
  }

  /// **Quitter le champ enregistre.** Peu importe par où l'on sort — appui
  /// ailleurs, touche de validation, retour du clavier sur Android : tout
  /// passe par la perte du focus, et le texte reste dans le contrôleur, donc
  /// rien n'est perdu même si l'écriture échoue.
  void _auChangementDeFocus() {
    if (_focus.hasFocus || !_enEdition || _enregistrement) return;
    _enregistrer();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('À propos', style: AppTypography.h3),
          ),
          AppSpacing.gapSm,

          _LigneBio(
            controleur: _controleur,
            focus: _focus,
            enEdition: _enEdition,
            enregistrement: _enregistrement,
            erreur: _erreur,
            texteAffiche: widget.bio?.trim() ?? '',
            onOuvrir: _ouvrir,
            onValider: () => _focus.unfocus(),
          ),
          const Divider(height: 1, indent: 52, color: AppColors.border),
          _LigneLecture(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: widget.email ?? 'Adresse indisponible',
            attenue: widget.email == null,
          ),
        ],
      ),
    );
  }

  void _ouvrir() {
    if (_enEdition) return;
    setState(() {
      _enEdition = true;
      _erreur = null;
      _valeurInitiale = _controleur.text;
    });
    _focus.requestFocus();
  }

  Future<void> _enregistrer() async {
    final String texte = _controleur.text.trim();

    // Rien n'a bougé : on referme sans écrire.
    if (texte == _valeurInitiale.trim()) {
      setState(() {
        _enEdition = false;
        _erreur = null;
      });
      return;
    }

    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await ref.read(profileActionsProvider).saveBio(texte);
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _enEdition = false;
      });
    } catch (error) {
      if (!mounted) return;
      // **On reste en édition, et le texte reste dans le contrôleur.** Refermer
      // sur un échec ferait disparaître la saisie en même temps que le
      // message, et laisserait croire que la bio est enregistrée.
      setState(() {
        _enregistrement = false;
        _erreur = AuthFailure.from(error).message;
      });
    }
  }
}

/// La ligne de bio, en lecture ou en saisie.
class _LigneBio extends StatelessWidget {
  const _LigneBio({
    required this.controleur,
    required this.focus,
    required this.enEdition,
    required this.enregistrement,
    required this.erreur,
    required this.texteAffiche,
    required this.onOuvrir,
    required this.onValider,
  });

  final TextEditingController controleur;
  final FocusNode focus;
  final bool enEdition;
  final bool enregistrement;
  final String? erreur;
  final String texteAffiche;
  final VoidCallback onOuvrir;
  final VoidCallback onValider;

  @override
  Widget build(BuildContext context) {
    final bool vide = texteAffiche.isEmpty;

    return InkWell(
      onTap: enEdition ? null : onOuvrir,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadii.fieldRadius,
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bio',
                        style: AppTypography.body.copyWith(
                          fontWeight: AppTypography.semiBold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (enEdition)
                        TextField(
                          controller: controleur,
                          focusNode: focus,
                          enabled: !enregistrement,
                          // La ligne s'agrandit avec le texte : une bio de
                          // trois lignes se relit en entier pendant qu'on
                          // l'écrit.
                          minLines: 1,
                          maxLines: null,
                          maxLength: 280,
                          // Le compteur alourdirait une ligne de carte ; la
                          // borne, elle, reste.
                          buildCounter:
                              (
                                _, {
                                required int currentLength,
                                required bool isFocused,
                                required int? maxLength,
                              }) => null,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.midnight,
                          ),
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => onValider(),
                          // Toucher ailleurs sort du champ — et sortir du
                          // champ enregistre.
                          onTapOutside: (_) => focus.unfocus(),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'Quelques mots sur vous',
                            hintStyle: AppTypography.caption,
                          ),
                        )
                      else
                        EmojiText(
                          // Une bio vide n'est pas un trou à cacher : la ligne
                          // reste, et invite à la remplir.
                          vide
                              ? 'Ajoutez quelques mots sur vous'
                              : texteAffiche,
                          style: AppTypography.caption.copyWith(
                            color: vide
                                ? AppColors.textSecondary
                                : AppColors.midnight,
                            fontStyle: vide ? FontStyle.italic : null,
                          ),
                        ),
                    ],
                  ),
                ),
                AppSpacing.hGapSm,
                _Affordance(
                  enEdition: enEdition,
                  enregistrement: enregistrement,
                  onValider: onValider,
                ),
              ],
            ),

            if (erreur != null) ...<Widget>[
              AppSpacing.gapSm,
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: AppRadii.fieldRadius,
                  ),
                  child: Text(
                    erreur!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ce qui, à droite de la ligne, dit ce qu'on peut y faire.
///
/// **Plus de chevron** : il annonçait un écran qui s'ouvre, et la bio se
/// modifie désormais sur place. Un crayon dit « on écrit ici » ; en saisie, il
/// cède la place à une coche, qui donne un moyen explicite de valider sans
/// dépendre du clavier.
class _Affordance extends StatelessWidget {
  const _Affordance({
    required this.enEdition,
    required this.enregistrement,
    required this.onValider,
  });

  final bool enEdition;
  final bool enregistrement;
  final VoidCallback onValider;

  @override
  Widget build(BuildContext context) {
    if (enregistrement) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (enEdition) {
      return IconButton(
        onPressed: onValider,
        tooltip: 'Enregistrer la bio',
        visualDensity: VisualDensity.compact,
        icon: const Icon(
          Icons.check_rounded,
          size: 20,
          color: AppColors.primary,
        ),
      );
    }
    return const Tooltip(
      message: 'Modifier la bio',
      child: Icon(
        Icons.edit_outlined,
        size: 18,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Une ligne qui se lit seulement.
class _LigneLecture extends StatelessWidget {
  const _LigneLecture({
    required this.icon,
    required this.label,
    required this.value,
    this.attenue = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Valeur de remplacement : elle se lit en gris clair, pour ne pas passer
  /// pour une donnée réelle.
  final bool attenue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadii.fieldRadius,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.caption.copyWith(
                    color: attenue
                        ? AppColors.textSecondary
                        : AppColors.midnight,
                    fontStyle: attenue ? FontStyle.italic : null,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
