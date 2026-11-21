import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/theme/jelvo_colors.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/models/agenda_entry.dart';
import 'package:jelvo/l10n/app_localizations.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/models/contact_birthday.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/models/app_notification.dart';
import 'package:jelvo/features/notifications/models/notification_category.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/notifications/repository/push_repository.dart';
import 'package:jelvo/features/profile/models/anniversaire.dart';
import 'package:jelvo/features/profile/models/profile.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/profile/widgets/anniversaire_sheet.dart';
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
import 'package:jelvo/data/language_storage.dart';

/// Lundi 3 août 2026, comme les autres tests de calendrier.
final DateTime _testNow = DateTime(2026, 8, 3, 9);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  // =========================================================================
  // La règle, sans widget
  // =========================================================================
  group('Le jour fêté', () {
    // **La table de cas.** Elle est volontairement la même qu'en SQL : la
    // règle existe des deux côtés — la base pour l'envoi, l'application pour
    // le calendrier, qui doit la calculer pour une année arbitraire sans
    // demander une ligne par année. Le dernier test du groupe épingle cette
    // coïncidence, qui autrement ne protesterait pas en se défaisant.
    const Anniversaire vingtNeufFevrier = Anniversaire(jour: 29, mois: 2);

    test('le 29 février tombe le 29 une année bissextile', () {
      expect(vingtNeufFevrier.jourFete(2024), DateTime(2024, 2, 29));
    });

    test('et le 28 une année ordinaire — jamais le 1er mars', () {
      // Le reporter au 1er mars le ferait changer de mois, et « mon
      // anniversaire est en février » cesserait d'être vrai. Une seule règle
      // couvre les deux cas : le dernier jour du mois.
      expect(vingtNeufFevrier.jourFete(2025), DateTime(2025, 2, 28));
      expect(vingtNeufFevrier.jourFete(2026), DateTime(2026, 2, 28));
      expect(vingtNeufFevrier.jourFete(2100), DateTime(2100, 2, 28));
    });

    test('2000 est bissextile, 1900 ne l’est pas', () {
      // Le cas que les règles naïves ratent. Dart le sait ; on le vérifie
      // plutôt que de le supposer.
      expect(vingtNeufFevrier.jourFete(2000), DateTime(2000, 2, 29));
      expect(vingtNeufFevrier.jourFete(1900), DateTime(1900, 2, 28));
    });

    test('une date ordinaire n’est jamais ramenée', () {
      expect(
        const Anniversaire(jour: 31, mois: 1).jourFete(2025),
        DateTime(2025, 1, 31),
      );
      expect(
        const Anniversaire(jour: 30, mois: 4).jourFete(2025),
        DateTime(2025, 4, 30),
      );
      // Décembre : le calcul passe par « le jour 0 du mois suivant », qui
      // franchit l'année.
      expect(
        const Anniversaire(jour: 31, mois: 12).jourFete(2025),
        DateTime(2025, 12, 31),
      );
    });

    test('seFeteLe suit la même règle', () {
      expect(vingtNeufFevrier.seFeteLe(DateTime(2025, 2, 28)), isTrue);
      expect(vingtNeufFevrier.seFeteLe(DateTime(2025, 3, 1)), isFalse);
      expect(vingtNeufFevrier.seFeteLe(DateTime(2024, 2, 28)), isFalse);
      expect(vingtNeufFevrier.seFeteLe(DateTime(2024, 2, 29)), isTrue);
    });

    test('la table de cas est la même en SQL', () {
      // La règle vit à deux endroits et ne peut pas vivre à un seul : la base
      // en a besoin pour l'envoi du jour, l'application pour une année
      // quelconque. Ce qui protège de la divergence, c'est que les deux
      // soient éprouvées sur **les mêmes dates** — et c'est cela qu'on
      // épingle ici, faute de pouvoir appeler le SQL depuis un test Dart.
      final String fumee = File(
        'supabase/verification/fumee.sql',
      ).readAsStringSync();
      expect(
        fumee,
        contains("date '2024-02-29'"),
        reason: 'le cas bissextile doit être éprouvé côté SQL aussi',
      );
      expect(
        fumee,
        contains("date '2025-02-28'"),
        reason: 'le cas ordinaire doit être éprouvé côté SQL aussi',
      );
    });
  });

  group('Ce qui est une date et ce qui n’en est pas', () {
    test('le 29 février est valide, le 30 non', () {
      expect(Anniversaire.estValide(29, 2), isTrue);
      expect(Anniversaire.estValide(30, 2), isFalse);
    });

    test('les bornes de mois et de jour', () {
      expect(Anniversaire.estValide(31, 4), isFalse);
      expect(Anniversaire.estValide(1, 0), isFalse);
      expect(Anniversaire.estValide(1, 13), isFalse);
      expect(Anniversaire.estValide(0, 1), isFalse);
    });

    test('une moitié de date vaut une absence', () {
      // La base refuse un jour sans mois ; côté lecture, une moitié ne doit
      // pas s'afficher à moitié.
      expect(Anniversaire.depuisLigne(12, null), isNull);
      expect(Anniversaire.depuisLigne(null, 3), isNull);
      expect(Anniversaire.depuisLigne(null, null), isNull);
      expect(
        Anniversaire.depuisLigne(12, 3),
        const Anniversaire(jour: 12, mois: 3),
      );
    });

    test('une paire impossible lue en base est écartée', () {
      // Ne doit pas arriver — la contrainte la refuse — mais une ligne
      // abîmée vaut mieux écartée qu'affichée.
      expect(Anniversaire.depuisLigne(30, 2), isNull);
    });

    test('le libellé ne porte pas d’année, et ne glisse pas', () async {
      // Le libellé formate une date : il lui faut donc la langue, comme à
      // tout `AppDates`. C'est le français qui est éprouvé ici — les mois des
      // trois autres langues sont ceux d'`intl`, pas les nôtres.
      final AppTexts t = await _textes();
      expect(const Anniversaire(jour: 12, mois: 3).libelle(t), '12 mars');
      // Le piège : construire la `DateTime` du libellé sur une année non
      // bissextile ramènerait le 29 février au 1er mars.
      expect(const Anniversaire(jour: 29, mois: 2).libelle(t), '29 février');
      expect(const Anniversaire(jour: 1, mois: 1).libelle(t), '1 janvier');
    });
  });

  // =========================================================================
  // La notification
  // =========================================================================
  group('La notification d’anniversaire', () {
    test('elle compte pour l’onglet Calendrier', () {
      // C'est là que l'anniversaire se regarde. Le ranger dans Contacts
      // enverrait au carnet, qui n'en montre pas la liste.
      expect(NotificationType.birthday.navIndex, 2);
    });

    test('elle ne propose aucune action', () async {
      // Jelvo n'a pas d'écran de profil d'autrui : un bouton mènerait
      // ailleurs que là où il annonce.
      const AppNotification notif = AppNotification(
        id: 'n1',
        type: NotificationType.birthday,
        payload: <String, dynamic>{'name': 'Léa Marchand'},
      );
      final AppTexts t = await _textes();
      expect(notif.actionLabel(t), isNull);
      expect(notif.title(t), 'Léa Marchand');
      expect(notif.message(t), contains('anniversaire'));
    });

    test('un type inconnu ne devient pas un anniversaire', () {
      expect(NotificationType.fromDb('birthday'), NotificationType.birthday);
      expect(NotificationType.fromDb('birthdays'), NotificationType.autre);
    });

    test('les neuf types atteignent l’écran, celui-ci compris', () async {
      // Le décor du faux dépôt recopie `types_de_notification()` : un type
      // oublié là n'atteindrait jamais l'écran, et la famille se rendrait
      // sans lui. Le compte est écrit à la main pour que l'ajout d'un type
      // oblige à passer ici.
      final FakePushRepository push = FakePushRepository();
      final List<NotificationPreference> prefs = await push.fetchPreferences();
      expect(prefs, hasLength(9));
      expect(
        prefs.map((NotificationPreference p) => p.type),
        contains('birthday'),
      );
      // Et il est bien rangé : la famille « Événements » le couvre, donc il
      // ne tombe pas dans le filet « Autres ».
      expect(
        NotificationCategory.evenements
            .preferencesDe(prefs)
            .map((NotificationPreference p) => p.type),
        contains('birthday'),
      );
      expect(NotificationCategory.autres.preferencesDe(prefs), isEmpty);
    });

    test('la famille « Événements » le porte, et aucune ne l’oublie', () {
      expect(
        NotificationCategory.evenements.types,
        contains('birthday'),
        reason:
            'les familles suivent l’endroit où la chose se regarde, et un '
            'anniversaire est une ligne du calendrier',
      );
      // Le contrôle qui compte vraiment : aucun type ne doit tomber dans
      // « Autres » par oubli — cette famille est un filet, pas une adresse.
      final Set<String> ranges = <String>{
        for (final NotificationCategory c in NotificationCategory.values)
          ...c.types,
      };
      expect(ranges, contains('birthday'));
    });
  });

  // =========================================================================
  // La saisie, sur le profil
  // =========================================================================
  group('La ligne « Anniversaire » du profil', () {
    testWidgets('vide, elle invite et n’affiche pas de fausse date', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      expect(find.text('Anniversaire'), findsOneWidget);
      expect(
        find.text('Ajoutez le jour et le mois, sans l’année'),
        findsOneWidget,
      );
    });

    testWidgets('renseignée, elle affiche la date sans année', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(
        tester,
        profile: _profil(const Anniversaire(jour: 29, mois: 2)),
      );

      expect(find.text('29 février'), findsOneWidget);
      // Pas d'année, nulle part : c'est tout l'objet du choix de stockage.
      expect(find.textContaining(RegExp(r'\b(19|20)\d{2}\b')), findsNothing);
    });

    testWidgets('elle ouvre la feuille, qui dit ne pas demander l’année', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();

      expect(find.byType(AnniversaireSheet), findsOneWidget);
      expect(find.textContaining('ne demande pas votre année'), findsOneWidget);
      // `showDatePicker` aurait exigé une année : la feuille n'en porte
      // aucune trace.
      expect(find.byType(CalendarDatePicker), findsNothing);
    });

    testWidgets('enregistrer écrit le jour et le mois', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _ouvrirProfil(tester);

      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();

      await _choisir(tester, 'Jour', '14');
      await _choisir(tester, 'Mois', 'mars');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        profils.dernierAnniversaire,
        const Anniversaire(jour: 14, mois: 3),
      );
    });

    testWidgets('sans valeur complète, « Enregistrer » n’écrit rien', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _ouvrirProfil(tester);

      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();

      // Rien n'est présélectionné : une moitié de date ne doit pas pouvoir
      // partir, et la base la refuserait de toute façon.
      await _choisir(tester, 'Jour', '14');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(profils.anniversaireEcrit, isFalse);
    });

    testWidgets('« Retirer » n’apparaît que s’il y a quelque chose à retirer', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);
      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer'), findsNothing);
    });

    testWidgets('« Retirer » efface vraiment la date', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _ouvrirProfil(
        tester,
        profile: _profil(const Anniversaire(jour: 14, mois: 3)),
      );

      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      // Le drapeau distingue « appelé avec null » d'un simple oubli : sans
      // lui, une inertie passerait pour un effacement.
      expect(profils.anniversaireEcrit, isTrue);
      expect(profils.dernierAnniversaire, isNull);
    });

    testWidgets('un échec reste dans la feuille, avec son message', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester, echecEcriture: true);

      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();
      await _choisir(tester, 'Jour', '14');
      await _choisir(tester, 'Mois', 'mars');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Refermer ferait disparaître l'erreur en même temps que la saisie, et
      // laisserait croire à un enregistrement.
      expect(find.byType(AnniversaireSheet), findsOneWidget);
      expect(
        find.text(
          'Connexion indisponible. Vérifiez votre accès à Internet, puis réessayez.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('le 29 février annonce ce qu’il fera les autres années', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);
      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();

      await _choisir(tester, 'Mois', 'février');
      await _choisir(tester, 'Jour', '29');

      expect(find.textContaining('28 février'), findsOneWidget);
    });

    testWidgets('changer de mois ramène un jour devenu impossible', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _ouvrirProfil(tester);
      await tester.tap(find.text('Anniversaire'));
      await tester.pumpAndSettle();

      await _choisir(tester, 'Mois', 'janvier');
      await _choisir(tester, 'Jour', '31');
      // 31 avril n'existe pas : le jour est ramené au 30 plutôt que vidé.
      await _choisir(tester, 'Mois', 'avril');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        profils.dernierAnniversaire,
        const Anniversaire(jour: 30, mois: 4),
      );
    });
  });

  // =========================================================================
  // Le calendrier
  // =========================================================================
  group('L’anniversaire au calendrier', () {
    test('il apparaît le jour dit, sur toute la journée', () async {
      final ProviderContainer c = await _conteneur(<ContactBirthday>[
        const ContactBirthday(
          contactId: 'u2',
          anniversaire: Anniversaire(jour: 3, mois: 8),
          firstName: 'Léa',
          lastName: 'Marchand',
        ),
      ]);

      final List<AgendaEntry> jour = c.read(
        dayAgendaProvider((DateTime(2026, 8, 3), await _textes())),
      );
      final AgendaEntry ligne = jour.firstWhere(
        (AgendaEntry e) => e.kind == AgendaEntryKind.birthday,
      );

      expect(ligne.title, contains('Léa Marchand'));
      expect(ligne.start, DateTime(2026, 8, 3));
      expect(ligne.end, DateTime(2026, 8, 3, 23, 59));
      // La gouttière dirait « 00:00 », ce qui serait faux.
      expect(ligne.timeLabel, 'Journée');
      // Rien à ouvrir : il n'y a pas d'écran de profil d'autrui.
      expect(ligne.isOpenable, isFalse);
    });

    test('et nulle part ailleurs', () async {
      final ProviderContainer c = await _conteneur(<ContactBirthday>[
        const ContactBirthday(
          contactId: 'u2',
          anniversaire: Anniversaire(jour: 3, mois: 8),
          firstName: 'Léa',
        ),
      ]);

      expect(
        c
            .read(dayAgendaProvider((DateTime(2026, 8, 4), await _textes())))
            .where((AgendaEntry e) => e.kind == AgendaEntryKind.birthday),
        isEmpty,
      );
    });

    test('le 29 février se fête le 28 en année ordinaire', () async {
      final ProviderContainer c = await _conteneur(<ContactBirthday>[
        const ContactBirthday(
          contactId: 'u2',
          anniversaire: Anniversaire(jour: 29, mois: 2),
          firstName: 'Noé',
        ),
      ]);

      final AppTexts t = await _textes();
      bool aUnAnniversaire(DateTime jour) => c
          .read(dayAgendaProvider((jour, t)))
          .any((AgendaEntry e) => e.kind == AgendaEntryKind.birthday);

      // 2026 n'est pas bissextile.
      expect(aUnAnniversaire(DateTime(2026, 2, 28)), isTrue);
      expect(aUnAnniversaire(DateTime(2026, 3, 1)), isFalse);
      // 2028 l'est : le vrai jour revient.
      expect(aUnAnniversaire(DateTime(2028, 2, 29)), isTrue);
      expect(aUnAnniversaire(DateTime(2028, 2, 28)), isFalse);
    });

    test('personne sans date, aucune ligne — le cas par défaut', () async {
      // Le faux dépôt ne rend rien, comme la fonction SQL, qui filtre les
      // profils sans date avant de renvoyer quoi que ce soit.
      final ProviderContainer c = await _conteneur(const <ContactBirthday>[]);
      expect(
        c
            .read(dayAgendaProvider((DateTime(2026, 8, 3), await _textes())))
            .where((AgendaEntry e) => e.kind == AgendaEntryKind.birthday),
        isEmpty,
      );
    });

    test('la teinte est l’ambre de la palette, pas une couleur nouvelle', () {
      // Le code couleur du calendrier gagne une quatrième entrée sans qu'une
      // teinte ait été inventée : `warning` existait et n'y servait pas.
      final AgendaEntry ligne = AgendaEntry(
        id: 'a',
        kind: AgendaEntryKind.birthday,
        title: 'x',
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 3, 23, 59),
        accent: AgendaAccent.anniversaire,
      );
      expect(ligne.accentColor(JelvoColors.clair), JelvoColors.clair.warning);
      expect(ligne.accentColor(JelvoColors.sombre), JelvoColors.sombre.warning);
    });
  });
}

