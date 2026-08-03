/// Source de temps injectable.
///
/// Les dépôts et providers ne doivent jamais appeler `DateTime.now()`
/// directement : en passant par un [Clock], les tests peuvent figer la date et
/// vérifier des libellés comme « Aujourd'hui » ou « En retard ».
abstract interface class Clock {
  DateTime now();
}

/// Horloge réelle, utilisée en production.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Horloge figée, destinée aux tests et aux captures d'écran.
class FixedClock implements Clock {
  const FixedClock(this._value);

  final DateTime _value;

  @override
  DateTime now() => _value;
}
