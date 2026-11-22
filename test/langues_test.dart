import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/language_storage.dart';
import 'package:jelvo/features/home/providers/home_providers.dart';
import 'package:jelvo/features/profile/widgets/language_sheet.dart';
import 'package:jelvo/router/app_bottom_nav.dart';

import 'langues_harnais.dart';

/// Les écrans ouverts dans les quatre langues pour y chercher un
/// débordement. Les identifiants sont ceux des faux dépôts.
const List<String> _ecrans = <String>[
  '/',
  '/groupes',
  '/groupes/g1',
  '/groupes/g1/discussion',
  '/groupes/nouveau',
  '/groupes/g1/modifier',
  '/calendrier',
  '/contacts',
  '/contacts/ajouter',
  '/taches',
  '/taches/t1',
  '/taches/t1/attribution',
  '/evenements/e1',
  '/evenements/e1/invitation',
  '/invitations',
  '/invitations/i1',
  '/creer',
  '/profil',
  '/profil/modifier',
  '/profil/avatar',
  '/profil/qr',
  '/parametres',
  '/parametres/mot-de-passe',
  '/parametres/a-propos',
  '/notifications',
  '/disponibilites',
  '/personnes/u2',
];

/// Les clés dont la valeur est **la même dans deux langues sans que ce soit
/// un oubli** : le mot s'écrit pareil, ou la chaîne n'est qu'un gabarit.
const Set<String> _identiquesALaLettre = <String>{
  'coreParticipantCount', // « participant » s'écrit pareil en anglais
  'authMessageDiagnosticRaw', // « diagnostic » aussi
};

Map<String, Object?> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, Object?>;

Future<void> _ouvrirParametres(WidgetTester tester, String profil) async {
  await tester.tap(find.byTooltip(profil));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(IconButton).last);
  await tester.pumpAndSettle();
}

Locale _localeRendue(WidgetTester tester) =>
    Localizations.localeOf(tester.element(find.byType(Scaffold).first));

