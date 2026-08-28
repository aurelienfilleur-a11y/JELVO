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
        title: const Text('Scanner un QR code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: _controller == null
            ? EmptyState(
                icon: Icons.no_photography_outlined,
                title: 'Scan indisponible ici',
                message: QrScanSupport.unavailableMessage,
                actionLabel: 'Chercher par pseudo',
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
                                title: 'Caméra inaccessible',
                                message:
                                    'Autorisez l’accès à la caméra pour '
                                    'scanner un QR code.',
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
                          'Visez le QR code d’un proche pour lui envoyer une '
                              'demande de contact.',
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
    if (_handling) return;

    String? pseudo;
    for (final Barcode barcode in capture.barcodes) {
      pseudo ??= QrContact.decode(barcode.rawValue);
    }

    if (pseudo == null) {
      setState(() => _message = 'Ce QR code n’est pas un profil Jelvo.');
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
            () => _message = 'Aucun compte ne porte le pseudo @$pseudo.',
          );
        }
        return;
      }

      final ContactRequestOutcome outcome = await ref
          .read(contactActionsProvider)
          .sendRequest(profile.id);
      if (mounted) {
        setState(() => _message = '${profile.fullName} — ${outcome.message}');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = AuthFailure.from(error).message);
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
