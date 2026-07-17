import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/features/export/temporary_export.dart';

void main() {
  late Directory root;
  late PrivateFileStore fileStore;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rosid_temporary_export_');
    fileStore = PrivateFileStore(rootDirectory: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('deletes the generated file after successful use', () async {
    late String generatedPath;

    final result = await withTemporaryExport(
      fileStore: fileStore,
      create: () async {
        generatedPath = await fileStore.createExportPath('success.csv');
        await File(generatedPath).writeAsString('private data');
        return generatedPath;
      },
      use: (path) async {
        expect(await File(path).exists(), isTrue);
        return 'shared';
      },
    );

    expect(result, 'shared');
    expect(await File(generatedPath).exists(), isFalse);
  });

  test('deletes the generated file when use throws', () async {
    late String generatedPath;

    await expectLater(
      withTemporaryExport<void>(
        fileStore: fileStore,
        create: () async {
          generatedPath = await fileStore.createExportPath('failed.pdf');
          await File(generatedPath).writeAsBytes([1, 2, 3]);
          return generatedPath;
        },
        use: (path) => throw StateError('share failed'),
      ),
      throwsStateError,
    );

    expect(await File(generatedPath).exists(), isFalse);
  });
}
