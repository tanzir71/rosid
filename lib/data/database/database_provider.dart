import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';

class DatabaseEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final databaseEpochProvider = NotifierProvider<DatabaseEpochNotifier, int>(
  DatabaseEpochNotifier.new,
);

final databaseProvider = Provider<AppDatabase>((ref) {
  ref.watch(databaseEpochProvider);
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
