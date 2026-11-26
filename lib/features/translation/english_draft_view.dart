import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/features/translation/name_book_screen.dart';
import 'package:rosid/features/translation/term_help_sheet.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_engine.dart';
import 'package:rosid/translation/translation_repository.dart';

/// English draft tab body and bottom bar matching
/// `design/screens/translate-english-draft.png` and
/// `design/screens/translate-english-draft-dark.png`.
///
/// Keeps the hidden Bergamot WebView alive while mounted and releases it on
/// dispose (`handover/milestones/M5-english-draft.md` step 3).
class EnglishDraftView extends ConsumerStatefulWidget {
  const EnglishDraftView({
    required this.scanId,
    required this.onExport,
    this.previewLines,
    this.previewTerms,
    super.key,
  });

  final String scanId;
  final VoidCallback onExport;

  @visibleForTesting
  final List<DraftLineView>? previewLines;

  @visibleForTesting
  final List<TermRule>? previewTerms;

  @override
  ConsumerState<EnglishDraftView> createState() => _EnglishDraftViewState();
}

class _EnglishDraftViewState extends ConsumerState<EnglishDraftView> {
  List<DraftLineView>? _lines;
  List<TermRule> _terms = const [];
  bool _loading = true;
  String? _error;
  TranslationEngine? _engine;

  @override
  void initState() {
    super.initState();
    if (widget.previewLines != null) {
      _lines = widget.previewLines;
      _terms = widget.previewTerms ?? const [];
      _loading = false;
    } else {
      _engine = ref.read(translationEngineProvider);
      _loadOrGenerate(forceRefresh: false);
    }
  }

  @override
  void dispose() {
    // Release hidden WebView when leaving the English tab.
    _engine?.release();
    super.dispose();
  }

  Future<void> _loadOrGenerate({required bool forceRefresh}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = ref.read(translationRepositoryProvider);
      final terms = await repo.loadTerms();
      final draft = await repo.generateOrRefreshDraft(
        widget.scanId,
        forceRefreshUnedited: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _lines = draft;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'failed';
      });
    }
  }

  TermRule? _findTerm(String id) {
    for (final t in _terms) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _openTermHelp(String termId) async {
    final term = _findTerm(termId);
    if (term == null) return;
    final changed = await showTermHelpSheet(context, ref, term);
    if (changed && mounted) {
      await _loadOrGenerate(forceRefresh: true);
    }
  }

  Future<void> _openTermsPicker() async {
    final changed = await showTermsPickerSheet(context, ref);
    if (changed && mounted) {
      await _loadOrGenerate(forceRefresh: true);
    }
  }

  Future<void> _openNameBook() async {
    await context.push('/names');
    if (mounted && widget.previewLines == null) {
      await _loadOrGenerate(forceRefresh: true);
    }
  }

  Future<void> _confirmSuggestedName(DraftNameMark mark) async {
    final names = await ref.read(translationRepositoryProvider).loadNames();
    NameBookRule? existing;
    for (final n in names) {
      if (n.bangla.trim() == mark.bangla.trim()) {
        existing = n;
        break;
      }
    }
    if (!mounted) return;
    final changed = await showNameEditorSheet(
      context,
      ref,
      existing: existing,
      initialBangla: mark.bangla,
      initialEnglish: mark.english,
      initialCategory: mark.category,
    );
    if (changed && mounted && widget.previewLines == null) {
      await _loadOrGenerate(forceRefresh: true);
    }
  }

  Future<void> _openLineEditor() async {
    final lines = _lines ?? const <DraftLineView>[];
    if (lines.isEmpty) return;

    final result = await showModalBottomSheet<_DraftEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditDraftSheet(lines: lines),
    );

    if (result == null) return;
    if (result.action == 'save') {
      final repo = ref.read(translationRepositoryProvider);
      for (final line in lines) {
        final next = (result.values[line.translationId] ?? '').trim();
        if (next.isNotEmpty && next != line.englishText.trim()) {
          await repo.updateDraftLine(
            scanId: widget.scanId,
            translationId: line.translationId,
            newEnglishText: next,
          );
        }
      }
      if (mounted) {
        await _loadOrGenerate(forceRefresh: false);
      }
    } else if (result.action == 'remake' && mounted) {
      await _loadOrGenerate(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    return Column(
      children: [
        Expanded(
          child: _loading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l10n.makingEnglishDraft,
                          textAlign: TextAlign.center,
                          style: RosidTextTokens.uiBody.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.loadFailed,
                          style: RosidTextTokens.uiBody.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RosidButton(
                          label: l10n.remakeDraft,
                          onPressed: () => _loadOrGenerate(forceRefresh: true),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _DraftInfoBanner(text: l10n.englishDraftBanner),
                    const SizedBox(height: 14),
                    _EnglishPaperSurface(
                      lines: _lines ?? const [],
                      draftLabel: l10n.draftStamp,
                      onTapTerm: _openTermHelp,
                      onTapNewName: _confirmSuggestedName,
                    ),
                  ],
                ),
        ),
        _EnglishActionBar(
          onNames: _openNameBook,
          onTerms: _openTermsPicker,
          onEdit: _openLineEditor,
          onExport: widget.onExport,
        ),
      ],
    );
  }
}

