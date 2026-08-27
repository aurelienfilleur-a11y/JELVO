import 'dart:async';
import 'dart:typed_data';

import 'package:jelvo/features/chat/services/voice_player.dart';
import 'package:jelvo/features/chat/services/voice_recorder.dart';

/// Enregistreur sans micro.
///
/// Un `AudioRecorder` s'appuie sur un canal de plateforme, absent du harnais
/// de test : sans ce faux, ouvrir la conversation lèverait une
/// `MissingPluginException` avant même d'afficher un bouton.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({
    this.autorisation = true,
    this.duree = const Duration(seconds: 8),
    this.extension = 'm4a',
  });

  /// Faux pour éprouver le refus du microphone.
  bool autorisation;

  Duration duree;
  String extension;

  bool enCours = false;
  int demarrages = 0;
  int annulations = 0;

  @override
  Future<bool> autorise() async => autorisation;

  @override
  Future<bool> demarrer() async {
    if (!autorisation) return false;
    demarrages++;
    enCours = true;
    return true;
  }

  @override
  Future<VoiceRecording?> arreter() async {
    if (!enCours) return null;
    enCours = false;
    return VoiceRecording(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      extension: extension,
      duration: duree,
    );
  }

  @override
  Future<void> annuler() async {
    annulations++;
    enCours = false;
  }

  @override
  Future<void> disposer() async {}
}

/// Lecteur sans son. Il émet les mêmes signaux que `just_audio` — position,
/// lecture, fin —, ce qui suffit à éprouver la bulle.
class FakeVoicePlayer implements VoicePlayer {
  FakeVoicePlayer({this.dureeAnnoncee});

  /// Ce que le fichier déclare. `null` reproduit un conteneur qui ne dit pas
  /// sa durée — le cas courant des enregistrements `MediaRecorder`.
  final Duration? dureeAnnoncee;

  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _lectures = StreamController<bool>.broadcast();
  final StreamController<void> _fins = StreamController<void>.broadcast();

  String? urlChargee;
  Duration? derniereRecherche;

  @override
  Future<Duration?> charger(String url) async {
    urlChargee = url;
    return dureeAnnoncee;
  }

  @override
  Future<void> jouer() async => _lectures.add(true);

  @override
  Future<void> pauser() async => _lectures.add(false);

  @override
  Future<void> allerA(Duration position) async {
    derniereRecherche = position;
    _positions.add(position);
  }

  /// Fait avancer la lecture, comme le ferait le son.
  void avancer(Duration position) => _positions.add(position);

  void terminer() => _fins.add(null);

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<bool> get lectures => _lectures.stream;

  @override
  Stream<void> get fins => _fins.stream;

  @override
  Future<void> disposer() async {
    await _positions.close();
    await _lectures.close();
    await _fins.close();
  }
}
