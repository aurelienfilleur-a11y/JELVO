import 'package:just_audio/just_audio.dart';

/// Lecture d'un message vocal.
///
/// L'interface existe pour la même raison que [VoiceRecorder] : un
/// `AudioPlayer` lève sur un canal de plateforme absent, et les tests de
/// widget n'en ont aucun.
///
/// **Un seul lecteur pour toute la conversation.** Ce n'est pas une économie
/// de mémoire, c'est la règle voulue : deux messages vocaux qui parlent en
/// même temps ne s'écoutent ni l'un ni l'autre. Lancer le second arrête donc
/// le premier, sans que rien n'ait à s'en occuper.
abstract interface class VoicePlayer {
  /// Charge une URL et renvoie la durée annoncée par le fichier, si elle
  /// l'est. Elle peut manquer — voir `VoiceRecording.duration`.
  Future<Duration?> charger(String url);

  Future<void> jouer();
  Future<void> pauser();
  Future<void> allerA(Duration position);

  Stream<Duration> get positions;

  /// Vrai tant que le son sort.
  Stream<bool> get lectures;

  /// Émet quand le message est arrivé à son terme.
  Stream<void> get fins;

  Future<void> disposer();
}

class JustAudioVoicePlayer implements VoicePlayer {
  JustAudioVoicePlayer() : _lecteur = AudioPlayer();

  final AudioPlayer _lecteur;

  @override
  Future<Duration?> charger(String url) => _lecteur.setUrl(url);

  @override
  Future<void> jouer() => _lecteur.play();

  @override
  Future<void> pauser() => _lecteur.pause();

  @override
  Future<void> allerA(Duration position) => _lecteur.seek(position);

  @override
  Stream<Duration> get positions => _lecteur.positionStream;

  @override
  Stream<bool> get lectures =>
      _lecteur.playerStateStream.map((PlayerState etat) => etat.playing);

  @override
  Stream<void> get fins => _lecteur.playerStateStream
      .where(
        (PlayerState etat) => etat.processingState == ProcessingState.completed,
      )
      .map((_) {});

  @override
  Future<void> disposer() => _lecteur.dispose();
}
