import 'dart:math' as math;

import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Remembered word correction entry stored in the `corrections` table.
class RememberedCorrection {
  const RememberedCorrection({
    required this.wrongText,
    required this.rightText,
    this.count = 1,
  });

  final String wrongText;
  final String rightText;
  final int count;
}

/// Post-reading text processor (`handover/02-architecture.md` & M3 steps 9–10):
/// - Unicode NFC normalisation (preserving `originalText`)
/// - Applies remembered user corrections (and prioritizes them as first alternative)
/// - Suggests up to 3 alternatives for uncertain words using remembered words +
///   a curated Bangladeshi civic/document vocabulary
/// - Computes page-level handwriting signal from low confidence + uneven strokes.
class PostReadingProcessor {
  const PostReadingProcessor({
    this.uncertainLineThreshold = 0.78,
    this.handwritingLineConfidence = 0.70,
  });

  final double uncertainLineThreshold;
  final double handwritingLineConfidence;

  /// Curated common Bangla & English document words for near-match check suggestions.
  static const List<String> commonDocumentWords = <String>[
    'খতিয়ান',
    'মৌজা',
    'দাগ',
    'শতাংশ',
    'উপজেলা',
    'জেলা',
    'পিতা',
    'মাতা',
    'মালিকের',
    'নাম',
    'শ্রেণি',
    'ভিটি',
    'নাল',
    'বাড়ি',
    'জমির',
    'পরিমাণ',
    'ভূমি',
    'রেকর্ড',
    'জরিপ',
    'অধিদপ্তর',
    'জন্ম',
    'নিবন্ধন',
    'সনদ',
    'তারিখ',
    'ঠিকানা',
    'বাংলাদেশ',
    'সরকার',
    'গণপ্রজাতন্ত্রী',
    'ঢাকা',
    'সাভার',
    'বিরুলিয়া',
    'চট্টগ্রাম',
    'রাজশাহী',
    'খুলনা',
    'সিলেট',
    'কুমিল্লা',
    'রংপুর',
    'ময়মনসিংহ',
    'সর্বমোট',
    'মোট',
    'ভ্যাট',
    'মূসক',
    'টাকা',
    'বিকাশ',
    'নগদ',
    'রকেট',
    'দাখিলা',
    'নামজারি',
    'জমাভাগ',
    'দলিল',
    'আবেদন',
    'নোটিশ',
    'সহকারী',
    'কমিশনার',
    'গ্রাহকের',
    'বিদ্যুৎ',
    'বিল',
    'মাস',
    'মোঃ',
    'মোসাঃ',
    'মৃত',
    'রহমান',
    'ইসলাম',
    'হোসেন',
    'আহমেদ',
    'বেগম',
    'আক্তার',
    'করিম',
    'হাসান',
    'Total',
    'Subtotal',
    'Grand',
    'VAT',
    'Date',
    'Receipt',
    'Invoice',
    'bKash',
    'Nagad',
    'Rocket',
    'Cash',
    'Card',
    'Bangladesh',
    'Dhaka',
    'Certificate',
    'Registration',
  ];

  /// Normalizes a line to Unicode NFC, attaches uncertain words with up to 3
  /// alternatives, and optionally applies high-count exact remembered corrections.
  RecognizedLine processLine(
    RecognizedLine line, {
    List<RememberedCorrection> remembered = const [],
    List<String> nameBookWords = const [],
  }) {
    final normalized = unorm.nfc(line.text).trim();
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final exactMap = <String, RememberedCorrection>{};
    for (final c in remembered) {
      final key = unorm.nfc(c.wrongText).trim();
      final existing = exactMap[key];
      if (existing == null || c.count > existing.count) {
        exactMap[key] = c;
      }
    }

    final uncertain = <UncertainWord>[];
    final updatedTokens = List<String>.from(tokens);
    var autoCorrected = false;

    final vocab = <String>{
      ...remembered.map((r) => unorm.nfc(r.rightText).trim()),
      ...nameBookWords.map((w) => unorm.nfc(w).trim()),
      ...commonDocumentWords,
    };

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final cleanToken = _stripOuterPunctuation(token);
      if (cleanToken.length < 2) continue;

      final exact = exactMap[cleanToken];
      if (exact != null && exact.count >= 2 && line.confidence < 0.85) {
        updatedTokens[i] = token.replaceFirst(cleanToken, exact.rightText);
        autoCorrected = true;
        continue;
      }

      final isUncertain =
          line.confidence < uncertainLineThreshold || exact != null;
      if (isUncertain) {
        final alts = _suggestAlternatives(
          cleanToken,
          remembered: remembered,
          vocab: vocab,
        );
        if (line.confidence < uncertainLineThreshold || alts.isNotEmpty) {
          uncertain.add(
            UncertainWord(
              word: cleanToken,
              wordIndex: i,
              confidence: line.confidence,
              alternatives: alts,
            ),
          );
        }
      }
    }

    return line.copyWith(
      text: updatedTokens.join(' '),
      corrected: line.corrected || autoCorrected,
      uncertainWords: uncertain,
    );
  }

  /// Decides whether a page is partly handwritten (`02-architecture.md`):
  /// many lines have low confidence AND uneven stroke widths.
  bool detectHandwriting({
    required List<RecognizedLine> lines,
    required List<double> strokeVariances,
  }) {
    if (lines.isEmpty) return false;
    final lowConfCount = lines
        .where((l) => l.confidence < handwritingLineConfidence)
        .length;
    final lowConfRatio = lowConfCount / lines.length;
    final avgStrokeVar = strokeVariances.isEmpty
        ? 0.0
        : strokeVariances.reduce((a, b) => a + b) / strokeVariances.length;
    return lowConfRatio >= 0.35 && avgStrokeVar >= 0.42;
  }

  List<String> _suggestAlternatives(
    String word, {
    required List<RememberedCorrection> remembered,
    required Set<String> vocab,
  }) {
    final results = <String>[];

    // 1. Exact remembered correction always comes first.
    for (final c in remembered) {
      if (unorm.nfc(c.wrongText).trim() == word && c.rightText != word) {
        if (!results.contains(c.rightText)) results.add(c.rightText);
      }
    }

    // 2. Near-edit-distance matches from remembered rights, name book, and common words.
    final scored = <(int, String)>[];
    final maxDist = word.runes.length <= 4 ? 1 : 2;
    for (final candidate in vocab) {
      if (candidate == word ||
          candidate.isEmpty ||
          results.contains(candidate)) {
        continue;
      }
      if ((candidate.runes.length - word.runes.length).abs() > maxDist) {
        continue;
      }
      final dist = levenshtein(word, candidate);
      if (dist > 0 && dist <= maxDist) {
        scored.add((dist, candidate));
      }
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, cand) in scored) {
      results.add(cand);
      if (results.length >= 3) break;
    }
    return results.take(3).toList(growable: false);
  }

  String _stripOuterPunctuation(String s) {
    return s.replaceAll(RegExp(r'^[,.:;()\[\]<>।]+|[,.:;()\[\]<>।]+$'), '');
  }

  static int levenshtein(String a, String b) {
    final ra = a.runes.toList(growable: false);
    final rb = b.runes.toList(growable: false);
    if (ra.isEmpty) return rb.length;
    if (rb.isEmpty) return ra.length;
    var prev = List<int>.generate(rb.length + 1, (i) => i);
    var curr = List<int>.filled(rb.length + 1, 0);
    for (var i = 1; i <= ra.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= rb.length; j++) {
        final cost = ra[i - 1] == rb[j - 1] ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[rb.length];
  }
}
