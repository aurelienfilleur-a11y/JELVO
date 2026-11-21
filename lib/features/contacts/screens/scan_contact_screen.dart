import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';
import '../repository/contact_repository.dart';
import '../widgets/qr_support.dart';

/// Scanner de QR code, pour ajouter un contact sans saisir son pseudo.
///
/// Sur une plateforme sans caméra — le web, notamment — l'écran affiche un
/// état explicite au lieu d'une vue noire.
class ScanContactScreen extends ConsumerStatefulWidget {
  const ScanContactScreen({super.key});

  @override
  ConsumerState<ScanContactScreen> createState() => _ScanContactScreenState();
}

class _ScanContactScreenState extends ConsumerState<ScanContactScreen> {
  MobileScannerController? _controller;

  /// Empêche qu'un même code, détecté à chaque image, déclenche une rafale de
  /// demandes.
  bool _handling = false;
  String? _lastPseudo;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (QrScanSupport.isAvailable) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: Text(AppTexts.of(context).contactsScannerQRCode),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppTexts.of(context).commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: _controller == null
            ? EmptyState(
                icon: Icons.no_photography_outlined,
                title: AppTexts.of(context).contactsScanIndisponibleIci,
                message: QrScanSupport.unavailableMessage(AppTexts.of(context)),
                actionLabel: AppTexts.of(context).contactsChercherPseudo,
                onActionPressed: () => Navigator.of(context).maybePop(),
              )
            : Column(
                children: <Widget>[
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder:
                              (
                                BuildContext context,
                                MobileScannerException e,
                              ) => EmptyState(
                                icon: Icons.videocam_off_outlined,
                                title: AppTexts.of(
                                  context,
                                ).contactsCameraInaccessible,
                                message: AppTexts.of(
                                  context,
                                ).contactsAutorisezAccesCameraScanner,
                              ),
                        ),
                        const _ScannerFrame(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    child: Text(
                      _message ??
                          AppTexts.of(context).contactsVisezQRCodeProche,
                      textAlign: TextAlign.center,
                      style: context.typo.caption,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final AppTexts t = AppTexts.of(context);
    if (_handling) return;

    String? pseudo;
    for (final Barcode barcode in capture.barcodes) {
      pseudo ??= QrContact.decode(barcode.rawValue);
    }

    if (pseudo == null) {
      setState(() => _message = AppTexts.of(context).contactsQRCodeProfilJelvo);
      return;
    }
    if (pseudo == _lastPseudo) return;

    _handling = true;
    _lastPseudo = pseudo;
    try {
      final List<ProfileSummary> found = await ref
          .read(contactRepositoryProvider)
          .searchByPseudo(pseudo);

      final ProfileSummary? profile = found
          .where((ProfileSummary p) => p.pseudo == pseudo)
          .firstOrNull;

      if (profile == null) {
        if (mounted) {
          setState(
            () => _message = AppTexts.of(
              context,
            ).contactsAucunComptePortePseudo(pseudo!),
          );
        }
        return;
      }

      final ContactRequestOutcome outcome = await ref
          .read(contactActionsProvider)
          .sendRequest(profile.id);
      if (mounted) {
        setState(
          () => _message = t.contactsNomEtMessage(
            profile.fullName,
            outcome.message(t),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _message = AuthFailure.from(error).message(AppTexts.of(context)),
        );
      }
    } finally {
      _handling = false;
    }
  }
}

/// Cadre de visée, purement indicatif.
class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: AppRadii.cardRadius,
        ),
      ),
    );
  }
}
