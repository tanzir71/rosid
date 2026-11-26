import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/ocr/pipeline/post_reading.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/parsing/paper_classifier.dart';
import 'package:uuid/uuid.dart';

/// One uncertain word queued for review on `CheckWordsScreen`.
class WordCheckCandidate {
  const WordCheckCandidate({
    required this.line,
    required this.word,
    required this.wordIndex,
    required this.alternatives,
    required this.pageImagePath,
  });

  final TextLine line;
  final String word;
  final int wordIndex;
  final List<String> alternatives;
  final String? pageImagePath;
}

/// Complete view model loaded for `/paper/:id` and `/paper/:id/check`.
class PaperViewData {
  const PaperViewData({
    required this.scan,
    required this.document,
    required this.pages,
    required this.lines,
    required this.details,
    required this.checkWords,
    required this.title,
    required this.displayBody,
  });

  final Scan scan;
  final Document? document;
  final List<ScanPage> pages;
  final List<TextLine> lines;
  final List<Detail> details;
  final List<WordCheckCandidate> checkWords;
  final String title;
  final String displayBody;

  PaperKind get paperKind => PaperKind.byId(scan.kind);

  int get wordsToCheckCount =>
      checkWords.isNotEmpty ? checkWords.length : scan.checkCount;
}

/// Offline Android TextToSpeech bridge (returns false on unsupported platforms
/// or when no offline Bangla voice is installed, hiding Listen per M4 spec).
class OfflineSpeechService {
  static const MethodChannel _channel = MethodChannel('app.rosid.rosid/tts');

  Future<bool> isBanglaVoiceAvailable() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isBanglaAvailable');
      return ok ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> speak(String text, {String locale = 'bn-BD'}) async {
    try {
      await _channel.invokeMethod<void>('speak', {
        'text': text,
        'locale': locale,
      });
    } on Object {
      // Best-effort offline speech.
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on Object {
      // Best-effort stop.
    }
  }
}

final offlineSpeechServiceProvider = Provider<OfflineSpeechService>(
  (ref) => OfflineSpeechService(),
);

final banglaVoiceAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(offlineSpeechServiceProvider).isBanglaVoiceAvailable(),
);

class PaperRepository {
  PaperRepository(this.db, this.records);

  final AppDatabase db;
  final RecordRepository records;
  static const _uuid = Uuid();
  static const _post = PostReadingProcessor();
  static const _classifier = PaperClassifier();

