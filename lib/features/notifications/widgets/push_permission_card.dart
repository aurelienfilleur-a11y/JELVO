import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/push_providers.dart';
import '../push/push_service.dart';

/// L'état de l'autorisation d'envoi, et ce qu'il faut faire pour en sortir.
///
/// **Un seul étage** : elle décide si l'appareil reçoit quoi que ce soit. Les
/// huit types, eux, se règlent famille par famille depuis les paramètres —
/// les mêler ici laissait croire qu'un type coché suffisait à recevoir.
///
/// Elle porte les limites d'iOS, le refus définitif et la consigne
/// d'installation. Chaque état dit **ce qu'il faut faire**, pas seulement où
/// l'on en est : « refusé » sans la marche à suivre laisse dans une impasse,
/// l'API ne permettant plus de redemander une fois qu'on a dit non.
class PushPermissionCard extends ConsumerWidget {
  const PushPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PushStatus> etat = ref.watch(pushStatusProvider);
    final PushStatus statut = etat.value ?? PushStatus.nonSupporte;
    final bool enCours = etat.isLoading;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_icone(statut), color: _teinte(statut)),
              AppSpacing.hGapMd,
              Expanded(child: Text(_titre(statut), style: AppTypography.h3)),
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
            _explication(statut),
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
              onPressed: () => _autoriser(context, ref),
            ),
          ],
          if (statut == PushStatus.actif) ...<Widget>[
            AppSpacing.gapLg,
            SecondaryButton(
              label: 'Désactiver sur cet appareil',
              icon: Icons.notifications_off_outlined,
              onPressed: () => _desactiver(context, ref),
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

  static IconData _icone(PushStatus statut) => switch (statut) {
    PushStatus.actif => Icons.notifications_active_rounded,
    PushStatus.refuse => Icons.notifications_off_rounded,
    PushStatus.installationRequise => Icons.ios_share_rounded,
    _ => Icons.notifications_none_rounded,
  };

  static Color _teinte(PushStatus statut) => switch (statut) {
    PushStatus.actif => AppColors.success,
    PushStatus.refuse => AppColors.danger,
    PushStatus.installationRequise => AppColors.warning,
    _ => AppColors.primary,
  };

  static String _titre(PushStatus statut) => switch (statut) {
    PushStatus.actif => 'Notifications actives',
    PushStatus.refuse => 'Notifications refusées',
    PushStatus.installationRequise => 'Installez Jelvo pour les recevoir',
    PushStatus.aAutoriser => 'Notifications désactivées',
    PushStatus.nonSupporte => 'Notifications indisponibles ici',
  };

  static String _explication(PushStatus statut) => switch (statut) {
    PushStatus.actif =>
      'Cet appareil recevra les notifications que vous laissez cochées '
          'que vous laissez cochées dans les paramètres.',
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

  Future<void> _autoriser(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final PushStatus apres = await ref
        .read(pushStatusProvider.notifier)
        .autoriser();

    if (apres != PushStatus.actif) {
      messager.showSnackBar(
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
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    await ref.read(pushStatusProvider.notifier).desactiver();
    messager.showSnackBar(
      const SnackBar(
        content: Text('Notifications désactivées sur cet appareil.'),
      ),
    );
  }
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
