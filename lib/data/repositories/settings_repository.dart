import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:uuid/uuid.dart';

class SettingsRepository {
  const SettingsRepository(this.database);

  final AppDatabase database;

  Future<List<Category>> categories() {
    return (database.select(
      database.categories,
    )..orderBy([(row) => OrderingTerm.asc(row.nameEn)])).get();
  }

  Future<void> addCategory(String nameEn, String nameBn) {
    return database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Uuid().v7(),
            nameEn: nameEn,
            nameBn: nameBn,
            icon: 'category',
          ),
        );
  }

  Future<void> updateCategory(Category category, String nameEn, String nameBn) {
    return (database.update(
      database.categories,
    )..where((row) => row.id.equals(category.id))).write(
      CategoriesCompanion(nameEn: Value(nameEn), nameBn: Value(nameBn)),
    );
  }

  Future<void> deleteCategory(Category category) async {
    if (category.isDefault) return;
    await (database.delete(
      database.categories,
    )..where((row) => row.id.equals(category.id))).go();
  }

  Future<List<String>> deleteAllData() async {
    final pages = await database.select(database.scanPages).get();
    await database.transaction(() async {
      await database.delete(database.scans).go();
      await (database.delete(
        database.categories,
      )..where((row) => row.isDefault.equals(false))).go();
      await database.delete(database.tags).go();
      await database.customStatement('DELETE FROM scan_search');
    });
    return [
      for (final page in pages) ...[
        page.imagePath,
        if (page.processedPath != null) page.processedPath!,
      ],
    ];
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
