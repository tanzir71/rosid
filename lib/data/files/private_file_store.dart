import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PrivateFileStore {
  const PrivateFileStore();

  Future<Directory> _directory(String child) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(root.path, 'rosid', child));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> persistCapture({
    required String sourcePath,
    required String scanId,
    required int pageIndex,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected image no longer exists', sourcePath);
    }
    final directory = await _directory('scans');
    final extension = path.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final destination = path.join(
      directory.path,
      '${scanId}_$pageIndex$safeExtension',
    );
    await source.copy(destination);
    return destination;
  }

  Future<String> writeProcessed({
    required List<int> bytes,
    required String scanId,
    required int pageIndex,
    String suffix = 'color',
  }) async {
    final directory = await _directory('processed');
    final destination = path.join(
      directory.path,
      '${scanId}_${pageIndex}_$suffix.jpg',
    );
    await File(destination).writeAsBytes(bytes, flush: true);
    return destination;
  }

  Future<String> createExportPath(String fileName) async {
    final directory = await _directory('exports');
    return path.join(directory.path, fileName);
  }

  Future<void> deleteIfPresent(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}

final privateFileStoreProvider = Provider<PrivateFileStore>(
  (ref) => const PrivateFileStore(),
);
