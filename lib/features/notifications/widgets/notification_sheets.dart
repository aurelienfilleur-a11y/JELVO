import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/notification_category.dart';
import '../providers/push_providers.dart';
import '../push/push_service.dart';
import '../repository/push_repository.dart';
import 'push_permission_card.dart';

/// Le détail d'une famille de notifications, en feuille.
///
/// La ligne des paramètres annonce l'état de la famille ; c'est ici qu'on
/// règle chaque type. Aucun type n'est fusionné : la base en connaît huit, et
/// les huit restent basculables — la famille n'est qu'un rangement.
class NotificationCategorySheet extends ConsumerWidget {
  const NotificationCategorySheet({super.key, required this.categorie});

  final NotificationCategory categorie;

  static Future<void> ouvrir(
    BuildContext context,
    NotificationCategory categorie,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => NotificationCategorySheet(categorie: categorie),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<NotificationPreference>> async = ref.watch(
      notificationPreferencesProvider,
    );
    final List<NotificationPreference> preferences = categorie.preferencesDe(
      async.value ?? const <NotificationPreference>[],
    );

    return SafeArea(
      child: Padding(
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
            Text(categorie.label, style: context.typo.h2),

            if (async.hasError) ...<Widget>[
              AppSpacing.gapLg,
              Text(
                AuthFailure.from(async.error!).message,
                style: context.typo.caption.copyWith(
                  color: context.couleurs.danger,
                ),
              ),
            ],

            for (final NotificationPreference p in preferences)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.label, style: context.typo.body),
                subtitle: Text(
                  p.description,
                  style: context.typo.caption.copyWith(
                    color: context.couleurs.textSecondary,
                  ),
                ),
                value: p.enabled,
                onChanged: (bool valeur) =>
                    _basculer(context, ref, p.type, valeur),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _basculer(
    BuildContext context,
    WidgetRef ref,
    String type,
    bool valeur,
  ) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .basculer(type, enabled: valeur);
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}

/// L'autorisation d'envoi sur cet appareil — la ligne qui coupe tout.
///
/// Elle reprend telle quelle la carte d'autorisation existante : c'est elle
/// qui porte les limites d'iOS, le refus définitif et la consigne
/// d'installation, et les réécrire ici les aurait fait diverger.
class PushPermissionSheet extends ConsumerWidget {
  const PushPermissionSheet({super.key});

  static Future<void> ouvrir(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const PushPermissionSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
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
            Text('Notifications push', style: context.typo.h2),
            AppSpacing.gapLg,
            const PushPermissionCard(),
          ],
        ),
      ),
    );
  }
}

/// Ce que la ligne « Notifications push » annonce à droite.
String libellePush(PushStatus statut) => switch (statut) {
  PushStatus.actif => 'Activées',
  PushStatus.aAutoriser => 'Désactivées',
  PushStatus.refuse => 'Refusées',
  PushStatus.installationRequise => 'À installer',
  PushStatus.nonSupporte => 'Indisponibles',
};
