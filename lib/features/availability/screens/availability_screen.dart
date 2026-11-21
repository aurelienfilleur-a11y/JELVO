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
        title: Text(AppTexts.of(context).availabilityDisponibilites),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppTexts.of(context).commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppTexts.of(context).availabilityNouveauCreneau,
            onPressed: () => ouvrirFormulaireDeCreneau(context),
          ),
        ],
      ),
      body: tout.hasError && (tout.value?.isEmpty ?? true)
          ? SafeArea(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: AppTexts.of(
                  context,
                ).availabilityDisponibilitesIndisponibles,
                message: AuthFailure.from(
                  tout.error!,
                ).message(AppTexts.of(context)),
                actionLabel: AppTexts.of(context).commonRetry,
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
                    title: AppTexts.of(context).availabilitySemaineType,
                    subtitle: AppTexts.of(
                      context,
                    ).availabilityCreneauxReviennentChaqueSemaine,
                  ),
                  AppSpacing.gapMd,
                  if (parJour.isEmpty)
                    Text(
                      AppTexts.of(
                        context,
                      ).availabilityAucunCreneauRecurrentRien,
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
                    title: AppTexts.of(context).coreExceptions,
                    subtitle: AppTexts.of(
                      context,
                    ).availabilityDatePrecisePrimeSemaine,
                  ),
                  AppSpacing.gapMd,
                  if (exceptions.isEmpty)
                    Text(
                      AppTexts.of(context).availabilityAucuneExceptionJourConge,
                      style: context.typo.bodyMuted,
                    )
                  else
                    _BlocJour(titre: null, creneaux: exceptions),

                  AppSpacing.gapXl,
                  PrimaryButton(
                    label: AppTexts.of(context).availabilityAjouterCreneau,
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
              AppTexts.of(context).availabilityContactsMembresGroupesVoient,
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
    final AppTexts t = AppTexts.of(context);
    final DateTime? date = creneau.onDate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          StatusDot(
            tone: creneau.status.tone,
            label: creneau.status.label(AppTexts.of(context)),
            filled: true,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              date == null
                  ? creneau.plage
                  : t.availabilityDateEtPlage(
                      AppDates.shortDate(date, t),
                      creneau.plage,
                    ),
              style: context.typo.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // **Deux boutons d'icône de 48 dp ne tiennent pas ici.** La
          // pastille de statut porte un mot, et la ligne débordait de 3 px à
          // 360 dp — dans les quatre langues : ce défaut-là précède la
          // traduction, c'est le balayage des langues qui l'a trouvé.
          // `compact` les ramène à 40 dp, ce qui reste une cible touchable.
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: AppTexts.of(context).availabilityModifierCreneau,
            color: context.couleurs.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ouvrirFormulaireDeCreneau(context, creneau: creneau),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            tooltip: AppTexts.of(context).availabilitySupprimerCreneau,
            color: context.couleurs.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: () => _supprimer(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    // Lu **avant** l’attente : le contexte peut avoir disparu après.
    final AppTexts t = AppTexts.of(context);
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
                ? t.availabilityCreneauSupprime
                : t.availabilityCreneauExisteListeVa,
          ),
        ),
      );
      if (!retire) {
        await ref.read(myAvailabilityProvider.notifier).refresh();
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message(t))),
      );
    }
  }
}