// ===========================================================================
// Harnais
// ===========================================================================

Profile _profil(Anniversaire? anniversaire) => Profile(
  id: 'utilisateur-test',
  pseudo: 'camille.rousseau',
  firstName: 'Camille',
  lastName: 'Rousseau',
  bio: 'Toujours partante pour une rando.',
  anniversaire: anniversaire,
);

/// Conteneur pour les lectures du calendrier, sans widget : l'agrégation vit
/// dans le provider, et c'est elle qu'on éprouve.
///
/// **Il attend que la lecture ait répondu.** Sans cet `await`,
/// `contactBirthdaysProvider` serait encore en vol, son `.value` nul
/// retomberait sur la liste vide de repli, et le test passerait pour de
/// mauvaises raisons — en ne voyant aucun anniversaire là où il en attend un.
/// Un `AppTexts` français hors de tout widget.
///
/// Les lignes d'agenda portent des phrases — « Journée », « X fête son
/// anniversaire » —, et c'est la langue qui les écrit : la lecture de
/// `dayAgendaProvider` la prend donc en argument, comme elle prend le jour.
Future<AppTexts> _textes() => AppTexts.delegate.load(const Locale('fr'));

Future<ProviderContainer> _conteneur(
  List<ContactBirthday> anniversaires,
) async {
  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeContactRepository contacts = FakeContactRepository()
    ..anniversaires = anniversaires;

  final ProviderContainer c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FixedClock(_testNow)),
      // **La langue est épinglée au français.** Ces tests affirment des
      // phrases exactes ; sans cela, ils liraient la langue de la machine
      // — `en_US` sur le harnais — et échoueraient sur du bon anglais.
      languageStorageProvider.overrideWithValue(
        EphemeralLanguageStorage(langue: const Locale('fr')),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
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
  );
  addTearDown(c.dispose);
  await c.read(contactBirthdaysProvider.future);
  return c;
}

