import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/translation/bangla_transliterator.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_engine.dart';
import 'package:uuid/uuid.dart';

/// Parsed metadata stored in `translations.flags_json` for one translated line.
class DraftLineView {
  const DraftLineView({
    required this.translationId,
    required this.lineOrder,
    required this.sourceText,
    required this.englishText,
    required this.edited,
    required this.nameMarks,
    required this.termMentions,
  });

  final String translationId;
  final int lineOrder;
  final String sourceText;
  final String englishText;
  final bool edited;
  final List<DraftNameMark> nameMarks;
  final List<DraftTermMention> termMentions;
}

class _SeedTermMeta {
  const _SeedTermMeta({
    required this.id,
    required this.bangla,
    required this.aliases,
    required this.transliteration,
    required this.english,
    required this.both,
    required this.explanation,
    required this.defaultForm,
  });

  final String id;
  final String bangla;
  final List<String> aliases;
  final String transliteration;
  final String english;
  final String both;
  final String explanation;
  final String defaultForm;
}

/// Manages `terms`, `names`, and `translations` tables for M5 English drafts.
class TranslationRepository {
  TranslationRepository(this.db, this.engine);

  final AppDatabase db;
  final TranslationEngine engine;
  static const _uuid = Uuid();
  static const _rules = DraftRulesEngine();

  Map<String, _SeedTermMeta>? _seedMetaCache;

