import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/data/language_storage.dart';
import 'package:jelvo/features/notifications/push/push_service.dart';
import 'package:jelvo/features/profile/widgets/language_sheet.dart';

import 'fakes/fake_push.dart';
import 'langues_harnais.dart';

/// Les gabarits de `supabase/functions/envoyer-push/traductions.ts`.
///
/// **Le fichier est lu, pas recopié.** C'est le même contrat que celui de
/// `web/index.html` tenu par `test/launch_screen_test.dart` : deux copies qui
/// ne protesteraient jamais en divergeant, et un test qui les confronte.
Map<String, Map<String, String>> _gabarits() {
  final String source = File(
    'supabase/functions/envoyer-push/traductions.ts',
  ).readAsStringSync();

  final Map<String, Map<String, String>> parLangue =
      <String, Map<String, String>>{};
  for (final String bloc in const <String>['FR', 'EN', 'ES', 'DE']) {
    final RegExpMatch? debut = RegExp(
      'const $bloc: Gabarits = \\{',
    ).firstMatch(source);
    expect(debut, isNotNull, reason: 'bloc $bloc absent de traductions.ts');
    final int fin = source.indexOf('\n};', debut!.end);
    expect(fin, greaterThan(debut.end), reason: 'bloc $bloc non terminé');

    final Map<String, String> gabarits = <String, String>{};
    for (final RegExpMatch ligne in RegExp(
      r"'([\w.]+)':\s*'((?:[^'\\]|\\.)*)'",
    ).allMatches(source.substring(debut.end, fin))) {
      gabarits[ligne.group(1)!] = ligne.group(2)!;
    }
    parLangue[bloc.toLowerCase()] = gabarits;
  }
  return parLangue;
}

/// Les clés que le SQL dépose réellement dans `push_outbox.cle`.
Set<String> _clesDuSql() {
  final Set<String> cles = <String>{};
  for (final FileSystemEntity entree in Directory('supabase').listSync()) {
    if (entree is! File || !entree.path.endsWith('.sql')) continue;
    // `schema_actuel.sql` est une **sortie** : il recopie le corps des
    // fonctions, et compter ses clés reviendrait à se citer soi-même.
    if (entree.path.endsWith('schema_actuel.sql')) continue;
    for (final RegExpMatch m in RegExp(
      r"'(push\.[\w.]+)'",
    ).allMatches(entree.readAsStringSync())) {
      cles.add(m.group(1)!);
    }
  }
  return cles;
}

Set<String> _parametres(String gabarit) => RegExp(
  r'\{(\w+)\}',
).allMatches(gabarit).map((RegExpMatch m) => m.group(1)!).toSet();

