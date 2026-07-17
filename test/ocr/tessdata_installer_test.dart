import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:rosid/ocr/tessdata_installer.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rosid-tessdata-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('installs complete assets through the injected seams', () async {
    final assets = <String, List<int>>{
      'assets/tessdata/eng.traineddata': [1, 2, 3],
      'assets/tessdata/ben.traineddata': [4, 5],
    };
    final installer = _installer(directory, assets);

    final result = await installer.install();

    expect(result.isComplete, isTrue);
    expect(
      await File(path.join(directory.path, 'eng.traineddata')).readAsBytes(),
      [1, 2, 3],
    );
    expect(
      await File(path.join(directory.path, 'ben.traineddata')).readAsBytes(),
      [4, 5],
    );
    expect(
      directory.listSync().where((entry) => entry.path.endsWith('.installing')),
      isEmpty,
    );
  });

  test('replaces a destination whose length differs from the asset', () async {
    final destination = File(path.join(directory.path, 'eng.traineddata'));
    await destination.writeAsBytes([9]);
    final installer = _installer(directory, {
      'assets/tessdata/eng.traineddata': [1, 2, 3],
      'assets/tessdata/ben.traineddata': [4, 5],
    });

    final result = await installer.install();

    expect(result.isComplete, isTrue);
    expect(await destination.readAsBytes(), [1, 2, 3]);
    expect(File('${destination.path}.installing').existsSync(), isFalse);
    expect(File('${destination.path}.previous').existsSync(), isFalse);
  });

  test('reports a missing asset and removes partial install files', () async {
    final installer = _installer(directory, {
      'assets/tessdata/eng.traineddata': [1, 2, 3],
    });

    final result = await installer.install();

    expect(result.installed, ['eng.traineddata']);
    expect(result.missing, ['ben.traineddata']);
    expect(
      File(
        path.join(directory.path, 'ben.traineddata.installing'),
      ).existsSync(),
      isFalse,
    );
  });
}

TessdataInstaller _installer(
  Directory directory,
  Map<String, List<int>> assets,
) {
  return TessdataInstaller(
    destinationDirectoryProvider: () async => directory,
    assetLoader: (assetPath) async {
      final bytes = assets[assetPath];
      if (bytes == null) throw StateError('Missing $assetPath');
      return ByteData.sublistView(Uint8List.fromList(bytes));
    },
  );
}
