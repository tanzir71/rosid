import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';

/// Check words screen (`design/screens/read-check-words.png`).
/// Shows one uncertain word at a time with an enlarged crop from the scan,
/// editable reading field, up to 3 alternatives (remembered corrections first),
/// Skip, and Looks right.
class CheckWordsScreen extends ConsumerStatefulWidget {
  const CheckWordsScreen({
    required this.scanId,
    this.previewCropWidget,
    super.key,
  });

  final String scanId;

  @visibleForTesting
  final Widget? previewCropWidget;

  @override
  ConsumerState<CheckWordsScreen> createState() => _CheckWordsScreenState();
}

class _CheckWordsScreenState extends ConsumerState<CheckWordsScreen> {
  final TextEditingController _controller = TextEditingController();
  int _index = 0;
  String? _loadedForCandidateKey;
  bool _addToNameBook = false;
  bool _saving = false;
  Uint8List? _cachedCropBytes;
  String? _cachedCropKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncCandidate(WordCheckCandidate candidate) {
    final key = '${candidate.line.id}:${candidate.wordIndex}:${candidate.word}';
    if (_loadedForCandidateKey == key) return;
    _loadedForCandidateKey = key;
    _controller.text = candidate.word;
    _addToNameBook = false;
    _loadLineCrop(candidate, key);
  }

  Future<void> _loadLineCrop(WordCheckCandidate candidate, String key) async {
    if (widget.previewCropWidget != null) return;
    final path = candidate.pageImagePath;
    if (path == null || !File(path).existsSync()) return;
    if (_cachedCropKey == key) return;
    try {
      final raw = await File(path).readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) return;
      final box = DetectedLineBox.fromBoxJson(candidate.line.boxJson);
      img.Image cropped;
      if (box != null) {
        final r = box.boundingRect;
        final isNorm = r.right <= 1.5 && r.bottom <= 1.5;
        final x = (isNorm ? r.left * decoded.width : r.left).round().clamp(
          0,
          decoded.width - 1,
        );
        final y = (isNorm ? r.top * decoded.height : r.top).round().clamp(
          0,
          decoded.height - 1,
        );
        final w = (isNorm ? r.width * decoded.width : r.width).round().clamp(
          16,
          decoded.width - x,
        );
        final h = (isNorm ? r.height * decoded.height : r.height).round().clamp(
          16,
          decoded.height - y,
        );
        cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      } else {
        cropped = decoded;
      }
      final bytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
      if (mounted && _loadedForCandidateKey == key) {
        setState(() {
          _cachedCropKey = key;
          _cachedCropBytes = bytes;
        });
      }
    } on Object {
      // Fall back gracefully to line text preview if image unreadable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final paperAsync = ref.watch(paperViewProvider(widget.scanId));

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: l10n.checkWords,
        leading: IconButton(
          key: const ValueKey('check-close'),
          tooltip: l10n.cancel,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/paper/${widget.scanId}');
            }
          },
          icon: RosidIcon(RosidIcons.close, size: 22, color: c.inkPrimary),
        ),
      ),
      body: paperAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (paper) {
          if (paper == null || paper.checkWords.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RosidIcon(
                      RosidIcons.checkCircle,
                      size: 36,
                      color: c.goodBase,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.checkWordsEmpty,
                      textAlign: TextAlign.center,
                      style: RosidTextTokens.uiBody.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RosidButton(
                      label: l10n.done,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            );
          }

          final total = paper.checkWords.length;
          final safeIdx = _index.clamp(0, total - 1);
          final candidate = paper.checkWords[safeIdx];
          _syncCandidate(candidate);

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < total.clamp(1, 10); i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= safeIdx ? c.accentBase : c.lineStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizeDigits(
                      l10n.wordProgress(safeIdx + 1, total),
                      locale,
                    ),
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          l10n.fromYourScan,
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 92,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: RosidColorTokens.paperSheetLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.lineSubtle),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildCropPreview(context, candidate),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.rosidReadThisAs,
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('check-word-field'),
                          controller: _controller,
                          style: RosidTextTokens.uiTitle.copyWith(
                            color: c.inkPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: c.bgSheet,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(14),
                              child: RosidIcon(
                                RosidIcons.edit,
                                size: 20,
                                color: c.inkSecondary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                RosidSizeTokens.radiusControl,
                              ),
                              borderSide: BorderSide(
                                color: c.accentBase,
                                width: 1.8,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                RosidSizeTokens.radiusControl,
                              ),
                              borderSide: BorderSide(
                                color: c.accentBase,
                                width: 2.2,
                              ),
                            ),
                          ),
                        ),
                        if (candidate.alternatives.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            l10n.pickAnotherReading,
                            style: RosidTextTokens.uiCaption.copyWith(
                              color: c.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final alt in candidate.alternatives.take(3))
                                RosidChip(
                                  key: ValueKey('check-alt-$alt'),
                                  label: alt,
                                  selected: _controller.text.trim() == alt,
                                  onTap: () => setState(() {
                                    _controller.text = alt;
                                  }),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RosidIcon(
                                RosidIcons.info,
                                size: 16,
                                color: c.inkSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.rememberNamesNote,
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_controller.text.trim() != candidate.word) ...[
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              l10n.addToNamesBook,
                              style: RosidTextTokens.uiCaption.copyWith(
                                color: c.inkPrimary,
                              ),
                            ),
                            value: _addToNameBook,
                            onChanged: (v) =>
                                setState(() => _addToNameBook = v ?? false),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      RosidButton(
                        key: const ValueKey('check-skip'),
                        label: l10n.skip,
                        kind: RosidButtonKind.outline,
                        onPressed: _saving
                            ? null
                            : () {
                                if (safeIdx + 1 < total) {
                                  setState(() => _index = safeIdx + 1);
                                } else {
                                  context.pop();
                                }
                              },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RosidButton(
                          key: const ValueKey('check-looks-right'),
                          label: l10n.looksRight,
                          icon: RosidIcons.check,
                          expand: true,
                          busy: _saving,
                          onPressed: () =>
                              _acceptAndAdvance(context, candidate, total),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCropPreview(BuildContext context, WordCheckCandidate candidate) {
    if (widget.previewCropWidget != null) {
      return widget.previewCropWidget!;
    }
    if (_cachedCropBytes != null) {
      return Image.memory(_cachedCropBytes!, fit: BoxFit.contain);
    }
    final c = RosidColors.of(context);
    final words = candidate.line.textContent.split(' ');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < words.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              padding: i == candidate.wordIndex
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                  : EdgeInsets.zero,
              decoration: i == candidate.wordIndex
                  ? BoxDecoration(
                      color: c.accentSoft,
                      border: Border.all(color: c.accentBase, width: 1.8),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                words[i],
                style: RosidTextTokens.uiTitleLg.copyWith(
                  color: RosidColorTokens.paperInkLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _acceptAndAdvance(
    BuildContext context,
    WordCheckCandidate candidate,
    int total,
  ) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(paperRepositoryProvider)
          .applyWordCorrection(
            scanId: widget.scanId,
            line: candidate.line,
            wrongWord: candidate.word,
            rightWord: _controller.text.trim().isEmpty
                ? candidate.word
                : _controller.text.trim(),
            addToNameBook: _addToNameBook,
          );
      ref.invalidate(paperViewProvider(widget.scanId));
      if (!context.mounted) return;
      if (_index + 1 >= total) {
        context.pop();
      } else {
        setState(() {
          _loadedForCandidateKey = null;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
