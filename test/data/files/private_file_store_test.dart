import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/data/files/private_file_store.dart';

void main() {
  late Directory root;
  late PrivateFileStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rosid_file_store_');
    store = PrivateFileStore(rootDirectory: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('record deletion removes scan files and temporary exports', () async {
    final source = File('${root.path}${Platform.pathSeparator}source.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final raw = await store.persistCapture(
      sourcePath: source.path,
      scanId: 'scan-1',
      pageIndex: 0,
    );
    final color = await store.writeProcessed(
      bytes: [4],
      scanId: 'scan-1',
      pageIndex: 0,
    );
    final binary = await store.writeProcessed(
      bytes: [5],
      scanId: 'scan-1',
      pageIndex: 0,
      suffix: 'bw',
    );
    final thumbnail = await store.writeThumbnail(bytes: [6], scanId: 'scan-1');
    final other = await store.writeProcessed(
      bytes: [7],
      scanId: 'scan-2',
      pageIndex: 0,
    );
    final export = File(await store.createExportPath('scan-1.pdf'));
    final shareCopy = File(
      '${root.path}${Platform.pathSeparator}share_plus'
      '${Platform.pathSeparator}scan-1.pdf',
    );
    await export.writeAsBytes([8]);
    await shareCopy.parent.create(recursive: true);
    await shareCopy.writeAsBytes([9]);

    await store.deleteRecordArtifacts(scanId: 'scan-1', knownPaths: [raw]);

    for (final target in [
      raw,
      color,
      binary,
      thumbnail,
      export.path,
      shareCopy.path,
    ]) {
      expect(await File(target).exists(), isFalse);
    }
    expect(await File(other).exists(), isTrue);
  });

  test('delete all exports removes CSV and PDF copies', () async {
    final csv = File(await store.createExportPath('expenses.csv'));
    final pdf = File(await store.createExportPath('notes.pdf'));
    await csv.writeAsString('private expense data');
    await pdf.writeAsBytes([1, 2, 3]);

    await store.deleteAllExports();

    expect(await csv.exists(), isFalse);
    expect(await pdf.exists(), isFalse);
  });

  test('deletes only files owned by the temporary export directory', () async {
    final export = File(await store.createExportPath('private.csv'));
    final outside = File(
      '${root.path}${Platform.pathSeparator}outside-private.csv',
    );
    await export.writeAsString('exported private data');
    await outside.writeAsString('unrelated private data');

    await store.deleteExportIfPresent(export.path);

    expect(await export.exists(), isFalse);
    expect(await outside.exists(), isTrue);
    await expectLater(
      store.deleteExportIfPresent(outside.path),
      throwsArgumentError,
    );
    expect(await outside.exists(), isTrue);
  });

  test(
    'rejects export names that can escape the temporary directory',
    () async {
      for (final name in [
        '../outside.csv',
        r'..\outside.csv',
        root.absolute.path,
      ]) {
        await expectLater(store.createExportPath(name), throwsArgumentError);
      }
    },
  );

  test('delete all app data removes every bounded private artifact', () async {
    final source = File('${root.path}${Platform.pathSeparator}source-all.jpg');
    await source.writeAsBytes([1, 2, 3]);
    await store.persistCapture(
      sourcePath: source.path,
      scanId: 'scan-all',
      pageIndex: 0,
    );
    await store.writeProcessed(
      bytes: [4],
      scanId: 'scan-all',
      pageIndex: 0,
      suffix: 'color_g2',
    );
    await store.writeProcessed(
      bytes: [5],
      scanId: 'scan-all',
      pageIndex: 0,
      suffix: 'bw_g2',
    );
    await store.writeProcessed(
      bytes: [6],
      scanId: 'orphan',
      pageIndex: 8,
      suffix: 'bw_g9',
    );
    await store.writeThumbnail(bytes: [7], scanId: 'scan-all', generation: 2);
    await File(await store.createExportPath('private.csv')).writeAsBytes([8]);

    await store.deleteAllAppData();

    for (final child in const ['scans', 'processed', 'thumbnails', 'exports']) {
      expect(
        await Directory(
          '${root.path}${Platform.pathSeparator}rosid${Platform.pathSeparator}$child',
        ).exists(),
        isFalse,
      );
    }
    expect(await source.exists(), isTrue);
  });
}
