import 'dart:async';

/// Tables whose mutations other parts of the app may want to react to.
enum DbTable {
  users,
  accountingPeriods,
  accounts,
  incomeCategories,
  expenseCategories,
  transactions,
  transfers,
}

/// A tiny in-app pub/sub used in place of drift's generated reactive
/// streams (see plan note: drift_dev/build_runner conflicts with the
/// current Flutter stable Dart SDK). Every DAO write calls [notify] after
/// its transaction commits; Riverpod `StreamProvider`s listen via
/// [watch] and re-run their query whenever the relevant table changes.
class DbChangeNotifier {
  DbChangeNotifier._internal();
  static final DbChangeNotifier instance = DbChangeNotifier._internal();

  final StreamController<DbTable> _controller =
      StreamController<DbTable>.broadcast();

  void notify(DbTable table) {
    if (!_controller.isClosed) {
      _controller.add(table);
    }
  }

  void notifyAll(Iterable<DbTable> tables) {
    for (final t in tables) {
      notify(t);
    }
  }

  /// Emits whenever [table] changes, plus one immediate synthetic event
  /// so subscribers can do an initial load without a separate call.
  Stream<void> watch(DbTable table) async* {
    yield 0;
    yield* _controller.stream.where((t) => t == table).map((_) => 0);
  }

  /// Emits whenever any of [tables] changes, plus one immediate event.
  Stream<void> watchAny(Iterable<DbTable> tables) async* {
    yield 0;
    final set = tables.toSet();
    yield* _controller.stream.where(set.contains).map((_) => 0);
  }
}
