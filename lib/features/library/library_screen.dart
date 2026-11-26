import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/utils/money.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/features/library/library_search_service.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

class LibraryPaperRowData {
  const LibraryPaperRowData({
    required this.scanId,
    required this.title,
    required this.kind,
    required this.date,
    required this.pageCount,
    required this.wordsToCheck,
    required this.hasEnglishDraft,
    this.amountLabel,
    this.renewBy,
  });

  final String scanId;
  final String title;
  final String kind;
  final DateTime date;
  final int pageCount;
  final int wordsToCheck;
  final bool hasEnglishDraft;
  final String? amountLabel;
  final DateTime? renewBy;
}

final libraryPapersProvider = FutureProvider.autoDispose
    .family<List<LibraryPaperRowData>, ({String filter, bool includeReceipts})>(
      (ref, args) async {
        final db = ref.watch(databaseProvider);
        final scans = await (db.select(
          db.scans,
        )..orderBy([(s) => OrderingTerm.desc(s.createdAt)])).get();
        if (scans.isEmpty) return const [];

        final docs = await db.select(db.documents).get();
        final receipts = await db.select(db.receipts).get();
        final pages = await db.select(db.scanPages).get();
        final translations = await db.select(db.translations).get();

        final docByScan = {for (final d in docs) d.scanId: d};
        final receiptByScan = {for (final r in receipts) r.scanId: r};
        final pageCountByScan = <String, int>{};
        for (final p in pages) {
          pageCountByScan[p.scanId] = (pageCountByScan[p.scanId] ?? 0) + 1;
        }
        final hasDraftSet = {for (final t in translations) t.scanId};

        final out = <LibraryPaperRowData>[];
        for (final s in scans) {
          final isReceipt = s.type == 'receipt' || s.kind == 'receipt';
          if (isReceipt && !args.includeReceipts) continue;
          if (!_matchesFilter(
            s.kind,
            isReceipt: isReceipt,
            filter: args.filter,
          )) {
            continue;
          }

          final doc = docByScan[s.id];
          final receipt = receiptByScan[s.id];
          if (doc == null && receipt == null && s.ocrRawText.trim().isEmpty) {
            continue;
          }

          final title =
              receipt?.merchant ??
              doc?.title ??
              s.ocrRawText
                  .split('\n')
                  .firstWhere(
                    (l) => l.trim().isNotEmpty,
                    orElse: () => 'Untitled paper',
                  );

          out.add(
            LibraryPaperRowData(
              scanId: s.id,
              title: title,
              kind: isReceipt ? 'receipt' : s.kind,
              date: receipt?.dateOfPurchase ?? s.createdAt,
              pageCount: pageCountByScan[s.id] ?? 1,
              wordsToCheck: s.checkCount,
              hasEnglishDraft: hasDraftSet.contains(s.id),
              amountLabel: receipt != null
                  ? formatMoney(receipt.total, receipt.currency)
                  : null,
              renewBy: s.renewBy,
            ),
          );
        }
        return out;
      },
    );

bool _matchesFilter(
  String kind, {
  required bool isReceipt,
  required String filter,
}) {
  return switch (filter) {
    'all' => true,
    'receipt' => isReceipt,
    'id' => kind == 'id',
    'land' => kind == 'land' || kind == 'deed',
    'document' =>
      !isReceipt && kind != 'id' && kind != 'land' && kind != 'deed',
    _ => true,
  };
}

final _librarySearchProvider = FutureProvider.autoDispose
    .family<LibrarySearchResult, ({String query, bool includeReceipts})>(
      (ref, args) => ref
          .watch(librarySearchServiceProvider)
          .search(args.query, includeReceipts: args.includeReceipts),
    );

