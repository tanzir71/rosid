import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:sqlite3/sqlite3.dart' as sq;
import 'package:uuid/uuid.dart';

class BackupWrongPasswordException implements Exception {
  const BackupWrongPasswordException();
  @override
  String toString() => 'Wrong backup password';
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'Invalid backup file: $message';
}

class BackupCreateResult {
  const BackupCreateResult({
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
    required this.paperCount,
    required this.createdAt,
  });

  final String filePath;
  final String fileName;
  final int sizeBytes;
  final int paperCount;
  final DateTime createdAt;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.paperCount,
    required this.restoredFiles,
    required this.backupCreatedAt,
  });

  final int paperCount;
  final int restoredFiles;
  final DateTime? backupCreatedAt;
}

/// Encrypted full backup & atomic restore engine per `02-architecture.md`:
///
/// Binary layout:
/// - 8 bytes ASCII magic: `ROSIDBK2`
/// - 2 bytes uint16 BE version (`2`)
/// - 4 bytes uint32 BE Argon2id memoryKiB
/// - 4 bytes uint32 BE Argon2id iterations
/// - 4 bytes uint32 BE Argon2id parallelism
/// - 16 bytes salt
/// - 12 bytes AES-GCM nonce
/// - 16 bytes AES-GCM MAC tag
/// - remaining bytes: AES-256-GCM ciphertext of a ZIP archive containing
///   `manifest.json`, `rosid.sqlite` (produced via `VACUUM INTO`), and
///   `files/{scans,processed,thumbnails}/*`.
class BackupService {
  const BackupService({
    this.memoryKiB = 16384,
    this.iterations = 2,
    this.parallelism = 1,
  });

  static final List<int> magic = utf8.encode('ROSIDBK2');
  static const int formatVersion = 2;
  static const int headerFixedBytes = 8 + 2 + 12 + 16 + 12 + 16; // 66 bytes

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  static final Random _random = Random.secure();
  static const _uuid = Uuid();

