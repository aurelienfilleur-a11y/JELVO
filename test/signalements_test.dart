import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/language_storage.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/models/profil_consultable.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/signalements/models/signalement.dart';
import 'package:jelvo/features/signalements/providers/signalement_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/l10n/app_localizations.dart';
import 'package:jelvo/main.dart';

import 'package:jelvo/features/auth/models/auth_failure.dart';
import 'package:jelvo/features/signalements/models/blocage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_signalement_repository.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _maintenant = DateTime(2026, 11, 22, 9);

/// Une ligne telle que `profil_consultable` la rend, pour que l'écran d'un
/// profil ait quelque chose à afficher.
Map<String, dynamic> _ligneProfil({
  String id = 'u2',
  bool cestMoi = false,
  bool groupesPartages = false,
}) => <String, dynamic>{
  'id': id,
  'pseudo': 'lea.marchand',
  'first_name': 'Léa',
  'last_name': 'Marchand',
  'avatar_url': null,
  'bio': null,
  'anniversaire_jour': null,
  'anniversaire_mois': null,
  'cest_moi': cestMoi,
  'autre_id': id,
  'statut': 'accepted',
  'sens': 'sortant',
  'favori': false,
  'groupes_communs': groupesPartages ? 1 : 0,
  'groupes_partages': groupesPartages
      ? <Map<String, dynamic>>[
          <String, dynamic>{'id': 'g1', 'name': 'Famille Rousseau'},
        ]
      : <Map<String, dynamic>>[],
  'disponibilite': null,
};

Future<FakeProfileRepository> _pumpApp(
  WidgetTester tester, {
  required FakeSignalementRepository signalements,
  FakeChatRepository? chat,
  bool groupesPartages = false,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeProfileRepository profils = FakeProfileRepository();
  profils.profilsConsultables['u2'] = ProfilConsultable.depuisLigne(
    _ligneProfil(groupesPartages: groupesPartages),
  );
  profils.profilsConsultables[FakeChatRepository.moi] =
      ProfilConsultable.depuisLigne(
        _ligneProfil(id: FakeChatRepository.moi, cestMoi: true),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_maintenant)),
        languageStorageProvider.overrideWithValue(
          EphemeralLanguageStorage(langue: const Locale('fr')),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profils),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(chat ?? FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        signalementRepositoryProvider.overrideWithValue(signalements),
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
  return profils;
}

/// Va droit à un chemin, par le routeur : l'écran de modération est à quatre
/// gestes de l'accueil, et le viser par des touches rendrait chaque test
/// dépendant de la mise en page des paramètres.
Future<void> _aller(WidgetTester tester, String chemin) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(chemin);
  await tester.pumpAndSettle();
}

Signalement _signalementDeMessage({
  String id = 's1',
  bool traite = false,
  bool efface = false,
  String? note,
}) {
  return Signalement(
    id: id,
    cible: SignalementCible.message,
    motif: SignalementMotif.harcelement,
    creeLe: DateTime(2026, 11, 22, 8),
    commentaire: 'Il insiste depuis trois jours',
    contexte: const <String, dynamic>{
      'contenu': 'Texte signalé par quelqu’un',
      'groupe_nom': 'Famille Rousseau',
    },
    traiteLe: traite ? DateTime(2026, 11, 22, 8, 30) : null,
    note: note,
    messageId: 'm1',
    groupId: 'g1',
    profilId: 'u2',
    auteurNom: 'Camille Rousseau',
    viseNom: 'Léa Marchand',
    groupeNom: 'Famille Rousseau',
    messageEfface: efface,
  );
}