/// Library & Search inside papers screen (`/library`) matching
/// `design/screens/library.png` and `design/screens/library-search.png`.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    this.initialQuery = '',
    this.previewPapers,
    this.previewSearchResult,
    super.key,
  });

  final String initialQuery;

  @visibleForTesting
  final List<LibraryPaperRowData>? previewPapers;

  @visibleForTesting
  final LibrarySearchResult? previewSearchResult;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _searchController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.previewSearchResult?.query ?? widget.initialQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty || widget.previewSearchResult != null;

    final chips = <(String, String)>[
      ('all', l10n.all),
      ('document', l10n.documents),
      ('id', l10n.ids),
      if (expenseEnabled) ('receipt', l10n.receipts),
      ('land', l10n.land),
    ];

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: l10n.library),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.bgSheet,
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
              border: Border.all(
                color: isSearching ? c.accentBase : c.lineSubtle,
                width: isSearching ? 1.6 : 1,
              ),
            ),
            child: TextField(
              key: const ValueKey('library-search-field'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
              decoration: InputDecoration(
                hintText: l10n.search,
                hintStyle: RosidTextTokens.uiBody.copyWith(
                  color: c.inkTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: RosidIcon(
                    RosidIcons.search,
                    size: 20,
                    color: c.inkSecondary,
                  ),
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('library-search-clear'),
                        icon: RosidIcon(
                          RosidIcons.close,
                          size: 18,
                          color: c.inkSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    RosidChip(
                      key: ValueKey('library-filter-${chips[i].$1}'),
                      label: chips[i].$2,
                      selected: _selectedFilter == chips[i].$1,
                      onTap: () =>
                          setState(() => _selectedFilter = chips[i].$1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildPaperGroups(context, locale, expenseEnabled),
          ] else ...[
            const SizedBox(height: 14),
            _buildSearchHits(context, locale, query, expenseEnabled),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperGroups(
    BuildContext context,
    Locale locale,
    bool expenseEnabled,
  ) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    if (widget.previewPapers != null) {
      return _MonthGroupedList(papers: widget.previewPapers!, locale: locale);
    }

    final papersAsync = ref.watch(
      libraryPapersProvider((
        filter: _selectedFilter,
        includeReceipts: expenseEnabled,
      )),
    );
    return papersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Center(child: Text(l10n.loadFailed)),
      data: (papers) {
        if (papers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.bgSheet,
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
              border: Border.all(color: c.lineSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.noPapersYet,
                  style: RosidTextTokens.uiHeading.copyWith(
                    color: c.inkPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.scanFirstPaperPrompt,
                  style: RosidTextTokens.uiCaption.copyWith(
                    color: c.inkSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                RosidButton(
                  label: l10n.scan,
                  kind: RosidButtonKind.tonal,
                  icon: RosidIcons.scan,
                  onPressed: () => context.push('/scan?mode=document'),
                ),
              ],
            ),
          );
        }
        return _MonthGroupedList(papers: papers, locale: locale);
      },
    );
  }

  Widget _buildSearchHits(
    BuildContext context,
    Locale locale,
    String query,
    bool expenseEnabled,
  ) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    Widget renderResult(LibrarySearchResult res) {
      if (res.hits.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              l10n.noResults,
              style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizeDigits(l10n.foundInPapers(res.paperCount), locale),
            style: RosidTextTokens.uiCaption.copyWith(
              color: c.inkSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < res.hits.length; i++) ...[
            if (i > 0) Divider(color: c.lineSubtle, height: 1),
            _SearchHitRow(
              hit: res.hits[i],
              locale: locale,
              onTap: () => context.push(
                '/paper/${res.hits[i].scanId}${res.hits[i].isEnglishDraft ? "?tab=english" : ""}',
              ),
            ),
          ],
          Divider(color: c.lineSubtle, height: 1),
        ],
      );
    }

    if (widget.previewSearchResult != null) {
      return renderResult(widget.previewSearchResult!);
    }

    final searchAsync = ref.watch(
      _librarySearchProvider((query: query, includeReceipts: expenseEnabled)),
    );
    return searchAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Center(child: Text(l10n.loadFailed)),
      data: renderResult,
    );
  }
}

class _MonthGroupedList extends StatelessWidget {
  const _MonthGroupedList({required this.papers, required this.locale});

  final List<LibraryPaperRowData> papers;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final groups = <String, List<LibraryPaperRowData>>{};
    final monthFmt = DateFormat.yMMMM(locale.toLanguageTag());
    for (final p in papers) {
      final key = localizeDigits(monthFmt.format(p.date), locale);
      groups.putIfAbsent(key, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              entry.key,
              style: RosidTextTokens.uiLabel.copyWith(
                color: c.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final p in entry.value) ...[
            _buildPaperRow(context, p, l10n),
            Divider(color: c.lineSubtle, height: 1),
          ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildPaperRow(
    BuildContext context,
    LibraryPaperRowData p,
    dynamic l10n,
  ) {
    final kindLabel = switch (p.kind) {
      'land' => l10n.landRecord as String,
      'deed' => l10n.paperKindDeed as String,
      'certificate' => l10n.certificate as String,
      'id' => l10n.idCard as String,
      'licence' => l10n.paperKindLicence as String,
      'bill' => l10n.paperKindBill as String,
      'receipt' => l10n.receipt as String,
      'letter' => l10n.paperKindLetter as String,
      'notes' => l10n.paperKindNotes as String,
      _ => l10n.document as String,
    };
    final dateShort = localizeDigits(
      DateFormat('d MMM', locale.toLanguageTag()).format(p.date),
      locale,
    );

    String? pillLabel;
    RosidTone pillTone = RosidTone.neutral;
    if (p.wordsToCheck > 0) {
      pillLabel = localizeDigits(
        l10n.wordsToCheckCount(p.wordsToCheck) as String,
        locale,
      );
      pillTone = RosidTone.warn;
    } else if (p.renewBy != null) {
      final rStr = localizeDigits(
        DateFormat('d MMM', locale.toLanguageTag()).format(p.renewBy!),
        locale,
      );
      pillLabel = l10n.renewByDate(rStr) as String;
      pillTone = RosidTone.neutral;
    } else if (p.hasEnglishDraft) {
      pillLabel = l10n.englishTab as String;
      pillTone = RosidTone.accent;
    }

    final thumbKind = switch (p.kind) {
      'land' || 'deed' => RosidPaperKind.land,
      'certificate' => RosidPaperKind.certificate,
      'id' => RosidPaperKind.id,
      'receipt' || 'bill' => RosidPaperKind.receipt,
      _ => RosidPaperKind.letter,
    };

    return RosidPaperRow(
      key: ValueKey('library-paper-${p.scanId}'),
      title: p.title,
      subtitle: '$kindLabel, $dateShort',
      kind: thumbKind,
      trailingTop: p.amountLabel != null
          ? localizeDigits(p.amountLabel!, locale)
          : localizeDigits(l10n.pagesCount(p.pageCount) as String, locale),
      pillLabel: pillLabel,
      pillTone: pillTone,
      onTap: () => context.push('/paper/${p.scanId}'),
    );
  }
}

class _SearchHitRow extends StatelessWidget {
  const _SearchHitRow({
    required this.hit,
    required this.locale,
    required this.onTap,
  });

  final LibrarySearchHit hit;
  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final whereLabel = hit.isEnglishDraft
        ? l10n.englishDraftLabel
        : localizeDigits(l10n.pageBanglaText(hit.pageNumber), locale);

    final thumbKind = switch (hit.kind) {
      'land' || 'deed' => RosidPaperKind.land,
      'certificate' => RosidPaperKind.certificate,
      'id' => RosidPaperKind.id,
      'receipt' || 'bill' => RosidPaperKind.receipt,
      _ => RosidPaperKind.letter,
    };

    return InkWell(
      key: ValueKey(
        'search-hit-${hit.scanId}-${hit.isEnglishDraft ? "en" : "bn"}',
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RosidPaperThumbnail(kind: thumbKind, width: 42, height: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.title,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    whereLabel,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _HighlightedSnippet(
                    text: hit.snippetLine,
                    terms: hit.matchedTerms,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.text, required this.terms});

  final String text;
  final List<String> terms;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final baseStyle = RosidTextTokens.docBody.copyWith(
      color: c.inkPrimary,
      fontSize: 15,
    );

    final words = text.split(' ');
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: baseStyle));
      final w = words[i];
      final wNorm = TextNormalizer.normalizeForSearch(w);
      final isHit =
          wNorm.isNotEmpty &&
          terms.any(
            (t) => t.isNotEmpty && (wNorm.contains(t) || t.contains(wNorm)),
          );
      if (isHit) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(w, style: baseStyle),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w, style: baseStyle));
      }
    }
    return Text.rich(TextSpan(children: spans));
  }
}
