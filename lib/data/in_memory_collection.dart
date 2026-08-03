import 'dart:async';

/// Collection en mémoire observable, indexée par identifiant.
///
/// Elle tient lieu de source de données locale tant qu'aucun backend n'est
/// branché : les dépôts des features s'appuient dessus et exposent un
/// `Stream`, si bien que le passage à une vraie base ou à une API ne changera
/// que l'implémentation des dépôts, pas les providers ni les écrans.
class InMemoryCollection<T> {
  InMemoryCollection({
    required this._idOf,
    Iterable<T> seed = const <Never>[],
  }) {
    for (final T item in seed) {
      _items[_idOf(item)] = item;
    }
  }

  /// Extrait l'identifiant d'un élément ; fourni par l'appelant pour que la
  /// collection n'impose aucune interface aux modèles.
  final String Function(T item) _idOf;
  final Map<String, T> _items = <String, T>{};
  final StreamController<List<T>> _controller =
      StreamController<List<T>>.broadcast();

  /// Instantané non modifiable du contenu courant.
  List<T> get items => List<T>.unmodifiable(_items.values);

  /// Flux émettant l'état courant à l'abonnement, puis à chaque modification.
  Stream<List<T>> watch() async* {
    yield items;
    yield* _controller.stream;
  }

  T? findById(String id) => _items[id];

  /// Insère ou remplace un élément, puis notifie les abonnés.
  void upsert(T item) {
    _items[_idOf(item)] = item;
    _emit();
  }

  void upsertAll(Iterable<T> values) {
    for (final T item in values) {
      _items[_idOf(item)] = item;
    }
    _emit();
  }

  void remove(String id) {
    if (_items.remove(id) != null) _emit();
  }

  /// Applique [update] à l'élément [id] s'il existe. Sans effet sinon.
  void mutate(String id, T Function(T current) update) {
    final T? current = _items[id];
    if (current == null) return;
    _items[id] = update(current);
    _emit();
  }

  void dispose() => _controller.close();

  void _emit() {
    if (!_controller.isClosed) _controller.add(items);
  }
}
