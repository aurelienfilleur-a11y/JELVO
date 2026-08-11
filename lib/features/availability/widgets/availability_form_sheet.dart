import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../models/availability.dart';
import '../providers/availability_providers.dart';

/// Ouvre le formulaire de créneau en feuille. Passer [creneau] le modifie.
Future<void> ouvrirFormulaireDeCreneau(
  BuildContext context, {
  AvailabilitySlot? creneau,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => AvailabilityFormSheet(creneau: creneau),
  );
}

class AvailabilityFormSheet extends ConsumerStatefulWidget {
  const AvailabilityFormSheet({super.key, this.creneau});

  final AvailabilitySlot? creneau;

  @override
  ConsumerState<AvailabilityFormSheet> createState() =>
      _AvailabilityFormSheetState();
}

class _AvailabilityFormSheetState extends ConsumerState<AvailabilityFormSheet> {
  late AvailabilityKind _kind;
  late AvailabilityStatus _status;
  late int _weekday;
  late TimeOfDay _debut;
  late TimeOfDay _fin;
  DateTime? _date;

  bool _envoi = false;
  String? _erreur;

  bool get _modification => widget.creneau != null;

  @override
  void initState() {
    super.initState();
    final AvailabilitySlot? c = widget.creneau;
    _kind = c?.kind ?? AvailabilityKind.recurring;
    _status = c?.status ?? AvailabilityStatus.available;
    _weekday = c?.weekday ?? DateTime.now().weekday;
    _date = c?.onDate;
    _debut = _heureDe(c?.start ?? 9 * 60);
    _fin = _heureDe(c?.end ?? 12 * 60);
  }

  static TimeOfDay _heureDe(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  static int _minutesDe(TimeOfDay heure) => heure.hour * 60 + heure.minute;

  @override
  Widget build(BuildContext context) {
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
              _modification ? 'Modifier le créneau' : 'Nouveau créneau',
              style: AppTypography.h2,
            ),
            AppSpacing.gapLg,

            SegmentedButton<AvailabilityKind>(
              segments: <ButtonSegment<AvailabilityKind>>[
                for (final AvailabilityKind k in AvailabilityKind.values)
                  ButtonSegment<AvailabilityKind>(
                    value: k,
                    label: Text(k.label),
                  ),
              ],
              selected: <AvailabilityKind>{_kind},
              showSelectedIcon: false,
              onSelectionChanged: (Set<AvailabilityKind> choix) =>
                  setState(() => _kind = choix.first),
            ),

            AppSpacing.gapLg,
            if (_kind == AvailabilityKind.recurring)
              _selecteurDeJour()
            else
              SecondaryButton(
                label: _date == null
                    ? 'Choisir la date'
                    : AppDates.fullDate(_date!),
                icon: Icons.calendar_today_rounded,
                onPressed: _choisirDate,
              ),

            AppSpacing.gapLg,
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: 'De ${_debut.format(context)}',
                    icon: Icons.schedule_rounded,
                    onPressed: () => _choisirHeure(debut: true),
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: SecondaryButton(
                    label: 'À ${_fin.format(context)}',
                    icon: Icons.schedule_outlined,
                    onPressed: () => _choisirHeure(debut: false),
                  ),
                ),
              ],
            ),

            AppSpacing.gapLg,
            SegmentedButton<AvailabilityStatus>(
              segments: <ButtonSegment<AvailabilityStatus>>[
                for (final AvailabilityStatus s in AvailabilityStatus.values)
                  ButtonSegment<AvailabilityStatus>(
                    value: s,
                    label: Text(s.label),
                  ),
              ],
              selected: <AvailabilityStatus>{_status},
              showSelectedIcon: false,
              onSelectionChanged: (Set<AvailabilityStatus> choix) =>
                  setState(() => _status = choix.first),
            ),

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
              label: _modification ? 'Enregistrer' : 'Ajouter le créneau',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _envoi,
              onPressed: _valider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _selecteurDeJour() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (int jour = 1; jour <= 7; jour++)
          ChoiceChip(
            label: Text(AvailabilitySlot.nomDuJour(jour).substring(0, 3)),
            selected: _weekday == jour,
            onSelected: (_) => setState(() => _weekday = jour),
          ),
      ],
    );
  }

  Future<void> _choisirDate() async {
    final DateTime now = ref.read(nowProvider);
    final DateTime? choisie = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('fr'),
    );
    if (choisie != null) setState(() => _date = choisie);
  }

  Future<void> _choisirHeure({required bool debut}) async {
    final TimeOfDay? choisie = await showTimePicker(
      context: context,
      initialTime: debut ? _debut : _fin,
    );
    if (choisie == null) return;
    setState(() {
      if (debut) {
        _debut = choisie;
        // Une fin antérieure au début serait refusée par la base ; on la
        // repousse plutôt que d'attendre l'erreur.
        if (_minutesDe(_fin) <= _minutesDe(choisie)) {
          final int total = (_minutesDe(choisie) + 60).clamp(0, 23 * 60 + 59);
          _fin = _heureDe(total);
        }
      } else {
        _fin = choisie;
      }
    });
  }

  Future<void> _valider() async {
    setState(() => _erreur = null);

    if (_kind == AvailabilityKind.exception && _date == null) {
      setState(() => _erreur = 'Choisissez la date du créneau.');
      return;
    }
    if (_minutesDe(_fin) <= _minutesDe(_debut)) {
      setState(() => _erreur = 'La fin doit suivre le début.');
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _envoi = true);
    try {
      await ref
          .read(availabilityActionsProvider)
          .save(
            id: widget.creneau?.id,
            kind: _kind,
            status: _status,
            start: _minutesDe(_debut),
            end: _minutesDe(_fin),
            weekday: _kind == AvailabilityKind.recurring ? _weekday : null,
            onDate: _kind == AvailabilityKind.exception ? _date : null,
          );
      navigator.maybePop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_modification ? 'Créneau modifié.' : 'Créneau ajouté.'),
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