void main() {
  setUpAll(() => initializeDateFormatting());

  // ==========================================================================
  // Le contrat entre les quatre fichiers
  // ==========================================================================
  group('Les quatre fichiers ARB', () {
    late Map<String, Object?> fr;

    setUpAll(() => fr = _arb('fr'));

    /// Retire les branches ICU — `one{…}`, `other{…}`, `=0{…}` — avec leur
    /// corps, accolades imbriquées comprises.
    ///
    /// **Sans cela, le corps d'une branche passe pour un paramètre** dès
    /// qu'il est un mot ASCII d'un seul tenant : `one{task}` se lit comme
    /// `{task}`. Le défaut ne se voyait pas tant que les branches françaises
    /// portaient un accent ou une espace — `one{tâche}` y échappait par
    /// accident, `\w` ne couvrant pas `â` en Dart. Un pluriel du mot seul,
    /// comme `{count, plural, one{tâche} other{tâches}}`, l'a mis au jour :
    /// le français ne rapportait que `count`, l'anglais `count`, `task` et
    /// `tasks`, et la comparaison échouait sur deux valeurs toutes deux
    /// justes.
    String sansBranches(String valeur) {
      final RegExp debut = RegExp(
        r'(?<!\w)(?:zero|one|two|few|many|other|=\d+)\s*\{',
      );
      String reste = valeur;
      while (true) {
        final RegExpMatch? m = debut.firstMatch(reste);
        if (m == null) return reste;
        int profondeur = 1;
        int j = m.end;
        while (j < reste.length && profondeur > 0) {
          if (reste[j] == '{') profondeur++;
          if (reste[j] == '}') profondeur--;
          j++;
        }
        reste = reste.substring(0, m.start) + reste.substring(j);
      }
    }

    /// `{nom}` et `{nom, plural` — jamais le corps d'une branche ICU, où
    /// `=0{Aucun événement}` ressemble à un paramètre nommé `Aucun`.
    Set<String> parametres(String valeur) =>
        RegExp(r'\{(\w+)\s*(?:\}|,\s*plural)')
            .allMatches(sansBranches(valeur))
            .map((RegExpMatch m) => m.group(1)!)
            .toSet();

    Set<String> branchesExplicites(String valeur) => RegExp(r'=\d+\s*\{')
        .allMatches(valeur)
        .map((RegExpMatch m) => m.group(0)!.replaceAll(RegExp(r'\s'), ''))
        .toSet();

    Iterable<String> cles(Map<String, Object?> arb) =>
        arb.keys.where((String k) => !k.startsWith('@'));

    test('le français est la référence, et il n’est pas vide', () {
      // Le nombre est écrit à la main : une clé perdue par un script de
      // migration ne proteste pas toute seule.
      expect(cles(fr).length, greaterThanOrEqualTo(857));
    });

    for (final String code in <String>['en', 'es', 'de']) {
      test('$code porte exactement les mêmes clés que le français', () {
        final Map<String, Object?> autre = _arb(code);
        expect(
          cles(autre).toSet(),
          cles(fr).toSet(),
          reason:
              'Une clé ajoutée au français sans traduction se verrait à '
              'l’écran de quelqu’un, et nulle part avant.',
        );
      });

      test('$code garde les mêmes paramètres et les mêmes branches', () {
        final Map<String, Object?> autre = _arb(code);
        for (final String k in cles(fr)) {
          final String a = fr[k]! as String;
          final String b = autre[k]! as String;
          expect(
            parametres(b),
            parametres(a),
            reason:
                '$code/$k : un paramètre perdu lève à la génération, '
                'un paramètre renommé ne lève pas et n’affiche rien.',
          );
          // Une branche `=0` dit « Aucun événement » là où la catégorie
          // `other` dirait « 0 événement ». La perdre dans une seule langue
          // ne se verrait qu'à zéro, c'est-à-dire sur un compte neuf.
          expect(
            branchesExplicites(b),
            branchesExplicites(a),
            reason: '$code/$k',
          );
          expect(
            b.contains(', plural,'),
            a.contains(', plural,'),
            reason: '$code/$k : un pluriel aplati en phrase fixe.',
          );
        }
      });

      test('$code ne laisse aucune valeur française en place', () {
        final Map<String, Object?> autre = _arb(code);
        // Une valeur identique est **parfois** juste : « Description » en
        // anglais, « Admin » partout, un gabarit qui n'a pas un mot à lui.
        // Les noms de paramètres sont donc retirés avant de compter — sans
        // quoi `{valeur} {libelle}, {detail}` passerait pour une phrase.
        final List<String> suspectes = <String>[];
        for (final String k in cles(fr)) {
          final String a = fr[k]! as String;
          if (a != autre[k]) continue;
          if (_identiquesALaLettre.contains(k)) continue;
          final String nu = a.replaceAll(RegExp(r'\{[^}]*\}'), ' ');
          final int mots = RegExp(r'[^\W\d_]{2,}').allMatches(nu).length;
          if (mots >= 3) suspectes.add(k);
        }
        expect(suspectes, isEmpty);
      });
    }
  });

  // ==========================================================================
  // Le réglage, sans widget
  // ==========================================================================
  group('Le réglage de langue', () {
    test('rien de choisi veut dire « celle du téléphone »', () {
      expect(LanguageStorage.depuisJeton(null), isNull);
      expect(LanguageStorage.depuisJeton('systeme'), isNull);
      expect(LanguageStorage.jeton(null), 'systeme');
    });

    test('ce qui est écrit est un code, pas un rang', () {
      // Un index se décalerait le jour où une cinquième langue s'ajoute, et
      // l'appareil se réveillerait dans une langue qu'il n'a pas choisie.
      for (final Locale langue in LanguageStorage.languesPrisesEnCharge) {
        expect(LanguageStorage.jeton(langue), langue.languageCode);
        expect(LanguageStorage.depuisJeton(langue.languageCode), langue);
      }
    });

    test('un stockage abîmé suit le téléphone plutôt que de lever', () {
      expect(LanguageStorage.depuisJeton('kl'), isNull);
      expect(LanguageStorage.depuisJeton(''), isNull);
    });

    test('la région ne compte pas : es_MX donne l’espagnol', () {
      // Exiger la région reviendrait à servir l'anglais à tout le Mexique
      // pour une variante que Jelvo ne distingue pas.
      expect(
        LanguageStorage.resoudre(<Locale>[const Locale('es', 'MX')]),
        const Locale('es'),
      );
      expect(
        LanguageStorage.resoudre(<Locale>[const Locale('de', 'AT')]),
        const Locale('de'),
      );
    });

    test('une langue inconnue retombe sur l’anglais, pas sur le français', () {
      // Quelqu'un dont le téléphone est en japonais a plus de chances de lire
      // l'anglais, bien que le français soit la langue de référence du projet.
      expect(
        LanguageStorage.resoudre(<Locale>[const Locale('ja')]),
        const Locale('en'),
      );
      expect(LanguageStorage.resoudre(null), const Locale('en'));
      expect(LanguageStorage.langueParDefaut, const Locale('en'));
    });

    test('la seconde préférence est lue quand la première est inconnue', () {
      expect(
        LanguageStorage.resoudre(<Locale>[
          const Locale('ja'),
          const Locale('fr', 'CA'),
        ]),
        const Locale('fr'),
      );
    });

    test('la clé est celle du stockage, et elle ne change pas', () {
      // En changer réveillerait tout le monde dans la langue du téléphone.
      expect(LanguageStorage.cle, 'jelvo-langue');
    });
  });

  // ==========================================================================
  // L'écran
  // ==========================================================================
  group('L’application suit la langue', () {
    testWidgets('sans choix, elle suit le téléphone', (
      WidgetTester tester,
    ) async {
      await pumpAppLangue(tester, telephone: <Locale>[const Locale('de')]);
      expect(_localeRendue(tester), const Locale('de'));
      expect(find.text('Start'), findsWidgets);
    });

    testWidgets('un téléphone hors des quatre donne l’anglais', (
      WidgetTester tester,
    ) async {
      await pumpAppLangue(tester, telephone: <Locale>[const Locale('ja')]);
      expect(_localeRendue(tester), const Locale('en'));
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('un choix enregistré l’emporte sur le téléphone', (
      WidgetTester tester,
    ) async {
      // Lu dans `main()` avant `runApp` : rien ne doit s'ouvrir en allemand
      // pour basculer ensuite.
      await pumpAppLangue(
        tester,
        choix: const Locale('es'),
        telephone: <Locale>[const Locale('de')],
      );
      expect(_localeRendue(tester), const Locale('es'));
      expect(find.text('Inicio'), findsWidgets);
    });

    testWidgets('« Langue » annonce le choix courant, dans sa langue', (
      WidgetTester tester,
    ) async {
      await pumpAppLangue(tester, choix: const Locale('fr'));
      await _ouvrirParametres(tester, 'Profil');

      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('sans choix, la ligne dit qu’elle suit le téléphone', (
      WidgetTester tester,
    ) async {
      await pumpAppLangue(tester, telephone: <Locale>[const Locale('fr')]);
      await _ouvrirParametres(tester, 'Profil');

      // Et non « Français » : ce n'est pas un choix, c'est une délégation —
      // le jour où le téléphone passe à l'espagnol, l'application suit.
      expect(find.text('Celle du téléphone'), findsOneWidget);
    });

    testWidgets('la feuille nomme chaque langue dans sa propre langue', (
      WidgetTester tester,
    ) async {
      await pumpAppLangue(tester, choix: const Locale('fr'));
      await _ouvrirParametres(tester, 'Profil');
      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();

      // « German » ne sert à rien à quelqu'un qui cherche l'allemand sans
      // parler anglais.
      for (final String natif in const <String>[
        'Français',
        'Deutsch',
        'English',
        'Español',
      ]) {
        expect(find.text(natif), findsWidgets, reason: natif);
      }
      // Le réglage ne vaut que sur cet appareil, comme l'apparence.
      expect(find.textContaining('cet appareil'), findsOneWidget);
    });

    testWidgets('choisir l’allemand bascule l’écran et s’enregistre', (
      WidgetTester tester,
    ) async {
      final LanguageStorage stockage = await pumpAppLangue(
        tester,
        choix: const Locale('fr'),
      );
      await _ouvrirParametres(tester, 'Profil');
      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(LanguageSheet),
          matching: find.text('Deutsch'),
        ),
      );
      await tester.pumpAndSettle();

      // L'écran suit le doigt, sans bouton de validation : une langue se juge
      // en la voyant.
      expect(_localeRendue(tester), const Locale('de'));
      expect(stockage.choix, const Locale('de'));
      expect(find.text('Einstellungen'), findsWidgets);
    });

    testWidgets('revenir à « Celle du téléphone » rend la main au système', (
      WidgetTester tester,
    ) async {
      final LanguageStorage stockage = await pumpAppLangue(
        tester,
        choix: const Locale('es'),
        telephone: <Locale>[const Locale('en')],
      );
      await _ouvrirParametres(tester, 'Perfil');
      await tester.tap(find.text('Idioma'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(LanguageSheet),
          matching: find.text('El del teléfono'),
        ),
      );
      await tester.pumpAndSettle();

      expect(stockage.choix, isNull);
      expect(_localeRendue(tester), const Locale('en'));
    });
  });

  // ==========================================================================
  // Ce que la langue change, et qui n'est pas du texte
  // ==========================================================================
  group('Les dates et les heures suivent la langue', () {
    late Map<String, AppTexts> textes;

    setUpAll(() async {
      textes = <String, AppTexts>{
        for (final Locale l in LanguageStorage.languesPrisesEnCharge)
          l.languageCode: await AppTexts.delegate.load(l),
      };
    });

    test('l’heure est en 24 h en français, en 12 h en anglais', () {
      // C'est le squelette `jm` qui le sait, et aucun gabarit littéral ne
      // l'aurait su : `'HH:mm'` aurait donné « 14:00 » à un anglophone.
      final DateTime quatorzeHeures = DateTime(2026, 8, 5, 14);
      expect(AppDates.time(quatorzeHeures, textes['fr']!), '14:00');
      expect(AppDates.time(quatorzeHeures, textes['de']!), '14:00');
      // L'espace qui précède « PM » est une espace fine insécable dans les
      // données CLDR récentes : la comparaison porte sur les deux morceaux.
      final String enAnglais = AppDates.time(quatorzeHeures, textes['en']!);
      expect(enAnglais, startsWith('2:00'));
      expect(enAnglais, endsWith('PM'));
    });

    test('la date complète se construit dans l’ordre de la langue', () {
      final DateTime jour = DateTime(2026, 8, 5);
      expect(AppDates.fullDate(jour, textes['fr']!), contains('août'));
      expect(AppDates.fullDate(jour, textes['en']!), contains('August'));
      expect(AppDates.fullDate(jour, textes['de']!), contains('August'));
      // L'espagnol intercale « de » — un gabarit littéral aurait écrit
      // « miércoles 5 agosto », qui ne s'écrit pas.
      expect(AppDates.fullDate(jour, textes['es']!), contains(' de '));
    });

    test('le mois sans année ne porte jamais d’année', () {
      for (final AppTexts t in textes.values) {
        expect(
          AppDates.dateSansAnnee(DateTime(2024, 2, 29), t),
          isNot(contains('2024')),
        );
      }
    });
  });

  group('La salutation', () {
    test('le samedi et le dimanche, c’est « Bon week-end »', () async {
      final AppTexts t = await AppTexts.delegate.load(const Locale('fr'));
      for (final DateTime jour in <DateTime>[
        DateTime(2026, 8, 8, 10), // samedi
        DateTime(2026, 8, 9, 15), // dimanche
      ]) {
        final ProviderContainer conteneur = ProviderContainer(
          overrides: [clockProvider.overrideWithValue(FixedClock(jour))],
        );
        addTearDown(conteneur.dispose);
        expect(conteneur.read(greetingProvider(t)), MomentDuJour.weekEnd);
        expect(MomentDuJour.weekEnd.salutation(t), 'Bon week-end');
      }
    });

    test('le soir l’emporte sur le week-end', () async {
      // « Bon week-end » à 23 h un samedi serait étrange, « Bonsoir » est
      // juste tous les jours.
      final AppTexts t = await AppTexts.delegate.load(const Locale('fr'));
      final ProviderContainer conteneur = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 8, 8, 23))),
        ],
      );
      addTearDown(conteneur.dispose);
      expect(conteneur.read(greetingProvider(t)), MomentDuJour.soir);
    });

    test('aucune fête nationale n’est annoncée, dans aucune langue', () {
      // Une fête dépend du **pays**, pas de la langue : l'espagnol couvre
      // vingt pays, et Jelvo ne sait pas où vous êtes. Le contrôle est donc
      // sur l'énumération : quatre moments, et pas un cinquième.
      expect(MomentDuJour.values.length, 4);
      expect(MomentDuJour.values, isNot(contains(null)));
    });

    test('l’après-midi espagnol commence plus tard', () async {
      // *buenas tardes* commence après le déjeuner. Les bornes sont une
      // donnée de langue, et c'est la seule raison pour laquelle le provider
      // prend la langue.
      final AppTexts es = await AppTexts.delegate.load(const Locale('es'));
      final AppTexts fr = await AppTexts.delegate.load(const Locale('fr'));
      final ProviderContainer conteneur = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 8, 5, 13))),
        ],
      );
      addTearDown(conteneur.dispose);
      expect(conteneur.read(greetingProvider(fr)), MomentDuJour.apresMidi);
      expect(conteneur.read(greetingProvider(es)), MomentDuJour.matin);
    });
  });

  // ==========================================================================
  // Les langues longues
  // ==========================================================================
  group('Rien ne déborde dans les quatre langues', () {
    // **Un débordement n'est pas une exception qu'on rattrape** : Flutter le
    // consigne par `FlutterError.reportError`, et le harnais fait échouer le
    // test à moins qu'on le prenne. Ouvrir chaque écran dans chaque langue
    // est donc le contrôle lui-même — et le message nomme le fichier et la
    // ligne du widget fautif, ce qu'aucune relecture ne donne.
    //
    // 360 dp est la largeur minimale que le projet se donne. C'est ce
    // balayage qui a trouvé quatre défauts, dont **deux antérieurs à la
    // traduction** : le « Tout voir » d'un `SectionHeader` et les deux
    // boutons d'un créneau débordaient déjà en français.
    for (final Locale langue in LanguageStorage.languesPrisesEnCharge) {
      testWidgets('les quatre onglets tiennent en ${langue.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpAppLangue(
          tester,
          choix: langue,
          taille: const Size(360, 1600),
        );

        // L'onglet où l'on se trouve porte `selectedIcon` : l'ordre 1, 2, 3,
        // 0 fait que la cible n'est jamais l'onglet courant.
        for (final int i in const <int>[1, 2, 3, 0]) {
          await tester.tap(find.byIcon(AppBottomNav.destinations[i].icon));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'onglet $i en ${langue.languageCode}',
          );
        }
      });

      for (final String chemin in _ecrans) {
        testWidgets('$chemin tient en ${langue.languageCode}', (
          WidgetTester tester,
        ) async {
          await pumpAppLangue(
            tester,
            choix: langue,
            taille: const Size(360, 1600),
          );
          // Par le routeur plutôt que par des touches : un écran empilé à
          // cinq gestes de l'accueil serait autrement hors du balayage, et
          // c'est là que les libellés les plus longs se trouvent.
          GoRouter.of(tester.element(find.byType(Scaffold).first)).go(chemin);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$chemin en ${langue.languageCode}',
          );
        });
      }
    }
  });
}
