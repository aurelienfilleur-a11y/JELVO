import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/availability.dart';
import '../providers/availability_providers.dart';
import '../widgets/availability_form_sheet.dart';

/// Saisie de ses disponibilités, ouverte depuis le profil.
///
/// Deux sections, parce que les deux formes de créneau ne se lisent pas de la
/// même façon : la semaine type d'un côté, les dates qui s'en écartent de
/// l'autre.
///
/// **Ce que voient les autres n'apparaît nulle part ici**, et pour cause : ils
/// ne voient qu'un mot parmi trois. Le bandeau en tête le rappelle, parce
/// qu'écrire « indisponible mardi soir » n'a de sens que si l'on sait qui peut
/// le lire — et la réponse est : personne.
class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AvailabilitySlot>> tout = ref.watch(
      myAvailabilityProvider,
    );
    final Map<int, List<AvailabilitySlot>> parJour = ref.watch(
      recurringByWeekdayProvider,
    );
    final List<AvailabilitySlot> exceptions = ref.watch(exceptionSlotsProvider);

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: const Text('Mes disponibilités'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nouveau créneau',
            onPressed: () => ouvrirFormulaireDeCreneau(context),
          ),
        ],
      ),
      body: tout.hasError && (tout.value?.isEmpty ?? true)
          ? SafeArea(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Disponibilités indisponibles',
                message: AuthFailure.from(tout.error!).message,
                actionLabel: 'Réessayer',
                onActionPressed: () =>
                    ref.read(myAvailabilityProvider.notifier).refresh(),
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(myAvailabilityProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.lg,
                  AppSpacing.screenMargin,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  const _BandeauConfidentialite(),
                  AppSpacing.gapXl,

                  SectionHeader(
                    title: 'Ma semaine type',
                    subtitle: 'Créneaux qui reviennent chaque semaine',
                  ),
                  AppSpacing.gapMd,
                  if (parJour.isEmpty)
                    Text(
                      'Aucun créneau récurrent. Sans rien de déclaré, les '
                      'autres vous voient « Inconnu ».',
                      style: context.typo.bodyMuted,
                    )
                  else
                    for (int jour = 1; jour <= 7; jour++)
                      if (parJour[jour] != null)
                        _BlocJour(
                          titre: AvailabilitySlot.nomDuJour(jour),
                          creneaux: parJour[jour]!,
                        ),

                  AppSpacing.gapXl,
                  SectionHeader(
                    title: 'Exceptions',
                    subtitle: 'Une date précise, qui prime sur la semaine type',
                  ),
                  AppSpacing.gapMd,
                  if (exceptions.isEmpty)
                    Text(
                      'Aucune exception. Un jour de congé ou un déplacement se '
                      'pose ici.',
                      style: context.typo.bodyMuted,
                    )
                  else
                    _BlocJour(titre: null, creneaux: exceptions),

                  AppSpacing.gapXl,
                  PrimaryButton(
                    label: 'Ajouter un créneau',
                    icon: Icons.add_rounded,
                    onPressed: () => ouvrirFormulaireDeCreneau(context),
                  ),
                ],
              ),
            ),
    );
  }
}

/// La règle de confidentialité, dite là où on saisit — pas enfouie dans une
/// page d'aide que personne n'ouvre.
class _BandeauConfidentialite extends StatelessWidget {
  const _BandeauConfidentialite();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.couleurs.primarySoft,
      // Le pavé teinté se passe de contour : `null` voudrait dire « celui du
      // thème », comme partout ailleurs.
      borderColor: Colors.transparent,
      shadows: const <BoxShadow>[],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, color: context.couleurs.primary),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              'Vos contacts et les membres de vos groupes voient seulement '
              '« Disponible », « Indisponible » ou « Inconnu ». Jamais vos '
              'horaires, jamais la raison.',
              style: context.typo.caption.copyWith(
                color: context.couleurs.encre,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlocJour extends StatelessWidget {
  const _BlocJour({required this.titre, required this.creneaux});

  final String? titre;
  final List<AvailabilitySlot> creneaux;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (titre != null) ...<Widget>[
              AppSpacing.gapSm,
              Text(titre!, style: context.typo.h3),
            ],
            for (final AvailabilitySlot creneau in creneaux)
              _LigneCreneau(creneau: creneau),
          ],
        ),
      ),
    );
  }
}

class _LigneCreneau extends ConsumerWidget {
  const _LigneCreneau({required this.creneau});

  final AvailabilitySlot creneau;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? date = creneau.onDate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          StatusDot(
            tone: creneau.status.tone,
            label: creneau.status.label,
            filled: true,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              date == null
                  ? creneau.plage
                  : '${AppDates.shortDate(date)} · ${creneau.plage}',
              style: context.typo.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Modifier le créneau',
            color: context.couleurs.textSecondary,
            onPressed: () =>
                ouvrirFormulaireDeCreneau(context, creneau: creneau),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            tooltip: 'Supprimer le créneau',
            color: context.couleurs.textSecondary,
            onPressed: () => _supprimer(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      // Le booléen vient de la fonction SQL : c'est lui qui dit si quelque
      // chose a été retiré, et non l'absence d'exception.
      final bool retire = await ref
          .read(availabilityActionsProvider)
          .remove(creneau.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            retire
                ? 'Créneau supprimé.'
                : 'Ce créneau n’existe plus. La liste va se rafraîchir.',
          ),
        ),
      );
      if (!retire) {
        await ref.read(myAvailabilityProvider.notifier).refresh();
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}
