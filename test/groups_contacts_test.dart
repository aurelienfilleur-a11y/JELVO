import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/contacts/widgets/qr_support.dart';
import 'package:jelvo/features/groups/models/group_invite.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/groups/screens/join_group_screen.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_group_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

/// Lance l'application complète avec les quatre dépôts simulés.
Future<({FakeGroupRepository groups, FakeContactRepository contacts})> _pumpApp(
  WidgetTester tester, {
  FakeGroupRepository? groupRepository,
  FakeContactRepository? contactRepository,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeGroupRepository groups = groupRepository ?? FakeGroupRepository();
  final FakeContactRepository contacts =
      contactRepository ?? FakeContactRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(groups),
        contactRepositoryProvider.overrideWithValue(contacts),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (groups: groups, contacts: contacts);
}

/// Monte la seule page publique d'un lien, sans passer par la garde du routeur.
///
/// L'écran n'est atteignable que par une URL ; un routeur minimal évite de
/// dupliquer tout le graphe de navigation pour l'éprouver.
Future<void> _pumpJoinScreen(
  WidgetTester tester, {
  required FakeGroupRepository groups,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: signedIn);
  addTearDown(auth.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/rejoindre/jeton-test',
    routes: <RouteBase>[
      GoRoute(
        path: '/rejoindre/:jeton',
        builder: (BuildContext context, GoRouterState state) =>
            JoinGroupScreen(token: state.pathParameters['jeton'] ?? ''),
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('accueil')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(groups),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Groupes', () {
    testWidgets('la liste affiche les groupes de l’utilisateur', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();

      expect(find.text('Famille Rousseau'), findsOneWidget);
      expect(find.text('Vacances en Corse'), findsOneWidget);
      expect(find.text('3 membres'), findsOneWidget);
    });

    testWidgets('un carnet vide propose de créer un groupe', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        groupRepository: FakeGroupRepository(groups: const []),
      );

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun groupe pour le moment'), findsOneWidget);
      expect(find.text('Créer un groupe'), findsWidgets);
    });

    testWidgets('ouvrir un groupe affiche ses membres', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      expect(find.text('Membres'), findsOneWidget);
      expect(find.text('Léa Marchand'), findsOneWidget);
      expect(find.text('Camille Rousseau (vous)'), findsOneWidget);
      // L'utilisateur est admin de ce groupe : la modification lui est ouverte.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('un nom vide bloque la création', (WidgetTester tester) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      // Le « + » central de la barre porte la même icône : on vise le bouton
      // d'en-tête par son infobulle.
      await tester.tap(find.byTooltip('Nouveau groupe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer le groupe'));
      await tester.pump();

      expect(find.text('Donnez un nom à votre groupe.'), findsOneWidget);
      expect(fakes.groups.lastDeletedGroupId, isNull);
    });

    testWidgets('créer un groupe mène à son écran', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nouveau groupe'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Coloc Bastille');
      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(fakes.groups.lastCreatedName, 'Coloc Bastille');
      // L'écran du groupe remplace le formulaire, qui ne doit pas se rouvrir
      // par un retour arrière.
      expect(find.text('Créer le groupe'), findsNothing);
      expect(find.text('Membres'), findsOneWidget);
    });

    testWidgets('quitter un groupe passe par une confirmation', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter le groupe').last);
      await tester.pumpAndSettle();

      // Tant que la confirmation n'est pas donnée, rien n'est envoyé.
      expect(fakes.groups.lastLeftGroupId, isNull);

      await tester.tap(find.text('Quitter').last);
      await tester.pumpAndSettle();

      expect(fakes.groups.lastLeftGroupId, 'g1');
    });
  });

  group('Invitation par lien', () {
    testWidgets('un lien valide présente le groupe et permet de rejoindre', (
      WidgetTester tester,
    ) async {
      final FakeGroupRepository groups = FakeGroupRepository();
      await _pumpJoinScreen(tester, groups: groups);

      expect(find.text('Vacances en Corse'), findsOneWidget);
      expect(find.text('4 membres'), findsOneWidget);

      await tester.tap(find.text('Rejoindre le groupe'));
      await tester.pumpAndSettle();

      expect(groups.lastJoinedToken, 'jeton-test');
    });

    testWidgets('un lien expiré est refusé avec un message en français', (
      WidgetTester tester,
    ) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(previewStatus: InviteLinkStatus.expire),
      );

      expect(find.text('Lien inutilisable'), findsOneWidget);
      expect(
        find.textContaining('Ce lien d’invitation a expiré'),
        findsOneWidget,
      );
      expect(find.text('Rejoindre le groupe'), findsNothing);
    });

    testWidgets('un lien révoqué est refusé', (WidgetTester tester) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(previewStatus: InviteLinkStatus.revoque),
      );

      expect(
        find.textContaining('a été révoqué par le groupe'),
        findsOneWidget,
      );
    });

    testWidgets('sans session, le lien mène à l’inscription', (
      WidgetTester tester,
    ) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(),
        signedIn: false,
      );

      expect(find.text('Créer un compte pour rejoindre'), findsOneWidget);
      expect(find.text('J\'ai déjà un compte'), findsOneWidget);
      expect(find.text('Rejoindre le groupe'), findsNothing);
    });

    testWidgets('déjà membre, le message le dit sans erreur', (
      WidgetTester tester,
    ) async {
      final FakeGroupRepository groups = FakeGroupRepository(
        joinOutcome: JoinOutcome.dejaMembre,
      );
      await _pumpJoinScreen(tester, groups: groups);

      await tester.tap(find.text('Rejoindre le groupe'));
      await tester.pumpAndSettle();

      expect(groups.lastJoinedToken, 'jeton-test');
    });
  });

  group('Contacts', () {
    testWidgets('les favoris sont épinglés en tête du carnet', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      final Offset lea = tester.getTopLeft(find.text('Léa Marchand'));
      final Offset yanis = tester.getTopLeft(find.text('Yanis Bertrand'));
      expect(lea.dy, lessThan(yanis.dy));
    });

    testWidgets('une demande reçue peut être acceptée', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      expect(find.text('Demandes reçues'), findsOneWidget);
      expect(find.text('Noah Delacroix'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastAcceptedUserId, 'u4');
    });

    testWidgets('une demande reçue peut être refusée', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastDeclinedUserId, 'u4');
    });

    testWidgets('la recherche par pseudo propose d’ajouter la personne', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_add_alt_rounded).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sarah');
      // Laisse passer le débounce de la recherche.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Sarah Nguyen'), findsOneWidget);

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastRequestedUserId, 'u5');
      expect(find.text('Demande envoyée.'), findsOneWidget);
    });
  });

  group('QR code', () {
    test('le contenu encodé se relit', () {
      expect(
        QrContact.encode('Camille.Rousseau'),
        'jelvo:contact/camille.rousseau',
      );
      expect(
        QrContact.decode('jelvo:contact/camille.rousseau'),
        'camille.rousseau',
      );
    });

    test('un pseudo nu reste accepté', () {
      expect(QrContact.decode('camille.rousseau'), 'camille.rousseau');
    });

    test('un QR étranger est rejeté', () {
      expect(QrContact.decode('https://example.test/produit/42'), isNull);
      expect(QrContact.decode('ab'), isNull);
      expect(QrContact.decode(null), isNull);
    });
  });
}
