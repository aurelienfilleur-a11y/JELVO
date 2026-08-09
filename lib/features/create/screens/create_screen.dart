import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/creation_kind.dart';
import '../providers/create_providers.dart';
import '../widgets/creation_kind_selector.dart';

/// Écran de création, ouvert par le bouton central « + ».
///
/// Événements et tâches sont enregistrés pour de bon ; le choix « Groupe »
/// renvoie vers l'écran dédié, plus riche.
///
/// [groupId] et [kind] viennent de l'URL : ouvert depuis l'écran d'un groupe,
/// l'écran s'affiche déjà réglé sur ce groupe et sur le bon type. Les deux
/// restent modifiables — pré-remplir n'est pas verrouiller.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key, this.groupId, this.kind});

  final String? groupId;
  final CreationKind? kind;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  String? _titleError;
  String? _errorMessage;
  String? _groupId;
  DateTime? _date;
  TimeOfDay? _heure;
  bool _submitting = false;

  /// Type en cours d'édition.
  ///
  /// Distinct du provider, qui retient le dernier type *choisi à la main* et
  /// sert de valeur par défaut d'une ouverture à l'autre : quand l'URL impose
  /// un type, c'est elle qui gagne, sans effacer cette préférence. Le provider
  /// ne peut de toute façon pas être écrit ici — Riverpod 3 interdit de
  /// modifier un provider depuis un cycle de vie du widget.
  late CreationKind _kind;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
    _kind = widget.kind ?? ref.read(selectedCreationKindProvider);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreationKind kind = _kind;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Créer'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.sm,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text('Que voulez-vous créer ?', style: AppTypography.h1),
            AppSpacing.gapSm,
            Text(
              'Choisissez un type, puis renseignez l’essentiel. Vous pourrez '
              'compléter les détails plus tard.',
              style: AppTypography.bodyMuted,
            ),

            AppSpacing.gapXl,
            CreationKindSelector(
              selected: kind,
              onSelected: (CreationKind value) {
                ref.read(selectedCreationKindProvider.notifier).select(value);
                setState(() {
                  _kind = value;
                  // Une erreur affichée pour un autre type n'a plus de sens.
                  _titleError = null;
                });
              },
            ),

            AppSpacing.gapXl,
            SectionHeader(
              title: 'Détails',
              subtitle: 'Pour votre ${kind.label.toLowerCase()}',
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: _titleLabel(kind),
              hint: _titleHint(kind),
              controller: _titleController,
              errorText: _titleError,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: _detailLabel(kind),
              hint: _detailHint(kind),
              controller: _detailController,
              maxLines: 3,
              minLines: 3,
              helperText: 'Optionnel',
            ),

            if (kind != CreationKind.group) ...<Widget>[
              AppSpacing.gapLg,
              _selecteurDeGroupe(kind),
              AppSpacing.gapLg,
              _selecteurDeDate(kind),
            ],

            if (_errorMessage != null) ...<Widget>[
              AppSpacing.gapLg,
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],

            AppSpacing.gapXxl,
            PrimaryButton(
              label: 'Créer ${_articleFor(kind)}${kind.label.toLowerCase()}',
              icon: Icons.check_rounded,
              isLoading: _submitting,
              onPressed: _submit,
            ),
            AppSpacing.gapMd,
            SecondaryButton(
              label: 'Annuler',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Groupe de rattachement. « Personnel » reste possible : un rendez-vous
  /// chez le dentiste ne regarde personne d'autre.
  Widget _selecteurDeGroupe(CreationKind kind) {
    final List<Group> groups = ref.watch(activeGroupsProvider);

    // Le groupe pré-rempli par l'URL peut ne pas encore figurer dans la liste,
    // qui arrive de façon asynchrone. Sans cette garde, le `Dropdown` lèverait
    // pour une valeur absente de ses entrées ; la clé, elle, force la
    // ré-initialisation du champ dès que le groupe apparaît, sinon la
    // sélection resterait invisible alors même qu'elle serait enregistrée.
    final bool connu = groups.any((Group group) => group.id == _groupId);
    final String? valeur = connu ? _groupId : null;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: DropdownButtonFormField<String?>(
        key: ValueKey<String?>(valeur),
        initialValue: valeur,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Groupe',
          border: InputBorder.none,
        ),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            child: Text('Personnel — visible de vous seul'),
          ),
          for (final Group group in groups)
            DropdownMenuItem<String?>(
              value: group.id,
              child: Text(group.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _submitting
            ? null
            : (String? value) => setState(() => _groupId = value),
      ),
    );
  }

  /// Date et heure. Pour une tâche, l'heure reste facultative : une échéance
  /// « samedi » se passe d'un horaire.
  Widget _selecteurDeDate(CreationKind kind) {
    final bool event = kind == CreationKind.event;
    final DateTime now = ref.watch(nowProvider);

    return Row(
      children: <Widget>[
        Expanded(
          child: SecondaryButton(
            label: _date == null
                ? (event ? 'Choisir la date' : 'Échéance')
                : AppDates.shortDate(_date!),
            icon: Icons.calendar_today_rounded,
            onPressed: _submitting
                ? null
                : () async {
                    final DateTime? choisie = await showDatePicker(
                      context: context,
                      initialDate: _date ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                      locale: const Locale('fr'),
                    );
                    if (choisie != null) setState(() => _date = choisie);
                  },
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: SecondaryButton(
            label: _heure == null ? 'Heure' : _heure!.format(context),
            icon: Icons.schedule_rounded,
            onPressed: _submitting
                ? null
                : () async {
                    final TimeOfDay? choisie = await showTimePicker(
                      context: context,
                      initialTime:
                          _heure ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (choisie != null) setState(() => _heure = choisie);
                  },
          ),
        ),
      ],
    );
  }

  DateTime? get _instant {
    final DateTime? jour = _date;
    if (jour == null) return null;
    final TimeOfDay heure = _heure ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    final CreationKind kind = _kind;

    setState(() {
      _titleError = title.isEmpty ? 'Ce champ est obligatoire.' : null;
      _errorMessage = null;
    });
    if (_titleError != null) return;

    if (kind == CreationKind.group) {
      // La création d'un groupe a son propre écran, plus riche.
      if (!mounted) return;
      context.pushReplacementNamed(AppRoutes.groupCreate);
      return;
    }

    if (kind == CreationKind.event && _instant == null) {
      setState(() => _errorMessage = 'Choisissez la date de l’événement.');
      return;
    }

    final String? description = _detailController.text.trim().isEmpty
        ? null
        : _detailController.text.trim();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      if (kind == CreationKind.event) {
        await ref
            .read(eventActionsProvider)
            .create(
              title: title,
              startsAt: _instant!,
              groupId: _groupId,
              description: description,
            );
      } else {
        await ref
            .read(taskActionsProvider)
            .create(
              title: title,
              groupId: _groupId,
              description: description,
              dueAt: _instant,
            );
      }
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${kind.label} « $title » créé${kind == CreationKind.task ? 'e' : ''}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _titleLabel(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Titre de l’événement',
    CreationKind.task => 'Intitulé de la tâche',
    CreationKind.group => 'Nom du groupe',
  };

  static String _titleHint(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Déjeuner avec Camille',
    CreationKind.task => 'Réserver le restaurant',
    CreationKind.group => 'Famille Rousseau',
  };

  static String _detailLabel(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Lieu et notes',
    CreationKind.task => 'Notes',
    CreationKind.group => 'Description',
  };

  static String _detailHint(CreationKind kind) => switch (kind) {
    CreationKind.event => 'Le Petit Comptoir, réserver pour 4',
    CreationKind.task => 'Penser à confirmer la veille',
    CreationKind.group => 'Anniversaires, vacances et rendez-vous',
  };

  /// Article défini élidé selon le genre du type créé.
  static String _articleFor(CreationKind kind) => switch (kind) {
    CreationKind.event => 'l’',
    CreationKind.task => 'la ',
    CreationKind.group => 'le ',
  };
}
