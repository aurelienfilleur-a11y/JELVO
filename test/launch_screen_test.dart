import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jelvo/data/theme_storage.dart';
import 'package:jelvo/demarrage.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_task_repository.dart';

/// L'écran de lancement et la couleur du bandeau vivent dans
/// `web/index.html`, et il n'y a pas d'autre endroit où ils puissent vivre :
/// ils doivent être justes **avant** que Flutter démarre.
///
/// La contrepartie est que la page recopie trois choses que le Dart connaît
/// aussi — la clé de stockage, les trois mots d'apparence, et deux teintes de
/// la palette. Aucune de ces recopies ne proteste quand elle devient fausse :
/// le démarrage retomberait simplement sur « suivre le téléphone », et le
/// clignotement reviendrait sans que rien ne le dise. D'où ce fichier.
void main() {
  late String page;

  setUpAll(() {
    page = File('web/index.html').readAsStringSync();
  });

  /// `#RRGGBB` en majuscules, comme l'écrit la page.
  String hexa(Color couleur) =>
      '#${(couleur.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  group("Le contrat entre la page et l'application", () {
    test('la page lit la clé de stockage de ThemeStorage', () {
      expect(ThemeStorage.cle, 'jelvo-apparence');
      expect(
        page,
        contains("localStorage.getItem('${ThemeStorage.cle}')"),
        reason:
            'la page doit lire la clé que ThemeStorage écrit, sans quoi le '
            'réglage est ignoré au démarrage',
      );
    });

    test('la page connaît les trois mots que ThemeStorage écrit', () {
      // Partir de `ThemeMode` plutôt que d'une liste recopiée : une valeur
      // ajoutée à l'énumération doit faire échouer ce test, pas passer
      // inaperçue.
      for (final ThemeMode mode in ThemeMode.values) {
        expect(
          page,
          contains("'${ThemeStorage.jeton(mode)}'"),
          reason:
              'la page doit savoir quoi faire du mot ${ThemeStorage.jeton(mode)}',
        );
      }
    });

    test('les deux fonds de la page sont ceux de la palette', () {
      expect(page, contains(hexa(JelvoColors.clair.background)));
      expect(page, contains(hexa(JelvoColors.sombre.background)));
    });

    test("le violet de la marque n'est plus la couleur du bandeau", () {
      // Le bandeau continue l'écran : il prend `background`, pas `primary`.
      // Le violet y figurait, et c'est ce qui le rendait faux dans les deux
      // apparences.
      expect(page, isNot(contains(hexa(JelvoColors.clair.primary))));
    });
  });

  group("L'écran de lancement", () {
    test('la page porte le voile et le logo fourni', () {
      expect(page, contains('id="jelvo-amorce"'));
      expect(page, contains('icons/Icon-192.png'));
      expect(
        File('web/icons/Icon-192.png').existsSync(),
        isTrue,
        reason: 'le logo de l’écran de lancement doit exister au dépôt',
      );
    });

    test("c'est l'application qui dit quand l'effacer", () {
      // La première image de Flutter ne suffisait pas : à cet instant
      // l'accueil est construit mais ses lectures sont en vol, et il
      // s'affiche avec ses états vides. Elle ne sert plus que de filet.
      expect(page, contains('window.jelvoApplicationPrete'));
      expect(
        page,
        contains("addEventListener('flutter-first-frame'"),
        reason:
            'le filet reste : un signal qui ne vient pas ne doit pas '
            'laisser le voile posé sur une application chargée',
      );
    });

    test('il est retiré de la page, pas seulement rendu transparent', () {
      // Laissé en place, un voile transparent avalerait les touches.
      expect(page, contains('removeChild(amorce)'));
    });
  });

  group('Le bandeau de la barre d’état', () {
    test('il suit le téléphone par requête de média, sans script', () {
      expect(
        page,
        contains('media="(prefers-color-scheme: dark)"'),
        reason:
            'le mode Automatique doit suivre le réglage du téléphone même '
            'après le démarrage, ce qu’une couleur figée ne fait pas',
      );
    });

    test('iOS installé a sa propre déclaration, réglable', () {
      // Sur iOS 25 et avant, `theme-color` n'est pas lu par l'application
      // ajoutée à l'écran d'accueil : sans cette ligne, le bandeau y reste
      // blanc. iOS la lit au lancement et ne la relit pas — d'où le test
      // suivant, qui porte sur le seul mécanisme réglable à chaud.
      expect(page, contains('apple-mobile-web-app-status-bar-style'));
      expect(page, contains('id="jelvo-bandeau-ios"'));
      expect(page, contains("'black'"));
    });

    test(
      'le fond est posé en clair sur html et body, pas seulement en méta',
      () {
        // **C'est ceci qui fait suivre le bandeau à chaud.** Depuis iOS 26,
        // WebKit ne lit plus ni `apple-mobile-web-app-status-bar-style` ni
        // `theme-color` : il échantillonne le fond de la page. Une variable CSS
        // ne se lit pas de l'extérieur du document, et la toile de Flutter ne
        // porte aucune couleur : il reste `html` et `body`, qui doivent donc
        // recevoir la teinte en clair à chaque changement.
        expect(
          page,
          contains('racine.style.backgroundColor = fond'),
          reason:
              'sans cette ligne le bandeau garde la couleur du lancement '
              'jusqu’à ce qu’on quitte et rouvre l’application',
        );
        expect(page, contains('document.body.style.backgroundColor = fond'));
      },
    );
  });

  group("Les écrans de lancement d'iOS", () {
    // Ils ne portent plus le logo : un seul endroit le dessine, le voile de la
    // page. C'est ce qui a supprimé le saut de taille, et c'est aussi ce qui a
    // permis d'abandonner la liste de douze modèles — un aplat n'a pas de
    // géométrie à faire coïncider.
    final List<String> fichiers =
        (Directory('web/splash').listSync().whereType<File>().toList()
              ..sort((File a, File b) => a.path.compareTo(b.path)))
            .map((File f) => f.uri.pathSegments.last)
            .where((String n) => n.endsWith('.png'))
            .toList();

    test('il y en a un par apparence, et deux en tout', () {
      expect(
        fichiers,
        <String>['lancement-clair.png', 'lancement-sombre.png'],
        reason:
            'un fichier de plus est le signe que la liste de modèles revient : '
            'c’est elle qui était en retard par construction',
      );
    });

    test('aucune déclaration ne porte de dimension', () {
      // **Le contrôle négatif qui compte.** Dès qu'une balise cite une taille,
      // elle ne vaut plus que pour les appareils qui l'ont exactement, et la
      // liste est de retour — avec les modèles de l'an prochain en moins.
      final Iterable<RegExpMatch> balises = RegExp(
        r'<link rel="apple-touch-startup-image"[^>]*>',
        multiLine: true,
        dotAll: true,
      ).allMatches(page);
      expect(balises, hasLength(2));
      for (final RegExpMatch m in balises) {
        final String balise = m.group(0)!;
        expect(balise, isNot(contains('device-width')));
        expect(balise, isNot(contains('device-height')));
        expect(balise, isNot(contains('device-pixel-ratio')));
        expect(
          balise,
          matches(RegExp(r'prefers-color-scheme: (light|dark)')),
          reason: 'l’apparence reste le seul critère de choix',
        );
      }
    });

    test('chaque fichier est déclaré, et chaque déclaration a son fichier', () {
      // Les deux listes vivent à deux endroits — le générateur et la page — et
      // rien ne protesterait si elles divergeaient : iOS retomberait sur son
      // propre écran, sans rien dire.
      final Set<String> declares = RegExp(
        r'href="splash/([^"]+)"',
      ).allMatches(page).map((RegExpMatch m) => m.group(1)!).toSet();
      expect(declares, fichiers.toSet());
      for (final String nom in declares) {
        expect(File('web/splash/$nom').existsSync(), isTrue, reason: nom);
      }
    });

    test('ce sont des aplats, et de la teinte de la palette', () {
      // Le logo ne doit **pas** y être : s'il revenait, il faudrait de nouveau
      // faire coïncider sa taille avec celle du voile, donc de nouveau des
      // captures par modèle. Un aplat le prouve, et un nom de fichier ne
      // prouverait rien.
      for (final MapEntry<String, Color> cas in <String, Color>{
        'lancement-clair.png': JelvoColors.clair.background,
        'lancement-sombre.png': JelvoColors.sombre.background,
      }.entries) {
        final _Png image = _Png.lire(File('web/splash/${cas.key}'));
        expect(
          image.couleurUnique,
          isNotNull,
          reason: '${cas.key} n’est pas un aplat',
        );
        expect(
          hexa(image.couleurUnique!),
          hexa(cas.value),
          reason: '${cas.key} ne porte pas le fond de la palette',
        );
      }
    });

    test('leur proportion est celle des iPhone, et non une taille', () {
      // 19,5:9, tenu par Apple depuis l'iPhone X. C'est ce rapport de forme
      // qui remplace la liste de modèles : il n'y a plus de taille à viser,
      // donc plus de taille à manquer — iOS met l'aplat à l'échelle, et un
      // aplat mis à l'échelle reste le même aplat.
      final _Png image = _Png.lire(File('web/splash/lancement-clair.png'));
      expect(image.hauteur / image.largeur, closeTo(19.5 / 9, 0.05));
    });
  });

  group("Quand l'application se dit prête", () {
    ProviderContainer conteneur({required bool connecte}) {
      final FakeAuthRepository auth = FakeAuthRepository(signedIn: connecte);
      addTearDown(auth.dispose);
      final ProviderContainer c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('sans session, prête tout de suite', () {
      // La bienvenue et la connexion ne lisent rien : les retenir ferait
      // regarder un logo sans raison.
      expect(conteneur(connecte: false).read(applicationPreteProvider), isTrue);
    });

    test('avec session, pas avant que les lectures aient répondu', () {
      final ProviderContainer c = conteneur(connecte: true);
      // Contrôle négatif, et c'est lui qui compte : au premier instant les
      // quatre lectures sont en vol, et c'est exactement là que l'accueil
      // s'affichait vide.
      expect(c.read(applicationPreteProvider), isFalse);
    });

    test('puis prête une fois les quatre lectures revenues', () async {
      final ProviderContainer c = conteneur(connecte: true);
      await c.read(currentProfileProvider.future);
      await c.read(myGroupsProvider.future);
      await c.read(eventsProvider.future);
      await c.read(tasksProvider.future);
      expect(c.read(applicationPreteProvider), isTrue);
    });
  });
}

