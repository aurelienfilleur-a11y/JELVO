import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/features/availability/models/availability.dart';

/// Le jour de la semaine se compte différemment des deux côtés.
///
/// Dart et l'application retiennent l'ISO — 1 = lundi … 7 = dimanche. La base
/// retient `extract(dow)` — 0 = dimanche … 6 = samedi —, et le fait tenir par
/// une contrainte : `availabilities_weekday_check : CHECK (weekday >= 0 AND
/// weekday <= 6)`.
///
/// Les deux conventions **coïncident du lundi au samedi**. Seul le dimanche
/// les sépare, ce qui est précisément ce qui rend l'écart facile à ne pas
/// voir : six cas sur sept passent avec une conversion absente.
void main() {
  group('Conversion du jour de la semaine', () {
    test('lundi à samedi sont identiques dans les deux sens', () {
      for (int iso = DateTime.monday; iso <= DateTime.saturday; iso++) {
        expect(AvailabilitySlot.jourBaseDepuisIso(iso), iso);
        expect(AvailabilitySlot.jourIsoDepuisBase(iso), iso);
      }
    });

    test('le dimanche vaut 7 côté Dart et 0 côté base', () {
      expect(AvailabilitySlot.jourBaseDepuisIso(DateTime.sunday), 0);
      expect(AvailabilitySlot.jourIsoDepuisBase(0), DateTime.sunday);
    });

    test('aucune valeur écrite ne sort de 0..6', () {
      for (int iso = 1; iso <= 7; iso++) {
        final int dow = AvailabilitySlot.jourBaseDepuisIso(iso)!;
        expect(dow, inInclusiveRange(0, 6));
      }
    });

    test('la conversion est réversible dans les deux sens', () {
      for (int iso = 1; iso <= 7; iso++) {
        expect(
          AvailabilitySlot.jourIsoDepuisBase(
            AvailabilitySlot.jourBaseDepuisIso(iso),
          ),
          iso,
        );
      }
      for (int dow = 0; dow <= 6; dow++) {
        expect(
          AvailabilitySlot.jourBaseDepuisIso(
            AvailabilitySlot.jourIsoDepuisBase(dow),
          ),
          dow,
        );
      }
    });

    test('`null` reste `null` — une exception n’a pas de jour', () {
      expect(AvailabilitySlot.jourBaseDepuisIso(null), isNull);
      expect(AvailabilitySlot.jourIsoDepuisBase(null), isNull);
    });
  });

  test('une ligne de la base est relue en convention ISO', () {
    final AvailabilitySlot dimanche =
        AvailabilitySlot.fromRow(<String, dynamic>{
          'id': 'd1',
          'kind': 'recurring',
          'status': 'available',
          'start_time': '09:00:00',
          'end_time': '12:30:00',
          'weekday': 0,
          'on_date': null,
        });

    expect(dimanche.weekday, DateTime.sunday);
    expect(AvailabilitySlot.nomDuJour(dimanche.weekday!), 'Dimanche');
    expect(dimanche.plage, '09:00 – 12:30');
  });
}
