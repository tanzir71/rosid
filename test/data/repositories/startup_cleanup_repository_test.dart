import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/data/repositories/startup_cleanup_repository.dart';

void main() {
  test(
    'restart purges interrupted scans and preserves completed records',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'rosid_restart_cleanup_',
      );
      final databaseFile = File(
        '${root.path}${Platform.pathSeparator}rosid-test.sqlite',
      );
      final files = PrivateFileStore(rootDirectory: root);
      final source = File('${root.path}${Platform.pathSeparator}source.jpg');
      await source.writeAsBytes([1, 2, 3]);
      final staleCsv = File(await files.createExportPath('stale.csv'));
      final stalePdf = File(await files.createExportPath('stale.pdf'));
      final staleShareCopy = File(
        '${root.path}${Platform.pathSeparator}share_plus'
        '${Platform.pathSeparator}shared.pdf',
      );
      await staleCsv.writeAsString('private expense data');
      await stalePdf.writeAsBytes([9, 8, 7]);
      await staleShareCopy.parent.create(recursive: true);
      await staleShareCopy.writeAsBytes([6, 5, 4]);

      var database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      var scans = ScanRepository(database);
      final abandonedRaw = await files.persistCapture(
        sourcePath: source.path,
        scanId: 'abandoned-scan',
        pageIndex: 0,
      );
      await scans.createScan(
        id: 'abandoned-scan',
        mode: ScanMode.document,
        imagePath: abandonedRaw,
        langHint: 'automatic',
        createdAt: DateTime(2026, 7, 17),
      );
      final abandonedColor = await files.writeProcessed(
        bytes: [4],
        scanId: 'abandoned-scan',
        pageIndex: 0,
        suffix: 'color_g3',
      );
      final abandonedBinary = await files.writeProcessed(
        bytes: [5],
        scanId: 'abandoned-scan',
        pageIndex: 0,
        suffix: 'bw_g3',
      );
      final abandonedThumbnail = await files.writeThumbnail(
        bytes: [6],
        scanId: 'abandoned-scan',
        generation: 3,
      );
      final rowlessRaw = await files.persistCapture(
        sourcePath: source.path,
        scanId: 'rowless-scan',
        pageIndex: 0,
      );
      final rowlessProcessed = await files.writeProcessed(
        bytes: [7],
        scanId: 'rowless-scan',
        pageIndex: 0,
        suffix: 'bw_g1',
      );
      final rowlessThumbnail = await files.writeThumbnail(
        bytes: [8],
        scanId: 'rowless-scan',
        generation: 1,
      );
      await scans.setProcessedPagePath(
        pageId: 'abandoned-scan-page-0',
        path: abandonedColor,
      );
      await scans.setThumbnailPath(
        scanId: 'abandoned-scan',
        path: abandonedThumbnail,
      );

      await scans.createScan(
        id: 'completed-scan',
        mode: ScanMode.document,
        imagePath: '/private/completed.jpg',
        langHint: 'automatic',
        createdAt: DateTime(2026, 7, 17),
      );
      final completedRaw = await files.persistCapture(
        sourcePath: source.path,
        scanId: 'completed-scan',
        pageIndex: 0,
      );
      await RecordRepository(database).saveDocument(
        scanId: 'completed-scan',
        title: 'Saved notes',
        body: 'Persisted',
        tags: const [],
      );
      await database.indexScan(
        scanId: 'orphan-search-row',
        text: const ['orphanonlytoken'],
      );
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      scans = ScanRepository(database);
      try {
        final removed = await StartupCleanupRepository(
          database,
          files,
        ).purgeUnreviewedScans();

        expect(removed, 1);
        expect(await database.select(database.scans).get(), hasLength(1));
        expect((await scans.getScan('completed-scan')).id, 'completed-scan');
        expect(await database.searchScanIds('orphanonlytoken'), isEmpty);
        for (final path in [
          abandonedRaw,
          abandonedColor,
          abandonedBinary,
          abandonedThumbnail,
          rowlessRaw,
          rowlessProcessed,
          rowlessThumbnail,
        ]) {
          expect(await File(path).exists(), isFalse, reason: path);
        }
        expect(await File(completedRaw).exists(), isTrue);
        expect(await staleCsv.exists(), isFalse);
        expect(await stalePdf.exists(), isFalse);
        expect(await staleShareCopy.exists(), isFalse);
      } finally {
        await database.close();
        if (await root.exists()) await root.delete(recursive: true);
      }
    },
  );
}
