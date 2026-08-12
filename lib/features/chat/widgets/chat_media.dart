import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/message.dart';
import '../providers/chat_providers.dart';

/// Vignette d'un média dans une bulle.
///
/// Le bucket est **privé** : `messages.media_url` ne contient pas une URL mais
/// un **chemin**, et l'affichage demande une URL signée à la volée. Stocker
/// l'URL aurait produit des liens morts en quelques heures.
///
/// Une vidéo n'est pas lue ici : voir [_Video].
class ChatMedia extends ConsumerWidget {
  const ChatMedia({super.key, required this.message});

  final Message message;

  static const double largeur = 220;
  static const double hauteur = 160;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? chemin = message.mediaUrl;
    if (chemin == null) return const SizedBox.shrink();

    final AsyncValue<String> url = ref.watch(signedMediaUrlProvider(chemin));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: SizedBox(
          width: largeur,
          height: hauteur,
          child: url.when(
            loading: () => const _Cadre(child: CircularProgressIndicator()),
            error: (Object erreur, _) => const _Cadre(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            data: (String lien) => message.mediaKind == MediaKind.video
                ? _Video(url: lien)
                : _Photo(url: lien, message: message),
          ),
        ),
      ),
    );
  }
}

class _Cadre extends StatelessWidget {
  const _Cadre({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: SizedBox(width: 24, height: 24, child: child),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.message});

  final String url;
  final Message message;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _ouvrirEnGrand(context, url),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: ChatMedia.largeur,
        height: ChatMedia.hauteur,
        loadingBuilder:
            (BuildContext context, Widget enfant, ImageChunkEvent? progres) =>
                progres == null
                ? enfant
                : const _Cadre(child: CircularProgressIndicator()),
        errorBuilder: (_, _, _) => const _Cadre(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Une vidéo, affichée mais **non lue dans l'application**.
///
/// La lecture en place demanderait `video_player`, c'est-à-dire une nouvelle
/// dépendance — un choix qui vous revient, pas une exécution. En attendant, la
/// vidéo part, se stocke et s'affiche comme pièce jointe ; ce qui manque est
/// la lecture, et le dire est plus honnête qu'un bouton qui ne ferait rien.
class _Video extends StatelessWidget {
  const _Video({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.midnight,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.play_circle_outline_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 4),
          Text(
            'Vidéo',
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Photo en plein écran, fond noir, fermeture au toucher.
void _ouvrirEnGrand(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (BuildContext pageContext, _, _) => GestureDetector(
        onTap: () => Navigator.of(pageContext).maybePop(),
        child: Stack(
          children: <Widget>[
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(pageContext).top + AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(pageContext).maybePop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
