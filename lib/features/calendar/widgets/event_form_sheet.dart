import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../../groups/models/group_member.dart';
import '../../groups/providers/group_providers.dart';
import '../../tasks/widgets/assignee_picker.dart';
import '../../tasks/widgets/option_row.dart';
import '../models/calendar_event.dart';
import '../models/recurrence.dart';
import '../providers/calendar_providers.dart';

/// Ouvre le formulaire d'événement en feuille. Passer [event] bascule en
/// modification.
Future<void> ouvrirFormulaireDEvenement(
  BuildContext context, {
  CalendarEvent? event,
  String? groupId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => EventFormSheet(event: event, groupId: groupId),
  );
}

class EventFormSheet extends ConsumerStatefulWidget {
  const EventFormSheet({super.key, this.event, this.groupId});

  final CalendarEvent? event;
  final String? groupId;

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  final TextEditingController _titre = TextEditingController();
  final TextEditingController _lieu = TextEditingController();
  final TextEditingController _description = TextEditingController();

  late String? _groupId;
  late Set<String> _participants;
  late Recurrence _recurrence;
  late ReminderOffset _rappel;
  DateTime? _jour;
  TimeOfDay? _debut;
  TimeOfDay? _fin;

  bool _plusDOptions = false;
  bool _envoi = false;
  String? _erreurTitre;
  String? _erreur;

  bool get _modification => widget.event != null;

  @override
  void initState() {
    super.initState();
    final CalendarEvent? event = widget.event;

    _groupId = event?.groupId ?? widget.groupId;
    _participants = <String>{
      if (event != null)
        for (final EventParticipant p in event.participants) p.userId,
    };
    _recurrence = Recurrence.fromRrule(event?.rrule);
    _rappel = ReminderOffset.fromMinutes(event?.reminderMinutes);

    if (event != null) {
      _jour = DateTime(event.start.year, event.start.month, event.start.day);
      _debut = TimeOfDay.fromDateTime(event.start);
      _fin = TimeOfDay.fromDateTime(event.end);
      _titre.text = event.title;
      _lieu.text = event.location ?? '';
      _description.text = event.notes ?? '';
      _plusDOptions = event.notes?.isNotEmpty ?? false;
    }
  }

  @override
  void dispose() {
    _titre.dispose();
    _lieu.dispose();
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
              _modification ? 'Modifier l’événement' : 'Nouvel événement',
              style: AppTypography.h2,
            ),
            AppSpacing.gapLg,