class _DraftInfoBanner extends StatelessWidget {
  const _DraftInfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Container(
      key: const ValueKey('english-draft-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: RosidIcon(
              RosidIcons.translate,
              size: 20,
              color: c.accentInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: RosidTextTokens.uiCaption.copyWith(
                color: c.accentInk,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paper surface for the English draft: ALWAYS light paper (`paperSheetLight`)
/// with dark ink (`paperInkLight`) even in dark theme, matching
/// `design/screens/translate-english-draft-dark.png`.
class _EnglishPaperSurface extends StatelessWidget {
  const _EnglishPaperSurface({
    required this.lines,
    required this.draftLabel,
    required this.onTapTerm,
    required this.onTapNewName,
  });

  final List<DraftLineView> lines;
  final String draftLabel;
  final ValueChanged<String> onTapTerm;
  final ValueChanged<DraftNameMark> onTapNewName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      key: const ValueKey('english-draft-paper'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: RosidColorTokens.paperSheetLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RosidColorTokens.paperLineLight),
        boxShadow: RosidShadowTokens.elevPaper,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            right: 0,
            child: Theme(
              data: AppTheme.light(),
              child: RosidStamp(
                key: const ValueKey('english-draft-stamp'),
                label: draftLabel,
                tone: RosidStampTone.accent,
                angleRadians: 0.08,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _DraftLineBlock(
                  line: lines[i],
                  reserveStampRoom: i == 0,
                  onTapTerm: onTapTerm,
                  onTapNewName: onTapNewName,
                  fromNameBookLabel: l10n.spellingFromNameBook,
                  newNameLabel: l10n.newNameCheckSpelling,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DraftLineBlock extends StatelessWidget {
  const _DraftLineBlock({
    required this.line,
    required this.reserveStampRoom,
    required this.onTapTerm,
    required this.onTapNewName,
    required this.fromNameBookLabel,
    required this.newNameLabel,
  });

  final DraftLineView line;
  final bool reserveStampRoom;
  final ValueChanged<String> onTapTerm;
  final ValueChanged<DraftNameMark> onTapNewName;
  final String fromNameBookLabel;
  final String newNameLabel;

  @override
  Widget build(BuildContext context) {
    final mutedPaperInk = RosidColorTokens.paperInkLight.withValues(
      alpha: 0.54,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: reserveStampRoom ? 92 : 0),
          child: Text(
            line.sourceText,
            style: RosidTextTokens.uiCaption.copyWith(
              color: mutedPaperInk,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: EdgeInsets.only(right: reserveStampRoom ? 74 : 0),
          child: _TermRichLine(
            text: line.englishText,
            mentions: line.termMentions,
            onTapTerm: onTapTerm,
          ),
        ),
        for (final mark in line.nameMarks) ...[
          const SizedBox(height: 5),
          _NameStatusLine(
            mark: mark,
            fromNameBookLabel: fromNameBookLabel,
            newNameLabel: newNameLabel,
            onTapNewName: () => onTapNewName(mark),
          ),
        ],
      ],
    );
  }
}

class _TermRichLine extends StatelessWidget {
  const _TermRichLine({
    required this.text,
    required this.mentions,
    required this.onTapTerm,
  });

  final String text;
  final List<DraftTermMention> mentions;
  final ValueChanged<String> onTapTerm;

  @override
  Widget build(BuildContext context) {
    final baseStyle = RosidTextTokens.docBody.copyWith(
      color: RosidColorTokens.paperInkLight,
      fontSize: 15.5,
      height: 1.45,
    );

    if (mentions.isEmpty) {
      return Text(text, style: baseStyle);
    }

    // Highlight the first clickable legal term token (e.g. `Khatian` in
    // `Khatian (record of rights) No. 1245`), matching `translate-english-draft.png`.
    final spans = <InlineSpan>[];
    var cursor = 0;

    // Sort mentions by their occurrence index in text.
    final matches = <(int, int, String)>[];
    for (final m in mentions) {
      // Prefer underlining the lead word before parentheses (e.g. "Khatian")
      // or the full rendered term if short.
      final lead = m.renderedText.contains('(')
          ? m.renderedText.split('(').first.trim()
          : m.renderedText;
      if (lead.isEmpty) continue;
      final idx = text.indexOf(lead, cursor);
      if (idx >= 0) {
        matches.add((idx, idx + lead.length, m.termId));
      }
    }
    matches.sort((a, b) => a.$1.compareTo(b.$1));

    for (final (start, end, termId) in matches) {
      if (start < cursor) continue;
      if (start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, start), style: baseStyle),
        );
      }
      final linkText = text.substring(start, end);
      spans.add(
        TextSpan(
          text: linkText,
          style: baseStyle.copyWith(
            color: RosidColorTokens.accentBaseLight,
            decoration: TextDecoration.underline,
            decorationColor: RosidColorTokens.accentBaseLight,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => onTapTerm(termId),
        ),
      );
      cursor = end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class _NameStatusLine extends StatelessWidget {
  const _NameStatusLine({
    required this.mark,
    required this.fromNameBookLabel,
    required this.newNameLabel,
    required this.onTapNewName,
  });

  final DraftNameMark mark;
  final String fromNameBookLabel;
  final String newNameLabel;
  final VoidCallback onTapNewName;

  @override
  Widget build(BuildContext context) {
    final isBook = mark.status == DraftNameStatus.fromNameBook;
    final color = isBook
        ? RosidColorTokens.goodBaseLight
        : RosidColorTokens.warnBaseLight;
    final icon = isBook ? RosidIcons.checkCircle : RosidIcons.alert;
    final label = isBook ? fromNameBookLabel : newNameLabel;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RosidIcon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: RosidTextTokens.uiMicro.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (isBook) return row;
    return InkWell(
      key: ValueKey('new-name-mark-${mark.bangla}'),
      onTap: onTapNewName,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

class _EnglishActionBar extends StatelessWidget {
  const _EnglishActionBar({
    required this.onNames,
    required this.onTerms,
    required this.onEdit,
    required this.onExport,
  });

  final VoidCallback onNames;
  final VoidCallback onTerms;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: c.bgSheet,
        border: Border(top: BorderSide(color: c.lineSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _DraftBarAction(
              key: const ValueKey('english-action-names'),
              icon: RosidIcons.people,
              label: l10n.names,
              onTap: onNames,
            ),
            _DraftBarAction(
              key: const ValueKey('english-action-terms'),
              icon: RosidIcons.book,
              label: l10n.terms,
              onTap: onTerms,
            ),
            _DraftBarAction(
              key: const ValueKey('english-action-edit'),
              icon: RosidIcons.edit,
              label: l10n.edit,
              onTap: onEdit,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RosidButton(
                key: const ValueKey('english-action-export'),
                label: l10n.export,
                icon: RosidIcons.share,
                expand: true,
                onPressed: onExport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftBarAction extends StatelessWidget {
  const _DraftBarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final RosidIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RosidIcon(icon, size: 20, color: c.inkPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RosidTextTokens.uiMicro.copyWith(color: c.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftEditorResult {
  const _DraftEditorResult({required this.action, this.values = const {}});

  final String action;
  final Map<String, String> values;
}

class _EditDraftSheet extends StatefulWidget {
  const _EditDraftSheet({required this.lines});

  final List<DraftLineView> lines;

  @override
  State<_EditDraftSheet> createState() => _EditDraftSheetState();
}

class _EditDraftSheetState extends State<_EditDraftSheet> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = <String, TextEditingController>{
      for (final l in widget.lines)
        l.translationId: TextEditingController(text: l.englishText),
    };
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.editEnglishDraft,
                    style: RosidTextTokens.uiTitle.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.editEnglishLineHint,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.lineSubtle, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                itemCount: widget.lines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, idx) {
                  final line = widget.lines[idx];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.sourceText,
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        key: ValueKey('edit-draft-line-$idx'),
                        controller: _controllers[line.translationId],
                        maxLines: null,
                        style: RosidTextTokens.docBody.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                color: c.bgSheet,
                border: Border(top: BorderSide(color: c.lineSubtle)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    RosidButton(
                      key: const ValueKey('draft-editor-remake'),
                      label: l10n.remakeDraft,
                      kind: RosidButtonKind.outline,
                      onPressed: () =>
                          Navigator.of(ctx)
                              .pop(const _DraftEditorResult(action: 'remake')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RosidButton(
                        key: const ValueKey('draft-editor-save'),
                        label: l10n.save,
                        expand: true,
                        onPressed: () => Navigator.of(ctx).pop(
                          _DraftEditorResult(
                            action: 'save',
                            values: {
                              for (final e in _controllers.entries)
                                e.key: e.value.text,
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
