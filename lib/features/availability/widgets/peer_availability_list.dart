import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/availability.dart';
import '../providers/availability_providers.dart';

/// Une personne dont on veut connaître la disponibilité, réduite à ce que
/// l'affichage demande. Le widget ne connaît donc ni `GroupMember`, ni
/// `Contact` : il sert les deux.
@immutable
class PeerCandidate {
  const PeerCandidate({required this.userId, required this.name});

  final String userId;
  final String name;
}

/// Disponibilité des personnes conviées, à l'instant choisi.
///
/// **Trois mots, jamais plus** : `get_availability_status` ne renvoie que
/// « disponible », « indisponible » ou rien, et la règle de visibilité —
/// contacts et co-membres — lui appartient. L'application n'a donc rien à
/// filtrer, et surtout rien de plus à montrer : ni l'horaire, ni la raison.
///
/// L'absence de réponse et le refus de répondre tombent tous deux sur
/// « Inconnu ». Les distinguer trahirait déjà quelque chose.
class PeerAvailabilityList extends ConsumerWidget {
  const PeerAvailabilityList({
    super.key,
    required this.candidates,
    required this.at,
  });

  final List<PeerCandidate> candidates;

  /// Instant interrogé — en pratique le début de l'événement en cours de
  /// saisie. Tant qu'aucune date n'est choisie, ne pas construire ce widget.
  final DateTime at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (candidates.isEmpty) return const SizedBox.shrink();

    final AsyncValue<Map<String, PeerAvailability>> statuts = ref.watch(
      peerAvailabilityProvider((
        users: <String>[for (final PeerCandidate c in candidates) c.userId],
        at: at,
      )),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Qui est disponible ?', style: AppTypography.h3),
              ),
              if (statuts.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'À l’heure choisie. Vous ne voyez qu’un mot, jamais leurs '
            'créneaux.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.gapMd,

          // Une panne de lecture ne doit pas barrer la création : on l'annonce
          // et on laisse le formulaire utilisable.
          if (statuts.hasError)
            Text(
              'Disponibilités indisponibles pour l’instant.',
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            )
          else
            for (final PeerCandidate candidat in candidates)
              _Ligne(
                nom: candidat.name,
                statut:
                    statuts.value?[candidat.userId] ?? PeerAvailability.unknown,
              ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.nom, required this.statut});

  final String nom;
  final PeerAvailability statut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              nom,
              style: AppTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSpacing.hGapMd,
          StatusDot(tone: statut.tone, label: statut.label, filled: true),
        ],
      ),
    );
  }
}
