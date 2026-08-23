import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group_invite.dart';
import '../models/group_member.dart';
import '../providers/group_providers.dart';
import 'membership_term_picker.dart';

/// Réglage du terme d'une adhésion existante.
///
/// **Prolonger, écourter et rendre permanent sont le même geste** : déplacer
/// une date, ou l'effacer. Trois entrées de menu distinctes auraient demandé
/// à l'administrateur de savoir d'avance dans quel sens il va, alors que
/// l'écran le lui montre.
class MembershipTermSheet extends ConsumerStatefulWidget {
  const MembershipTermSheet({
    super.key,
    required this.groupId,
    required this.member,
  });

  final String groupId;
  final GroupMember member;

  @override
  ConsumerState<MembershipTermSheet> createState() =>
      _MembershipTermSheetState();
}

class _MembershipTermSheetState extends ConsumerState<MembershipTermSheet> {
  late DateTime? _terme = widget.member.expiresAt;
  bool _enregistrement = false;
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(nowProvider);
    final GroupMember membre = widget.member;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Durée de l’adhésion', style: AppTypography.h2),
          AppSpacing.gapSm,
          Text(
            membre.isTemporary
                ? '${membre.displayName} fait partie du groupe jusqu’au '
                      '${AppDates.fullDate(membre.expiresAt!)}.'
                : '${membre.displayName} fait partie du groupe sans terme.',
            style: AppTypography.bodyMuted,
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
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          ],

          AppSpacing.gapXl,
          MembershipTermPicker(
            now: now,
            value: _terme,
            enabled: !_enregistrement,
            label: 'Nouvelle durée',
            onChanged: (DateTime? valeur) => setState(() {
              _terme = valeur;
              _erreur = null;
            }),
          ),

          AppSpacing.gapXl,
          PrimaryButton(
            label: 'Enregistrer',
            icon: Icons.check_rounded,
            isLoading: _enregistrement,
            onPressed: _enregistrer,
          ),
        ],
      ),
    );
  }

  Future<void> _enregistrer() async {
    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      final MemberOutcome issue = await ref
          .read(groupActionsProvider)
          .setMembershipTerm(
            groupId: widget.groupId,
            userId: widget.member.userId,
            expiresAt: _terme,
          );

      if (!mounted) return;
      // Un refus reste dans la feuille : la refermer sur un message furtif
      // laisserait croire que la date a été posée.
      if (!issue.isSuccess && issue != MemberOutcome.inchange) {
        setState(() {
          _enregistrement = false;
          _erreur = issue.message(widget.member.shortName);
        });
        return;
      }

      navigateur.maybePop();
      messager.showSnackBar(
        SnackBar(
          content: Text(
            issue.message(
              widget.member.shortName,
              terme: _terme == null ? null : AppDates.fullDate(_terme!),
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _erreur = AuthFailure.from(error).message;
      });
    }
  }
}