  Future<PaperViewData?> loadPaper(String scanId) async {
    final scan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    if (scan == null) return null;

    final doc = await (db.select(
      db.documents,
    )..where((d) => d.scanId.equals(scanId))).getSingleOrNull();

    final pages =
        await (db.select(db.scanPages)
              ..where((p) => p.scanId.equals(scanId))
              ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
            .get();

    final lines =
        await (db.select(db.textLines)
              ..where((t) => t.scanId.equals(scanId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.pageIndex),
                (t) => OrderingTerm.asc(t.lineOrder),
              ]))
            .get();

    var details = await (db.select(
      db.details,
    )..where((d) => d.scanId.equals(scanId))).get();

    final rememberedRows = await db.select(db.corrections).get();
    final remembered = [
      for (final r in rememberedRows)
        RememberedCorrection(
          wrongText: r.wrongReading,
          rightText: r.rightReading,
          count: r.count,
        ),
    ];
    final nameRows = await db.select(db.names).get();
    final nameWords = [
      for (final n in nameRows) ...[n.bangla, n.english],
    ];

    final pagePathByIndex = <int, String>{
      for (final p in pages) p.pageIndex: p.processedPath ?? p.imagePath,
    };

    final checkWords = <WordCheckCandidate>[];
    for (final line in lines) {
      if (line.corrected) continue;
      final processed = _post.processLine(
        RecognizedLine(
          pageIndex: line.pageIndex,
          lineOrder: line.lineOrder,
          text: line.textContent,
          originalText: line.textContent,
          box:
              DetectedLineBox.fromBoxJson(line.boxJson) ??
              const DetectedLineBox(
                topLeft: (0, 0),
                topRight: (100, 0),
                bottomRight: (100, 24),
                bottomLeft: (0, 24),
                score: 1,
              ),
          confidence: line.confidence,
          script: line.script,
          engineId: scan.ocrEngine ?? 'rosid',
        ),
        remembered: remembered,
        nameBookWords: nameWords,
      );
      for (final u in processed.uncertainWords) {
        checkWords.add(
          WordCheckCandidate(
            line: line,
            word: u.word,
            wordIndex: u.wordIndex,
            alternatives: u.alternatives,
            pageImagePath: pagePathByIndex[line.pageIndex] ?? scan.imagePath,
          ),
        );
      }
    }

    final displayBody = (doc?.body.trim().isNotEmpty ?? false)
        ? doc!.body
        : (lines.isNotEmpty
              ? lines.map((l) => l.textContent).join('\n')
              : scan.ocrRawText);

    // If details haven't been computed yet (e.g., seeded/legacy scan), compute on the fly.
    if (details.isEmpty && displayBody.trim().isNotEmpty) {
      final lineTexts = lines.isNotEmpty
          ? lines.map((l) => l.textContent).toList()
          : displayBody.split('\n');
      final extracted = _classifier.extractDetails(
        lineTexts,
        kind: PaperKind.byId(scan.kind),
      );
      details = [
        for (var i = 0; i < extracted.length; i++)
          Detail(
            id: 'ephemeral-$i',
            scanId: scanId,
            detailKey: extracted[i].key,
            value: extracted[i].value,
            sourceLineId:
                extracted[i].sourceLineIndex != null &&
                    extracted[i].sourceLineIndex! < lines.length
                ? lines[extracted[i].sourceLineIndex!].id
                : null,
          ),
      ];
    }

    final title = (doc?.title.trim().isNotEmpty ?? false)
        ? doc!.title
        : displayBody
              .split('\n')
              .map((l) => l.trim())
              .firstWhere((l) => l.isNotEmpty, orElse: () => 'Untitled paper');

    return PaperViewData(
      scan: scan,
      document: doc,
      pages: pages,
      lines: lines,
      details: details,
      checkWords: checkWords,
      title: title,
      displayBody: displayBody,
    );
  }