            AppTextField(
              label: 'Titre *',
              hint: 'Ex. : Déjeuner chez Camille',
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
                titre: 'Participants',
                membres: membres,
                selection: _participants,
                aideLibre:
                    'Personne de sélectionné : tous les membres du groupe '
                    'seront conviés.',
                onToggle: (String userId) => setState(() {
                  if (!_participants.remove(userId)) {
                    _participants.add(userId);
                  }
                }),
              ),
            ],

            AppSpacing.gapLg,
            _blocHoraires(),

            AppSpacing.gapLg,
            AppTextField(
              label: 'Lieu',
              hint: 'Ex. : Le Petit Comptoir',
              controller: _lieu,
              prefixIcon: Icons.place_outlined,
            ),

            AppSpacing.gapLg,
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  OptionRow(
                    label: 'Rappel',
                    hint: 'Jelvo préviendra les participants',
                    value: _rappel.label,
                    onTap: _choisirRappel,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  OptionRow(
                    label: 'Répéter',
                    hint: 'Pour les rendez-vous réguliers',
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
                  : 'Créer l’événement',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _envoi,
              onPressed: _valider,
            ),
          ],
        ),
      ),
    );
  }

  /// Date, heure de début **et heure de fin**.
  ///
  /// La durée était figée à une heure : un déjeuner de famille et un
  /// week-end entier ne se ressemblent pourtant pas.
  Widget _blocHoraires() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Quand ?', style: AppTypography.h3),
          AppSpacing.gapMd,
          SecondaryButton(
            label: _jour == null
                ? 'Choisir la date *'
                : AppDates.fullDate(_jour!),
            icon: Icons.calendar_today_rounded,
            onPressed: _choisirDate,
          ),
          AppSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: _debut == null ? 'Début' : _debut!.format(context),
                  icon: Icons.schedule_rounded,
                  onPressed: () => _choisirHeure(debut: true),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: SecondaryButton(
                  label: _fin == null ? 'Fin' : _fin!.format(context),
                  icon: Icons.schedule_outlined,
                  onPressed: () => _choisirHeure(debut: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
            AppTextField(
              label: 'Description',
              hint: 'Ce qu’il faut savoir, ce qu’il faut apporter',
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
      initialDate: _jour ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('fr'),
    );
    if (choisie != null) setState(() => _jour = choisie);
  }

  Future<void> _choisirHeure({required bool debut}) async {
    final TimeOfDay? choisie = await showTimePicker(
      context: context,
      initialTime: debut
          ? (_debut ?? const TimeOfDay(hour: 12, minute: 0))
          : (_fin ?? _decalee(_debut) ?? const TimeOfDay(hour: 13, minute: 0)),
    );
    if (choisie == null) return;
    setState(() {
      if (debut) {
        _debut = choisie;
        // Une fin antérieure au début n'a pas de sens : on la repousse d'une
        // heure plutôt que de refuser la saisie.
        if (_fin == null || _minutes(_fin!) <= _minutes(choisie)) {
          _fin = _decalee(choisie);
        }
      } else {
        _fin = choisie;
      }
    });
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay? _decalee(TimeOfDay? t) {
    if (t == null) return null;
    final int total = _minutes(t) + 60;
    // Au-delà de minuit, on s'arrête à 23:59 : l'application ne gère pas
    // encore un événement à cheval sur deux jours.
    if (total >= 24 * 60) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  DateTime? _instant(TimeOfDay? heure, TimeOfDay defaut) {
    final DateTime? jour = _jour;
    if (jour == null) return null;
    final TimeOfDay h = heure ?? defaut;
    return DateTime(jour.year, jour.month, jour.day, h.hour, h.minute);
  }

  Future<void> _valider() async {
    final String titre = _titre.text.trim();
    setState(() {
      _erreurTitre = titre.isEmpty ? 'Donnez un titre à l’événement.' : null;
      _erreur = null;
    });
    if (_erreurTitre != null) return;

    final DateTime? debut = _instant(
      _debut,
      const TimeOfDay(hour: 12, minute: 0),
    );
    if (debut == null) {
      setState(() => _erreur = 'Choisissez la date de l’événement.');
      return;
    }
    final DateTime fin =
        _instant(_fin, const TimeOfDay(hour: 13, minute: 0)) ??
        debut.add(const Duration(hours: 1));
    if (fin.isBefore(debut)) {
      setState(() => _erreur = 'La fin doit suivre le début.');
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? lieu = _lieu.text.trim().isEmpty ? null : _lieu.text.trim();
    final String? description = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();

    setState(() => _envoi = true);
    try {
      final EventActions actions = ref.read(eventActionsProvider);
      if (_modification) {
        await actions.update(
          eventId: widget.event!.id,
          title: titre,
          startsAt: debut,
          endsAt: fin,
          description: description,
          location: lieu,
          rrule: _recurrence.rrule,
          imageUrl: widget.event!.imageUrl,
          reminderMinutes: _rappel.minutes,
        );
      } else {
        await actions.create(
          title: titre,
          startsAt: debut,
          endsAt: fin,
          groupId: _groupId,
          description: description,
          location: lieu,
          rrule: _recurrence.rrule,
          reminderMinutes: _rappel.minutes,
          // `null` et non une liste vide : `creer_evenement` interprète `null`
          // comme « tous les membres du groupe », ce qui est le défaut voulu
          // quand aucun avatar n'est sélectionné.
          participants: _participants.isEmpty ? null : _participants.toList(),
        );
      }
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _modification
                ? 'L’événement a été modifié.'
                : 'L’événement « $titre » a été créé.',
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
