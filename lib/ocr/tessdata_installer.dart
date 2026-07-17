import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef TessdataAssetLoader = Future<ByteData> Function(String assetPath);
typedef TessdataDirectoryProvider = Future<Directory> Function();

class TessdataInstallResult {
  const TessdataInstallResult({required this.installed, required this.missing});

  final List<String> installed;
  final List<String> missing;

  bool get isComplete => missing.isEmpty;
}

class TessdataInstaller {
  const TessdataInstaller({
    this.assetLoader,
    this.destinationDirectoryProvider,
  });

  static const files = ['eng.traineddata', 'ben.traineddata'];

  final TessdataAssetLoader? assetLoader;
  final TessdataDirectoryProvider? destinationDirectoryProvider;

  Future<TessdataInstallResult> install() async {
    final directory = await _destinationDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    final installed = <String>[];
    final missing = <String>[];
    for (final fileName in files) {
      final destination = File(path.join(directory.path, fileName));
      final temporary = File('${destination.path}.installing');
      try {
        final data = await _loadAsset('assets/tessdata/$fileName');
        final expectedLength = data.lengthInBytes;
        if (expectedLength <= 0) {
          throw StateError('$fileName is empty');
        }
        await _deleteIfPresent(temporary);
        if (await destination.exists() &&
            await destination.length() == expectedLength) {
          installed.add(fileName);
          continue;
        }

        await temporary.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, expectedLength),
          flush: true,
        );
        if (await temporary.length() != expectedLength) {
          throw FileSystemException(
            'Incomplete tessdata write',
            temporary.path,
          );
        }
        await _replaceAtomically(temporary, destination);
        if (await destination.length() != expectedLength) {
          throw FileSystemException(
            'Installed tessdata length mismatch',
            destination.path,
          );
        }
        installed.add(fileName);
      } on Object {
        await _deleteIfPresent(temporary);
        missing.add(fileName);
      }
    }
    return TessdataInstallResult(installed: installed, missing: missing);
  }

  Future<ByteData> _loadAsset(String assetPath) {
    return (assetLoader ?? rootBundle.load)(assetPath);
  }

  Future<Directory> _destinationDirectory() async {
    if (destinationDirectoryProvider != null) {
      return destinationDirectoryProvider!();
    }
    final root = await getApplicationDocumentsDirectory();
    return Directory(path.join(root.path, 'tessdata'));
  }

  Future<void> _replaceAtomically(File temporary, File destination) async {
    try {
      await temporary.rename(destination.path);
      return;
    } on FileSystemException {
      // Windows cannot rename over an existing file. Mobile platforms take
      // the atomic path above; this backup path preserves the last good copy.
      final backup = File('${destination.path}.previous');
      await _deleteIfPresent(backup);
      if (await destination.exists()) {
        await destination.rename(backup.path);
      }
      try {
        await temporary.rename(destination.path);
        await _deleteIfPresent(backup);
      } on Object {
        if (!await destination.exists() && await backup.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}

final tessdataInstallerProvider = Provider<TessdataInstaller>(
  (ref) => const TessdataInstaller(),
);
