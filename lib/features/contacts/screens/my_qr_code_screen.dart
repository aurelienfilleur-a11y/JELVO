import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/core.dart';
import '../../profile/models/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../widgets/qr_support.dart';

/// QR code personnel, à faire scanner pour être ajouté en contact.
class MyQrCodeScreen extends ConsumerWidget {
  const MyQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon QR code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: profile == null
            ? const Center(child: CircularProgressIndicator())
            : _content(context, profile),
      ),
    );
  }

  Widget _content(BuildContext context, Profile profile) {
    final String payload = QrContact.encode(profile.pseudo);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.xl,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Center(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.midnight,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.midnight,
                  ),
                ),
                AppSpacing.gapLg,
                Text(profile.displayName, style: AppTypography.h3),
                Text(profile.pseudoHandle, style: AppTypography.bodyMuted),
              ],
            ),
          ),
        ),

        AppSpacing.gapXl,
        Text(
          'Faites scanner ce code pour être ajouté en contact. Il ne contient '
          'que votre pseudo — ni adresse e-mail, ni agenda.',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),

        AppSpacing.gapXl,
        SecondaryButton(
          label: 'Partager mon pseudo',
          icon: Icons.ios_share_rounded,
          onPressed: () => _share(profile),
        ),
      ],
    );
  }

  Future<void> _share(Profile profile) async {
    // Un échec de partage n'a rien de bloquant : le QR reste affiché.
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Ajoutez-moi sur Jelvo : ${profile.pseudoHandle}',
          subject: 'Mon pseudo Jelvo',
        ),
      );
    } catch (_) {}
  }
}
