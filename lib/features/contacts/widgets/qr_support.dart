import 'package:flutter/foundation.dart';

/// Contenu encodé dans le QR code personnel, et conditions du scan.
///
/// Le préfixe évite qu'un QR quelconque soit pris pour un pseudo Jelvo : un
/// code-barres de supermarché ne doit pas déclencher de demande de contact.
abstract final class QrContact {
  static const String scheme = 'jelvo:contact/';

  /// Contenu à encoder pour le pseudo donné.
  static String encode(String pseudo) => '$scheme${pseudo.toLowerCase()}';

  /// Pseudo lu dans un QR code, ou `null` si le contenu n'en est pas un.
  ///
  /// Accepte aussi un pseudo nu : certains générateurs de QR se contentent du
  /// texte, et refuser ce cas n'apporterait rien à l'utilisateur.
  static String? decode(String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    final String candidate = value.startsWith(scheme)
        ? value.substring(scheme.length)
        : value;

    final RegExp pseudoPattern = RegExp(r'^[a-z0-9.]{3,20}$');
    final String normalized = candidate.toLowerCase();
    return pseudoPattern.hasMatch(normalized) ? normalized : null;
  }
}

/// Disponibilité du scan de QR code sur la plateforme courante.
///
/// `mobile_scanner` s'appuie sur les API caméra natives d'Android et d'iOS.
/// Sur le web et sur ordinateur, l'écran de scan est remplacé par un message
/// et par la recherche par pseudo, plutôt que par une caméra qui reste noire.
abstract final class QrScanSupport {
  static bool get isAvailable {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String get unavailableMessage =>
      'Le scan de QR code demande une caméra : il est disponible sur '
      'l’application mobile. Ici, cherchez la personne par son pseudo.';
}
