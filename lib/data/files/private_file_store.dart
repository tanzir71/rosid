import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PrivateFileStore {
  const PrivateFileStore({this.rootDirectory, this.exportRootDirectory});

  final Directory? rootDirectory;
  final Directory? exportRootDirectory;

  Future<Directory> _root() async =>
      rootDirectory ?? await getApplicationDocumentsDirectory();

  Future<Directory> _temporaryRoot() async =>
      exportRootDirectory ?? rootDirectory ?? await getTemporaryDirectory();

  Future<Directory> _directory(String child, {bool create = true}) async {
    final root = await _root();
    final directory = Directory(path.join(root.path, 'rosid', child));
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _exportsDirectory({bool create = true}) async {
    final root = await _temporaryRoot();
    final directory = Directory(path.join(root.path, 'rosid', 'exports'));
    if (create && !await directory.exists()) {
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

  Future<String> persistCaptureBytes({
    required List<int> bytes,
    required String scanId,
    required int pageIndex,
    String extension = '.jpg',
  }) async {
    final directory = await _directory('scans');
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final destination = path.join(
      directory.path,
      '${scanId}_$pageIndex$safeExtension',
    );
    await File(destination).writeAsBytes(bytes, flush: true);
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

  Future<String> writeThumbnail({
    required List<int> bytes,
    required String scanId,
    int? generation,
  }) async {
    final directory = await _directory('thumbnails');
    final fileName = generation == null
        ? '$scanId.jpg'
        : '${scanId}_g$generation.jpg';
    final destination = path.join(directory.path, fileName);
    await File(destination).writeAsBytes(bytes, flush: true);
    return destination;
  }

  Future<String> createExportPath(String fileName) async {
    final isUnsafeName =
        fileName.isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        path.posix.isAbsolute(fileName) ||
        path.windows.isAbsolute(fileName) ||
        path.posix.basename(fileName) != fileName ||
        path.windows.basename(fileName) != fileName;
    if (isUnsafeName) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid export name');
    }
    final directory = await _exportsDirectory();
    return path.join(directory.path, fileName);
  }

  Future<void> deleteExportIfPresent(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final directory = await _exportsDirectory(create: false);
    final normalizedDirectory = path.normalize(directory.absolute.path);
    final normalizedFile = path.normalize(File(filePath).absolute.path);
    if (path.dirname(normalizedFile) != normalizedDirectory) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'Export is outside the private temporary export directory',
      );
    }
    final file = File(normalizedFile);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteIfPresent(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteScanArtifacts({
    required String scanId,
    Iterable<String> knownPaths = const [],
  }) async {
    if (scanId.isEmpty || path.basename(scanId) != scanId) {
      throw ArgumentError.value(scanId, 'scanId', 'Invalid scan identifier');
    }
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    for (final filePath in knownPaths.toSet()) {
      await attempt(() => deleteIfPresent(filePath));
    }
    for (final child in const ['scans', 'processed']) {
      final directory = await _directory(child, create: false);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File &&
            path.basename(entity.path).startsWith('${scanId}_')) {
          await attempt(() async {
            await entity.delete();
          });
        }
      }
    }
    final thumbnailDirectory = await _directory('thumbnails', create: false);
    if (await thumbnailDirectory.exists()) {
      await for (final entity in thumbnailDirectory.list(followLinks: false)) {
        final name = path.basename(entity.path);
        if (entity is File &&
            (name == '$scanId.jpg' || name.startsWith('${scanId}_'))) {
          await attempt(() async => entity.delete());
        }
      }
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> deleteRecordArtifacts({
    required String scanId,
    Iterable<String> knownPaths = const [],
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await attempt(
      () => deleteScanArtifacts(scanId: scanId, knownPaths: knownPaths),
    );
    await attempt(deleteStaleExportArtifacts);
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> deleteObsoleteDerivedArtifacts({
    required String scanId,
    required Iterable<String> keepPaths,
  }) async {
    if (scanId.isEmpty || path.basename(scanId) != scanId) {
      throw ArgumentError.value(scanId, 'scanId', 'Invalid scan identifier');
    }
    final keep = keepPaths.map(path.normalize).toSet();
    for (final child in const ['processed', 'thumbnails']) {
      final directory = await _directory(child, create: false);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        final belongsToScan = child == 'processed'
            ? name.startsWith('${scanId}_')
            : name == '$scanId.jpg' || name.startsWith('${scanId}_');
        if (belongsToScan && !keep.contains(path.normalize(entity.path))) {
          await entity.delete();
        }
      }
    }
  }

  Future<int> deleteArtifactsWithoutScanRows(
    Iterable<String> liveScanIds,
  ) async {
    final live = liveScanIds.toSet();
    var removed = 0;
    for (final child in const ['scans', 'processed', 'thumbnails']) {
      final directory = await _directory(child, create: false);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        final isLive = live.any(
          (scanId) => child == 'thumbnails'
              ? name == '$scanId.jpg' || name.startsWith('${scanId}_')
              : name.startsWith('${scanId}_'),
        );
        if (!isLive) {
          await entity.delete();
          removed++;
        }
      }
    }
    return removed;
  }

  Future<void> deleteAllExports() async {
    final exports = await _exportsDirectory(create: false);
    if (await exports.exists()) await exports.delete(recursive: true);
  }

  Future<void> deleteStaleExportArtifacts() async {
    await deleteAllExports();
    final temporaryRoot = await _temporaryRoot();
    final shareCache = Directory(path.join(temporaryRoot.path, 'share_plus'));
    if (await shareCache.exists()) await shareCache.delete(recursive: true);
  }

  Future<void> deleteAllAppData() async {
    await deleteStaleExportArtifacts();
    final root = await _root();
    final appDirectory = path.normalize(path.join(root.path, 'rosid'));
    if (!path.isWithin(path.normalize(root.path), appDirectory)) {
      throw StateError('Invalid app data directory');
    }
    for (final child in const ['scans', 'processed', 'thumbnails']) {
      final targetPath = path.normalize(path.join(appDirectory, child));
      if (!path.isWithin(appDirectory, targetPath)) {
        throw StateError('Invalid app data child directory');
      }
      final target = Directory(targetPath);
      if (await target.exists()) await target.delete(recursive: true);
    }
  }
}

final privateFileStoreProvider = Provider<PrivateFileStore>(
  (ref) => const PrivateFileStore(),
);
