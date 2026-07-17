import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TessdataInstallResult {
  const TessdataInstallResult({required this.installed, required this.missing});

  final List<String> installed;
  final List<String> missing;

  bool get isComplete => missing.isEmpty;
}

class TessdataInstaller {
  const TessdataInstaller();

  static const files = ['eng.traineddata', 'ben.traineddata'];

  Future<TessdataInstallResult> install() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(root.path, 'tessdata'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final installed = <String>[];
    final missing = <String>[];
    for (final fileName in files) {
      final destination = File(path.join(directory.path, fileName));
      if (await destination.exists() && await destination.length() > 0) {
        installed.add(fileName);
        continue;
      }
      try {
        final data = await rootBundle.load('assets/tessdata/$fileName');
        await destination.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        installed.add(fileName);
      } on Object {
        missing.add(fileName);
      }
    }
    return TessdataInstallResult(installed: installed, missing: missing);
  }
}

final tessdataInstallerProvider = Provider<TessdataInstaller>(
  (ref) => const TessdataInstaller(),
);
