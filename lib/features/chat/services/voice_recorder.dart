import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Un enregistrement terminé, prêt à partir dans le bucket.
@immutable
class VoiceRecording {
  const VoiceRecording({
    required this.bytes,
    required this.extension,
    required this.duration,
  });

  final Uint8List bytes;

  /// `m4a` ou `webm` selon ce que la plateforme sait encoder — voir
  /// [SystemVoiceRecorder].
  final String extension;

  /// Mesurée à l'horloge de l'enregistrement, et non lue dans le fichier.
  final Duration duration;
}

/// Ce dont l'écran a besoin pour enregistrer la voix.
///
/// L'interface existe pour la même raison que les dépôts : les tests de
/// widget n'ont ni micro ni canal de plateforme, et un `AudioRecorder` y
/// lèverait une `MissingPluginException` avant même d'afficher un bouton.
abstract interface class VoiceRecorder {
  /// Demande — et vérifie — l'autorisation du microphone.
  Future<bool> autorise();

  /// Commence à enregistrer. Renvoie faux si la plateforme refuse.
  Future<bool> demarrer();

  /// Arrête et rend l'enregistrement. `null` si rien n'a été capturé.
  Future<VoiceRecording?> arreter();

  /// Arrête et jette. Rien ne part.
  Future<void> annuler();

  Future<void> disposer();
}

/// L'enregistreur réel, adossé au paquet `record`.
///
///
/// LE FORMAT N'EST PAS LE MÊME PARTOUT, ET NE PEUT PAS L'ÊTRE
///
/// Sur le web, l'enregistrement passe par `MediaRecorder`, dont les formats
/// dépendent du navigateur — et **aucun n'est commun aux trois** :
///
/// | Navigateur | Ce qu'il sait enregistrer |
/// | --- | --- |
/// | Safari, iOS compris | AAC dans un conteneur MP4 |
/// | Chrome, Edge | Opus dans un conteneur WebM |
/// | Firefox | Opus dans un conteneur WebM, ou Ogg |
///
/// Choisir un format unique reviendrait donc à priver une famille de
/// navigateurs de la fonctionnalité. L'encodeur est **négocié** :
/// `isEncoderSupported` est interrogé dans l'ordre, AAC d'abord — c'est le
/// seul que Safari lit *et* écrit, et il se lit partout ailleurs.
///
/// L'extension suit l'encodeur retenu, et c'est elle qui décide du type MIME
/// à l'envoi comme à la lecture : un `.webm` annoncé `audio/mp4` ne se lirait
/// nulle part.
///
///
/// CE QUE LE NAVIGATEUR IMPOSE, ET QU'AUCUN CODE NE CONTOURNE
///
/// - **l'autorisation du microphone est demandée à la première utilisation**,
///   et un refus est définitif côté application : l'API ne permet pas de
///   redemander. C'est la même limite que les notifications système ;
/// - **il faut un geste de l'utilisateur** pour ouvrir le flux : commencer à
///   enregistrer depuis une minuterie ou un rappel ne marcherait pas ;
/// - **Safari n'accorde le micro qu'en HTTPS** — ou sur `localhost`.
class SystemVoiceRecorder implements VoiceRecorder {
  SystemVoiceRecorder();

  final AudioRecorder _enregistreur = AudioRecorder();
  final Stopwatch _chronometre = Stopwatch();

  String _extension = 'm4a';

  /// Encodeurs interrogés dans l'ordre, avec l'extension du conteneur que
  /// chacun produit.
  static const Map<AudioEncoder, String> _candidats = <AudioEncoder, String>{
    AudioEncoder.aacLc: 'm4a',
    AudioEncoder.opus: 'webm',
    AudioEncoder.wav: 'wav',
  };

  @override
  Future<bool> autorise() => _enregistreur.hasPermission();

  @override
  Future<bool> demarrer() async {
    if (!await _enregistreur.hasPermission()) return false;

    AudioEncoder? retenu;
    for (final MapEntry<AudioEncoder, String> candidat in _candidats.entries) {
      if (await _enregistreur.isEncoderSupported(candidat.key)) {
        retenu = candidat.key;
        _extension = candidat.value;
        break;
      }
    }
    if (retenu == null) return false;

    await _enregistreur.start(
      RecordConfig(
        encoder: retenu,
        // La voix n'a besoin ni de stéréo ni de la bande passante d'une
        // musique : 32 kbit/s en mono donnent deux minutes pour moins d'un
        // demi-mégaoctet, et se transportent sur un réseau médiocre.
        bitRate: 32000,
        sampleRate: 44100,
        numChannels: 1,
        noiseSuppress: true,
        echoCancel: true,
      ),
      path: await _chemin(),
    );

    _chronometre
      ..reset()
      ..start();
    return true;
  }

  @override
  Future<VoiceRecording?> arreter() async {
    _chronometre.stop();
    final String? source = await _enregistreur.stop();
    if (source == null) return null;

    // `stop` rend un chemin de fichier sur mobile et une URL `blob:` sur le
    // web. `XFile` lit les deux — c'est précisément ce pour quoi il existe.
    final Uint8List octets = await XFile(source).readAsBytes();
    if (octets.isEmpty) return null;

    return VoiceRecording(
      bytes: octets,
      extension: _extension,
      // La durée vient de l'horloge et non du fichier : les conteneurs
      // produits par `MediaRecorder` n'annoncent pas toujours la leur, et un
      // « 0:00 » sur un message de vingt secondes serait pire qu'un arrondi.
      duration: _chronometre.elapsed,
    );
  }

  @override
  Future<void> annuler() async {
    _chronometre.stop();
    await _enregistreur.cancel();
  }

  @override
  Future<void> disposer() => _enregistreur.dispose();

  /// Le web ignore ce chemin ; les cibles natives l'exigent.
  Future<String> _chemin() async {
    if (kIsWeb) return '';
    final String dossier = (await getTemporaryDirectory()).path;
    final int marque = DateTime.now().millisecondsSinceEpoch;
    return '$dossier/jelvo-vocal-$marque.$_extension';
  }
}