/// Lecteur de PNG minimal, pour un seul usage : contrôler qu'une image de
/// lancement est bien un aplat de la teinte de la palette.
///
/// **Décoder plutôt que se fier au nom du fichier**, parce que c'est le
/// contenu qui porte la règle : un logo qui reviendrait dans ces images
/// ramènerait les deux tailles à faire coïncider, donc les captures par
/// modèle. Un nom de fichier ne dirait rien de cela.
class _Png {
  const _Png._(this.largeur, this.hauteur, this.pixels);

  final int largeur;
  final int hauteur;

  /// Les octets RVB, sans les octets de filtre des lignes.
  final Uint8List pixels;

  static _Png lire(File fichier) {
    final Uint8List octets = fichier.readAsBytesSync();
    final ByteData vue = ByteData.sublistView(octets);
    if (vue.getUint64(0) != 0x89504E470D0A1A0A) {
      throw StateError('${fichier.path} n’est pas un PNG');
    }
    final int largeur = vue.getUint32(16);
    final int hauteur = vue.getUint32(20);
    if (octets[24] != 8 || octets[25] != 2) {
      throw StateError('${fichier.path} n’est pas en RVB 8 bits sans alpha');
    }

    final List<int> comprime = <int>[];
    int tete = 8;
    while (tete + 8 <= octets.length) {
      final int taille = vue.getUint32(tete);
      final String type = String.fromCharCodes(octets, tete + 4, tete + 8);
      if (type == 'IDAT') {
        comprime.addAll(octets.sublist(tete + 8, tete + 8 + taille));
      }
      tete += 12 + taille;
    }
    final List<int> brut = zlib.decode(comprime);

    final int pas = 1 + largeur * 3;
    final Uint8List pixels = Uint8List(largeur * hauteur * 3);
    for (int y = 0; y < hauteur; y++) {
      if (brut[y * pas] != 0) {
        throw StateError(
          '${fichier.path} : la ligne $y est filtrée (${brut[y * pas]}) — '
          'le générateur n’écrit que des lignes non filtrées',
        );
      }
      pixels.setRange(
        y * largeur * 3,
        (y + 1) * largeur * 3,
        brut,
        y * pas + 1,
      );
    }
    return _Png._(largeur, hauteur, pixels);
  }

  /// La couleur de l'image si elle n'en porte qu'une, `null` sinon.
  Color? get couleurUnique {
    for (int i = 0; i + 2 < pixels.length; i += 3) {
      if (pixels[i] != pixels[0] ||
          pixels[i + 1] != pixels[1] ||
          pixels[i + 2] != pixels[2]) {
        return null;
      }
    }
    return Color.fromARGB(0xFF, pixels[0], pixels[1], pixels[2]);
  }
}