void main() {
  setUpAll(() => initializeDateFormatting());

  // ==========================================================================
  // Le contrat entre les quatre langues de l'envoyeur
  // ==========================================================================
  group('Les gabarits de notification', () {
    late Map<String, Map<String, String>> gabarits;

    setUpAll(() => gabarits = _gabarits());

    test('les quatre langues sont là, et aucune n’est vide', () {
      expect(gabarits.keys.toSet(), <String>{'fr', 'en', 'es', 'de'});
      for (final String langue in gabarits.keys) {
        expect(
          gabarits[langue]!.length,
          greaterThanOrEqualTo(23),
          reason: langue,
        );
      }
    });

    test('elles portent exactement les mêmes clés', () {
      // Une clé oubliée dans une seule langue retombe sur le français, et
      // personne ne le voit : la notification part, simplement pas traduite.
      for (final String langue in const <String>['en', 'es', 'de']) {
        expect(
          gabarits[langue]!.keys.toSet(),
          gabarits['fr']!.keys.toSet(),
          reason: langue,
        );
      }
    });

    test('et les mêmes paramètres, clé par clé', () {
      // Un paramètre renommé ne lève pas : il se substitue à la chaîne vide,
      // et la phrase sort amputée de son sujet ou de son objet.
      for (final String langue in const <String>['en', 'es', 'de']) {
        for (final String cle in gabarits['fr']!.keys) {
          expect(
            _parametres(gabarits[langue]![cle]!),
            _parametres(gabarits['fr']![cle]!),
            reason: '$langue/$cle',
          );
        }
      }
    });

    test('le français de l’envoyeur ne traîne pas dans les trois autres', () {
      for (final String langue in const <String>['en', 'es', 'de']) {
        for (final String cle in gabarits['fr']!.keys) {
          final String fr = gabarits['fr']![cle]!;
          // Un gabarit qui n'est que des paramètres est légitimement
          // identique — « {auteur} : {message} » l'est dans les quatre.
          if (_parametres(fr).isNotEmpty &&
              fr.replaceAll(RegExp(r'\{\w+\}'), '').trim().length <= 2) {
            continue;
          }
          expect(gabarits[langue]![cle], isNot(fr), reason: '$langue/$cle');
        }
      }
    });
  });

  // ==========================================================================
  // Le contrat entre le SQL et l'envoyeur
  // ==========================================================================
  group('Les clés du SQL et celles de l’envoyeur', () {
    test('toute clé déposée par la base est connue de l’envoyeur', () {
      // **C'est le contrôle qui compte.** Une clé déposée que l'envoyeur ne
      // connaît pas ne lève pas : il retombe sur le texte français, et la
      // traduction cesse en silence pour ce type de notification.
      final Set<String> connues = _gabarits()['fr']!.keys.toSet();
      final Set<String> deposees = _clesDuSql();

      expect(deposees, isNotEmpty, reason: 'aucune clé trouvée dans supabase/');
      expect(deposees.difference(connues), isEmpty);
    });

    test('et tout gabarit a un déposant, sauf les deux de l’envoyeur', () {
      // Un gabarit que rien ne dépose est du texte mort — sauf
      // `push.personnel` et `push.quelquun`, que l'envoyeur rend lui-même :
      // le premier quand il n'y a pas de groupe, le second quand le profil de
      // l'auteur a disparu.
      final Set<String> connues = _gabarits()['fr']!.keys.toSet();
      final Set<String> deposees = _clesDuSql();

      expect(connues.difference(deposees), <String>{
        'push.personnel',
        'push.quelquun',
      });
    });

    test('chaque type de notification a sa clé', () {
      // Le type est ce que l'écran de réglages permet de couper ; sans clé, ce
      // type-là resterait en français pour tout le monde.
      final Set<String> deposees = _clesDuSql();
      for (final String attendue in const <String>[
        'push.chat.texte',
        'push.invitation.groupe',
        'push.invitation.evenement',
        'push.tache.confiee',
        'push.tache.reponse.accepte',
        'push.evenement.reponse.oui',
        'push.evenement.deplace',
        'push.rappel.tache',
        'push.rappel.evenement',
        'push.anniversaire',
      ]) {
        expect(deposees, contains(attendue), reason: attendue);
      }
    });

    test('les horodatages partent en ISO, jamais formatés', () {
      // `to_char(…, 'DD/MM à HH24:MI')` est un format **français**. Les deux
      // paramètres qui portent un instant doivent donc arriver en ISO, et
      // c'est l'envoyeur qui formate selon la langue.
      final Map<String, String> fr = _gabarits()['fr']!;
      expect(_parametres(fr['push.evenement.deplace']!), contains('instant'));
      expect(_parametres(fr['push.rappel.evenement']!), contains('heure'));

      final String sql = File(
        'supabase/tranche5c_notifications_push.sql',
      ).readAsStringSync();
      expect(sql, contains('YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    });
  });

  // ==========================================================================
  // La colonne, et la migration
  // ==========================================================================
  group('La file et l’appareil', () {
    late String sql;

    setUpAll(
      () => sql = File(
        'supabase/tranche5c_notifications_push.sql',
      ).readAsStringSync(),
    );

    test('la langue est une colonne de l’appareil, pas du compte', () {
      // `push_tokens` a une ligne par appareil, et le réglage vit sur
      // l'appareil : les deux granularités coïncident. Une colonne sur
      // `profiles` reprendrait d'une main ce que le réglage donne de l'autre.
      expect(sql, contains('alter table public.push_tokens'));
      expect(sql, contains('add column if not exists langue text'));
      // Le mot « profiles » apparaît en commentaire — pour dire pourquoi la
      // colonne n'y est pas. C'est l'`alter table` qu'on cherche ici.
      expect(sql, isNot(contains('alter table public.profiles')));
    });

    test('la langue n’est jamais écrasée par un client plus ancien', () {
      // Un client qui ne connaît pas le paramètre enverrait `null`, et
      // effacerait la langue qu'un client à jour a posée sur le même appareil.
      expect(
        sql,
        contains('coalesce(excluded.langue, public.push_tokens.langue)'),
      );
    });

    test('les trois signatures changées portent leur `drop`', () {
      // **C'est l'invariant qui rend ce fichier rejouable**, et son absence a
      // été constatée : sans le `drop`, un rejeu de ce fichier sur une base
      // déjà à jour échoue en « cannot change return type of existing
      // function », et bloque toutes les migrations suivantes. C'est aussi ce
      // qui a ramené la traduction ici plutôt que dans un fichier séparé — un
      // second fichier n'aurait pas pu réparer celui-ci.
      for (final String drop in const <String>[
        'drop function if exists public.enregistrer_push(text, text, text, text);',
        'drop function if exists public.empiler_push(uuid, text, text, text, text);',
        'drop function if exists public.push_a_envoyer(integer);',
      ]) {
        expect(sql, contains(drop), reason: drop);
      }

      // Et le droit est reposé après : la tranche 7 ne se rejoue que si son
      // propre contenu change, donc elle ne rattraperait pas un `grant` perdu.
      expect(
        sql,
        contains(
          'public.enregistrer_push(text, text, text, text, text) '
          'to authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.push_a_envoyer(integer) '
          'to service_role',
        ),
      );
    });

    test('ses appelants viennent après, dans le manifeste', () {
      // Les tranches 5d, 8 et 12 appellent `empiler_push` avec sept
      // paramètres : la signature doit exister avant elles.
      final List<String> ordre = File('supabase/migrations.txt')
          .readAsLinesSync()
          .map((String l) => l.trim())
          .where((String l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();

      final int cinqC = ordre.indexOf('tranche5c_notifications_push.sql');
      expect(cinqC, isNot(-1));
      for (final String apres in const <String>[
        'tranche5d_rappels.sql',
        'tranche8_ecrans_invitation.sql',
        'tranche12_anniversaires.sql',
        'tranche7_durcissement.sql',
      ]) {
        expect(cinqC, lessThan(ordre.indexOf(apres)), reason: apres);
      }
    });

    test('le texte français reste, et c’est le filet', () {
      // Une fonction Edge en retard d'un déploiement — c'est arrivé, trois
      // mois — verrait une clé inconnue. Du français vaut mieux que rien.
      final String envoyeur = File(
        'supabase/functions/envoyer-push/traductions.ts',
      ).readAsStringSync();
      expect(envoyeur, contains('ligne.title ?? '));
      expect(envoyeur, contains('ligne.body ?? '));
    });
  });

  // ==========================================================================
  // Côté application : la langue voyage avec l'abonnement
  // ==========================================================================
  group('La langue voyage avec l’abonnement', () {
    testWidgets('elle part avec le réenregistrement du démarrage', (
      WidgetTester tester,
    ) async {
      final FakePushRepository push = FakePushRepository();
      await pumpAppLangue(
        tester,
        choix: const Locale('de'),
        push: push,
        statutPush: PushStatus.actif,
      );

      expect(push.registrations, greaterThan(0));
      expect(push.lastRegisteredLangue, 'de');
    });

    testWidgets('changer de langue réenregistre, et ne l’attend pas', (
      WidgetTester tester,
    ) async {
      // Sans cela, la notification suivante serait restée dans l'ancienne
      // langue jusqu'à la session d'après — et personne n'aurait relié les
      // deux.
      final FakePushRepository push = FakePushRepository();
      await pumpAppLangue(
        tester,
        choix: const Locale('fr'),
        push: push,
        statutPush: PushStatus.actif,
      );
      expect(push.lastRegisteredLangue, 'fr');

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(LanguageSheet),
          matching: find.text('Español'),
        ),
      );
      await tester.pumpAndSettle();

      expect(push.lastRegisteredLangue, 'es');
    });

    test('le code envoyé est l’un des quatre, toujours', () {
      // `resoudre` est la **même** fonction que celle du
      // `localeListResolutionCallback` : deux implémentations auraient fini
      // par servir deux langues au même appareil.
      for (final List<Locale> preferees in <List<Locale>>[
        <Locale>[const Locale('ja')],
        <Locale>[const Locale('es', 'MX')],
        <Locale>[],
      ]) {
        expect(
          LanguageStorage.languesPrisesEnCharge,
          contains(LanguageStorage.resoudre(preferees)),
        );
      }
    });
  });
}
