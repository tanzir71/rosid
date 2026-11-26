import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/ocr/pipeline/onnx_latin_recognizer.dart';
import 'package:rosid/ocr/pipeline/onnx_line_detector.dart';
import 'package:rosid/ocr/pipeline/post_reading.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/ocr/pipeline/script_router.dart';
import 'package:rosid/ocr/pipeline/tesseract_line_recognizer.dart';
import 'package:rosid/parsing/paper_classifier.dart';
import 'package:uuid/uuid.dart';

/// Full M3 ReadingPipeline:
/// grey page -> PP-OCRv5 line detector -> line crops -> script router ->
/// PP-OCRv5 Latin recogniser | Tesseract Bangla recogniser -> NFC + remembered
/// corrections + handwriting signal -> lines with 4-point boxes & confidence.
class RosidReadingPipeline implements ReadingPipeline {
  RosidReadingPipeline({
    required this.lineDetector,
    required this.latinRecognizer,
    required this.banglaRecognizer,
    this.scriptRouter = const ScriptRouter(),
    this.postProcessor = const PostReadingProcessor(),
    this.rememberedCorrectionsLoader,
    this.nameBookWordsLoader,
  });

  final LineDetector lineDetector;
  final LineRecognizer latinRecognizer;
  final LineRecognizer banglaRecognizer;
  final ScriptRouter scriptRouter;
  final PostReadingProcessor postProcessor;
  final Future<List<RememberedCorrection>> Function()?
  rememberedCorrectionsLoader;
  final Future<List<String>> Function()? nameBookWordsLoader;

