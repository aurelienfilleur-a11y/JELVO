import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/signalement.dart';
import '../providers/signalement_providers.dart';

/// La file de modération — `/parametres/signalements`.
///
/// **Elle n'est pas protégée par cet écran, et elle ne pourrait pas l'être.**
/// PostgREST est atteignable sans lui : la règle est tenue par la base, où
/// `signalements` n'a aucun privilège et où les trois fonctions appellent
/// `est_moderateur()` dans leur corps. Un appel direct avec un identifiant
/// arbitraire obtient donc zéro ligne, exactement comme un écran vide.
///
/// Ce que l'écran fait, c'est ne pas promettre : la ligne des paramètres
/// n'apparaît pas pour qui n'est pas modérateur, et l'écran ouvert de force
/// par son URL se rend vide plutôt qu'en erreur.
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  bool _traites = false;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    final AsyncValue<List<Signalement>> liste = ref.watch(
      signalementsProvider(_traites),
    );
    final List<Signalement> signalements = liste.value ?? const <Signalement>[];

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(title: Text(t.moderationTitre)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(signalementsProvider(_traites).notifier).refresh(),
        child: ListView(
          padding: AppSpacing.screenAll,
          children: <Widget>[
            // Deux onglets, et le défaut est la file : c'est ce qu'on ouvre
            // l'écran pour voir. L'archive existe pour retrouver ce qu'on a
            // décidé, pas pour le compter.
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(t.moderationATraiter),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(t.moderationTraites),
                ),
              ],
              selected: <bool>{_traites},
              showSelectedIcon: false,
              onSelectionChanged: (Set<bool> choix) =>
                  setState(() => _traites = choix.first),
            ),

            AppSpacing.gapLg,

            if (liste.hasError)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: t.moderationIndisponible,
                message: AuthFailure.from(liste.error!).message(t),
              )
            else if (liste.isLoading && signalements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (signalements.isEmpty)
              // **Deux vides, deux phrases.** Une file vide est une bonne
              // nouvelle ; une archive vide dit seulement qu'on n'a encore
              // rien rangé. Les confondre ferait lire la première comme un
              // chargement qui a échoué.
              EmptyState(
                icon: _traites
                    ? Icons.inventory_2_outlined
                    : Icons.verified_outlined,
                title: _traites
                    ? t.moderationVideTraitesTitre
                    : t.moderationVideTitre,
                message: _traites
                    ? t.moderationVideTraitesMessage
                    : t.moderationVideMessage,
              )
            else
              for (final Signalement s in signalements) ...<Widget>[
                _CarteSignalement(signalement: s),
                AppSpacing.gapMd,
              ],
          ],
        ),
      ),
    );
  }
}

class _CarteSignalement extends ConsumerStatefulWidget {
  const _CarteSignalement({required this.signalement});

  final Signalement signalement;

  @override
  ConsumerState<_CarteSignalement> createState() => _CarteSignalementState();
}

