import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/onboarding_storage.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/onboarding/screens/welcome_screen.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<EphemeralOnboardingStorage> _pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  bool bienvenueVue = false,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: signedIn);
  addTearDown(auth.dispose);
  final EphemeralOnboardingStorage accueil = EphemeralOnboardingStorage(
    dejaVu: bienvenueVue,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        onboardingStorageProvider.overrideWithValue(accueil),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return accueil;
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Écran de bienvenue', () {
    testWidgets('une installation neuve s’ouvre dessus', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Bienvenue sur Jelvo'), findsOneWidget);
      expect(
        find.text(
          'L’app qui rassemble vos groupes, vos projets et vos proches.',
        ),
        findsOneWidget,
      );
      // Il précède la connexion, il ne la remplace pas.
      expect(find.text('Content de vous revoir'), findsNothing);
    });

    testWidgets('les trois arguments sont là, avec leurs pictogrammes', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Tous vos groupes au même endroit'), findsOneWidget);
      expect(find.text('Un agenda partagé et synchronisé'), findsOneWidget);
      expect(find.text('Des tâches claires et efficaces'), findsOneWidget);

      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });

    testWidgets('une seule page : ni « Passer », ni points de pagination', (
      WidgetTester tester,
    ) async {
      // Trois arguments tiennent sur un écran ; un carrousel ferait attendre
      // ce qui est déjà visible.
      await _pumpApp(tester);

      expect(find.text('Passer'), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('le titre ne porte aucun emoji', (WidgetTester tester) async {
      // Le projet n'embarque aucune police emoji : le 👋 de la maquette
      // s'afficherait en carré « tofu ».
      await _pumpApp(tester);

      final String titre = tester
          .widget<Text>(find.text('Bienvenue sur Jelvo'))
          .data!;
      expect(titre.runes.every((int r) => r < 0x1F000), isTrue);
    });

    testWidgets('la bande d’illustration garde sa hauteur', (
      WidgetTester tester,
    ) async {
      // Avec le fichier ou sans lui, la carte des arguments doit commencer au
      // même endroit — d'où une hauteur fixe et un `BoxFit.contain`.
      await _pumpApp(tester);

      final Finder bande = find.ancestor(
        of: find.byType(Image),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(bande.first).height, 240);
    });

    testWidgets('l’illustration est bien au dépôt, au format annoncé', (
      WidgetTester tester,
    ) async {
      // `errorBuilder` masque une image absente sans rien casser : sans ce
      // contrôle, un fichier supprimé ou renommé passerait la CI au vert et ne
      // se verrait qu'à l'écran.
      final ByteData octets = await rootBundle.load(
        'assets/illustrations/bienvenue.png',
      );

      // L'en-tête PNG plutôt qu'un décodage : `decodeImageFromList` demande un
      // vrai `await` que le temps simulé d'un test de widget ne lui donne pas,
      // et le test resterait suspendu. La signature, puis IHDR — largeur et
      // hauteur en gros-boutiste aux octets 16 et 20.
      final ByteData entete = octets.buffer.asByteData();
      expect(entete.getUint64(0), 0x89504E470D0A1A0A, reason: 'signature PNG');
      expect(entete.getUint32(16), 1200);
      expect(entete.getUint32(20), 800);
    });

    testWidgets('« Commencer » mène à la connexion', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.text('Content de vous revoir'), findsOneWidget);
      expect(find.text('Bienvenue sur Jelvo'), findsNothing);
    });
  });

  group('On ne le revoit pas', () {
    testWidgets('« Commencer » retient que l’écran a été vu', (
      WidgetTester tester,
    ) async {
      final EphemeralOnboardingStorage accueil = await _pumpApp(tester);
      expect(accueil.dejaVu, isFalse);

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(accueil.dejaVu, isTrue);
    });

    testWidgets('déjà vu, l’application s’ouvre sur la connexion', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, bienvenueVue: true);

      expect(find.text('Content de vous revoir'), findsOneWidget);
      expect(find.text('Bienvenue sur Jelvo'), findsNothing);
    });

    testWidgets('avec une session, il ne s’affiche jamais', (
      WidgetTester tester,
    ) async {
      // Même sur une mémoire vierge : quelqu'un de connecté n'a pas à se voir
      // présenter l'application.
      final EphemeralOnboardingStorage accueil = await _pumpApp(
        tester,
        signedIn: true,
      );

      expect(find.text('Bienvenue sur Jelvo'), findsNothing);
      expect(find.text('Groupes'), findsWidgets);
      // Une session ouverte vaut présentation faite : se déconnecter plus tard
      // ne doit pas ramener l'écran.
      expect(accueil.dejaVu, isTrue);
    });

    testWidgets('un lien d’invitation n’est jamais préempté', (
      WidgetTester tester,
    ) async {
      // Rediriger `/rejoindre/<jeton>` vers la présentation perdrait le jeton
      // en silence — la panne la plus pénible, parce qu'elle ne laisse aucune
      // trace.
      await _pumpApp(tester);

      final BuildContext context = tester.element(find.byType(WelcomeScreen));
      GoRouter.of(context).go('/rejoindre/jeton-abc');
      await tester.pumpAndSettle();

      expect(find.text('Bienvenue sur Jelvo'), findsNothing);
    });
  });
}