  @override
  Future<ReadingPageResult> readPage({
    required Uint8List greyImageBytes,
    required int pageIndex,
    void Function(ReadingProgressEvent event)? onProgress,
    ReadingCancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final decoded = img.decodeImage(greyImageBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode page image for reading.');
    }

    onProgress?.call(
      const ReadingProgressEvent(stage: ReadingStage.detectingLines),
    );
    if (cancelToken?.isCancelled ?? false) {
      sw.stop();
      return ReadingPageResult(
        pageIndex: pageIndex,
        lines: const [],
        hasHandwriting: false,
        elapsedMs: sw.elapsedMilliseconds,
        engineSummary: 'cancelled',
        imageWidth: decoded.width,
        imageHeight: decoded.height,
      );
    }

    final boxes = await lineDetector.detect(decoded);
    final remembered = rememberedCorrectionsLoader != null
        ? await rememberedCorrectionsLoader!()
        : const <RememberedCorrection>[];
    final nameWords = nameBookWordsLoader != null
        ? await nameBookWordsLoader!()
        : const <String>[];

    final recognizedLines = <RecognizedLine>[];
    final strokeVariances = <double>[];
    final enginesUsed = <String>{};

    for (var i = 0; i < boxes.length; i++) {
      if (cancelToken?.isCancelled ?? false) break;
      onProgress?.call(
        ReadingProgressEvent(
          stage: ReadingStage.readingLines,
          currentLine: i + 1,
          totalLines: boxes.length,
        ),
      );

      final box = boxes[i];
      final rect = box.boundingRect;
      final x = rect.left.round().clamp(0, decoded.width - 1);
      final y = rect.top.round().clamp(0, decoded.height - 1);
      final cw = rect.width.round().clamp(1, decoded.width - x);
      final ch = rect.height.round().clamp(1, decoded.height - y);
      final crop = img.copyCrop(decoded, x: x, y: y, width: cw, height: ch);

      strokeVariances.add(scriptRouter.strokeWidthVariance(crop));
      final matra = scriptRouter.matraScore(crop);

      // Run fast PP-OCRv5 Latin ONNX first; route to Bangla Tesseract when matra
      // is present or Latin confidence is below threshold ("run both when unsure").
      final latinRes = await latinRecognizer.recognize(crop);
      LineRecognition chosen;
      if (matra < 0.34 &&
          latinRes.confidence >= 0.86 &&
          latinRes.text.length >= 2) {
        chosen = latinRes;
      } else {
        final LineRecognition bnRes;
        if (banglaRecognizer is TesseractLineRecognizer) {
          final hasAscii = RegExp(r'[A-Za-z0-9]').hasMatch(latinRes.text);
          final lang = latinRes.confidence >= 0.62 && hasAscii
              ? 'ben+eng'
              : 'ben';
          bnRes = await (banglaRecognizer as TesseractLineRecognizer)
              .recognizeWithLanguage(crop, language: lang);
        } else {
          bnRes = await banglaRecognizer.recognize(crop);
        }

        final hasBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(bnRes.text);
        if (!hasBangla &&
            latinRes.confidence >= 0.78 &&
            latinRes.text.length >= 2) {
          chosen = latinRes;
        } else if (bnRes.text.isNotEmpty) {
          chosen = bnRes;
        } else {
          chosen = latinRes;
        }
      }

      if (chosen.text.trim().isEmpty) continue;
      enginesUsed.add(chosen.engineId);

      final rawLine = RecognizedLine(
        pageIndex: pageIndex,
        lineOrder: recognizedLines.length,
        text: chosen.text,
        originalText: chosen.text,
        box: box,
        confidence: chosen.confidence,
        script: ScriptRouter.classifyTextScript(chosen.text),
        engineId: chosen.engineId,
      );
      recognizedLines.add(
        postProcessor.processLine(
          rawLine,
          remembered: remembered,
          nameBookWords: nameWords,
        ),
      );
    }

    final hasHandwriting = postProcessor.detectHandwriting(
      lines: recognizedLines,
      strokeVariances: strokeVariances,
    );

    onProgress?.call(
      ReadingProgressEvent(
        stage: ReadingStage.findingDetails,
        currentLine: boxes.length,
        totalLines: boxes.length,
        hasHandwriting: hasHandwriting,
      ),
    );

    sw.stop();
    return ReadingPageResult(
      pageIndex: pageIndex,
      lines: recognizedLines,
      hasHandwriting: hasHandwriting,
      elapsedMs: sw.elapsedMilliseconds,
      engineSummary: enginesUsed.join('+'),
      imageWidth: decoded.width,
      imageHeight: decoded.height,
    );
  }
}

/// Persists recognized lines into `text_lines` and updates `scans` full text &
/// `checkCount` cleanly in a single database transaction.
Future<void> persistReadingResults({
  required AppDatabase db,
  required String scanId,
  required List<ReadingPageResult> pageResults,
}) async {
  const uuid = Uuid();
  await db.transaction(() async {
    await (db.delete(db.textLines)..where((t) => t.scanId.equals(scanId))).go();
    await (db.delete(db.details)..where((d) => d.scanId.equals(scanId))).go();

    final fullBuf = <String>[];
    final insertedLineIds = <String>[];
    var totalUncertain = 0;
    var confSum = 0.0;
    var lineCount = 0;
    final engines = <String>{};

    for (final res in pageResults) {
      if (res.engineSummary.isNotEmpty) engines.add(res.engineSummary);
      for (final line in res.lines) {
        final lineId = uuid.v7();
        await db
            .into(db.textLines)
            .insert(
              TextLinesCompanion.insert(
                id: lineId,
                scanId: scanId,
                pageIndex: line.pageIndex,
                lineOrder: line.lineOrder,
                textContent: line.text,
                boxJson: Value(line.box.toBoxJson()),
                confidence: Value(line.confidence),
                script: Value(line.script),
                corrected: Value(line.corrected),
              ),
            );
        insertedLineIds.add(lineId);
        fullBuf.add(line.text);
        totalUncertain += line.uncertainWords.length;
        confSum += line.confidence;
        lineCount++;
      }
    }

    final fullText = fullBuf.join('\n');
    final existingScan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    const classifier = PaperClassifier();
    final kind = classifier.classify(fullText, currentKind: existingScan?.kind);
    final extractedDetails = classifier.extractDetails(fullBuf, kind: kind);
    for (final detail in extractedDetails) {
      final srcIdx = detail.sourceLineIndex;
      final srcLineId =
          srcIdx != null && srcIdx >= 0 && srcIdx < insertedLineIds.length
          ? insertedLineIds[srcIdx]
          : null;
      await db
          .into(db.details)
          .insert(
            DetailsCompanion.insert(
              id: uuid.v7(),
              scanId: scanId,
              detailKey: detail.key,
              value: detail.value,
              sourceLineId: Value(srcLineId),
            ),
          );
    }

    final meanConf = lineCount == 0 ? 0.0 : confSum / lineCount;
    await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
      ScansCompanion(
        kind: Value(kind.code),
        ocrRawText: Value(fullText),
        ocrEngine: Value(engines.join('+')),
        ocrMeanConfidence: Value(meanConf),
        checkCount: Value(totalUncertain),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });
}

final onnxLineDetectorProvider = Provider<OnnxLineDetector>((ref) {
  final det = OnnxLineDetector();
  ref.onDispose(det.dispose);
  return det;
});

final onnxLatinRecognizerProvider = Provider<OnnxLatinLineRecognizer>((ref) {
  final rec = OnnxLatinLineRecognizer();
  ref.onDispose(rec.dispose);
  return rec;
});

final tesseractLineRecognizerProvider = Provider<TesseractLineRecognizer>(
  (ref) => const TesseractLineRecognizer(),
);

final readingPipelineProvider = Provider<ReadingPipeline>((ref) {
  final db = ref.watch(databaseProvider);
  return RosidReadingPipeline(
    lineDetector: ref.watch(onnxLineDetectorProvider),
    latinRecognizer: ref.watch(onnxLatinRecognizerProvider),
    banglaRecognizer: ref.watch(tesseractLineRecognizerProvider),
    rememberedCorrectionsLoader: () async {
      final rows = await db.select(db.corrections).get();
      return [
        for (final r in rows)
          RememberedCorrection(
            wrongText: r.wrongReading,
            rightText: r.rightReading,
            count: r.count,
          ),
      ];
    },
    nameBookWordsLoader: () async {
      final rows = await db.select(db.names).get();
      return [
        for (final r in rows) ...[r.bangla, r.english],
      ];
    },
  );
});
