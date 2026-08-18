import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../providers/push_providers.dart';
import '../push/push_service.dart';
import '../repository/push_repository.dart';

/// Réglage des notifications système, dans l'écran Paramètres.
///
/// Deux étages, et ils ne se confondent pas :
///
/// 1. **l'autorisation** — un seul interrupteur, qui décide si l'appareil
///    reçoit quoi que ce soit ;
/// 2. **les six types** — désactivables un par un, mais sans effet tant que
///    l'autorisation n'est pas donnée.
///
/// Les types restent visibles et modifiables avant l'autorisation : les régler
/// d'avance est légitime, et les masquer donnerait l'impression qu'il n'y a
/// rien à régler.
class PushSettingsSection extends ConsumerWidget {
  const PushSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PushStatus> etat = ref.watch(pushStatusProvider);
    final AsyncValue<List<NotificationPreference>> preferences = ref.watch(
      notificationPreferencesProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Notifications',
          subtitle: 'Ce que Jelvo peut vous signaler',
        ),
        AppSpacing.gapMd,

        _CarteAutorisation(
          statut: etat.value ?? PushStatus.nonSupporte,
          enCours: etat.isLoading,
          onAutoriser: () => _autoriser(context, ref),
          onDesactiver: () => _desactiver(context, ref),
        ),

        AppSpacing.gapLg,
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: preferences.hasError
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    AuthFailure.from(preferences.error!).message,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final NotificationPreference p
                        in preferences.value ??
                            const <NotificationPreference>[])
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.label, style: AppTypography.body),
                        subtitle: Text(
                          p.description,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        value: p.enabled,
                        onChanged: (bool valeur) =>
                            _basculer(context, ref, p.type, valeur),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _autoriser(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final PushStatus apres = await ref
        .read(pushStatusProvider.notifier)
        .autoriser();

    if (apres != PushStatus.actif) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            apres == PushStatus.refuse
                ? 'Autorisation refusée. Elle se rouvre dans les réglages de '
                      'votre navigateur, pas ici.'
                : 'Les notifications n’ont pas pu être activées.',
          ),
        ),
      );
    }
  }

  Future<void> _desactiver(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await ref.read(pushStatusProvider.notifier).desactiver();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Notifications désactivées sur cet appareil.'),
      ),
    );
  }

  Future<void> _basculer(
    BuildContext context,
    WidgetRef ref,
    String type,
    bool valeur,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .basculer(type, enabled: valeur);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}

/// L'état de l'autorisation, et ce qu'il faut faire pour en sortir.
class _CarteAutorisation extends StatelessWidget {
  const _CarteAutorisation({
    required this.statut,
    required this.enCours,
    required this.onAutoriser,
    required this.onDesactiver,
  });

  final PushStatus statut;
  final bool enCours;
  final VoidCallback onAutoriser;
  final VoidCallback onDesactiver;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_icone, color: _teinte),
              AppSpacing.hGapMd,
              Expanded(child: Text(_titre, style: AppTypography.h3)),
              if (statut == PushStatus.actif)
                StatusDot(
                  tone: StatusTone.success,
                  label: 'Actives',
                  filled: true,
                ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            _explication,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          if (statut == PushStatus.aAutoriser) ...<Widget>[
            AppSpacing.gapLg,
            PrimaryButton(
              label: 'Activer les notifications',
              icon: Icons.notifications_active_outlined,
              isLoading: enCours,
              onPressed: onAutoriser,
            ),
          ],
          if (statut == PushStatus.actif) ...<Widget>[
            AppSpacing.gapLg,
            SecondaryButton(
              label: 'Désactiver sur cet appareil',
              icon: Icons.notifications_off_outlined,
              onPressed: onDesactiver,
            ),
          ],
          if (statut == PushStatus.installationRequise) ...<Widget>[
            AppSpacing.gapLg,
            const _ConsigneInstallation(),
          ],
        ],
      ),
    );
  }

  IconData get _icone => switch (statut) {
    PushStatus.actif => Icons.notifications_active_rounded,
    PushStatus.refuse => Icons.notifications_off_rounded,
    PushStatus.installationRequise => Icons.ios_share_rounded,
    _ => Icons.notifications_none_rounded,
  };

  Color get _teinte => switch (statut) {
    PushStatus.actif => AppColors.success,
    PushStatus.refuse => AppColors.danger,
    PushStatus.installationRequise => AppColors.warning,
    _ => AppColors.primary,
  };

  String get _titre => switch (statut) {
    PushStatus.actif => 'Notifications actives',
    PushStatus.refuse => 'Notifications refusées',
    PushStatus.installationRequise => 'Installez Jelvo pour les recevoir',
    PushStatus.aAutoriser => 'Notifications désactivées',
    PushStatus.nonSupporte => 'Notifications indisponibles ici',
  };

  /// Chaque état dit **ce qu'il faut faire**, pas seulement où l'on en est.
  /// « Refusé » sans la marche à suivre laisse dans une impasse : l'API ne
  /// permet plus de redemander une fois qu'on a dit non.
  String get _explication => switch (statut) {
    PushStatus.actif =>
      'Cet appareil recevra les notifications que vous laissez cochées '
          'ci-dessous.',
    PushStatus.refuse =>
      'Vous avez refusé l’autorisation. L’application ne peut plus la '
          'redemander : elle se rouvre dans les réglages de votre navigateur, '
          'à la ligne « Notifications » du site.',
    PushStatus.installationRequise =>
      'Sur iPhone et iPad, les notifications n’existent que dans Jelvo ajouté '
          'à l’écran d’accueil. Dans un onglet Safari, le système ne les '
          'propose pas du tout.',
    PushStatus.aAutoriser =>
      'Votre navigateur vous demandera l’autorisation. Vous pourrez revenir '
          'dessus à tout moment.',
    PushStatus.nonSupporte =>
      'Cette version de l’application ne gère pas les notifications système.',
  };
}

/// La marche à suivre, en toutes lettres.
///
/// iOS n'expose **aucun** moyen de proposer l'installation depuis la page :
/// `beforeinstallprompt` n'y existe pas. Un bouton est donc impossible, et la
/// consigne écrite est tout ce qui reste.
class _ConsigneInstallation extends StatelessWidget {
  const _ConsigneInstallation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String etape in const <String>[
            '1. Touchez le bouton Partager de Safari.',
            '2. Choisissez « Sur l’écran d’accueil ».',
            '3. Ouvrez Jelvo depuis l’icône, puis reconnectez-vous.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                etape,
                style: AppTypography.caption.copyWith(
                  color: AppColors.midnight,
                ),
              ),
            ),
          AppSpacing.gapSm,
          Text(
            'La reconnexion n’est pas une erreur : l’application installée a '
            'son propre stockage, distinct de Safari.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
