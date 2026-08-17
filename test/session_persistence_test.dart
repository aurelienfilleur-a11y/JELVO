import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/data/session_persistence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stockage en mémoire, pour observer ce qui est réellement écrit.
class _StockageEspion extends LocalStorage {
  String? valeur;
  int ecritures = 0;
  int suppressions = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => valeur != null;

  @override
  Future<String?> accessToken() async => valeur;

  @override
  Future<void> persistSession(String persistSessionString) async {
    valeur = persistSessionString;
    ecritures++;
  }

  @override
  Future<void> removePersistedSession() async {
    valeur = null;
    suppressions++;
  }
}

void main() {
  late _StockageEspion session;
  late _StockageEspion drapeau;
  late SessionPersistence persistance;

  setUp(() {
    session = _StockageEspion();
    drapeau = _StockageEspion();
    persistance = SessionPersistence(session: session, drapeau: drapeau);
  });

  group('Se souvenir de moi', () {
    test('sans rien avoir choisi, la case est cochée', () async {
      await persistance.initialize();
      expect(persistance.seSouvenir, isTrue);
    });

    test('cochée, la session s’écrit comme avant', () async {
      await persistance.initialize();
      await persistance.definir(seSouvenir: true);
      await persistance.persistSession('jeton');

      expect(session.valeur, 'jeton');
      expect(await persistance.accessToken(), 'jeton');
      expect(await persistance.hasAccessToken(), isTrue);
    });

    test('décochée, rien n’est écrit — il n’y a rien à retrouver', () async {
      await persistance.initialize();
      await persistance.definir(seSouvenir: false);
      await persistance.persistSession('jeton');

      expect(session.valeur, isNull);
      expect(await persistance.accessToken(), isNull);
      expect(await persistance.hasAccessToken(), isFalse);
    });

    test('décocher efface une session déjà enregistrée', () async {
      // Sans cela, une session écrite lors d'une connexion précédente
      // survivrait au décochage : exactement l'impression que la case ne
      // fonctionne pas.
      session.valeur = 'ancienne-session';

      await persistance.initialize();
      await persistance.definir(seSouvenir: false);

      expect(session.valeur, isNull);
    });

    test('le choix survit à la fermeture, la session non', () async {
      await persistance.initialize();
      await persistance.definir(seSouvenir: false);
      await persistance.persistSession('jeton');

      // Nouvelle instance sur les mêmes stockages : c'est ce que fait un
      // relancement de l'application.
      final SessionPersistence relance = SessionPersistence(
        session: session,
        drapeau: drapeau,
      );
      await relance.initialize();

      expect(relance.seSouvenir, isFalse, reason: 'le choix doit tenir');
      expect(
        await relance.accessToken(),
        isNull,
        reason: 'la session ne doit pas avoir survécu',
      );
    });

    test('recocher rend à nouveau la session persistante', () async {
      await persistance.initialize();
      await persistance.definir(seSouvenir: false);
      await persistance.definir(seSouvenir: true);
      await persistance.persistSession('jeton');

      final SessionPersistence relance = SessionPersistence(
        session: session,
        drapeau: drapeau,
      );
      await relance.initialize();

      expect(relance.seSouvenir, isTrue);
      expect(await relance.accessToken(), 'jeton');
    });

    test('se déconnecter efface, quel que soit le réglage', () async {
      // La suppression n'est jamais conditionnelle : une déconnexion doit
      // effacer même si la case est décochée, sans quoi un reliquat d'une
      // session précédente resterait sur l'appareil.
      await persistance.initialize();
      await persistance.definir(seSouvenir: false);
      session.valeur = 'reliquat';

      await persistance.removePersistedSession();

      expect(session.valeur, isNull);
    });
  });
}