void main() {
  setUpAll(initializeDateFormatting);

  // ========================================================================
  // Les mots d'état, sans widget
  // ========================================================================
  group('Les mots d’état', () {
    late AppTexts t;

    setUpAll(() async {
      t = await AppTexts.delegate.load(const Locale('fr'));
    });

    test('« déjà signalé » n’est pas une panne, c’est la réponse', () {
      // Le signalement n'a pas abouti, mais la phrase ne doit pas envoyer
      // chercher le défaut : rien n'est cassé, c'est déjà fait.
      expect(SignalementOutcome.dejaSignale.isSuccess, isFalse);
      expect(
        SignalementOutcome.dejaSignale.message(t),
        contains('déjà signalé'),
      );
    });

    test('un mot inconnu de la base ne lève pas', () {
      // `signaler` peut gagner un mot d'état demain ; un client plus ancien
      // doit afficher un message, pas planter.
      expect(
        SignalementOutcome.fromDb('mot_que_le_client_ignore'),
        SignalementOutcome.inconnu,
      );
      expect(SignalementOutcome.fromDb(null), SignalementOutcome.inconnu);
    });

    test('quatre mots seulement comptent pour une réussite', () {
      final List<SignalementOutcome> reussites = SignalementOutcome.values
          .where((SignalementOutcome o) => o.isSuccess)
          .toList();
      expect(reussites, <SignalementOutcome>[
        SignalementOutcome.signale,
        SignalementOutcome.traite,
        SignalementOutcome.rouvert,
        SignalementOutcome.supprime,
      ]);
    });

    test('les six motifs portent un libellé et une aide traduisibles', () {
      for (final SignalementMotif motif in SignalementMotif.values) {
        expect(motif.label(t), isNotEmpty);
        expect(motif.aide(t), isNotEmpty);
      }
      // Le contrôle qui compte : aucun libellé n'est écrit en dur dans le
      // modèle. Un `switch` qui renverrait du français referait exactement
      // le défaut des quatre-vingt-onze chaînes.
      expect(SignalementMotif.harcelement.label(t), 'Harcèlement');
    });
  });

  // ========================================================================
  // La lecture d'une ligne
  // ========================================================================
  group('La lecture d’un signalement', () {
    test('la recopie se lit, et l’absence de relation ne s’invente pas', () {
      final Signalement s = Signalement.fromRow(<String, dynamic>{
        'id': 's9',
        'cible_type': 'message',
        'motif': 'haine',
        'cree_le': '2026-11-22T07:00:00Z',
        'contexte': <String, dynamic>{
          'contenu': 'Ce qui a été écrit',
          'media_kind': null,
        },
        'message_id': 'm7',
        'group_id': 'g1',
        'auteur_nom': null,
        'vise_nom': 'Léa Marchand',
        'message_efface': true,
      });

      expect(s.cible, SignalementCible.message);
      expect(s.motif, SignalementMotif.haine);
      expect(s.contenuRecopie, 'Ce qui a été écrit');
      expect(s.messageEfface, isTrue);
      // `auteur_nom` nul **est** une information : le compte de celui qui a
      // signalé a été supprimé, et le dossier a survécu anonymisé.
      expect(s.auteurNom, isNull);
      expect(s.estTraite, isFalse);
    });

    test('un média recopié n’a pas de texte, et ce n’est pas un vide', () {
      final Signalement s = Signalement.fromRow(<String, dynamic>{
        'id': 's10',
        'cible_type': 'message',
        'motif': 'sexuel',
        'cree_le': '2026-11-22T07:00:00Z',
        'contexte': <String, dynamic>{'contenu': '', 'media_kind': 'image'},
        'message_id': 'm8',
      });

      expect(s.contenuRecopie, isEmpty);
      expect(s.mediaRecopie, 'image');
    });
  });

  // ========================================================================
  // Signaler
  // ========================================================================
  group('Signaler', () {
    testWidgets('un message d’autrui s’ouvre sur la feuille, le sien non', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository();
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/groupes/g1/discussion');

      // `m1` est de Léa, `m2` est de l'utilisateur.
      await tester.longPress(find.text('Bonjour tout le monde'));
      await tester.pumpAndSettle();
      expect(find.text('Signaler'), findsOneWidget);

      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      expect(find.text('Signaler ce message'), findsOneWidget);
      // Le nom titre la feuille : « ce message » seul serait abstrait.
      expect(find.text('Léa Marchand'), findsWidgets);

      // Et la phrase qui décide si l'on ose : la personne n'est pas prévenue.
      expect(
        find.textContaining('n’est pas prévenue'),
        findsOneWidget,
        reason: 'c’est la première question de quelqu’un qui hésite',
      );
      // Celle qui dispense de faire une capture d'écran avant de signaler.
      expect(find.textContaining('est recopié'), findsOneWidget);
    });

    testWidgets('son propre message n’offre pas de se signaler', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, signalements: FakeSignalementRepository());
      await _aller(tester, '/groupes/g1/discussion');

      await tester.longPress(find.text('On se retrouve à midi'));
      await tester.pumpAndSettle();

      expect(find.text('Signaler'), findsNothing);
      expect(find.text('Supprimer le message'), findsOneWidget);
    });

    testWidgets('sans motif choisi, rien ne part', (WidgetTester tester) async {
      final FakeSignalementRepository faux = FakeSignalementRepository();
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/groupes/g1/discussion');
      await tester.longPress(find.text('Bonjour tout le monde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      // **Le contrôle négatif** : la feuille reste, et rien n'a été envoyé.
      expect(faux.envois, 0);
      expect(find.text('Choisissez un motif.'), findsOneWidget);
      expect(find.text('Signaler ce message'), findsOneWidget);
    });

    testWidgets('un motif et un envoi : la cible et le motif arrivent', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository();
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/groupes/g1/discussion');
      await tester.longPress(find.text('Bonjour tout le monde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Harcèlement'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Depuis trois jours');
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(faux.envois, 1);
      expect(faux.derniereCible, SignalementCible.message);
      expect(faux.dernierCibleId, 'm1');
      expect(faux.dernierMotif, SignalementMotif.harcelement);
      expect(faux.dernierCommentaire, 'Depuis trois jours');
      // La feuille se referme, et le message confirme.
      expect(find.text('Signaler ce message'), findsNothing);
      expect(find.textContaining('Signalement envoyé'), findsOneWidget);
    });

    testWidgets('« déjà signalé » reste dans la feuille, avec son message', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository(
        issueSignalement: SignalementOutcome.dejaSignale,
      );
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/groupes/g1/discussion');
      await tester.longPress(find.text('Bonjour tout le monde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam ou publicité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      // **Le refus ne referme pas.** Une `SnackBar` furtive sur une feuille
      // qui se referme laisserait croire à un envoi.
      expect(find.text('Signaler ce message'), findsOneWidget);
      expect(find.textContaining('déjà signalé'), findsOneWidget);
    });

    testWidgets('un groupe se signale depuis son menu', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository();
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/groupes/g1');

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();

      expect(find.text('Signaler ce groupe'), findsOneWidget);
      // La recopie du contenu ne concerne qu'un message : la phrase ne
      // s'affiche donc pas ici.
      expect(find.textContaining('est recopié'), findsNothing);

      await tester.tap(find.text('Autre chose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(faux.derniereCible, SignalementCible.group);
      expect(faux.dernierCibleId, 'g1');
    });

    testWidgets('un profil se signale, mais jamais le sien', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository();
      await _pumpApp(tester, signalements: faux);

      await _aller(tester, '/personnes/u2');
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      expect(find.text('Signaler ce profil'), findsOneWidget);
      await tester.tap(find.text('Propos haineux'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(faux.derniereCible, SignalementCible.profile);
      expect(faux.dernierCibleId, 'u2');

      // **Le contrôle négatif** : sur son propre profil, pas de menu du tout.
      // Un menu qui n'offrirait que de se signaler soi-même promettrait une
      // action que la base refuse.
      await _aller(tester, '/personnes/${FakeChatRepository.moi}');
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });
  });

  // ========================================================================
  // L'écran de modération
  // ========================================================================
  group('L’écran de modération', () {
    testWidgets('la ligne des paramètres n’existe pas sans être modérateur', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(moderateur: false),
      );
      await _aller(tester, '/parametres');

      expect(find.text('Signalements'), findsNothing);
      expect(find.text('À propos de Jelvo'), findsOneWidget);
    });

    testWidgets('elle apparaît pour un modérateur, et mène à l’écran', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(
          moderateur: true,
          signalements: <Signalement>[_signalementDeMessage()],
        ),
      );
      await _aller(tester, '/parametres');

      expect(find.text('Signalements'), findsOneWidget);
      await tester.tap(find.text('Signalements'));
      await tester.pumpAndSettle();

      expect(find.text('À traiter'), findsOneWidget);
      expect(find.text('Traités'), findsOneWidget);
    });

    testWidgets('l’URL forcée sans être modérateur donne un écran vide', (
      WidgetTester tester,
    ) async {
      // **Ce n'est pas l'écran qui protège, et il ne pourrait pas.** La règle
      // est tenue par la base : la table n'a aucun privilège et les
      // fonctions appellent `est_moderateur()`. Ouvert de force, l'écran se
      // rend donc vide — pas en erreur, et pas avec du contenu.
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(moderateur: false),
      );
      await _aller(tester, '/parametres/signalements');

      expect(find.text('Rien à traiter'), findsOneWidget);
      expect(find.text('Famille Rousseau'), findsNothing);
    });

    testWidgets('la carte porte qui signale, qui est visé, et la recopie', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(
          moderateur: true,
          signalements: <Signalement>[_signalementDeMessage()],
        ),
      );
      await _aller(tester, '/parametres/signalements');

      expect(find.textContaining('Message · Harcèlement'), findsOneWidget);
      expect(find.text('Signalé par Camille Rousseau'), findsOneWidget);
      expect(find.text('Concerne Léa Marchand'), findsOneWidget);
      expect(find.text('Dans Famille Rousseau'), findsOneWidget);
      expect(find.text('Contenu signalé'), findsOneWidget);
      expect(find.text('Texte signalé par quelqu’un'), findsOneWidget);
      expect(
        find.text('« Il insiste depuis trois jours »'),
        findsOneWidget,
        reason: 'les précisions de qui signale font partie du dossier',
      );
    });

    testWidgets(
      'un compte supprimé signe le dossier sans le faire disparaître',
      (WidgetTester tester) async {
        await _pumpApp(
          tester,
          signalements: FakeSignalementRepository(
            moderateur: true,
            signalements: <Signalement>[
              Signalement(
                id: 's2',
                cible: SignalementCible.profile,
                motif: SignalementMotif.spam,
                creeLe: DateTime(2026, 11, 22, 8),
                profilId: 'u2',
                viseNom: 'Léa Marchand',
                // `auteur_nom` nul : son compte a été supprimé, le dossier a
                // survécu anonymisé.
              ),
            ],
          ),
        );
        await _aller(tester, '/parametres/signalements');

        expect(find.text('Signalé par Compte supprimé'), findsOneWidget);
        expect(find.text('Concerne Léa Marchand'), findsOneWidget);
      },
    );

    testWidgets('un message effacé depuis le signalement se dit', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(
          moderateur: true,
          signalements: <Signalement>[_signalementDeMessage(efface: true)],
        ),
      );
      await _aller(tester, '/parametres/signalements');

      // **C'est toute la raison d'être de la recopie** : le texte reste
      // lisible alors que son auteur l'a effacé.
      expect(find.text('Texte signalé par quelqu’un'), findsOneWidget);
      expect(find.textContaining('a été effacé depuis'), findsOneWidget);
      // Et le bouton de suppression disparaît : il n'y a plus rien à retirer.
      expect(find.text('Supprimer le message'), findsNothing);
    });

    testWidgets('un groupe signalé dit que la note est le seul levier', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(
          moderateur: true,
          signalements: <Signalement>[
            Signalement(
              id: 's3',
              cible: SignalementCible.group,
              motif: SignalementMotif.violence,
              creeLe: DateTime(2026, 11, 22, 8),
              groupId: 'g1',
              groupeNom: 'Famille Rousseau',
              auteurNom: 'Camille Rousseau',
            ),
          ],
        ),
      );
      await _aller(tester, '/parametres/signalements');

      expect(find.text('Supprimer le message'), findsNothing);
      // La phrase remplace le bouton absent : sans elle, on chercherait le
      // levier qui n'existe pas.
      expect(find.textContaining('la note est le seul levier'), findsOneWidget);
    });
  });

  // ========================================================================
  // Agir
  // ========================================================================
  group('Agir sur un signalement', () {
    testWidgets(
      'supprimer le message se confirme, et « Annuler » n’écrit rien',
      (WidgetTester tester) async {
        final FakeSignalementRepository faux = FakeSignalementRepository(
          moderateur: true,
          signalements: <Signalement>[_signalementDeMessage()],
        );
        await _pumpApp(tester, signalements: faux);
        await _aller(tester, '/parametres/signalements');

        await tester.tap(find.text('Supprimer le message'));
        await tester.pumpAndSettle();
        expect(find.textContaining('se referme en'), findsOneWidget);

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(faux.suppressions, 0);

        await tester.tap(find.text('Supprimer le message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();

        expect(faux.suppressions, 1);
        expect(faux.dernierMessageSupprime, 's1');
        expect(find.text('Message supprimé.'), findsOneWidget);
      },
    );

    testWidgets('marquer traité demande la note, puis range la ligne', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository(
        moderateur: true,
        signalements: <Signalement>[_signalementDeMessage()],
      );
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/parametres/signalements');

      await tester.tap(find.text('Marquer traité'));
      await tester.pumpAndSettle();

      // **La note se demande au moment où l'on décide** : « ce que vous avez
      // fait » ne se retrouve pas une heure plus tard.
      await tester.enterText(find.byType(TextField), 'Message retiré');
      await tester.tap(find.text('Marquer traité').last);
      await tester.pumpAndSettle();

      expect(faux.traitements, 1);
      expect(faux.dernierTraite, 's1');
      expect(faux.derniereNote, 'Message retiré');
      expect(faux.dernierDrapeauTraite, isTrue);

      // La demande, mot pour mot : « ne pas le revoir ».
      expect(find.text('Rien à traiter'), findsOneWidget);
      expect(find.text('Texte signalé par quelqu’un'), findsNothing);

      // **Les deux onglets sont relus**, et pas seulement celui qu'on
      // regarde : la ligne passe de l'un à l'autre.
      expect(faux.lecturesArchive, greaterThan(0));
    });

    testWidgets('« Annuler » sur la note ne traite pas', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository(
        moderateur: true,
        signalements: <Signalement>[_signalementDeMessage()],
      );
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/parametres/signalements');

      await tester.tap(find.text('Marquer traité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // **Le contrôle qui distingue `null` de la chaîne vide** : annuler ne
      // doit pas valoir « traiter sans note ».
      expect(faux.traitements, 0);
      expect(find.text('Texte signalé par quelqu’un'), findsOneWidget);
    });

    testWidgets('l’archive montre les traités, et se rouvre sans note', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository(
        moderateur: true,
        signalements: <Signalement>[
          _signalementDeMessage(traite: true, note: 'Message retiré'),
        ],
        issueTraitement: SignalementOutcome.rouvert,
      );
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/parametres/signalements');

      expect(find.text('Aucun signalement traité'), findsNothing);
      expect(find.text('Rien à traiter'), findsOneWidget);

      await tester.tap(find.text('Traités'));
      await tester.pumpAndSettle();
      expect(find.text('Texte signalé par quelqu’un'), findsOneWidget);
      expect(find.text('Message retiré'), findsOneWidget);

      // Rouvrir ne redemande pas de note : le geste défait un traitement, il
      // n'en documente pas un nouveau.
      await tester.tap(find.text('Rouvrir'));
      await tester.pumpAndSettle();
      expect(faux.dernierDrapeauTraite, isFalse);
      expect(faux.derniereNote, isNull);
    });

    testWidgets('une lecture qui échoue le dit, au lieu de se rendre vide', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(
          moderateur: true,
          leveEnLecture: true,
        ),
      );
      await _aller(tester, '/parametres/signalements');

      expect(find.text('Signalements indisponibles'), findsOneWidget);
      expect(find.text('Rien à traiter'), findsNothing);
    });
  });

  // ========================================================================
  // Bloquer quelqu'un
  // ========================================================================
  group('Bloquer', () {
    test('les mots d’état disent la réponse, et non une panne', () async {
      final AppTexts t = await AppTexts.delegate.load(const Locale('fr'));

      expect(BlocageOutcome.dejaBloque.isSuccess, isFalse);
      expect(BlocageOutcome.pasBloque.isSuccess, isFalse);
      expect(BlocageOutcome.bloque.isSuccess, isTrue);
      expect(BlocageOutcome.debloque.isSuccess, isTrue);
      // Un mot que la base ajouterait demain ne doit pas faire lever un
      // client plus ancien.
      expect(BlocageOutcome.fromDb('autre_chose'), BlocageOutcome.inconnu);
      for (final BlocageOutcome o in BlocageOutcome.values) {
        expect(o.message(t), isNotEmpty);
      }
    });

    test(
      'JB001 a son propre message, et ce n’est pas « permission refusée »',
      () async {
        final AppTexts t = await AppTexts.delegate.load(const Locale('fr'));
        // **Le contrôle qui compte** : « permission refusée » enverrait
        // chercher un défaut de droits, là où la cause est un blocage posé
        // délibérément par l'une des deux personnes.
        final AuthFailure bloque = AuthFailure.from(
          const PostgrestException(
            message: 'blocage entre … et …',
            code: 'JB001',
          ),
        );
        expect(bloque.kind, AuthFailureKind.blocked);
        expect(bloque.message(t), isNot(t.errorForbidden));

        final AuthFailure refus = AuthFailure.from(
          const PostgrestException(
            message: 'row-level security',
            code: '42501',
          ),
        );
        expect(refus.kind, AuthFailureKind.forbidden);
      },
    );

    testWidgets(
      'le menu du profil l’offre, et la confirmation dit ce que ça fait',
      (WidgetTester tester) async {
        final FakeSignalementRepository faux = FakeSignalementRepository();
        await _pumpApp(tester, signalements: faux);
        await _aller(tester, '/personnes/u2');

        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Bloquer'), findsOneWidget);
        await tester.tap(find.text('Bloquer'));
        await tester.pumpAndSettle();

        expect(find.text('Bloquer cette personne ?'), findsOneWidget);
        expect(
          find.textContaining('ne pourra plus vous inviter'),
          findsOneWidget,
          reason: 'la confirmation doit dire ce que le blocage fait',
        );

        // **« Annuler » n’écrit rien** — le contrôle négatif.
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(faux.blocages, 0);

        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bloquer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bloquer').last);
        await tester.pumpAndSettle();

        expect(faux.blocages, 1);
        expect(faux.dernierBloque, 'u2');
        expect(find.text('Personne bloquée.'), findsOneWidget);
      },
    );

    testWidgets('le cas délicat se dit : un groupe partagé n’est pas touché', (
      WidgetTester tester,
    ) async {
      // La phrase n'apparaît **que** si un groupe est réellement partagé :
      // c'est `groupes_partages` de `profil_consultable` qui la déclenche.
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(),
        groupesPartages: true,
      );
      await _aller(tester, '/personnes/u2');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vous partagez un groupe'), findsOneWidget);
      // Et elle nomme la seule suite qui a du sens.
      expect(find.textContaining('quittez le groupe'), findsOneWidget);
    });

    testWidgets('sans groupe partagé, la phrase ne s’affiche pas', (
      WidgetTester tester,
    ) async {
      // **Le contrôle négatif de la phrase** : l'afficher toujours ferait
      // croire à un groupe partagé qui n'existe pas.
      await _pumpApp(tester, signalements: FakeSignalementRepository());
      await _aller(tester, '/personnes/u2');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloquer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vous partagez un groupe'), findsNothing);
      expect(
        find.textContaining('ne pourra plus vous inviter'),
        findsOneWidget,
      );
    });

    testWidgets('la liste des bloqués est le chemin du déblocage', (
      WidgetTester tester,
    ) async {
      final FakeSignalementRepository faux = FakeSignalementRepository(
        bloques: <PersonneBloquee>[
          PersonneBloquee(
            userId: 'u2',
            creeLe: DateTime(2026, 11, 22, 8),
            pseudo: 'lea.marchand',
            nom: 'Léa Marchand',
          ),
        ],
      );
      await _pumpApp(tester, signalements: faux);
      await _aller(tester, '/parametres');

      // La ligne annonce le compte.
      expect(find.text('Personnes bloquées'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      await tester.tap(find.text('Personnes bloquées'));
      await tester.pumpAndSettle();
      expect(find.text('Léa Marchand'), findsOneWidget);

      await tester.tap(find.text('Débloquer'));
      await tester.pumpAndSettle();
      // La confirmation dit ce qui **ne revient pas**.
      expect(
        find.textContaining('lien de contact ne revient pas'),
        findsOneWidget,
      );
      await tester.tap(find.text('Débloquer').last);
      await tester.pumpAndSettle();

      expect(faux.deblocages, 1);
      expect(faux.dernierDebloque, 'u2');
      expect(find.text('Personne débloquée.'), findsOneWidget);
      // La liste se relit : la ligne a disparu.
      expect(find.text('Léa Marchand'), findsNothing);
      expect(find.text('Personne n’est bloqué'), findsOneWidget);
    });

    testWidgets('zéro ne se dit pas sur la ligne des paramètres', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, signalements: FakeSignalementRepository());
      await _aller(tester, '/parametres');

      expect(find.text('Personnes bloquées'), findsOneWidget);
      // **Le contrôle négatif** : « 0 » sur cette ligne se lirait comme une
      // alerte, alors qu'il n'y a rien à signaler.
      await tester.tap(find.text('Personnes bloquées'));
      await tester.pumpAndSettle();
      expect(find.text('Personne n’est bloqué'), findsOneWidget);
      expect(
        find.textContaining('depuis son profil'),
        findsOneWidget,
        reason: 'l’état vide doit dire où l’on bloque',
      );
    });

    testWidgets('une personne bloquée n’est plus proposée en assignée', (
      WidgetTester tester,
    ) async {
      // Elle reste membre du groupe — le blocage ne retire personne — mais le
      // geste ne lui est plus proposé : la base le refuserait en JB001.
      await _pumpApp(
        tester,
        signalements: FakeSignalementRepository(
          bloques: <PersonneBloquee>[
            PersonneBloquee(
              userId: 'u2',
              creeLe: DateTime(2026, 11, 22, 8),
              nom: 'Léa Marchand',
            ),
          ],
        ),
      );
      await _aller(tester, '/creer?type=task&groupe=g1');
      await tester.pumpAndSettle();

      expect(find.text('Assigner à'), findsOneWidget);
      expect(
        find.text('Léa'),
        findsNothing,
        reason: 'le geste refusé ne doit pas être proposé',
      );
      // Camille, elle, reste proposée : c'est le filtre qui écarte, pas le
      // sélecteur qui serait vide.
      expect(find.text('Camille'), findsOneWidget);
    });

    testWidgets('sans blocage, elle est bien proposée', (
      WidgetTester tester,
    ) async {
      // **Le contrôle négatif du filtre.** Sans lui, le test précédent
      // passerait aussi bien si le sélecteur ne montrait jamais Léa, pour une
      // raison qui n'aurait rien à voir avec le blocage.
      await _pumpApp(tester, signalements: FakeSignalementRepository());
      await _aller(tester, '/creer?type=task&groupe=g1');
      await tester.pumpAndSettle();

      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('Camille'), findsOneWidget);
    });
  });
}
