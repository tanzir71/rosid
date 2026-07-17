import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';

class StartupCleanupRepository {
  const StartupCleanupRepository(this.database, this.fileStore);

  final AppDatabase database;
  final PrivateFileStore fileStore;

  Future<int> purgeUnreviewedScans() async {
    await fileStore.deleteStaleExportArtifacts();
    final query = database.select(database.scans).join([
      leftOuterJoin(
        database.receipts,
        database.receipts.scanId.equalsExp(database.scans.id),
      ),
      leftOuterJoin(
        database.documents,
        database.documents.scanId.equalsExp(database.scans.id),
      ),
    ])..where(database.receipts.id.isNull() & database.documents.id.isNull());
    final abandoned = (await query.get())
        .map((row) => row.readTable(database.scans))
        .toList(growable: false);

    for (final scan in abandoned) {
      final pages = await (database.select(
        database.scanPages,
      )..where((row) => row.scanId.equals(scan.id))).get();
      await fileStore.deleteScanArtifacts(
        scanId: scan.id,
        knownPaths: [
          scan.imagePath,
          if (scan.thumbPath != null) scan.thumbPath!,
          for (final page in pages) ...[
            page.imagePath,
            if (page.processedPath != null) page.processedPath!,
          ],
        ],
      );
      await database.transaction(() async {
        await (database.delete(
          database.scans,
        )..where((row) => row.id.equals(scan.id))).go();
        await database.customStatement(
          'DELETE FROM scan_search WHERE scan_id = ?',
          [scan.id],
        );
      });
    }
    await database.customStatement(
      'DELETE FROM scan_search '
      'WHERE scan_id NOT IN (SELECT id FROM scans)',
    );
    final liveScans = await database.select(database.scans).get();
    await fileStore.deleteArtifactsWithoutScanRows(
      liveScans.map((scan) => scan.id),
    );
    return abandoned.length;
  }
}

final startupCleanupRepositoryProvider = Provider<StartupCleanupRepository>(
  (ref) => StartupCleanupRepository(
    ref.watch(databaseProvider),
    ref.watch(privateFileStoreProvider),
  ),
);

final startupCleanupProvider = FutureProvider<int>(
  (ref) => ref.watch(startupCleanupRepositoryProvider).purgeUnreviewedScans(),
);
