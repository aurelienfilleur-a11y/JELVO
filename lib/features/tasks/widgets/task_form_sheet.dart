import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../../calendar/models/recurrence.dart';
import '../../groups/models/group_member.dart';
import '../../groups/providers/group_providers.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';
import 'assignee_picker.dart';
import 'option_row.dart';

/// Ouvre le formulaire de tâche en feuille.
///
/// Une feuille et non une page pleine : créer une tâche est un geste bref, et
/// garder l'écran d'origine visible derrière dit d'où l'on vient. Passer
/// [task] bascule en modification.
Future<void> ouvrirFormulaireDeTache(
  BuildContext context, {
  Task? task,
  String? groupId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Sans cela, la feuille s'arrête à la moitié de l'écran et le bouton de
    // validation reste hors de portée sur un téléphone.
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => TaskFormSheet(task: task, groupId: groupId),
  );
}

class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({super.key, this.task, this.groupId});

  /// Tâche à modifier, ou `null` pour une création.
  final Task? task;

  /// Groupe pré-sélectionné à la création.
  final String? groupId;

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final TextEditingController _titre = TextEditingController();
  final TextEditingController _description = TextEditingController();

  late String? _groupId;
  late Set<String> _assignes;
  late Recurrence _recurrence;
  late ReminderOffset _rappel;
  late TaskPriority _priorite;
  DateTime? _echeance;
  TimeOfDay? _heure;

  bool _plusDOptions = false;
  bool _envoi = false;
  String? _erreurTitre;
  String? _erreur;

  bool get _modification => widget.task != null;

  @override
  void initState() {
    super.initState();
    final Task? task = widget.task;

    _groupId = task?.groupId ?? widget.groupId;
    _assignes = <String>{
      if (task != null)
        for (final TaskAssignee a in task.assignees) a.userId,
    };
    _recurrence = Recurrence.fromRrule(task?.rrule);
    _rappel = ReminderOffset.fromInstants(task?.reminderAt, task?.dueDate);
    _priorite = task?.priority ?? TaskPriority.medium;
    _echeance = task?.dueDate;
    _heure = task?.dueDate == null
        ? null
        : TimeOfDay.fromDateTime(task!.dueDate!);

    _titre.text = task?.title ?? '';
    _description.text = task?.notes ?? '';
    // Une tâche déjà décrite s'ouvre sur ses détails : les replier obligerait à
    // les rouvrir pour vérifier ce qu'on modifie.
    _plusDOptions =
        _modification && (task!.notes?.isNotEmpty ?? false) ||
        (_modification && widget.task!.dueDate != null);
  }

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<GroupMember> membres = _groupId == null
        ? const <GroupMember>[]
        : ref.watch(groupMembersProvider(_groupId!)).value ??
              const <GroupMember>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _modification ? 'Modifier la tâche' : 'Nouvelle tâche',
              style: AppTypography.h2,
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: 'Titre *',
              hint: 'Ex. : Acheter le pain',
              controller: _titre,
              errorText: _erreurTitre,
              autofocus: !_modification,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_erreurTitre != null) setState(() => _erreurTitre = null);
              },
            ),

            if (_groupId != null) ...<Widget>[
              AppSpacing.gapLg,
              AssigneePicker(
                membres: membres,
                selection: _assignes,
                onToggle: (String userId) => setState(() {
                  if (!_assignes.remove(userId)) _assignes.add(userId);
                }),
              ),
            ],

            AppSpacing.gapLg,
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  OptionRow(
                    label: 'Rappel',
                    hint:
                        'Jelvo enverra une notification à la personne assignée',
                    value: _rappel.label,
                    onTap: _choisirRappel,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  OptionRow(
                    label: 'Répéter',
                    hint: 'Pour les tâches récurrentes',
                    value: _recurrence.label,
                    onTap: _choisirRecurrence,
                  ),
                ],
              ),
            ),

            AppSpacing.gapLg,
            _blocPlusDOptions(),

            if (_erreur != null) ...<Widget>[
              AppSpacing.gapLg,
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
            ],

            AppSpacing.gapXl,
            PrimaryButton(
              label: _modification
                  ? 'Enregistrer les modifications'
                  : 'Créer la tâche',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _envoi,
              onPressed: _valider,
            ),
          ],
        ),
      ),
    );
  }

  /// Échéance, priorité et description : utiles, mais pas à chaque fois.
  Widget _blocPlusDOptions() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _plusDOptions = !_plusDOptions),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Plus d’options', style: AppTypography.h3),
                  ),
                  Icon(
                    _plusDOptions
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_plusDOptions) ...<Widget>[
            const Divider(height: 1, color: AppColors.border),
            AppSpacing.gapMd,
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: _echeance == null
                        ? 'Échéance'
                        : AppDates.shortDate(_echeance!),
                    icon: Icons.calendar_today_rounded,
                    onPressed: _choisirDate,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: SecondaryButton(
                    label: _heure == null ? 'Heure' : _heure!.format(context),
                    icon: Icons.schedule_rounded,
                    onPressed: _choisirHeure,
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
            SegmentedButton<TaskPriority>(
              segments: <ButtonSegment<TaskPriority>>[
                for (final TaskPriority p in TaskPriority.values)
                  ButtonSegment<TaskPriority>(value: p, label: Text(p.label)),
              ],
              selected: <TaskPriority>{_priorite},
              showSelectedIcon: false,
              onSelectionChanged: (Set<TaskPriority> choix) =>
                  setState(() => _priorite = choix.first),
            ),
            AppSpacing.gapMd,
            AppTextField(
              label: 'Description',
              hint: 'Ce qu’il faut savoir pour s’en occuper',
              controller: _description,
              maxLines: 3,
              minLines: 2,
            ),
            AppSpacing.gapMd,
          ],
        ],
      ),
    );
  }

  Future<void> _choisirRappel() async {
    final ReminderOffset? choix = await _choisirDansListe<ReminderOffset>(
      titre: 'Rappel',
      valeurs: ReminderOffset.values,
      libelle: (ReminderOffset o) => o.label,
      courant: _rappel,
    );
    if (choix != null) setState(() => _rappel = choix);
  }

  Future<void> _choisirRecurrence() async {
    final Recurrence? choix = await _choisirDansListe<Recurrence>(
      titre: 'Répéter',
      valeurs: Recurrence.values,
      libelle: (Recurrence r) => r.label,
      courant: _recurrence,
    );
    if (choix != null) setState(() => _recurrence = choix);
  }

  Future<T?> _choisirDansListe<T>({
    required String titre,
    required List<T> valeurs,
    required String Function(T) libelle,
    required T courant,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(titre, style: AppTypography.h2),
            ),
            AppSpacing.gapMd,
            for (final T valeur in valeurs)
              ListTile(
                title: Text(libelle(valeur)),
                trailing: valeur == courant
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(valeur),
              ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }

  Future<void> _choisirDate() async {
    final DateTime now = ref.read(nowProvider);
    final DateTime? choisie = await showDatePicker(
      context: context,
      initialDate: _echeance ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('fr'),
    );
    if (choisie != null) setState(() => _echeance = choisie);
  }

  Future<void> _choisirHeure() async {
    final TimeOfDay? choisie = await showTimePicker(
      context: context,
      initialTime: _heure ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (choisie != null) setState(() => _heure = choisie);
  }

  DateTime? get _instantEcheance {
    final DateTime? jour = _echeance;
    if (jour == null) return null;
    final TimeOfDay heure = _heure ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
  }

  Future<void> _valider() async {
    final String titre = _titre.text.trim();
    setState(() {
      _erreurTitre = titre.isEmpty ? 'Donnez un titre à la tâche.' : null;
      _erreur = null;
    });
    if (_erreurTitre != null) return;

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final DateTime? echeance = _instantEcheance;
    final String? description = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();

    setState(() => _envoi = true);
    try {
      final TaskActions actions = ref.read(taskActionsProvider);
      if (_modification) {
        await actions.update(
          taskId: widget.task!.id,
          title: titre,
          description: description,
          dueAt: echeance,
          priority: _priorite,
          reminderAt: _rappel.instantAvant(echeance),
          rrule: _recurrence.rrule,
        );
        // Les assignés ne font pas partie de `modifier_tache` : ils passent par
        // leur propre fonction, `task_assignees` n'ayant pas de politique
        // DELETE.
        if (_groupId != null) {
          await actions.setAssignees(widget.task!.id, _assignes.toList());
        }
      } else {
        await actions.create(
          title: titre,
          groupId: _groupId,
          description: description,
          dueAt: echeance,
          priority: _priorite,
          reminderAt: _rappel.instantAvant(echeance),
          rrule: _recurrence.rrule,
          // Liste vide et non `null` : `creer_tache` interprète `null` comme
          // « assigne l'auteur », alors qu'une liste vide laisse la tâche
          // libre — ce que veut dire « aucun avatar sélectionné ».
          assignees: _groupId == null ? null : _assignes.toList(),
        );
      }
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _modification
                ? 'La tâche a été modifiée.'
                : 'La tâche « $titre » a été créée.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _erreur = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }
}
