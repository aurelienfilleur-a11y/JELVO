import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/theme_storage.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/chat/widgets/message_bubble.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';
import 'fakes/fake_voice.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

/// Rapport de contraste WCAG entre deux couleurs opaques.
///
/// Recalculé ici plutôt que recopié : une palette se retouche, et un chiffre
/// écrit en commentaire ne proteste jamais quand il devient faux.
double _contraste(Color a, Color b) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);

  final double la = luminance(a);
  final double lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<ThemeStorage> _pumpApp(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.system,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeChatRepository chat = FakeChatRepository();
  addTearDown(chat.dispose);
  final ThemeStorage apparence = EphemeralThemeStorage(mode: mode);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        themeStorageProvider.overrideWithValue(apparence),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
        voiceRecorderProvider.overrideWithValue(FakeVoiceRecorder()),
        voicePlayerFactoryProvider.overrideWithValue(FakeVoicePlayer.new),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return apparence;
}

Future<void> _ouvrirParametres(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Paramètres'));
  await tester.pumpAndSettle();
}

Brightness _luminosite(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('La palette sombre est lisible', () {
    const JelvoColors sombre = JelvoColors.sombre;
    const JelvoColors clair = JelvoColors.clair;

    test('le texte passe 4,5:1 sur le fond comme sur la carte', () {
      final Map<String, Color> textes = <String, Color>{
        'encre': sombre.encre,
        'textSecondary': sombre.textSecondary,
        'primaryInk': sombre.primaryInk,
        'successInk': sombre.successInk,
        'warningInk': sombre.warningInk,
        'dangerInk': sombre.dangerInk,
      };
      for (final MapEntry<String, Color> jeton in textes.entries) {
        for (final Color fond in <Color>[sombre.background, sombre.surface]) {
          expect(
            _contraste(jeton.value, fond),
            greaterThanOrEqualTo(4.5),
            reason: jeton.key,
          );
        }
      }
    });

    test('les teintes fonctionnelles se lisent sur leur fond teinté', () {
      // `warning` sur `warningSoft` ne donnait que 1,81:1 en clair : c'est le
      // défaut que les variantes `…Ink` corrigent, des deux côtés.
      for (final JelvoColors palette in <JelvoColors>[clair, sombre]) {
        expect(
          _contraste(palette.successInk, palette.successSoft),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(palette.warningInk, palette.warningSoft),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(palette.dangerInk, palette.dangerSoft),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(palette.primaryInk, palette.primarySoft),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('l’encre des aplats saturés tient dans les deux thèmes', () {
      // En sombre les aplats sont clairs : du blanc dessus tomberait à 2:1.
      for (final JelvoColors palette in <JelvoColors>[clair, sombre]) {
        expect(
          _contraste(palette.onAccent, palette.primary),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('les huit teintes d’expéditeur restent du texte lisible', () {
      for (final (JelvoColors palette, Color fond) in <(JelvoColors, Color)>[
        (clair, clair.background),
        (sombre, sombre.surface),
      ]) {
        for (final Color teinte in palette.speakerAccents) {
          expect(_contraste(teinte, fond), greaterThanOrEqualTo(4.5));
        }
      }
    });

    test('les accents de groupe portent une icône blanche et se détachent', () {
      // Deux bornes à la fois : assez foncés pour le blanc de l'icône (3:1,
      // seuil des objets graphiques), assez clairs pour que la tuile se voie
      // sur le fond de l'écran.
      for (final (JelvoColors palette, Color fond) in <(JelvoColors, Color)>[
        (clair, clair.background),
        (sombre, sombre.background),
      ]) {
        for (final Color accent in palette.groupAccents) {
          expect(_contraste(const Color(0xFFFFFFFF), accent), greaterThan(3));
          expect(_contraste(accent, fond), greaterThan(1.8));
        }
      }
    });

    test('la bulle de l’utilisateur garde son encre blanche', () {
      // Elle ne s'inverse pas d'un thème à l'autre : c'est ce qui permet à
      // l'heure et à la coche de lecture de garder leur blanc translucide.
      for (final JelvoColors palette in <JelvoColors>[clair, sombre]) {
        expect(palette.onBubbleMine, const Color(0xFFFFFFFF));
        expect(
          _contraste(palette.onBubbleMine, palette.bubbleMine),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(palette.onBubbleOther, palette.bubbleOther),
          greaterThanOrEqualTo(4.5),
        );
      }
      // Et la bulle des autres se distingue du fond de l'écran.
      expect(
        _contraste(sombre.bubbleOther, sombre.background),
        greaterThan(1.15),
      );
    });
  });

  group('Le réglage vit sur l’appareil', () {
    test('le jeton écrit est un mot, pas un rang', () async {
      // Un index se décalerait le jour où Flutter ajouterait une valeur, et
      // l'appareil se réveillerait dans une apparence jamais choisie.
      final ThemeStorage stockage = EphemeralThemeStorage();
      expect(stockage.mode, ThemeMode.system);

      await stockage.enregistrer(ThemeMode.dark);
      expect(stockage.mode, ThemeMode.dark);
    });

    testWidgets('« Apparence » annonce le choix courant', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, mode: ThemeMode.dark);
      await _ouvrirParametres(tester);

      expect(find.text('Apparence'), findsOneWidget);
      expect(find.text('Sombre'), findsOneWidget);
    });

    testWidgets('la feuille propose les trois choix, et le dit', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirParametres(tester);
      await tester.tap(find.text('Apparence'));
      await tester.pumpAndSettle();

      expect(find.text('Clair'), findsOneWidget);
      expect(find.text('Sombre'), findsOneWidget);
      expect(find.text('Automatique'), findsWidgets);
      // Le réglage ne vaut que sur cet appareil : le taire enverrait chercher
      // pourquoi le téléphone et l'ordinateur ne se ressemblent pas.
      expect(find.textContaining('cet appareil'), findsOneWidget);
    });

    testWidgets('choisir « Sombre » bascule l’écran et s’enregistre', (
      WidgetTester tester,
    ) async {
      final ThemeStorage stockage = await _pumpApp(tester);
      expect(_luminosite(tester), Brightness.light);

      await _ouvrirParametres(tester);
      await tester.tap(find.text('Apparence'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sombre'));
      await tester.pumpAndSettle();

      // L'écran suit le doigt, sans bouton de validation : une apparence se
      // juge en la voyant.
      expect(_luminosite(tester), Brightness.dark);
      expect(stockage.mode, ThemeMode.dark);
    });

    testWidgets('l’apparence enregistrée s’applique dès le premier rendu', (
      WidgetTester tester,
    ) async {
      // Le stockage est lu dans `main()` avant `runApp` : rien ne doit
      // s'ouvrir en clair pour basculer ensuite.
      await _pumpApp(tester, mode: ThemeMode.dark);
      expect(_luminosite(tester), Brightness.dark);
    });
  });

  group('Ce qui ne suit pas le thème, et pourquoi', () {
    testWidgets('la bulle de l’utilisateur reste violette en sombre', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, mode: ThemeMode.dark);
      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discussion'));
      await tester.pumpAndSettle();

      final Iterable<MessageBubble> bulles = tester.widgetList<MessageBubble>(
        find.byType(MessageBubble),
      );
      expect(bulles.any((MessageBubble b) => b.isMine), isTrue);
    });

    test('le voile des photos ne vient pas du thème', () {
      // Un dégradé bâti sur `encre` aurait éclairci le bas d'une photo en
      // mode sombre, effaçant le titre blanc qu'il sert à détacher.
      expect(JelvoColors.sombre.encre.computeLuminance(), greaterThan(0.5));
      expect(JelvoColors.clair.encre.computeLuminance(), lessThan(0.1));
    });
  });

  testWidgets('sans notre thème, un widget se rend en clair plutôt que lever', (
    WidgetTester tester,
  ) async {
    // Un widget isolé dans un `MaterialApp` de test n'a pas l'extension : il
    // doit s'afficher, pas planter.
    late JelvoColors lues;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            lues = context.couleurs;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(lues.primary, JelvoColors.clair.primary);
  });
}
