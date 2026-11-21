import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/models/availability.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/models/profil_consultable.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/profile/widgets/profile_stats_card.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';
import 'package:jelvo/router/app_router.dart';
import 'package:jelvo/router/app_routes.dart';

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

/// Une ligne telle que `profil_consultable` la rend.
///
/// Les noms de clés sont **ceux de la fonction SQL**, et c'est le point du
/// test : si la fonction changeait de vocabulaire, les deux parseurs qu'elle
/// réutilise — `Profile.fromMap` et `Contact.fromRow` — cesseraient de la
/// lire, et c'est ici que cela se verrait.
Map<String, dynamic> _ligne({
  String id = 'u2',
  String pseudo = 'lea.marchand',
  String firstName = 'Léa',
  String lastName = 'Marchand',
  String? avatarUrl,
  String? bio = 'Toujours partante pour une rando.',
  int? jour = 14,
  int? mois = 7,
  bool cestMoi = false,
  String? statut = 'accepted',
  String? sens = 'sortant',
  bool favori = false,
  List<Map<String, dynamic>> groupes = const <Map<String, dynamic>>[],
  String? disponibilite = 'available',
}) => <String, dynamic>{
  'id': id,
  'pseudo': pseudo,
  'first_name': firstName,
  'last_name': lastName,
  'avatar_url': avatarUrl,
  'bio': bio,
  'anniversaire_jour': jour,
  'anniversaire_mois': mois,
  'cest_moi': cestMoi,
  'autre_id': id,
  'statut': statut,
  'sens': sens,
  'favori': favori,
  'groupes_communs': groupes.length,
  'groupes_partages': groupes,
  'disponibilite': disponibilite,
};

typedef _Decor = ({
  FakeProfileRepository profils,
  FakeContactRepository contacts,
});

