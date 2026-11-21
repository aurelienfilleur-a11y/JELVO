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
    final AppTexts t = AppTexts.of(context);
    final AsyncValue<PushStatus> etat = ref.watch(pushStatusProvider);
    final PushStatus statut = etat.value ?? PushStatus.nonSupporte;
    final bool enCours = etat.isLoading;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_icone(statut), color: _teinte(context, statut)),
              AppSpacing.hGapMd,
              Expanded(child: Text(_titre(statut, t), style: context.typo.h3)),
              if (statut == PushStatus.actif)
                StatusDot(
                  tone: StatusTone.success,
                  label: t.notificationsActives,
                  filled: true,
                ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            _explication(statut, t),
            style: context.typo.caption.copyWith(
              color: context.couleurs.textSecondary,
            ),
          ),

          if (statut == PushStatus.aAutoriser) ...<Widget>[
            AppSpacing.gapLg,
            PrimaryButton(
              label: t.notificationsActiverNotifications,
              icon: Icons.notifications_active_outlined,
              isLoading: enCours,
              onPressed: () => _autoriser(context, ref),
            ),
          ],
          if (statut == PushStatus.actif) ...<Widget>[
            AppSpacing.gapLg,
            SecondaryButton(
              label: t.notificationsDesactiverCetAppareil,
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

  static Color _teinte(BuildContext context, PushStatus statut) =>
      switch (statut) {
        PushStatus.actif => context.couleurs.success,
        PushStatus.refuse => context.couleurs.danger,
        PushStatus.installationRequise => context.couleurs.warning,
        _ => context.couleurs.primary,
      };

  static String _titre(PushStatus statut, AppTexts t) => switch (statut) {
    PushStatus.actif => t.notificationsNotificationsActives,
    PushStatus.refuse => t.notificationsNotificationsRefusees,
    PushStatus.installationRequise => t.notificationsInstallezJelvoRecevoir,
    PushStatus.aAutoriser => t.notificationsNotificationsDesactivees,
    PushStatus.nonSupporte => t.notificationsNotificationsIndisponiblesIci,
  };

  static String _explication(PushStatus statut, AppTexts t) => switch (statut) {
    PushStatus.actif => t.notificationsCetAppareilRecevraNotifications,
    PushStatus.refuse => t.notificationsAvezRefuseAutorisationApplication,
    PushStatus.installationRequise =>
      t.notificationsIPhoneIPadNotificationsExistent,
    PushStatus.aAutoriser =>
      t.notificationsNavigateurDemanderaAutorisationPourrez,
    PushStatus.nonSupporte =>
      t.notificationsVersionApplicationGereNotifications,
  };

  Future<void> _autoriser(BuildContext context, WidgetRef ref) async {
    // Lus **avant** l'attente : la garde du routeur peut avoir quitté l'écran
    // au moment d'afficher la `SnackBar`.
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final AppTexts t = AppTexts.of(context);
    final PushStatus apres = await ref
        .read(pushStatusProvider.notifier)
        .autoriser();

    if (apres != PushStatus.actif) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            apres == PushStatus.refuse
                ? t.notificationsAutorisationRefuseeRouvreReglages
                : t.notificationsNotificationsOntPuEtre,
          ),
        ),
      );
    }
  }

  Future<void> _desactiver(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final AppTexts t = AppTexts.of(context);
    await ref.read(pushStatusProvider.notifier).desactiver();
    messager.showSnackBar(
      SnackBar(
        content: Text(t.notificationsNotificationsDesactiveesCetAppareil),
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
    final AppTexts t = AppTexts.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.couleurs.warningSoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String etape in <String>[
            t.notifications1TouchezBoutonPartager,
            t.notifications2ChoisissezEcranAccueil,
            t.notifications3OuvrezJelvoDepuis,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                etape,
                style: context.typo.caption.copyWith(
                  color: context.couleurs.encre,
                ),
              ),
            ),
          AppSpacing.gapSm,
          Text(
            t.notificationsReconnexionErreurApplicationInstallee,
            style: context.typo.caption.copyWith(
              color: context.couleurs.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
