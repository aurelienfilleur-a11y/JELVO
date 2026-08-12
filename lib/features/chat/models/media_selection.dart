import 'package:flutter/foundation.dart';

import '../../../data/app_config.dart';
import 'message.dart';

/// Un média choisi, prêt à être téléversé.
@immutable
class MediaSelection {
  const MediaSelection({
    required this.bytes,
    required this.extension,
    required this.kind,
  });

  final Uint8List bytes;
  final String extension;
  final MediaKind kind;

  int get sizeInBytes => bytes.length;

  /// Poids lisible : « 3,2 Mo », « 480 ko ».
  String get sizeLabel {
    if (sizeInBytes >= 1024 * 1024) {
      final double mo = sizeInBytes / (1024 * 1024);
      return '${mo.toStringAsFixed(1).replaceAll('.', ',')} Mo';
    }
    return '${(sizeInBytes / 1024).round()} ko';
  }

  /// Vrai si la vidéo dépasse ce que l'on accepte de téléverser.
  ///
  /// L'application ne ré-encode pas — aucun paquet de compression vidéo n'est
  /// dans les dépendances —, donc la seule borne disponible est le poids. Le
  /// refus est prononcé **à la sélection** : échouer après un téléversement de
  /// trente secondes serait bien pire.
  bool get isTooHeavy =>
      kind == MediaKind.video && sizeInBytes > AppConfig.chatMediaMaxVideoBytes;

  static String get maxVideoLabel {
    final int mo = AppConfig.chatMediaMaxVideoBytes ~/ (1024 * 1024);
    return '$mo Mo';
  }

  /// Extension normalisée d'un nom de fichier, avec repli selon le type.
  static String extensionOf(String? nomDeFichier, MediaKind kind) {
    final int point = (nomDeFichier ?? '').lastIndexOf('.');
    if (point != -1 && point < nomDeFichier!.length - 1) {
      final String brute = nomDeFichier
          .substring(point + 1)
          .toLowerCase()
          // Un nom venu du web porte parfois une chaîne de requête.
          .split('?')
          .first;
      if (brute.isNotEmpty && brute.length <= 5) return brute;
    }
    return kind == MediaKind.video ? 'mp4' : 'jpg';
  }
}