  Future<Map<String, _SeedTermMeta>> _loadSeedMeta() async {
    if (_seedMetaCache != null) return _seedMetaCache!;
    final raw = await rootBundle.loadString('assets/data/terms.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final map = <String, _SeedTermMeta>{};
    for (final item in decoded) {
      final m = item as Map<String, dynamic>;
      final meta = _SeedTermMeta(
        id: m['id'] as String,
        bangla: m['bangla'] as String,
        aliases: (m['aliases'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        transliteration: m['transliteration'] as String? ?? '',
        english: m['english'] as String? ?? '',
        both: m['both'] as String? ?? '',
        explanation: m['explanation'] as String? ?? '',
        defaultForm: m['defaultForm'] as String? ?? 'both',
      );
      map[meta.id] = meta;
    }
    _seedMetaCache = map;
    return map;
  }

  /// Ensures all 19 reference terms from `assets/data/terms.json` exist in the
  /// `terms` database table.
  Future<void> ensureTermsSeeded() async {
    final existingCount = (await db.select(db.terms).get()).length;
    if (existingCount > 0) return;
    final meta = await _loadSeedMeta();
    await db.batch((b) {
      for (final m in meta.values) {
        b.insert(
          db.terms,
          TermsCompanion.insert(
            id: m.id,
            bangla: m.bangla,
            transliteration: Value(m.transliteration),
            english: m.english,
            explanation: Value(m.explanation),
            chosenForm: Value(m.defaultForm),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<List<TermRule>> loadTerms() async {
    await ensureTermsSeeded();
    final meta = await _loadSeedMeta();
    final rows = await db.select(db.terms).get();
    return [
      for (final r in rows)
        TermRule(
          id: r.id,
          bangla: r.bangla,
          transliteration: r.transliteration,
          english: r.english,
          both:
              meta[r.id]?.both ??
              '${r.transliteration} (${r.english.toLowerCase()})',
          explanation: r.explanation,
          chosenForm: TermForm.fromCode(r.chosenForm),
          aliases: meta[r.id]?.aliases ?? const [],
        ),
    ];
  }

  /// Updates the user's preferred English rendering (`both`/`english`/`bangla`)
  /// for a term; applies across all land papers.
  Future<void> updateTermChoice(String termId, TermForm form) async {
    await ensureTermsSeeded();
    await (db.update(db.terms)..where((t) => t.id.equals(termId))).write(
      TermsCompanion(chosenForm: Value(form.code)),
    );
  }

  Future<List<NameBookRule>> loadNames() async {
    final rows =
        await (db.select(db.names)..orderBy([
              (n) => OrderingTerm.asc(n.category),
              (n) => OrderingTerm.desc(n.confirmed),
              (n) => OrderingTerm.asc(n.english),
            ]))
            .get();
    return [
      for (final r in rows)
        NameBookRule(
          id: r.id,
          bangla: r.bangla,
          english: r.english,
          category: r.category,
          source: r.source,
          confirmed: r.confirmed,
        ),
    ];
  }

  Future<NameBookRule> upsertName({
    String? id,
    required String bangla,
    required String english,
    required String category,
    required String source,
    bool? confirmed,
  }) async {
    final cleanBn = bangla.trim();
    final cleanEn = english.trim().isNotEmpty
        ? english.trim()
        : BanglaTransliterator.transliterate(cleanBn);
    final isConfirmed = confirmed ?? (source != 'suggested');

    String targetId = id ?? '';
    if (targetId.isEmpty) {
      final existing = await (db.select(
        db.names,
      )..where((n) => n.bangla.equals(cleanBn))).getSingleOrNull();
      if (existing != null) {
        targetId = existing.id;
      }
    }

    if (targetId.isNotEmpty) {
      await (db.update(db.names)..where((n) => n.id.equals(targetId))).write(
        NamesCompanion(
          bangla: Value(cleanBn),
          english: Value(cleanEn),
          category: Value(category),
          source: Value(source),
          confirmed: Value(isConfirmed),
        ),
      );
      return NameBookRule(
        id: targetId,
        bangla: cleanBn,
        english: cleanEn,
        category: category,
        source: source,
        confirmed: isConfirmed,
      );
    }

    final newId = _uuid.v7();
    await db
        .into(db.names)
        .insert(
          NamesCompanion.insert(
            id: newId,
            bangla: cleanBn,
            english: cleanEn,
            category: Value(category),
            source: Value(source),
            confirmed: Value(isConfirmed),
          ),
        );
    return NameBookRule(
      id: newId,
      bangla: cleanBn,
      english: cleanEn,
      category: category,
      source: source,
      confirmed: isConfirmed,
    );
  }

  Future<void> deleteName(String id) async {
    await (db.delete(db.names)..where((n) => n.id.equals(id))).go();
  }

  /// Loads persisted translated draft lines for [scanId], or returns empty list
  /// if no draft has been created yet.
  Future<List<DraftLineView>> loadDraft(String scanId) async {
    final rows =
        await (db.select(db.translations)
              ..where((t) => t.scanId.equals(scanId))
              ..orderBy([(t) => OrderingTerm.asc(t.lineOrder)]))
            .get();
    return rows.map(_rowToView).toList();
  }

  /// Builds or refreshes the English draft for [scanId].
  ///
  /// - Preserves any user-edited English line (`edited == true`) when remaking
  ///   the draft unless the source Bangla line changed.
  /// - Sends only free-text Bangla lines to the on-device Bergamot WASM model,
  ///   with numbers, dates, terms, and Name Book spellings protected by
  ///   placeholders.
  /// - Records newly seen unconfirmed names into the `names` table as
  ///   `source = 'suggested'`.
  Future<List<DraftLineView>> generateOrRefreshDraft(
    String scanId, {
    bool forceRefreshUnedited = true,
  }) async {
    final terms = await loadTerms();
    final names = await loadNames();

    final textLines =
        await (db.select(db.textLines)
              ..where((l) => l.scanId.equals(scanId))
              ..orderBy([
                (l) => OrderingTerm.asc(l.pageIndex),
                (l) => OrderingTerm.asc(l.lineOrder),
              ]))
            .get();

    final scan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    final doc = await (db.select(
      db.documents,
    )..where((d) => d.scanId.equals(scanId))).getSingleOrNull();

    // Determine source lines (prefer structured text_lines, fall back to document body / raw OCR).
    final sourceEntries = <(String?, String)>[];
    if (textLines.isNotEmpty) {
      for (final l in textLines) {
        if (l.textContent.trim().isNotEmpty) {
          sourceEntries.add((l.id, l.textContent.trim()));
        }
      }
    } else {
      final rawBody = (doc?.body.trim().isNotEmpty ?? false)
          ? doc!.body
          : (scan?.ocrRawText ?? '');
      for (final rawLine in rawBody.split('\n')) {
        if (rawLine.trim().isNotEmpty) {
          sourceEntries.add((null, rawLine.trim()));
        }
      }
    }

    if (sourceEntries.isEmpty) return const [];

    final existingRows =
        await (db.select(db.translations)
              ..where((t) => t.scanId.equals(scanId))
              ..orderBy([(t) => OrderingTerm.asc(t.lineOrder)]))
            .get();

    // If not forcing refresh and we already have matching lines, return them.
    if (!forceRefreshUnedited &&
        existingRows.length == sourceEntries.length &&
        _sourcesMatch(existingRows, sourceEntries)) {
      return existingRows.map(_rowToView).toList();
    }

    // Map previous edited rows by lineId or exact sourceText so user edits survive remakes!
    final preservedByLineId = <String, Translation>{};
    final preservedBySource = <String, Translation>{};
    for (final row in existingRows) {
      if (row.edited) {
        if (row.lineId != null) preservedByLineId[row.lineId!] = row;
        preservedBySource[row.sourceText] = row;
      }
    }

    // Prepare every line via pure rules first.
    final prepared = <PreparedLine>[];
    final freeTextIndices = <int>[];
    final freeTextInputs = <String>[];

    for (var i = 0; i < sourceEntries.length; i++) {
      final (lineId, src) = sourceEntries[i];
      final prep = _rules.prepareLine(src, names: names, terms: terms);
      prepared.add(prep);

      final preserved =
          (lineId != null ? preservedByLineId[lineId] : null) ??
          preservedBySource[src];
      final keepUserEdit = preserved != null && preserved.sourceText == src;
      if (!keepUserEdit && prep.hasFreeTextForModel) {
        freeTextIndices.add(i);
        freeTextInputs.add(prep.maskedForModel);
      }
    }

    // Translate all free-text lines in one batched Bergamot WASM call.
    final modelOutputs = freeTextInputs.isEmpty
        ? const <String>[]
        : await engine.translateBatch(freeTextInputs);
    final modelOutputByIndex = <int, String>{};
    for (var k = 0; k < freeTextIndices.length; k++) {
      if (k < modelOutputs.length && modelOutputs[k].trim().isNotEmpty) {
        modelOutputByIndex[freeTextIndices[k]] = modelOutputs[k];
      }
    }

    final newSuggestedNames = <DraftNameMark>[];
    final savedViews = <DraftLineView>[];

    await db.transaction(() async {
      await (db.delete(
        db.translations,
      )..where((t) => t.scanId.equals(scanId))).go();

      for (var i = 0; i < sourceEntries.length; i++) {
        final (lineId, src) = sourceEntries[i];
        final prep = prepared[i];
        final preserved =
            (lineId != null ? preservedByLineId[lineId] : null) ??
            preservedBySource[src];
        final keepUserEdit = preserved != null && preserved.sourceText == src;

        final result = _rules.finalizeLine(
          prep,
          modelOutput: modelOutputByIndex[i],
        );

        for (final mark in result.nameMarks) {
          if (mark.status == DraftNameStatus.newNameCheck) {
            newSuggestedNames.add(mark);
          }
        }

        final englishText = keepUserEdit
            ? preserved.englishText
            : result.englishDraft;
        final flags = _encodeFlags(result.nameMarks, result.termMentions);
        final rowId = _uuid.v7();

        await db
            .into(db.translations)
            .insert(
              TranslationsCompanion.insert(
                id: rowId,
                scanId: scanId,
                lineId: Value(lineId),
                lineOrder: i,
                sourceText: Value(src),
                englishText: englishText,
                flagsJson: Value(flags),
                edited: Value(keepUserEdit),
              ),
            );

        savedViews.add(
          DraftLineView(
            translationId: rowId,
            lineOrder: i,
            sourceText: src,
            englishText: englishText,
            edited: keepUserEdit,
            nameMarks: result.nameMarks,
            termMentions: result.termMentions,
          ),
        );
      }

      // Auto-record unseen suggested names in the `names` table (if not already present).
      final existingNameKeys = names.map((n) => n.bangla.trim()).toSet();
      for (final mark in newSuggestedNames) {
        final key = mark.bangla.trim();
        if (key.isEmpty || existingNameKeys.contains(key)) continue;
        existingNameKeys.add(key);
        await db
            .into(db.names)
            .insert(
              NamesCompanion.insert(
                id: _uuid.v7(),
                bangla: key,
                english: mark.english,
                category: Value(mark.category),
                source: const Value('suggested'),
                confirmed: const Value(false),
              ),
            );
      }
    });

    await _reindexScanWithTranslation(scanId, savedViews, names);
    return savedViews;
  }

  /// Updates a single English draft line edited by the user and marks `edited = true`.
  Future<void> updateDraftLine({
    required String scanId,
    required String translationId,
    required String newEnglishText,
  }) async {
    final trimmed = newEnglishText.trim();
    if (trimmed.isEmpty) return;
    await (db.update(
      db.translations,
    )..where((t) => t.id.equals(translationId))).write(
      TranslationsCompanion(
        englishText: Value(trimmed),
        edited: const Value(true),
      ),
    );
    final updated = await loadDraft(scanId);
    final names = await loadNames();
    await _reindexScanWithTranslation(scanId, updated, names);
  }

  bool _sourcesMatch(
    List<Translation> rows,
    List<(String?, String)> sourceEntries,
  ) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].sourceText != sourceEntries[i].$2) return false;
    }
    return true;
  }

  Future<void> _reindexScanWithTranslation(
    String scanId,
    List<DraftLineView> draftLines,
    List<NameBookRule> names,
  ) async {
    final scan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    if (scan == null) return;
    final doc = await (db.select(
      db.documents,
    )..where((d) => d.scanId.equals(scanId))).getSingleOrNull();
    final lines = await (db.select(
      db.textLines,
    )..where((l) => l.scanId.equals(scanId))).get();
    final combinedBn = lines.map((l) => l.textContent).join('\n');
    final matchedNameEnglish = <String>[
      for (final n in names)
        if (combinedBn.contains(n.bangla) ||
            (doc?.body.contains(n.bangla) ?? false))
          n.english,
    ];
    await db.indexScan(
      scanId: scanId,
      text: [
        scan.ocrRawText,
        combinedBn,
        doc?.title,
        doc?.body,
        draftLines.map((d) => d.englishText).join('\n'),
        matchedNameEnglish.join(' '),
      ],
    );
  }

  static String _encodeFlags(
    List<DraftNameMark> nameMarks,
    List<DraftTermMention> termMentions,
  ) {
    return jsonEncode({
      'names': [
        for (final n in nameMarks)
          {
            'bangla': n.bangla,
            'english': n.english,
            'category': n.category,
            'status': n.status == DraftNameStatus.fromNameBook ? 'book' : 'new',
          },
      ],
      'terms': [
        for (final t in termMentions)
          {'id': t.termId, 'rendered': t.renderedText},
      ],
    });
  }

  static DraftLineView _rowToView(Translation row) {
    final nameMarks = <DraftNameMark>[];
    final termMentions = <DraftTermMention>[];
    try {
      final decoded = jsonDecode(row.flagsJson) as Map<String, dynamic>;
      for (final item in (decoded['names'] as List<dynamic>? ?? const [])) {
        final m = item as Map<String, dynamic>;
        nameMarks.add(
          DraftNameMark(
            bangla: m['bangla'] as String? ?? '',
            english: m['english'] as String? ?? '',
            category: m['category'] as String? ?? 'person',
            status: m['status'] == 'book'
                ? DraftNameStatus.fromNameBook
                : DraftNameStatus.newNameCheck,
          ),
        );
      }
      for (final item in (decoded['terms'] as List<dynamic>? ?? const [])) {
        final m = item as Map<String, dynamic>;
        termMentions.add(
          DraftTermMention(
            termId: m['id'] as String? ?? '',
            renderedText: m['rendered'] as String? ?? '',
          ),
        );
      }
    } on Object {
      // Ignore malformed legacy flags.
    }

    return DraftLineView(
      translationId: row.id,
      lineOrder: row.lineOrder,
      sourceText: row.sourceText,
      englishText: row.englishText,
      edited: row.edited,
      nameMarks: nameMarks,
      termMentions: termMentions,
    );
  }
}

final translationRepositoryProvider = Provider<TranslationRepository>(
  (ref) => TranslationRepository(
    ref.watch(databaseProvider),
    ref.watch(translationEngineProvider),
  ),
);

final termsListProvider = FutureProvider<List<TermRule>>(
  (ref) => ref.watch(translationRepositoryProvider).loadTerms(),
);

final namesBookProvider = FutureProvider<List<NameBookRule>>(
  (ref) => ref.watch(translationRepositoryProvider).loadNames(),
);
