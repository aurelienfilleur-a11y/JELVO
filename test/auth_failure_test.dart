import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/features/auth/models/auth_failure.dart';
import 'package:jelvo/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduction des erreurs serveur, sans widget.
///
/// Le repli « Réessayez dans un instant » convient à une panne passagère et à
/// rien d'autre. Servi pour une colonne absente, il envoie chercher le défaut
/// du mauvais côté — c'est arrivé sur `profiles.avatar_preset`, dont la
/// migration n'était jamais passée.
void main() {
  // Le message n'est plus porté par l'échec : il se déduit du `kind`, dans la
  // langue de l'appareil. Le test en charge donc une — le français, langue de
  // référence — plutôt que de figer une phrase.
  late AppTexts t;
  setUpAll(() async => t = await AppTexts.delegate.load(const Locale('fr')));

  group('Colonne absente', () {
    test('PGRST204 ne dit pas de réessayer dans un instant', () {
      final AuthFailure echec = AuthFailure.from(
        const PostgrestException(
          message:
              "Could not find the 'avatar_preset' column of 'profiles' "
              'in the schema cache',
          code: 'PGRST204',
        ),
      );

      expect(echec.kind, AuthFailureKind.schemaOutdated);
      expect(echec.message(t), contains('mise à jour de la base'));
      expect(echec.message(t), isNot(contains('dans un instant')));
    });

    test('42703 — colonne inexistante — donne le même message', () {
      final AuthFailure echec = AuthFailure.from(
        const PostgrestException(
          message:
              'column "avatar_preset" of relation "profiles" '
              'does not exist',
          code: '42703',
        ),
      );
      expect(echec.kind, AuthFailureKind.schemaOutdated);
    });

    test('le détail technique reste renseigné', () {
      // Il n'atteint l'écran qu'en mode diagnostic, mais il doit exister :
      // c'est lui qui nomme la colonne en cause.
      final AuthFailure echec = AuthFailure.from(
        const PostgrestException(message: 'boom', code: 'PGRST204'),
      );
      expect(echec.technical, contains('PGRST204'));
    });
  });

  group('Les autres cas ne bougent pas', () {
    test('23505 reste « pseudo pris »', () {
      final AuthFailure echec = AuthFailure.from(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(echec.kind, AuthFailureKind.pseudoTaken);
    });

    test('42501 reste un refus de droits', () {
      final AuthFailure echec = AuthFailure.from(
        const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      );
      expect(echec.kind, AuthFailureKind.forbidden);
    });

    // Le repli d'une écriture PostgREST dit « n'ont pas pu être
    // enregistrées », et il porte désormais son propre `kind` : le message se
    // déduisant du `kind`, le laisser tomber dans `unknown` aurait servi
    // « une erreur est survenue » là où l'on sait que c'est une écriture.
    test('un code inconnu garde le repli d’écriture', () {
      final AuthFailure echec = AuthFailure.from(
        const PostgrestException(message: 'inattendu', code: '99999'),
      );
      expect(echec.kind, AuthFailureKind.notSaved);
      expect(echec.message(t), contains('dans un instant'));
      expect(echec.message(t), isNot(contains('mise à jour de la base')));
    });
  });
}