  Future<void> updatePaperKind(String scanId, PaperKind kind) async {
    await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
      ScansCompanion(kind: Value(kind.code), updatedAt: Value(DateTime.now())),
    );
    await _reextractDetails(scanId, kind);
  }

  Future<void> updateRenewBy(String scanId, DateTime? renewBy) async {
    await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
      ScansCompanion(renewBy: Value(renewBy), updatedAt: Value(DateTime.now())),
    );
  }

  /// Updates the user-edited full text in `documents` while preserving the
  /// original OCR reading in `scans.ocrRawText`.
  Future<void> updateFullText(
    String scanId, {
    required String title,
    required String body,
  }) async {
    await records.saveDocument(
      scanId: scanId,
      title: title,
      body: body,
      tags: const [],
    );
    final scan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    if (scan != null) {
      await _reextractDetails(scanId, PaperKind.byId(scan.kind));
    }
  }

  Future<void> fixLineText({
    required String scanId,
    required TextLine line,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await (db.update(db.textLines)..where((t) => t.id.equals(line.id))).write(
      TextLinesCompanion(
        textContent: Value(trimmed),
        corrected: const Value(true),
        confidence: const Value(1.0),
      ),
    );
    await _syncDocumentBodyFromLines(scanId);
  }

  /// Saves a word correction from `CheckWordsScreen`, records it in the
  /// `corrections` table for future scans, and optionally adds it to `names`.
  Future<void> applyWordCorrection({
    required String scanId,
    required TextLine line,
    required String wrongWord,
    required String rightWord,
    bool addToNameBook = false,
  }) async {
    final cleanRight = rightWord.trim();
    if (cleanRight.isEmpty) return;

    await db.transaction(() async {
      final updatedLineText = wrongWord == cleanRight
          ? line.textContent
          : line.textContent.replaceFirst(wrongWord, cleanRight);

      await (db.update(db.textLines)..where((t) => t.id.equals(line.id))).write(
        TextLinesCompanion(
          textContent: Value(updatedLineText),
          corrected: const Value(true),
          confidence: const Value(1.0),
        ),
      );

      if (wrongWord.trim() != cleanRight) {
        final existing =
            await (db.select(db.corrections)..where(
                  (c) =>
                      c.wrongReading.equals(wrongWord.trim()) &
                      c.rightReading.equals(cleanRight),
                ))
                .getSingleOrNull();
        if (existing != null) {
          await (db.update(db.corrections)
                ..where((c) => c.id.equals(existing.id)))
              .write(CorrectionsCompanion(count: Value(existing.count + 1)));
        } else {
          await db
              .into(db.corrections)
              .insert(
                CorrectionsCompanion.insert(
                  id: _uuid.v7(),
                  wrongReading: wrongWord.trim(),
                  rightReading: cleanRight,
                  count: const Value(1),
                ),
              );
        }
      }

      if (addToNameBook) {
        final existingName = await (db.select(
          db.names,
        )..where((n) => n.bangla.equals(cleanRight))).getSingleOrNull();
        if (existingName == null) {
          await db
              .into(db.names)
              .insert(
                NamesCompanion.insert(
                  id: _uuid.v7(),
                  bangla: cleanRight,
                  english: '',
                  category: const Value('person'),
                  source: const Value('suggested'),
                  confirmed: const Value(false),
                ),
              );
        }
      }
    });

    await _syncDocumentBodyFromLines(scanId);
  }

  Future<void> _syncDocumentBodyFromLines(String scanId) async {
    final lines =
        await (db.select(db.textLines)
              ..where((t) => t.scanId.equals(scanId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.pageIndex),
                (t) => OrderingTerm.asc(t.lineOrder),
              ]))
            .get();
    final body = lines.map((l) => l.textContent).join('\n');
    final existingDoc = await (db.select(
      db.documents,
    )..where((d) => d.scanId.equals(scanId))).getSingleOrNull();
    final title = (existingDoc?.title.trim().isNotEmpty ?? false)
        ? existingDoc!.title
        : (lines.isNotEmpty ? lines.first.textContent : 'Untitled paper');
    await records.saveDocument(
      scanId: scanId,
      title: title,
      body: body,
      tags: const [],
    );

    final remainingCheck = lines
        .where((l) => !l.corrected && l.confidence < 0.78)
        .length;
    final scan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
      ScansCompanion(
        checkCount: Value(remainingCheck),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (scan != null) {
      await _reextractDetails(scanId, PaperKind.byId(scan.kind));
    }
  }

  Future<void> _reextractDetails(String scanId, PaperKind kind) async {
    final lines =
        await (db.select(db.textLines)
              ..where((t) => t.scanId.equals(scanId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.pageIndex),
                (t) => OrderingTerm.asc(t.lineOrder),
              ]))
            .get();
    final doc = await (db.select(
      db.documents,
    )..where((d) => d.scanId.equals(scanId))).getSingleOrNull();
    final lineTexts = lines.isNotEmpty
        ? lines.map((l) => l.textContent).toList()
        : (doc?.body.split('\n') ?? const <String>[]);
    final extracted = _classifier.extractDetails(lineTexts, kind: kind);

    await db.transaction(() async {
      await (db.delete(db.details)..where((d) => d.scanId.equals(scanId))).go();
      for (final d in extracted) {
        final srcIdx = d.sourceLineIndex;
        final srcLineId = srcIdx != null && srcIdx >= 0 && srcIdx < lines.length
            ? lines[srcIdx].id
            : null;
        await db
            .into(db.details)
            .insert(
              DetailsCompanion.insert(
                id: _uuid.v7(),
                scanId: scanId,
                detailKey: d.key,
                value: d.value,
                sourceLineId: Value(srcLineId),
              ),
            );
      }
    });
  }
}

final paperRepositoryProvider = Provider<PaperRepository>(
  (ref) => PaperRepository(
    ref.watch(databaseProvider),
    ref.watch(recordRepositoryProvider),
  ),
);

final paperViewProvider = FutureProvider.family<PaperViewData?, String>(
  (ref, scanId) => ref.watch(paperRepositoryProvider).loadPaper(scanId),
);