Future<FakeProfileRepository> _ouvrirProfil(
  WidgetTester tester, {
  Profile? profile,
  bool echecEcriture = false,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeProfileRepository profils = FakeProfileRepository(
    profile: profile,
    echecEcriture: echecEcriture,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        // **La langue est épinglée au français.** Ces tests affirment des
        // phrases exactes ; sans cela, ils liraient la langue de la machine
        // — `en_US` sur le harnais — et échoueraient sur du bon anglais.
        languageStorageProvider.overrideWithValue(
          EphemeralLanguageStorage(langue: const Locale('fr')),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profils),
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
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  return profils;
}

/// Choisit une valeur dans une des deux listes déroulantes de la feuille.
Future<void> _choisir(
  WidgetTester tester,
  String libelle,
  String valeur,
) async {
  await tester.tap(
    find.descendant(
      of: find
          .ancestor(of: find.text(libelle), matching: find.byType(Column))
          .first,
      matching: find.byType(DropdownButtonFormField<int>),
    ),
  );
  await tester.pumpAndSettle();
  // La liste des jours compte 31 entrées : la valeur visée peut être hors
  // champ, et un `tap` sur un widget non visible échoue.
  await tester.ensureVisible(find.text(valeur).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(valeur).last);
  await tester.pumpAndSettle();
}
