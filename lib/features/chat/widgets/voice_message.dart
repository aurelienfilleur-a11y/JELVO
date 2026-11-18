import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/message.dart';
import '../providers/chat_providers.dart';

/// Un message vocal dans sa bulle : lire, où l'on en est, combien il dure.
///
/// **Pas de forme d'onde.** Les barres qu'on voit ailleurs représentent
/// l'amplitude du son, que rien n'enregistre ici : les dessiner au hasard
/// donnerait un motif décoratif qui *ressemble* à une donnée sans en être
/// une. Une barre de progression dit la même chose — où l'on en est — et ne
/// prétend rien de plus.
///
/// La durée vient de la base (`messages.media_duree_s`), et non du fichier :
/// elle s'affiche donc **avant** toute lecture, sans qu'aucun octet n'ait été
/// téléchargé. Une fois le fichier chargé, c'est sa propre durée qui prend le
/// relais, plus juste au dixième près.
class VoiceMessage extends ConsumerWidget {
  const VoiceMessage({super.key, required this.message, required this.couleur});

  final Message message;

  /// Blanc sur sa propre bulle violette, encre sur celle des autres.
  final Color couleur;

  /// Assez large pour que la barre serve à quelque chose, assez étroite pour
  /// tenir dans une bulle à 360 dp.
  static const double largeur = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? chemin = message.mediaUrl;
    if (chemin == null) return const SizedBox.shrink();

    final VoicePlayback lecture = ref.watch(voicePlaybackProvider);
    final bool actif = lecture.estCharge(message.id);
    final bool joue = lecture.joue(message.id);

    final Duration? totale = actif
        ? (lecture.duration ?? message.mediaDuration)
        : message.mediaDuration;
    final Duration position = actif ? lecture.position : Duration.zero;

    final double avancement =
        totale == null || totale.inMilliseconds == 0 || !actif
        ? 0
        : (position.inMilliseconds / totale.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: largeur,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Bouton(
            joue: joue,
            chargement: actif && lecture.loading,
            couleur: couleur,
            onPressed: () => ref
                .read(voicePlaybackProvider.notifier)
                .basculer(message.id, chemin),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Barre(
                  avancement: avancement,
                  couleur: couleur,
                  onSeek: totale == null || !actif
                      ? null
                      : (double part) => ref
                            .read(voicePlaybackProvider.notifier)
                            .allerA(totale * part),
                ),
                const SizedBox(height: 4),
                Text(
                  // Pendant la lecture, le compteur avance ; à l'arrêt, il
                  // annonce la durée. C'est ce qu'on veut savoir dans chaque
                  // cas, et cela évite un second nombre à côté du premier.
                  _minutage(
                    actif && position > Duration.zero ? position : totale,
                  ),
                  style: context.typo.caption.copyWith(
                    color: couleur.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// « 0:07 », « 1:42 ». Jamais d'heures : la durée est bornée à deux minutes.
  static String _minutage(Duration? duree) {
    if (duree == null) return '--:--';
    final int secondes = duree.inSeconds;
    return '${secondes ~/ 60}:${(secondes % 60).toString().padLeft(2, '0')}';
  }
}

class _Bouton extends StatelessWidget {
  const _Bouton({
    required this.joue,
    required this.chargement,
    required this.couleur,
    required this.onPressed,
  });

  final bool joue;
  final bool chargement;
  final Color couleur;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: couleur.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: chargement ? null : onPressed,
          child: Tooltip(
            message: joue ? 'Mettre en pause' : 'Écouter',
            child: Center(
              child: chargement
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: couleur,
                      ),
                    )
                  : Icon(
                      joue ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20,
                      color: couleur,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La barre de progression, touchable pour se déplacer dans le message.
class _Barre extends StatelessWidget {
  const _Barre({
    required this.avancement,
    required this.couleur,
    required this.onSeek,
  });

  final double avancement;
  final Color couleur;

  /// `null` tant que le message n'est pas chargé : se déplacer dans un son
  /// qu'on n'a pas encore demandé n'aurait rien à quoi s'appliquer.
  final ValueChanged<double>? onSeek;

  static const double _hauteur = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints contraintes) {
        return GestureDetector(
          onTapDown: onSeek == null
              ? null
              : (TapDownDetails details) => onSeek!(
                  (details.localPosition.dx / contraintes.maxWidth).clamp(
                    0.0,
                    1.0,
                  ),
                ),
          // La zone tactile fait 20 dp de haut pour un trait de 4 : viser un
          // trait de quatre pixels au doigt n'est pas une expérience.
          child: Container(
            height: 20,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_hauteur),
              child: LinearProgressIndicator(
                value: avancement,
                minHeight: _hauteur,
                backgroundColor: couleur.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(couleur),
              ),
            ),
          ),
        );
      },
    );
  }
}
