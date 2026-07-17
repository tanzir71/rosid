import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';

class ScanRepository {
  const ScanRepository(this.database);

  final AppDatabase database;

  Future<void> createScan({
    required String id,
    required ScanMode mode,
    required String imagePath,
    required String langHint,
    required DateTime createdAt,
  }) async {
    await database.transaction(() async {
      await database
          .into(database.scans)
          .insert(
            ScansCompanion.insert(
              id: id,
              type: mode.name,
              imagePath: imagePath,
              langHint: Value(langHint),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      await addPage(
        id: '$id-page-0',
        scanId: id,
        imagePath: imagePath,
        pageIndex: 0,
      );
    });
  }

  Future<void> addPage({
    required String id,
    required String scanId,
    required String imagePath,
    required int pageIndex,
  }) async {
    await database
        .into(database.scanPages)
        .insert(
          ScanPagesCompanion.insert(
            id: id,
            scanId: scanId,
            imagePath: imagePath,
            pageIndex: pageIndex,
          ),
        );
    await (database.update(database.scans)
          ..where((row) => row.id.equals(scanId)))
        .write(ScansCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> setProcessedPagePath({
    required String pageId,
    required String path,
  }) {
    return (database.update(database.scanPages)
          ..where((row) => row.id.equals(pageId)))
        .write(ScanPagesCompanion(processedPath: Value(path)));
  }

  Stream<List<Scan>> watchScans() {
    return (database.select(
      database.scans,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).watch();
  }

  Future<Scan> getScan(String id) {
    return (database.select(
      database.scans,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<List<ScanPage>> getPages(String scanId) {
    return (database.select(database.scanPages)
          ..where((row) => row.scanId.equals(scanId))
          ..orderBy([(row) => OrderingTerm.asc(row.pageIndex)]))
        .get();
  }

  Future<void> updateOcr({
    required String scanId,
    required String rawText,
    required String engine,
    required double meanConfidence,
  }) async {
    await (database.update(
      database.scans,
    )..where((row) => row.id.equals(scanId))).write(
      ScansCompanion(
        ocrRawText: Value(rawText),
        ocrEngine: Value(engine),
        ocrMeanConfidence: Value(meanConfidence),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await database.indexScan(scanId: scanId, text: [rawText]);
  }

  Future<void> deleteScan(String scanId) async {
    await (database.delete(
      database.scans,
    )..where((row) => row.id.equals(scanId))).go();
    await database.customStatement(
      'DELETE FROM scan_search WHERE scan_id = ?',
      [scanId],
    );
  }
}

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(ref.watch(databaseProvider)),
);
