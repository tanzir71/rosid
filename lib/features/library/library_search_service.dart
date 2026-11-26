import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

/// A single snippet match card shown on `library-search.png`.
class LibrarySearchHit {
  const LibrarySearchHit({
    required this.scanId,
    required this.title,
    required this.kind,
    required this.isEnglishDraft,
    required this.pageNumber,
    required this.snippetLine,
    required this.matchedTerms,
  });

  final String scanId;
  final String title;
  final String kind;
  final bool isEnglishDraft;
  final int pageNumber;
  final String snippetLine;
  final List<String> matchedTerms;
}

class LibrarySearchResult {
  const LibrarySearchResult({
    required this.query,
    required this.paperCount,
    required this.hits,
    required this.elapsedMs,
  });

  final String query;
  final int paperCount;
  final List<LibrarySearchHit> hits;
  final int elapsedMs;
}

/// Full-text search across Bangla text, English drafts, and cross-script Name
/// Book spellings (`handover/milestones/M7-library-and-bundles.md`).
class LibrarySearchService {
  const LibrarySearchService(this.db);

  final AppDatabase db;

  /// Searches across FTS5 (`scan_search`) with Name Book cross-script expansion
  /// and returns paper match snippets with highlighted terms.
  Future<LibrarySearchResult> search(
    String rawQuery, {
    bool includeReceipts = true,
  }) async {
    final sw = Stopwatch()..start();
    final normQuery = TextNormalizer.normalizeForSearch(rawQuery);
    if (normQuery.isEmpty) {
      sw.stop();
      return LibrarySearchResult(
        query: rawQuery,
        paperCount: 0,
        hits: const [],
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    // 1. Expand query through the Name Book in both directions (Bangla <-> English).
    final expandedTerms = <String>{normQuery};
    final nameRows = await db.select(db.names).get();
    for (final n in nameRows) {
      final bnNorm = TextNormalizer.normalizeForSearch(n.bangla);
      final enNorm = TextNormalizer.normalizeForSearch(n.english);
      if (bnNorm.isEmpty || enNorm.isEmpty) continue;
      if (bnNorm.contains(normQuery) || normQuery.contains(bnNorm)) {
        expandedTerms.add(enNorm);
      }
      if (enNorm.contains(normQuery) || normQuery.contains(enNorm)) {
        expandedTerms.add(bnNorm);
      }
    }

    // Build safe FTS5 OR expression: `"term1"* OR "term2"*`
    final ftsClauses = <String>[];
    for (final term in expandedTerms) {
      final tokens = term
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .map((t) => '"${t.replaceAll('"', '')}"*')
          .toList();
      if (tokens.isNotEmpty) {
        ftsClauses.add('(${tokens.join(' ')})');
      }
    }
    if (ftsClauses.isEmpty) {
      sw.stop();
      return LibrarySearchResult(
        query: rawQuery,
        paperCount: 0,
        hits: const [],
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    final ftsExpr = ftsClauses.join(' OR ');
    final rows = await db
        .customSelect(
          'SELECT DISTINCT scan_id FROM scan_search WHERE scan_search MATCH ? LIMIT 80',
          variables: [Variable<String>(ftsExpr)],
          readsFrom: {db.scans},
        )
        .get();
    final matchedScanIds = rows.map((r) => r.read<String>('scan_id')).toList();

    if (matchedScanIds.isEmpty) {
      sw.stop();
      return LibrarySearchResult(
        query: rawQuery,
        paperCount: 0,
        hits: const [],
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    // 2. Fetch metadata + lines + translations ONLY for the matched scans.
    final scanRows = await (db.select(
      db.scans,
    )..where((s) => s.id.isIn(matchedScanIds))).get();
    final filteredScans = includeReceipts
        ? scanRows
        : scanRows.where((s) => s.type != 'receipt').toList();
    final filteredIds = filteredScans.map((s) => s.id).toList();
    if (filteredIds.isEmpty) {
      sw.stop();
      return LibrarySearchResult(
        query: rawQuery,
        paperCount: 0,
        hits: const [],
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    final docRows = await (db.select(
      db.documents,
    )..where((d) => d.scanId.isIn(filteredIds))).get();
    final receiptRows = await (db.select(
      db.receipts,
    )..where((r) => r.scanId.isIn(filteredIds))).get();
    final lineRows =
        await (db.select(db.textLines)
              ..where((l) => l.scanId.isIn(filteredIds))
              ..orderBy([
                (l) => OrderingTerm.asc(l.pageIndex),
                (l) => OrderingTerm.asc(l.lineOrder),
              ]))
            .get();
    final transRows =
        await (db.select(db.translations)
              ..where((t) => t.scanId.isIn(filteredIds))
              ..orderBy([(t) => OrderingTerm.asc(t.lineOrder)]))
            .get();

    final docByScan = {for (final d in docRows) d.scanId: d};
    final receiptByScan = {for (final r in receiptRows) r.scanId: r};
    final linesByScan = <String, List<TextLine>>{};
    for (final l in lineRows) {
      linesByScan.putIfAbsent(l.scanId, () => []).add(l);
    }
    final transByScan = <String, List<Translation>>{};
    for (final t in transRows) {
      transByScan.putIfAbsent(t.scanId, () => []).add(t);
    }

    final termList = expandedTerms.toList();
    final hits = <LibrarySearchHit>[];
    final matchedPaperSet = <String>{};

    for (final scan in filteredScans) {
      final doc = docByScan[scan.id];
      final receipt = receiptByScan[scan.id];
      final title =
          receipt?.merchant ??
          doc?.title ??
          scan.ocrRawText
              .split('\n')
              .firstWhere(
                (l) => l.trim().isNotEmpty,
                orElse: () => 'Untitled paper',
              );

      // Find best matching Bangla / source line.
      TextLine? matchedBnLine;
      for (final l in linesByScan[scan.id] ?? const <TextLine>[]) {
        final norm = TextNormalizer.normalizeForSearch(l.textContent);
        if (termList.any(norm.contains)) {
          matchedBnLine = l;
          break;
        }
      }

      if (matchedBnLine != null) {
        matchedPaperSet.add(scan.id);
        hits.add(
          LibrarySearchHit(
            scanId: scan.id,
            title: title,
            kind: scan.kind,
            isEnglishDraft: false,
            pageNumber: matchedBnLine.pageIndex + 1,
            snippetLine: matchedBnLine.textContent,
            matchedTerms: termList,
          ),
        );
      } else {
        // Fallback: check document body / raw OCR lines.
        final fallbackBody = (doc?.body.trim().isNotEmpty ?? false)
            ? doc!.body
            : scan.ocrRawText;
        for (final line in fallbackBody.split('\n')) {
          final norm = TextNormalizer.normalizeForSearch(line);
          if (norm.isNotEmpty && termList.any(norm.contains)) {
            matchedPaperSet.add(scan.id);
            hits.add(
              LibrarySearchHit(
                scanId: scan.id,
                title: title,
                kind: scan.kind,
                isEnglishDraft: false,
                pageNumber: 1,
                snippetLine: line.trim(),
                matchedTerms: termList,
              ),
            );
            break;
          }
        }
      }

      // Also find matching English draft line (shown as separate hit card in `library-search.png`).
      for (final t in transByScan[scan.id] ?? const <Translation>[]) {
        final norm = TextNormalizer.normalizeForSearch(t.englishText);
        if (termList.any(norm.contains)) {
          matchedPaperSet.add(scan.id);
          hits.add(
            LibrarySearchHit(
              scanId: scan.id,
              title: title,
              kind: scan.kind,
              isEnglishDraft: true,
              pageNumber: 1,
              snippetLine: t.englishText,
              matchedTerms: termList,
            ),
          );
          break;
        }
      }

      // If matched only via title/merchant/tag, still include a hit.
      if (!matchedPaperSet.contains(scan.id)) {
        matchedPaperSet.add(scan.id);
        hits.add(
          LibrarySearchHit(
            scanId: scan.id,
            title: title,
            kind: scan.kind,
            isEnglishDraft: false,
            pageNumber: 1,
            snippetLine: title,
            matchedTerms: termList,
          ),
        );
      }
    }

    sw.stop();
    return LibrarySearchResult(
      query: rawQuery,
      paperCount: matchedPaperSet.length,
      hits: hits,
      elapsedMs: sw.elapsedMilliseconds,
    );
  }
}

final librarySearchServiceProvider = Provider<LibrarySearchService>(
  (ref) => LibrarySearchService(ref.watch(databaseProvider)),
);