class _CarteSignalementState extends ConsumerState<_CarteSignalement> {
  bool _travail = false;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    final Signalement s = widget.signalement;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // En-tête : de quoi il s'agit, depuis quand, et où l'on en est.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  t.moderationEnTete(_cible(t), s.motif.label(t)),
                  style: context.typo.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.hGapSm,
              StatusDot(
                tone: s.tone,
                label: AppDates.timeAgo(s.creeLe, t),
                filled: true,
              ),
            ],
          ),

          AppSpacing.gapSm,
          // Qui signale, qui est visé, et dans quel groupe. Le nom d'un
          // compte supprimé devient le libellé de l'ARB : `auteur_nom` est
          // nul, le dossier ayant survécu à l'anonymisation.
          _Ligne(
            icone: Icons.flag_outlined,
            texte: t.moderationSignalePar(s.auteurNom ?? t.coreCompteSupprime),
          ),
          if (s.viseNom != null)
            _Ligne(
              icone: Icons.person_outline_rounded,
              texte: t.moderationVise(s.viseNom!),
            ),
          if (s.groupeNom != null)
            _Ligne(
              icone: Icons.groups_outlined,
              texte: t.moderationDansGroupe(s.groupeNom!),
            ),

          // La recopie, encadrée : c'est la pièce du dossier, et elle ne doit
          // pas se confondre avec ce que l'écran dit par ailleurs.
          if (_recopie(t) != null) ...<Widget>[
            AppSpacing.gapMd,
            Text(
              t.moderationContenuRecopie,
              style: context.typo.caption.copyWith(
                fontWeight: AppTypography.semiBold,
              ),
            ),
            AppSpacing.gapXs,
            AppCard(
              color: context.couleurs.background,
              borderColor: context.couleurs.border,
              shadows: const <BoxShadow>[],
              padding: const EdgeInsets.all(AppSpacing.md),
              child: EmojiText(_recopie(t)!, style: context.typo.body),
            ),
          ],

          if (s.commentaire != null) ...<Widget>[
            AppSpacing.gapSm,
            // **Les guillemets viennent de l'ARB**, et c'est le détecteur
            // qui l'a imposé : « … » est français, l'anglais écrit “ … ” et
            // l'allemand „ … “. Les écrire ici les aurait donnés aux quatre
            // langues — le défaut même qu'on vient de corriger
            // quatre-vingt-onze fois.
            EmojiText(
              t.moderationCitation(s.commentaire!),
              style: context.typo.bodyMuted,
            ),
          ],

          // L'écart entre la recopie et l'état réel : c'est ce qui dit que
          // l'auteur a effacé son message depuis.
          if (s.messageEfface == true) ...<Widget>[
            AppSpacing.gapSm,
            _Ligne(
              icone: Icons.auto_delete_outlined,
              texte: t.moderationMessageEfface,
            ),
          ],

          if (s.note != null) ...<Widget>[
            AppSpacing.gapSm,
            _Ligne(icone: Icons.sticky_note_2_outlined, texte: s.note!),
          ],

          // Pour un groupe ou un profil, la note est le seul levier, et la
          // phrase le dit plutôt que de laisser chercher le bouton absent.
          if (!s.estTraite && s.cible != SignalementCible.message) ...<Widget>[
            AppSpacing.gapSm,
            Text(
              t.moderationAucunLevier,
              style: context.typo.caption.copyWith(
                color: context.couleurs.textSecondary,
              ),
            ),
          ],

          AppSpacing.gapMd,
          if (_travail)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (!s.estTraite &&
                    s.cible == SignalementCible.message &&
                    s.messageEfface != true)
                  SecondaryButton(
                    label: t.moderationSupprimerMessage,
                    isDestructive: true,
                    expanded: false,
                    onPressed: _confirmerSuppression,
                  ),
                SecondaryButton(
                  label: s.estTraite
                      ? t.moderationRouvrir
                      : t.moderationMarquerTraite,
                  expanded: false,
                  onPressed: () => _traiter(traite: !s.estTraite),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _cible(AppTexts t) => switch (widget.signalement.cible) {
    SignalementCible.message => t.moderationCibleMessage,
    SignalementCible.group => t.moderationCibleGroupe,
    SignalementCible.profile => t.moderationCibleProfil,
  };

  /// Ce qu'il y a à lire de la cible. Un média n'a pas de texte : on dit ce
  /// qu'il est, plutôt que de laisser un cadre vide.
  String? _recopie(AppTexts t) {
    final Signalement s = widget.signalement;
    final String? contenu = s.contenuRecopie;
    if (contenu != null && contenu.isNotEmpty) return contenu;

    return switch (s.mediaRecopie) {
      'image' => t.moderationMediaImage,
      'video' => t.moderationMediaVideo,
      'audio' => t.moderationMediaAudio,
      _ => s.descriptionRecopie ?? s.bioRecopie,
    };
  }

  Future<void> _confirmerSuppression() async {
    final AppTexts t = AppTexts.of(context);
    final bool? confirme = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogue) => AlertDialog(
        title: Text(t.moderationSupprimerMessage),
        content: Text(t.moderationSupprimerConfirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(true),
            child: Text(t.coreSupprimer),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    await _agir(
      (SignalementActions a) => a.supprimerMessage(widget.signalement.id),
    );
  }

  /// Marquer traité demande la note **avant** d'écrire : « ce que vous avez
  /// fait » ne se retrouve pas une heure plus tard, et une note facultative
  /// qu'on ne propose jamais n'est jamais écrite.
  Future<void> _traiter({required bool traite}) async {
    String? note;

    if (traite) {
      note = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogue) => const _NoteDialog(),
      );
      // `null` veut dire « Annuler », et la chaîne vide « traiter sans note » :
      // les confondre empêcherait de traiter sans écrire quoi que ce soit.
      if (note == null) return;
    }

    await _agir(
      (SignalementActions a) =>
          a.traiter(id: widget.signalement.id, note: note, traite: traite),
    );
  }

  Future<void> _agir(
    Future<SignalementOutcome> Function(SignalementActions) action,
  ) async {
    final AppTexts t = AppTexts.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    setState(() => _travail = true);

    try {
      final SignalementOutcome issue = await action(
        ref.read(signalementActionsProvider),
      );
      if (!mounted) return;
      setState(() => _travail = false);
      messager.showSnackBar(SnackBar(content: Text(issue.message(t))));
    } catch (error) {
      if (!mounted) return;
      setState(() => _travail = false);
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message(t))),
      );
    }
  }
}

/// Le dialogue de note, qui **possède** son contrôleur.
///
/// Un `TextEditingController` créé dans la méthode appelante et libéré après
/// `showDialog` l'est trop tôt : le dialogue se reconstruit pendant son
/// animation de fermeture, et lève « A TextEditingController was used after
/// being disposed ». Un widget avec état est le seul endroit d'où la durée de
/// vie du contrôleur est celle du champ.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    return AlertDialog(
      title: Text(t.moderationNote),
      content: TextField(
        controller: _champ,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(hintText: t.moderationNoteAide),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_champ.text),
          child: Text(t.moderationMarquerTraite),
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icone, size: 16, color: context.couleurs.textSecondary),
          AppSpacing.hGapSm,
          Expanded(child: EmojiText(texte, style: context.typo.caption)),
        ],
      ),
    );
  }
}
