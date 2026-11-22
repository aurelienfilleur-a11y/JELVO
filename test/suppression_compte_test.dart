import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/features/signalements/providers/signalement_providers.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/language_storage.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/models/message.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_signalement_repository.dart';
import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _maintenant = DateTime(2026, 11, 21, 9);

Future<({FakeAuthRepository auth, FakeProfileRepository profil})> _pumpApp(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeProfileRepository profil = FakeProfileRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_maintenant)),
        // La langue est épinglée : ces tests affirment des phrases exactes.
        languageStorageProvider.overrideWithValue(
          EphemeralLanguageStorage(langue: const Locale('fr')),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profil),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        signalementRepositoryProvider.overrideWithValue(
          FakeSignalementRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (auth: auth, profil: profil);
}

/// Accueil → Profil → Paramètres → Supprimer mon compte.
Future<void> _ouvrirSuppression(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Paramètres'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Supprimer mon compte'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Supprimer mon compte'));
  await tester.pumpAndSettle();
}

Future<void> _taperMotDePasse(WidgetTester tester, String valeur) async {
  await tester.enterText(find.byType(TextField).last, valeur);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('Le chemin depuis les paramètres', () {
    testWidgets('la ligne existe et ouvre l’écran, sans rien supprimer', (
      WidgetTester tester,
    ) async {
      final ({FakeAuthRepository auth, FakeProfileRepository profil}) decor =
          await _pumpApp(tester);

      await _ouvrirSuppression(tester);

      // L'écran est ouvert…
      expect(find.text('Supprimer définitivement'), findsOneWidget);
      // …et **rien n'a été supprimé** : la ligne ouvre, elle n'agit pas.
      expect(decor.profil.suppressionDemandee, isFalse);
      expect(decor.auth.isSignedIn, isTrue);
    });

    testWidgets('l’écran dit ce qui disparaît et ce qui reste', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirSuppression(tester);

      expect(find.text('Ce qui disparaît'), findsOneWidget);
      expect(find.text('Ce qui reste'), findsOneWidget);

      // Les deux moitiés de la règle, en toutes lettres.
      expect(
        find.textContaining('votre adresse e-mail'),
        findsOneWidget,
        reason: 'ce qui identifie doit être annoncé',
      );
      expect(
        find.textContaining('Compte supprimé'),
        findsOneWidget,
        reason: 'la signature des messages qui restent doit être annoncée',
      );
      expect(
        find.textContaining('messages vocaux'),
        findsOneWidget,
        reason: 'les vocaux partent, et cela doit se dire avant',
      );
      expect(
        find.textContaining('photos et les vidéos'),
        findsOneWidget,
        reason: 'les photos restent, et cela doit se dire aussi',
      );

      // Le caractère définitif, et la réinscription possible.
      // « définitive » seul attraperait aussi le libellé du bouton.
      expect(find.textContaining('ne peut pas être annulée'), findsOneWidget);
      expect(find.textContaining('réinscrire'), findsOneWidget);
    });
  });

  group('La confirmation', () {
    testWidgets('sans mot de passe, le bouton n’agit pas', (
      WidgetTester tester,
    ) async {
      final ({FakeAuthRepository auth, FakeProfileRepository profil}) decor =
          await _pumpApp(tester);
      await _ouvrirSuppression(tester);

      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      expect(decor.profil.suppressionDemandee, isFalse);
      expect(decor.auth.isSignedIn, isTrue);
    });

    testWidgets('un mot de passe faux le dit, et ne supprime rien', (
      WidgetTester tester,
    ) async {
      final ({FakeAuthRepository auth, FakeProfileRepository profil}) decor =
          await _pumpApp(tester);
      decor.auth.motDePasseValide = 'Secret123';
      await _ouvrirSuppression(tester);

      await _taperMotDePasse(tester, 'PasLeBon1');
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      // **Le contrôle qui compte** : la vérification n'est pas décorative.
      expect(decor.profil.suppressionDemandee, isFalse);
      expect(decor.auth.isSignedIn, isTrue);
    });

    testWidgets('le bon mot de passe supprime et referme la session', (
      WidgetTester tester,
    ) async {
      final ({FakeAuthRepository auth, FakeProfileRepository profil}) decor =
          await _pumpApp(tester);
      decor.auth.motDePasseValide = 'Secret123';
      await _ouvrirSuppression(tester);

      await _taperMotDePasse(tester, 'Secret123');
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      expect(decor.profil.suppressionDemandee, isTrue);
      expect(
        decor.auth.isSignedIn,
        isFalse,
        reason:
            'la session doit être refermée : la garde du routeur emmène '
            'alors vers la connexion d’elle-même',
      );
    });

    testWidgets('un refus de la base reste sur l’écran, session intacte', (
      WidgetTester tester,
    ) async {
      final ({FakeAuthRepository auth, FakeProfileRepository profil}) decor =
          await _pumpApp(tester);
      decor.auth.motDePasseValide = 'Secret123';
      // texte-en-dur-autorise: mot d'état de la fonction SQL, jamais affiché.
      decor.profil.etatSuppression = 'introuvable';
      await _ouvrirSuppression(tester);

      await _taperMotDePasse(tester, 'Secret123');
      await tester.tap(find.text('Supprimer définitivement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('n’a pas abouti'), findsOneWidget);
      expect(
        decor.auth.isSignedIn,
        isTrue,
        reason:
            'refermer la session sur un échec donnerait à croire que le '
            'compte est parti',
      );
    });
  });

  group('Ce que les autres voient', () {
    testWidgets('ses messages restent, signés « Compte supprimé »', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = FakeChatRepository(
        messages: <Message>[
          Message(
            id: 'm1',
            groupId: 'g1',
            senderId: 'parti',
            createdAt: _maintenant.subtract(const Duration(minutes: 5)),
            content: 'On fait un barbecue ?',
            senderSupprime: true,
          ),
        ],
      );

      await _pumpAppAvecChat(tester, chat);
      await _ouvrirConversation(tester);

      expect(
        find.text('On fait un barbecue ?'),
        findsOneWidget,
        reason: 'le message ne disparaît pas avec le compte',
      );
      expect(find.text('Compte supprimé'), findsOneWidget);
      expect(
        find.text('Membre'),
        findsNothing,
        reason: 'le repli générique mentirait sur ce qui s’est passé',
      );
    });

    testWidgets('son nom n’ouvre plus de profil', (WidgetTester tester) async {
      final FakeChatRepository chat = FakeChatRepository(
        messages: <Message>[
          Message(
            id: 'm1',
            groupId: 'g1',
            senderId: 'parti',
            createdAt: _maintenant.subtract(const Duration(minutes: 5)),
            content: 'On fait un barbecue ?',
            senderSupprime: true,
          ),
        ],
      );

      await _pumpAppAvecChat(tester, chat);
      await _ouvrirConversation(tester);

      await tester.tap(find.text('Compte supprimé'));
      await tester.pumpAndSettle();

      // On est resté dans la conversation : `profil_consultable` ne rend plus
      // de ligne, et le geste n'aurait mené qu'à « introuvable ».
      expect(find.text('On fait un barbecue ?'), findsOneWidget);
    });
  });
}

Future<void> _pumpAppAvecChat(
  WidgetTester tester,
  FakeChatRepository chat,
) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_maintenant)),
        languageStorageProvider.overrideWithValue(
          EphemeralLanguageStorage(langue: const Locale('fr')),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        signalementRepositoryProvider.overrideWithValue(
          FakeSignalementRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ouvrirConversation(WidgetTester tester) async {
  await tester.tap(find.text('Groupes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Famille Rousseau'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Discussion'));
  await tester.pumpAndSettle();
}
