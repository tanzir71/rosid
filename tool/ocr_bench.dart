import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:rosid/parsing/receipt_parser.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

/// Host OCR benchmark CLI (`handover/03-verification.md`, `M3-reading-text.md`).
///
/// Usage:
///   dart run tool/ocr_bench.dart --mode baseline --out evidence/M3/baseline.json
///   dart run tool/ocr_bench.dart --mode v2_tess_fast --out evidence/M3/cand_fast.json
///   dart run tool/ocr_bench.dart --mode v2_tess_best --out evidence/M3/cand_best.json
///   dart run tool/ocr_bench.dart --mode final --out evidence/M3/final.json
Future<void> main(List<String> args) async {
  var mode = 'baseline';
  var outPath = 'evidence/M3/ocr-bench.json';
  var fixturesDir = 'test/fixtures/synthetic';
  var limit = 0;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--mode':
        mode = args[++i];
      case '--out':
        outPath = args[++i];
      case '--fixtures':
        fixturesDir = args[++i];
      case '--limit':
        limit = int.parse(args[++i]);
    }
  }

  final rawJsonFile = File(
    '${Directory.systemTemp.path}/rosid_bench_$mode.json',
  );
  final pyArgs = [
    'tool/ocr_bench_engine.py',
    '--mode',
    mode,
    '--fixtures',
    fixturesDir,
    '--out',
    rawJsonFile.path,
    if (limit > 0) ...['--limit', '$limit'],
  ];

  stdout.writeln('[ocr_bench] Running engine mode=$mode on $fixturesDir...');
  final proc = await Process.run('python', pyArgs);
  if (proc.exitCode != 0) {
    stderr.writeln(proc.stdout);
    stderr.writeln(proc.stderr);
    exit(proc.exitCode);
  }
  stdout.write(proc.stdout);

  final raw =
      jsonDecode(await rawJsonFile.readAsString()) as Map<String, dynamic>;
  final items = (raw['results'] as List<dynamic>).cast<Map<String, dynamic>>();

  // Score every fixture using Dart's exact ReceiptParser + Land detail parser + CER/WER!
  const receiptParser = ReceiptParser();

  final byScript = <String, _MetricsAcc>{};
  final byKind = <String, _MetricsAcc>{};
  final bySurface = <String, _MetricsAcc>{}; // clean vs photo_like
  final allTimesMs = <double>[];

  var receiptCount = 0;
  var receiptTotalExact = 0;
  var receiptDateExact = 0;
  var receiptShopHit = 0;

  var landCount = 0;
  var landKhatianExact = 0;
  var landPlotExact = 0;
  var landAreaExact = 0;

  for (final item in items) {
    final kind = item['kind'] as String;
    final script = item['script'] as String;
    final isPhoto = item['is_photo_like'] as bool? ?? false;
    final isHw = item['is_synthetic_handwriting'] as bool? ?? false;
    final expected = _normForScore(item['expected_text'] as String);
    final predicted = _normForScore(item['predicted_text'] as String);
    final elapsedMs = (item['elapsed_ms'] as num).toDouble();
    final details = (item['details'] as Map<String, dynamic>?) ?? const {};

    allTimesMs.add(elapsedMs);

    final charEdits = _levenshtein(
      expected.runes.toList(),
      predicted.runes.toList(),
    );
    final charLen = math.max(1, expected.runes.length);
    final expWords = expected
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final predWords = predicted
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final wordEdits = _levenshtein(expWords, predWords);
    final wordLen = math.max(1, expWords.length);

    if (!isHw) {
      byScript
          .putIfAbsent(script, _MetricsAcc.new)
          .add(charEdits, charLen, wordEdits, wordLen);
      bySurface
          .putIfAbsent(isPhoto ? 'photo_like' : 'clean', _MetricsAcc.new)
          .add(charEdits, charLen, wordEdits, wordLen);
    }
    byKind
        .putIfAbsent(isHw ? 'synthetic_handwriting' : kind, _MetricsAcc.new)
        .add(charEdits, charLen, wordEdits, wordLen);

    if (kind == 'receipt' && details.isNotEmpty) {
      receiptCount++;
      final parsed = receiptParser.parse(item['predicted_text'] as String);
      final expectedTotal = (details['total'] as num?)?.toDouble();
      if (expectedTotal != null &&
          parsed.total.value != null &&
          (parsed.total.value! - expectedTotal).abs() < 0.02) {
        receiptTotalExact++;
      }
      final expectedDate = details['date'] as String?;
      if (expectedDate != null) {
        final d = parsed.date.value;
        final gotIso =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (gotIso == expectedDate) receiptDateExact++;
      }
      final expectedShop = (details['shop'] as String? ?? '').toLowerCase();
      if (expectedShop.isNotEmpty &&
          parsed.merchant.value.toLowerCase().contains(
            expectedShop.split(' ').first,
          )) {
        receiptShopHit++;
      }
    }

    if (kind == 'land' && details.isNotEmpty) {
      landCount++;
      final normPred = TextNormalizer.normalizeForParsing(
        item['predicted_text'] as String,
      );
      final kh = details['khatian_no']?.toString() ?? '';
      final pl = details['plot_no']?.toString() ?? '';
      final area = (details['area_decimals'] as num?)?.toDouble();
      if (kh.isNotEmpty && normPred.contains(kh)) landKhatianExact++;
      if (pl.isNotEmpty && normPred.contains(pl)) landPlotExact++;
      if (area != null && normPred.contains(area.toStringAsFixed(2))) {
        landAreaExact++;
      }
    }
  }

  allTimesMs.sort();
  final medianMs = allTimesMs.isEmpty
      ? 0.0
      : allTimesMs[allTimesMs.length ~/ 2];
  final p90Ms = allTimesMs.isEmpty
      ? 0.0
      : allTimesMs[(allTimesMs.length * 0.90).floor().clamp(
          0,
          allTimesMs.length - 1,
        )];

  final report = <String, dynamic>{
    'mode': mode,
    'engine_description': raw['engine_description'],
    'timestamp': DateTime.now().toIso8601String(),
    'fixture_count': items.length,
    'by_script': {for (final e in byScript.entries) e.key: e.value.toJson()},
    'by_kind': {for (final e in byKind.entries) e.key: e.value.toJson()},
    'by_surface': {for (final e in bySurface.entries) e.key: e.value.toJson()},
    'key_details': {
      'receipts_total': receiptCount,
      'receipt_total_exact': receiptTotalExact,
      'receipt_total_exact_rate': receiptCount == 0
          ? 0.0
          : double.parse((receiptTotalExact / receiptCount).toStringAsFixed(4)),
      'receipt_date_exact_rate': receiptCount == 0
          ? 0.0
          : double.parse((receiptDateExact / receiptCount).toStringAsFixed(4)),
      'receipt_shop_hit_rate': receiptCount == 0
          ? 0.0
          : double.parse((receiptShopHit / receiptCount).toStringAsFixed(4)),
      'land_total': landCount,
      'land_khatian_exact_rate': landCount == 0
          ? 0.0
          : double.parse((landKhatianExact / landCount).toStringAsFixed(4)),
      'land_plot_exact_rate': landCount == 0
          ? 0.0
          : double.parse((landPlotExact / landCount).toStringAsFixed(4)),
      'land_area_exact_rate': landCount == 0
          ? 0.0
          : double.parse((landAreaExact / landCount).toStringAsFixed(4)),
    },
    'timing_ms': {
      'median': double.parse(medianMs.toStringAsFixed(1)),
      'p90': double.parse(p90Ms.toStringAsFixed(1)),
    },
  };

  final outFile = File(outPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  stdout.writeln('\n=== OCR BENCHMARK ($mode) ===');
  for (final s in ['en', 'bn', 'mixed']) {
    final m = byScript[s];
    if (m != null) {
      stdout.writeln(
        '  script=$s: CER=${(m.cer * 100).toStringAsFixed(2)}% '
        'WER=${(m.wer * 100).toStringAsFixed(2)}% (n=${m.count})',
      );
    }
  }
  stdout.writeln(
    '  receipt total exact: $receiptTotalExact/$receiptCount '
    '(${(receiptCount == 0 ? 0 : receiptTotalExact * 100 / receiptCount).toStringAsFixed(1)}%)',
  );
  stdout.writeln(
    '  land khatian/plot/area: '
    '$landKhatianExact/$landCount, $landPlotExact/$landCount, $landAreaExact/$landCount',
  );
  stdout.writeln(
    '  page time: median=${medianMs.toStringAsFixed(0)}ms, p90=${p90Ms.toStringAsFixed(0)}ms',
  );
  stdout.writeln('  wrote: $outPath');
}

String _normForScore(String s) {
  return TextNormalizer.normalize(s).replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _levenshtein<T>(List<T> a, List<T> b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = math.min(
        math.min(curr[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

class _MetricsAcc {
  int count = 0;
  int charEdits = 0;
  int charTotal = 0;
  int wordEdits = 0;
  int wordTotal = 0;

  void add(int ce, int ct, int we, int wt) {
    count++;
    charEdits += ce;
    charTotal += ct;
    wordEdits += we;
    wordTotal += wt;
  }

  double get cer => charTotal == 0 ? 0 : charEdits / charTotal;
  double get wer => wordTotal == 0 ? 0 : wordEdits / wordTotal;

  Map<String, dynamic> toJson() => {
    'count': count,
    'cer': double.parse(cer.toStringAsFixed(4)),
    'wer': double.parse(wer.toStringAsFixed(4)),
  };
}