/// Ouvre `/personnes/<id>` dans l'application complète.
///
/// La route est poussée par le routeur plutôt qu'atteinte par une touche :
/// les cinq points d'entrée sont éprouvés à part, et un étranger n'a par
/// définition aucune ligne dans le carnet d'où le toucher.
Future<_Decor> _ouvrir(
  WidgetTester tester, {
  Map<String, dynamic>? ligne,
  String id = 'u2',
  bool echecLecture = false,
  bool pousser = true,
}) async {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeProfileRepository profils = FakeProfileRepository();
  profils.echecLectureProfil = echecLecture;
  if (ligne != null) {
    profils.profilsConsultables[id] = ProfilConsultable.depuisLigne(ligne);
  }
  final FakeContactRepository contacts = FakeContactRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profils),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(contacts),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
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

  // `pousser: false` laisse l'application sur l'accueil : c'est ce qu'il faut
  // pour éprouver les points d'entrée, qui doivent y mener d'eux-mêmes.
  if (pousser) {
    ProviderScope.containerOf(
      tester.element(find.byType(JelvoApp)),
    ).read(routerProvider).push(AppRoutes.publicProfilePathFor(id));
    await tester.pumpAndSettle();
  }

  return (profils: profils, contacts: contacts);
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('La ligne de la base', () {
    test('les cinq champs publics se lisent', () {
      final ProfilConsultable p = ProfilConsultable.depuisLigne(_ligne());

      expect(p.profil.id, 'u2');
      expect(p.profil.displayName, 'Léa Marchand');
      expect(p.profil.pseudoHandle, '@lea.marchand');
      expect(p.profil.bio, 'Toujours partante pour une rando.');
      expect(p.profil.anniversaire?.jour, 14);
      expect(p.profil.anniversaire?.mois, 7);
    });

    test('l’avatar prédéfini arrive déjà composé', () {
      // La fonction SQL rend `coalesce('preset:' || avatar_preset,
      // avatar_url)` dans le champ `avatar_url`, comme les onze autres
      // lectures. C'est donc `avatarAAfficher` qui doit le ressortir tel quel,
      // sans que rien côté Dart n'ait à recomposer quoi que ce soit.
      final ProfilConsultable p = ProfilConsultable.depuisLigne(
        _ligne(avatarUrl: 'preset:p2_07'),
      );
      expect(p.profil.avatarAAfficher, 'preset:p2_07');
    });

    test('sans ligne `contacts`, il n’y a pas de relation du tout', () {
      final ProfilConsultable p = ProfilConsultable.depuisLigne(
        _ligne(statut: null, sens: null),
      );

      expect(p.relation, isNull);
      expect(p.estContact, isFalse);
      expect(p.demandeRecue, isFalse);
      expect(p.demandeEnvoyee, isFalse);
    });

    test('une demande reçue se distingue d’une demande envoyée', () {
      expect(
        ProfilConsultable.depuisLigne(
          _ligne(statut: 'pending', sens: 'entrant'),
        ).demandeRecue,
        isTrue,
      );
      expect(
        ProfilConsultable.depuisLigne(
          _ligne(statut: 'pending', sens: 'sortant'),
        ).demandeEnvoyee,
        isTrue,
      );
    });

    // **Le contrôle qui porte la consigne.** Le champ réservé aux contacts
    // arrive à `null`, et c'est la fonction SQL qui en décide : un appel
    // direct à PostgREST obtient le même `null`.
    test('réservé aux contacts : null reste null, et non « inconnu »', () {
      final ProfilConsultable p = ProfilConsultable.depuisLigne(
        _ligne(statut: null, sens: null, disponibilite: null),
      );

      // La nuance compte : `PeerAvailability.unknown` dirait « rien de
      // déclaré », ce qui est une information. L'absence dit « ce n'est pas
      // votre affaire », et l'écran n'affiche alors aucune pastille.
      expect(p.disponibilite, isNull);
    });

    test('une disponibilité déclarée se lit', () {
      expect(
        ProfilConsultable.depuisLigne(
          _ligne(disponibilite: 'unavailable'),
        ).disponibilite,
        PeerAvailability.unavailable,
      );
    });
  });

  group('L’écran', () {
    testWidgets('il montre les cinq champs publics', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne());

      expect(find.text('Léa Marchand'), findsOneWidget);
      expect(find.text('@lea.marchand'), findsOneWidget);
      expect(find.text('Toujours partante pour une rando.'), findsOneWidget);
      expect(find.text('Anniversaire'), findsOneWidget);
      expect(find.text('14 juillet'), findsOneWidget);
    });

    // **Contrôle négatif : jamais l'adresse e-mail.** Elle figure sur son
    // propre profil, où elle vient de la session. Ici elle n'est lisible
    // nulle part, et ce n'est pas un champ omis par l'écran : elle vit dans
    // `auth.users`, que `profil_consultable` ne lit pas.
    testWidgets('aucune adresse e-mail n’apparaît', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne());

      expect(find.textContaining('@exemple'), findsNothing);
      expect(find.textContaining('.test'), findsNothing);
      // Le seul « @ » de l'écran est celui du pseudo.
      expect(find.textContaining('@'), findsOneWidget);
    });

    testWidgets('les boutons d’un profil à soi n’y sont pas', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne());

      expect(find.text('Modifier'), findsNothing);
      expect(find.text('QR Code'), findsNothing);
      expect(find.text('Partager profil'), findsNothing);
    });

    testWidgets('une contact voit sa disponibilité', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne());

      expect(find.text('Disponible'), findsOneWidget);
    });

    // **Le contrôle négatif du retrait.** Les compteurs ne sont pas rendus
    // inertes, ils ne sont plus là — et pas davantage pour une contact, qui
    // voit pourtant tout le reste. Un chiffre qu'on ne peut pas ouvrir
    // n'apprend rien de plus que lui-même, et les listes de l'application sont
    // celles de l'utilisateur connecté.
    testWidgets('aucune statistique, même pour une contact', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne());

      expect(find.byType(ProfileStatsCard), findsNothing);
      expect(find.textContaining('statistiques'), findsNothing);
      expect(find.text('Groupes'), findsNothing);
      expect(find.text('Tâches terminées'), findsNothing);
    });

    testWidgets('un non-contact garde les champs publics', (
      WidgetTester tester,
    ) async {
      await _ouvrir(
        tester,
        ligne: _ligne(statut: null, sens: null, disponibilite: null),
      );

      // Les champs publics restent là : c'est la consigne.
      expect(find.text('Léa Marchand'), findsOneWidget);
      expect(find.text('14 juillet'), findsOneWidget);

      // Ce qui lui manque est la seule pastille, et **rien ne l'annonce** : la
      // phrase qui expliquait l'absence de la carte est partie avec elle.
      // Annoncer qu'une donnée est retenue en dirait plus sur la personne
      // consultée que son absence — et un contact qui n'a rien déclaré n'a pas
      // de pastille non plus.
      expect(find.text('Disponible'), findsNothing);
      expect(find.textContaining('réservé'), findsNothing);
    });

    testWidgets('« Inconnu » ne s’affiche pas comme une donnée', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne(disponibilite: 'unknown'));

      expect(find.text('Inconnu'), findsNothing);
      // Et c'est bien le profil d'une contact qui est à l'écran : ce n'est pas
      // la relation qui manque, c'est la valeur.
      expect(find.text('Épingler'), findsOneWidget);
    });

    testWidgets('un identifiant inconnu le dit', (WidgetTester tester) async {
      await _ouvrir(tester, id: 'fantome');

      expect(find.text('Profil introuvable'), findsOneWidget);
    });

    testWidgets('une lecture qui échoue le dit', (WidgetTester tester) async {
      await _ouvrir(tester, ligne: _ligne(), echecLecture: true);

      expect(find.text('Profil indisponible'), findsOneWidget);
    });
  });

  group('Les groupes en commun', () {
    testWidgets('ils se listent, et mènent au groupe', (
      WidgetTester tester,
    ) async {
      await _ouvrir(
        tester,
        ligne: _ligne(
          groupes: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'g1', 'nom': 'Famille Rousseau'},
            <String, dynamic>{'id': 'g2', 'nom': 'Voyage en Corse'},
          ],
        ),
      );

      expect(find.text('2 groupes en commun'), findsOneWidget);
      expect(find.text('Famille Rousseau'), findsOneWidget);
      expect(find.text('Voyage en Corse'), findsOneWidget);
    });

    // « Zéro se dit aussi », comme la pastille du carnet : on se connaît sans
    // rien organiser ensemble, et une carte absente se lirait comme un
    // chargement qui a échoué.
    testWidgets('zéro se dit', (WidgetTester tester) async {
      await _ouvrir(tester, ligne: _ligne());

      expect(find.text('0 groupe en commun'), findsOneWidget);
      expect(find.textContaining('rien ensemble'), findsOneWidget);
    });

    testWidgets('un seul groupe se dit au singulier', (
      WidgetTester tester,
    ) async {
      await _ouvrir(
        tester,
        ligne: _ligne(
          groupes: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'g1', 'nom': 'Famille Rousseau'},
          ],
        ),
      );

      expect(find.text('1 groupe en commun'), findsOneWidget);
    });
  });

  group('Les actions suivent la relation', () {
    testWidgets('un étranger : on peut l’ajouter', (WidgetTester tester) async {
      final _Decor decor = await _ouvrir(
        tester,
        ligne: _ligne(statut: null, sens: null, disponibilite: null),
      );

      expect(find.text('Retirer'), findsNothing);
      await tester.tap(find.text('Ajouter en contact'));
      await tester.pumpAndSettle();

      expect(decor.contacts.lastRequestedUserId, 'u2');
    });

    testWidgets('une demande reçue : accepter ou refuser', (
      WidgetTester tester,
    ) async {
      final _Decor decor = await _ouvrir(
        tester,
        ligne: _ligne(statut: 'pending', sens: 'entrant', disponibilite: null),
      );

      expect(find.text('Refuser'), findsOneWidget);
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();

      expect(decor.contacts.lastAcceptedUserId, 'u2');
    });

    testWidgets('une demande envoyée s’annule, et ne s’accepte pas', (
      WidgetTester tester,
    ) async {
      final _Decor decor = await _ouvrir(
        tester,
        ligne: _ligne(statut: 'pending', sens: 'sortant', disponibilite: null),
      );

      expect(find.text('Accepter'), findsNothing);
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      // `contact_status` ne connaît pas de `declined` : annuler supprime la
      // ligne, comme refuser.
      expect(decor.contacts.lastRemovedUserId, 'u2');
    });

    testWidgets('une contact s’épingle', (WidgetTester tester) async {
      final _Decor decor = await _ouvrir(tester, ligne: _ligne());

      await tester.tap(find.text('Épingler'));
      await tester.pumpAndSettle();

      expect(decor.contacts.lastFavoriteValue, isTrue);
    });

    testWidgets('déjà épinglée, le même geste la désépingle', (
      WidgetTester tester,
    ) async {
      final _Decor decor = await _ouvrir(tester, ligne: _ligne(favori: true));

      expect(find.text('Épinglé'), findsOneWidget);
      await tester.tap(find.text('Épinglé'));
      await tester.pumpAndSettle();

      expect(decor.contacts.lastFavoriteValue, isFalse);
    });

    // Contrôle négatif : le retrait se confirme, et **annuler n'écrit rien**.
    testWidgets('retirer se confirme', (WidgetTester tester) async {
      final _Decor decor = await _ouvrir(tester, ligne: _ligne());

      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(decor.contacts.lastRemovedUserId, isNull);

      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer').last);
      await tester.pumpAndSettle();
      expect(decor.contacts.lastRemovedUserId, 'u2');
    });

    testWidgets('son propre profil n’offre aucune action de relation', (
      WidgetTester tester,
    ) async {
      await _ouvrir(
        tester,
        ligne: _ligne(cestMoi: true, statut: null, sens: null),
      );

      expect(find.text('Ajouter en contact'), findsNothing);
      expect(find.text('Retirer'), findsNothing);
      // **Pas de statistiques ici non plus**, pas même sur son propre profil
      // ouvert par ce chemin : elles vivent sur « Mon profil », où chaque
      // chiffre ouvre la liste qu'il résume.
      expect(find.text('Mes statistiques'), findsNothing);

      await tester.tap(find.text('Mon profil'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      // Et elles y sont, elles.
      expect(find.text('Mes statistiques'), findsOneWidget);
    });
  });

  group('Les points d’entrée', () {
    testWidgets('le nom d’un contact, dans le carnet', (
      WidgetTester tester,
    ) async {
      final _Decor decor = await _ouvrir(
        tester,
        ligne: _ligne(),
        pousser: false,
      );
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Léa Marchand').first);
      await tester.pumpAndSettle();

      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('@lea.marchand'), findsOneWidget);
      // Le profil a bien été demandé pour cette personne.
      expect(decor.profils.profilsConsultables.containsKey('u2'), isTrue);
    });

    testWidgets('le nom d’un membre, dans un groupe', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne(), pousser: false);
      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Léa Marchand').last);
      await tester.pumpAndSettle();

      expect(find.text('@lea.marchand'), findsOneWidget);
      expect(find.text('Toujours partante pour une rando.'), findsOneWidget);
    });

    testWidgets('le chevron du carnet, lui, ouvre toujours la fiche', (
      WidgetTester tester,
    ) async {
      await _ouvrir(tester, ligne: _ligne(), pousser: false);
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();

      // Deux cibles, deux sens : la fiche agit sur le lien, le profil montre
      // la personne.
      expect(find.text('Retirer de mes contacts'), findsOneWidget);
    });
  });
}
