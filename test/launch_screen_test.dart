import 'dart:io';

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
      // `theme-color` n'est pas lu par l'application ajoutée à l'écran
      // d'accueil : sans cette ligne, le bandeau y reste blanc.
      expect(page, contains('apple-mobile-web-app-status-bar-style'));
      expect(page, contains('id="jelvo-bandeau-ios"'));
      expect(page, contains("'black'"));
    });
  });

  group("Les écrans de lancement d'iOS", () {
    // Sans eux, une application ajoutée à l'écran d'accueil en affiche deux à
    // la suite — celui qu'iOS fabrique, puis celui de la page — et le logo
    // change de taille entre les deux.
    final List<String> fichiers =
        (Directory('web/splash').listSync().whereType<File>().toList()
              ..sort((File a, File b) => a.path.compareTo(b.path)))
            .map((File f) => f.uri.pathSegments.last)
            .where((String n) => n.endsWith('.png'))
            .toList();

    test('il y en a, et pour les deux apparences', () {
      expect(fichiers, isNotEmpty);
      expect(
        fichiers.where((String n) => n.endsWith('-clair.png')),
        isNotEmpty,
      );
      expect(
        fichiers.where((String n) => n.endsWith('-sombre.png')),
        hasLength(
          fichiers.where((String n) => n.endsWith('-clair.png')).length,
        ),
        reason:
            'une taille sans sa variante sombre retomberait sur l’écran '
            'fabriqué par iOS, donc sur l’ancien défaut',
      );
    });

    test('chaque fichier est déclaré, et chaque déclaration a son fichier', () {
      // Les deux listes vivent à deux endroits — le générateur et la page —
      // et rien ne protesterait si elles divergeaient : iOS retomberait
      // simplement sur son propre écran, sans rien dire.
      for (final String nom in fichiers) {
        expect(
          page,
          contains('href="splash/$nom"'),
          reason: '$nom est généré mais n’est déclaré nulle part',
        );
      }
      final Iterable<String> declares = RegExp(
        r'href="splash/([^"]+)"',
      ).allMatches(page).map((RegExpMatch m) => m.group(1)!);
      for (final String nom in declares) {
        expect(
          File('web/splash/$nom').existsSync(),
          isTrue,
          reason: '$nom est déclaré mais n’existe pas',
        );
      }
      expect(declares.toSet(), fichiers.toSet());
    });

    test('chaque déclaration dit sa taille, sa densité et son apparence', () {
      // iOS n'accepte que des dimensions exactes, et n'a pas d'autre moyen de
      // choisir l'apparence.
      for (final String nom in fichiers) {
        final RegExpMatch? m = RegExp(
          r'^(\d+)x(\d+)@(\d)x-(clair|sombre)\.png$',
        ).firstMatch(nom);
        expect(m, isNotNull, reason: 'nom de fichier inattendu : $nom');
        final String schema = m!.group(4) == 'sombre' ? 'dark' : 'light';
        final int debut = page.indexOf('href="splash/$nom"');
        final String balise = page.substring(debut, debut + 320);
        expect(balise, contains('(device-width: ${m.group(1)}px)'));
        expect(balise, contains('(device-height: ${m.group(2)}px)'));
        expect(balise, contains('(-webkit-device-pixel-ratio: ${m.group(3)})'));
        expect(balise, contains('(prefers-color-scheme: $schema)'));
      }
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
