import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/app_config.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/notifications/push/push_service.dart';
import 'package:jelvo/features/notifications/widgets/notification_sheets.dart';
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

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<({FakePushService service, FakePushRepository depot})> _pumpApp(
  WidgetTester tester, {
  PushStatus statut = PushStatus.aAutoriser,
  bool autorisationAccordee = true,
  FakePushRepository? depot,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakePushService service = FakePushService(
    statut: statut,
    autorisationAccordee: autorisationAccordee,
  );
  final FakePushRepository push = depot ?? FakePushRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(service),
        pushRepositoryProvider.overrideWithValue(push),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (service: service, depot: push);
}

/// Accueil → Profil → Paramètres.
Future<void> _ouvrirParametres(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Paramètres'));
  await tester.pumpAndSettle();
}

/// La carte d'autorisation vit désormais derrière la ligne du haut : c'est
/// elle qui coupe tout, et le détail par famille est ailleurs.
Future<void> _ouvrirAutorisation(WidgetTester tester) async {
  await _ouvrirParametres(tester);
  await tester.tap(find.text('Notifications push'));
  await tester.pumpAndSettle();
}

/// Le détail d'une famille de types.
Future<void> _ouvrirFamille(WidgetTester tester, String libelle) async {
  await _ouvrirParametres(tester);
  await tester.tap(find.text(libelle));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Autorisation', () {
    testWidgets('un bouton propose d’activer, et l’abonnement part en base', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester);
      await _ouvrirAutorisation(tester);

      expect(find.text('Notifications désactivées'), findsOneWidget);

      await tester.tap(find.text('Activer les notifications'));
      await tester.pumpAndSettle();

      expect(faux.service.abonnements, 1);
      expect(
        faux.depot.lastRegisteredEndpoint,
        FakePushService.abonnementDemo.endpoint,
      );
      expect(find.text('Notifications actives'), findsOneWidget);
    });

    testWidgets('un refus est annoncé, avec la marche à suivre', (
      WidgetTester tester,
    ) async {
      // L'API ne permet plus de redemander après un refus : dire seulement
      // « refusé » laisserait dans une impasse.
      await _pumpApp(tester, autorisationAccordee: false);
      await _ouvrirAutorisation(tester);

      await tester.tap(find.text('Activer les notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications refusées'), findsOneWidget);
      expect(find.textContaining('réglages de votre navigateur'), findsWidgets);
    });

    testWidgets('désactiver retire l’abonnement des deux côtés', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester, statut: PushStatus.actif);
      await _ouvrirAutorisation(tester);

      await tester.tap(find.text('Désactiver sur cet appareil'));
      await tester.pumpAndSettle();

      expect(faux.service.desabonnements, 1);
      expect(
        faux.depot.lastForgottenEndpoint,
        FakePushService.abonnementDemo.endpoint,
      );
    });
  });

  group('iOS : l’installation est un préalable', () {
    testWidgets('la marche à suivre est écrite, pas un bouton', (
      WidgetTester tester,
    ) async {
      // iOS n'expose pas `beforeinstallprompt` : proposer l'installation
      // depuis la page est **impossible**, la consigne est tout ce qui reste.
      await _pumpApp(tester, statut: PushStatus.installationRequise);
      await _ouvrirAutorisation(tester);

      expect(find.text('Installez Jelvo pour les recevoir'), findsOneWidget);
      expect(find.textContaining('Sur l’écran d’accueil'), findsOneWidget);
      expect(
        find.textContaining('son propre stockage, distinct de Safari'),
        findsOneWidget,
      );
      // Aucun bouton d'activation : il n'aurait rien à activer.
      expect(find.text('Activer les notifications'), findsNothing);
    });

    testWidgets('une plateforme sans Web Push le dit simplement', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, statut: PushStatus.nonSupporte);
      await _ouvrirAutorisation(tester);

      expect(find.text('Notifications indisponibles ici'), findsOneWidget);
      expect(find.text('Activer les notifications'), findsNothing);
    });
  });

  group('Les huit types, rangés en trois familles', () {
    testWidgets('chaque famille annonce son état', (WidgetTester tester) async {
      await _pumpApp(tester);
      await _ouvrirParametres(tester);

      // Trois lignes, pas huit interrupteurs : le détail est à une touche.
      for (final String famille in const <String>[
        'Groupes et discussions',
        'Événements',
        'Tâches et rappels',
      ]) {
        expect(find.text(famille), findsOneWidget);
      }
      // Tout est activé par défaut — le modèle est un opt-out.
      expect(find.text('Activées'), findsNWidgets(3));
      // La ligne du haut, elle, annonce l'autorisation de l'appareil, qui
      // n'est pas encore donnée : elle ne dit donc pas « Activées ».
      expect(find.text('Notifications push'), findsOneWidget);
    });

    testWidgets('les huit types restent basculables un par un', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester);

      // Aucun type n'est fusionné : la famille n'est qu'un rangement.
      await _ouvrirFamille(tester, 'Groupes et discussions');
      for (final String libelle in const <String>[
        'Nouveaux messages',
        'Invitations à un groupe',
      ]) {
        expect(find.text(libelle), findsOneWidget);
      }

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(SwitchListTile, 'Nouveaux messages'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(faux.depot.lastToggledType, 'chat_message');
      expect(faux.depot.lastToggledValue, isFalse);
    });

    testWidgets('les huit types se retrouvent dans les trois familles', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      for (final (String famille, List<String> types)
          in const <(String, List<String>)>[
            (
              'Groupes et discussions',
              <String>['Nouveaux messages', 'Invitations à un groupe'],
            ),
            (
              'Événements',
              <String>[
                'Invitations à un événement',
                'Réponses aux événements',
                'Changements de date',
              ],
            ),
            (
              'Tâches et rappels',
              <String>['Tâches assignées', 'Réponses aux tâches', 'Rappels'],
            ),
          ]) {
        await _ouvrirFamille(tester, famille);
        for (final String type in types) {
          expect(find.text(type), findsOneWidget, reason: '$famille → $type');
        }
        Navigator.of(
          tester.element(find.byType(NotificationCategorySheet)),
        ).pop();
        await tester.pumpAndSettle();
        // Revenir aux paramètres : la feuille refermée laisse l'écran dessous,
        // mais `_ouvrirFamille` repart du profil.
        Navigator.of(tester.element(find.text('Paramètres').first)).pop();
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.text('Mon profil').first)).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('un échec d’écriture remet l’interrupteur', (
      WidgetTester tester,
    ) async {
      // L'interrupteur bouge avant l'aller-retour, sans quoi il paraît inerte.
      // La contrepartie est qu'il doit revenir si l'écriture échoue, sinon
      // l'écran affirme un réglage que la base n'a pas.
      await _pumpApp(tester, depot: FailingPushRepository());
      await _ouvrirFamille(tester, 'Tâches et rappels');

      final Finder interrupteur = find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Rappels'),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(interrupteur).value, isTrue);

      await tester.tap(interrupteur);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Switch>(interrupteur).value,
        isTrue,
        reason: 'l’interrupteur doit revenir si la base n’a pas suivi',
      );
      // L'échec est dit, et en français : aucun message technique brut ne doit
      // atteindre l'écran.
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Réenregistrement au démarrage', () {
    testWidgets('un abonnement existant est reposé sans geste', (
      WidgetTester tester,
    ) async {
      // Un abonnement peut être révoqué sans que personne n'en informe la
      // base : on le repose à chaque ouverture de session.
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester, statut: PushStatus.actif);

      expect(faux.depot.registrations, greaterThanOrEqualTo(1));
      expect(
        faux.depot.lastRegisteredEndpoint,
        FakePushService.abonnementDemo.endpoint,
      );
    });

    testWidgets('sans abonnement, rien n’est écrit', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester);

      expect(faux.depot.registrations, 0);
      expect(faux.depot.lastRegisteredEndpoint, isNull);
    });
  });

  group('L’écran Paramètres', () {
    testWidgets('trois cartes titrées, puis la déconnexion', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirParametres(tester);

      expect(find.text('Compte'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Autre'), findsOneWidget);
      expect(find.text('Déconnexion'), findsOneWidget);
    });

    testWidgets('aucune ligne ne mène nulle part', (WidgetTester tester) async {
      // Les lignes de la maquette que Jelvo ne sait pas tenir sont **absentes**
      // plutôt que grisées : une carte de trois lignes vraies vaut mieux
      // qu'une de six dont la moitié ment.
      await _pumpApp(tester);
      await _ouvrirParametres(tester);

      for (final String absente in const <String>[
        'Sécurité et confidentialité',
        'Sessions actives',
        'Apparence',
        'Langue',
        'Fuseau horaire',
        'Aide et support',
        'Préférences',
      ]) {
        expect(find.text(absente), findsNothing, reason: absente);
      }
    });

    testWidgets('changer de mot de passe est enfin atteignable', (
      WidgetTester tester,
    ) async {
      // L'écriture existait déjà ; on ne pouvait y arriver qu'en prétendant
      // avoir oublié son mot de passe.
      await _pumpApp(tester);
      await _ouvrirParametres(tester);

      await tester.tap(find.text('Changer de mot de passe'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Motdepasse2');
      await tester.tap(find.text('Changer le mot de passe'));
      await tester.pumpAndSettle();

      // L'écran se referme sur un succès, et le dit.
      expect(find.text('Mot de passe changé.'), findsOneWidget);
    });

    testWidgets('« À propos » annonce la version du pubspec', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirParametres(tester);

      expect(find.text('v${AppConfig.version}'), findsOneWidget);
      await tester.tap(find.text('À propos de Jelvo'));
      await tester.pumpAndSettle();

      expect(find.text('Version ${AppConfig.version}'), findsOneWidget);
    });
  });
}