  /// Resolves the live SQLite database file path used by `driftDatabase(name: 'rosid')`.
  static Future<String> defaultDatabasePath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'rosid.sqlite');
  }

  /// Computes total storage used on device (SQLite DB + private images).
  static Future<int> computeStorageBytes({
    Directory? appDocsDir,
    String? databaseFilePath,
  }) async {
    var total = 0;
    final docs = appDocsDir ?? await getApplicationDocumentsDirectory();
    final dbPath = databaseFilePath ?? p.join(docs.path, 'rosid.sqlite');
    for (final suffix in const ['', '-wal', '-shm']) {
      final f = File('$dbPath$suffix');
      if (await f.exists()) {
        total += await f.length();
      }
    }
    final rosidDir = Directory(p.join(docs.path, 'rosid'));
    if (await rosidDir.exists()) {
      await for (final entity in rosidDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    }
    return total;
  }

  /// Creates an encrypted `.rosidbackup` file using `VACUUM INTO` on [db],
  /// bundling private files from [appDocsDir]/rosid/{scans,processed,thumbnails}.
  Future<BackupCreateResult> createBackup({
    required AppDatabase db,
    required String password,
    required String outputFilePath,
    Directory? appDocsDir,
    Directory? tempDir,
  }) async {
    if (password.isEmpty) {
      throw const BackupFormatException('Password cannot be empty');
    }
    final docs = appDocsDir ?? await getApplicationDocumentsDirectory();
    final tmpBase = tempDir ?? await getTemporaryDirectory();
    final workDir = Directory(p.join(tmpBase.path, 'rosid_bk_${_uuid.v4()}'));
    await workDir.create(recursive: true);

    try {
      final vacuumDbPath = p.join(workDir.path, 'rosid.sqlite');
      final escapedPath = vacuumDbPath.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escapedPath'");

      final scans = await db.select(db.scans).get();
      final createdAt = DateTime.now().toUtc();

      final archive = Archive();
      final dbBytes = await File(vacuumDbPath).readAsBytes();
      archive.addFile(ArchiveFile('rosid.sqlite', dbBytes.length, dbBytes));

      final rosidRoot = Directory(p.join(docs.path, 'rosid'));
      final includedFiles = <String>[];
      for (final folder in const ['scans', 'processed', 'thumbnails']) {
        final sub = Directory(p.join(rosidRoot.path, folder));
        if (!await sub.exists()) continue;
        await for (final entity in sub.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          final relPath = 'files/$folder/$name';
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
          includedFiles.add(relPath);
        }
      }

      final manifest = jsonEncode({
        'format': 'ROSIDBK2',
        'version': formatVersion,
        'createdAt': createdAt.toIso8601String(),
        'paperCount': scans.length,
        'fileCount': includedFiles.length,
      });
      final manifestBytes = utf8.encode(manifest);
      archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );

      final zipBytes = ZipEncoder().encode(archive);
      final encrypted = await _encryptPayload(
        Uint8List.fromList(zipBytes),
        password: password,
      );

      final outFile = File(outputFilePath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(encrypted, flush: true);

      return BackupCreateResult(
        filePath: outFile.path,
        fileName: p.basename(outFile.path),
        sizeBytes: encrypted.length,
        paperCount: scans.length,
        createdAt: createdAt,
      );
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  /// Validates, decrypts, stages, verifies SQLite integrity, and atomically swaps
  /// database + private files in one step. On wrong password or damaged/truncated
  /// file, throws [BackupWrongPasswordException] or [BackupFormatException]
  /// BEFORE touching the existing database or files!
  Future<BackupRestoreResult> restoreBackup({
    required String backupFilePath,
    required String password,
    required String targetDatabasePath,
    required Directory targetAppDocsDir,
    required Future<void> Function() closeLiveDatabase,
    required Future<void> Function() reopenLiveDatabase,
    Directory? tempDir,
  }) async {
    final file = File(backupFilePath);
    if (!await file.exists()) {
      throw const BackupFormatException('Backup file does not exist');
    }
    final raw = await file.readAsBytes();
    final zipBytes = await _decryptPayload(raw, password: password);

    final tmpBase = tempDir ?? await getTemporaryDirectory();
    final stageDir = Directory(
      p.join(tmpBase.path, 'rosid_restore_${_uuid.v4()}'),
    );
    await stageDir.create(recursive: true);

    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes);
      } on Object {
        throw const BackupFormatException('Backup archive is corrupted');
      }

      ArchiveFile? dbEntry;
      ArchiveFile? manifestEntry;
      final fileEntries = <ArchiveFile>[];
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final normalized = p.posix.normalize(entry.name);
        if (normalized.startsWith('..') || p.posix.isAbsolute(normalized)) {
          throw const BackupFormatException('Unsafe path inside archive');
        }
        if (normalized == 'rosid.sqlite') {
          dbEntry = entry;
        } else if (normalized == 'manifest.json') {
          manifestEntry = entry;
        } else if (normalized.startsWith('files/')) {
          fileEntries.add(entry);
        }
      }
      if (dbEntry == null) {
        throw const BackupFormatException('Missing database inside backup');
      }

      // Stage database and private files completely in temp first.
      final stagedDbPath = p.join(stageDir.path, 'rosid.sqlite');
      await File(stagedDbPath)
          .writeAsBytes(dbEntry.content as List<int>, flush: true);

      final stagedFilesRoot = Directory(p.join(stageDir.path, 'rosid'));
      await stagedFilesRoot.create(recursive: true);
      var restoredFileCount = 0;
      for (final entry in fileEntries) {
        final rel = p.posix.normalize(entry.name).substring('files/'.length);
        final parts = p.posix.split(rel);
        if (parts.length != 2 ||
            !const {'scans', 'processed', 'thumbnails'}.contains(parts[0])) {
          continue;
        }
        final destDir = Directory(p.join(stagedFilesRoot.path, parts[0]));
        await destDir.create(recursive: true);
        final destFile = File(p.join(destDir.path, parts[1]));
        await destFile.writeAsBytes(entry.content as List<int>, flush: true);
        restoredFileCount++;
      }

      // Verify SQLite opens cleanly, passes integrity_check, and rewrite paths
      // to targetAppDocsDir/rosid/... so restored scans load on any device.
      final int paperCount;
      try {
        final testDb = sq.sqlite3.open(stagedDbPath);
        try {
          final integrity = testDb.select('PRAGMA integrity_check');
          if (integrity.isEmpty || integrity.first.values.first != 'ok') {
            throw const BackupFormatException('Database failed integrity');
          }
          final tables = testDb
              .select("SELECT name FROM sqlite_master WHERE type='table'")
              .map((r) => r['name'] as String)
              .toSet();
          if (!tables.contains('scans') || !tables.contains('scan_pages')) {
            throw const BackupFormatException('Not a Rosid database');
          }
          _rewriteRestoredPaths(testDb, targetAppDocsDir.path);
          final countRows = testDb.select('SELECT COUNT(*) AS c FROM scans');
          paperCount = (countRows.first['c'] as int?) ?? 0;
        } finally {
          testDb.close();
        }
      } on BackupFormatException {
        rethrow;
      } on Object catch (e) {
        throw BackupFormatException('Database unreadable: $e');
      }

      DateTime? createdAt;
      if (manifestEntry != null) {
        try {
          final m = jsonDecode(
            utf8.decode(manifestEntry.content as List<int>),
          ) as Map<String, dynamic>;
          final iso = m['createdAt'] as String?;
          if (iso != null) createdAt = DateTime.tryParse(iso);
        } on Object {
          // Optional metadata.
        }
      }

      // Everything is verified in staging — now swap DB and files atomically.
      await closeLiveDatabase();

      final targetDbFile = File(targetDatabasePath);
      await targetDbFile.parent.create(recursive: true);
      final backupPrevDb = File('$targetDatabasePath.prev');
      if (await backupPrevDb.exists()) await backupPrevDb.delete();
      if (await targetDbFile.exists()) {
        await targetDbFile.rename(backupPrevDb.path);
      }
      for (final suffix in const ['-wal', '-shm']) {
        final aux = File('$targetDatabasePath$suffix');
        if (await aux.exists()) await aux.delete();
      }

      final targetRosidDir = Directory(p.join(targetAppDocsDir.path, 'rosid'));
      final backupPrevDir = Directory(
        p.join(targetAppDocsDir.path, 'rosid_prev_restore'),
      );
      if (await backupPrevDir.exists()) {
        await backupPrevDir.delete(recursive: true);
      }

      try {
        await File(stagedDbPath).copy(targetDatabasePath);
        if (await targetRosidDir.exists()) {
          await targetRosidDir.rename(backupPrevDir.path);
        }
        await _copyDirectory(stagedFilesRoot, targetRosidDir);
      } on Object {
        // Roll back previous data if disk swap fails.
        if (await targetDbFile.exists()) await targetDbFile.delete();
        if (await backupPrevDb.exists()) {
          await backupPrevDb.rename(targetDatabasePath);
        }
        if (await backupPrevDir.exists()) {
          if (await targetRosidDir.exists()) {
            await targetRosidDir.delete(recursive: true);
          }
          await backupPrevDir.rename(targetRosidDir.path);
        }
        await reopenLiveDatabase();
        rethrow;
      }

      if (await backupPrevDb.exists()) await backupPrevDb.delete();
      if (await backupPrevDir.exists()) {
        await backupPrevDir.delete(recursive: true);
      }

      await reopenLiveDatabase();

      return BackupRestoreResult(
        paperCount: paperCount,
        restoredFiles: restoredFileCount,
        backupCreatedAt: createdAt,
      );
    } finally {
      if (await stageDir.exists()) {
        await stageDir.delete(recursive: true);
      }
    }
  }

  Future<Uint8List> _encryptPayload(
    Uint8List plaintext, {
    required String password,
  }) async {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => _random.nextInt(256)),
    );
    final kdf = Argon2id(
      memory: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: 32,
    );
    final secretKey = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final out = BytesBuilder(copy: false);
    out.add(magic);
    final headerMeta = ByteData(14)
      ..setUint16(0, formatVersion)
      ..setUint32(2, memoryKiB)
      ..setUint32(6, iterations)
      ..setUint32(10, parallelism);
    out.add(headerMeta.buffer.asUint8List());
    out.add(salt);
    out.add(nonce);
    out.add(box.mac.bytes);
    out.add(box.cipherText);
    return out.toBytes();
  }

  Future<Uint8List> _decryptPayload(
    Uint8List raw, {
    required String password,
  }) async {
    if (raw.length <= headerFixedBytes) {
      throw const BackupFormatException('Backup file is truncated');
    }
    for (var i = 0; i < magic.length; i++) {
      if (raw[i] != magic[i]) {
        throw const BackupFormatException('Unrecognized backup header');
      }
    }
    final meta = ByteData.sublistView(raw, 8, 22);
    final version = meta.getUint16(0);
    if (version != formatVersion) {
      throw BackupFormatException('Unsupported backup version $version');
    }
    final mem = meta.getUint32(2);
    final iter = meta.getUint32(6);
    final par = meta.getUint32(10);
    if (mem < 64 || mem > 512 * 1024 || iter < 1 || iter > 64 || par < 1) {
      throw const BackupFormatException('Invalid KDF parameters');
    }

    final salt = raw.sublist(22, 38);
    final nonce = raw.sublist(38, 50);
    final macBytes = raw.sublist(50, 66);
    final cipherText = raw.sublist(66);

    final kdf = Argon2id(
      memory: mem,
      iterations: iter,
      parallelism: par,
      hashLength: 32,
    );
    final secretKey = await kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final aes = AesGcm.with256bits();
    try {
      final plain = await aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupWrongPasswordException();
    } on Object catch (e) {
      throw BackupFormatException('Decryption failed: $e');
    }
  }

  void _rewriteRestoredPaths(sq.Database db, String targetDocsPath) {
    String? rebase(String? oldPath) {
      if (oldPath == null || oldPath.isEmpty) return oldPath;
      final normalized = oldPath.replaceAll('\\', '/');
      for (final folder in const ['scans', 'processed', 'thumbnails']) {
        final marker = '/rosid/$folder/';
        final idx = normalized.lastIndexOf(marker);
        if (idx >= 0) {
          final fileName = normalized.substring(idx + marker.length);
          return p.join(targetDocsPath, 'rosid', folder, fileName);
        }
      }
      return oldPath;
    }

    final scans = db.select('SELECT id, image_path, thumb_path FROM scans');
    final updScan = db.prepare(
      'UPDATE scans SET image_path = ?, thumb_path = ? WHERE id = ?',
    );
    for (final row in scans) {
      updScan.execute([
        rebase(row['image_path'] as String?),
        rebase(row['thumb_path'] as String?),
        row['id'],
      ]);
    }
    updScan.close();

    final pages = db.select(
      'SELECT id, image_path, processed_path FROM scan_pages',
    );
    final updPage = db.prepare(
      'UPDATE scan_pages SET image_path = ?, processed_path = ? WHERE id = ?',
    );
    for (final row in pages) {
      updPage.execute([
        rebase(row['image_path'] as String?),
        rebase(row['processed_path'] as String?),
        row['id'],
      ]);
    }
    updPage.close();
  }

  Future<void> _copyDirectory(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list(followLinks: false)) {
      final targetPath = p.join(dst.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => const BackupService(),
);

final storageUsedBytesProvider = FutureProvider<int>((ref) async {
  ref.watch(databaseProvider);
  final store = ref.watch(privateFileStoreProvider);
  return BackupService.computeStorageBytes(appDocsDir: store.rootDirectory);
});
