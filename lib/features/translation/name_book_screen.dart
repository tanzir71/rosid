import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/translation/bangla_transliterator.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Name book screen (`/names`) matching `design/screens/translate-name-book.png`.
class NameBookScreen extends ConsumerWidget {
  const NameBookScreen({this.previewNames, super.key});

  @visibleForTesting
  final List<NameBookRule>? previewNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    final Widget body;
    if (previewNames != null) {
      body = _NameBookBody(
        names: previewNames!,
        onEdit: (entry) => showNameEditorSheet(context, ref, existing: entry),
      );
    } else {
      final asyncNames = ref.watch(namesBookProvider);
      body = asyncNames.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            l10n.loadFailed,
            style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
          ),
        ),
        data: (names) => _NameBookBody(
          names: names,
          onEdit: (entry) => showNameEditorSheet(context, ref, existing: entry),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: l10n.names,
        showBack: true,
        trailing: [
          IconButton(
            key: const ValueKey('names-add-button'),
            tooltip: l10n.addName,
            icon: RosidIcon(RosidIcons.plus, size: 22, color: c.inkPrimary),
            onPressed: () => showNameEditorSheet(context, ref),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _NameBookBody extends StatelessWidget {
  const _NameBookBody({required this.names, required this.onEdit});

  final List<NameBookRule> names;
  final ValueChanged<NameBookRule> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final people = names.where((n) => n.category != 'place').toList();
    final places = names.where((n) => n.category == 'place').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Text(
            l10n.namesIntro,
            style: RosidTextTokens.uiBody.copyWith(
              color: c.inkSecondary,
              height: 1.5,
            ),
          ),
        ),
        if (names.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.bgSheet,
                borderRadius: BorderRadius.circular(
                  RosidSizeTokens.radiusControl,
                ),
                border: Border.all(color: c.lineSubtle),
              ),
              child: Text(
                l10n.namesEmpty,
                style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
              ),
            ),
          )
        else ...[
          if (people.isNotEmpty) ...[
            _SectionHeading(label: l10n.people),
            for (var i = 0; i < people.length; i++) ...[
              if (i > 0) Divider(color: c.lineSubtle, height: 1),
              _NameRow(
                entry: people[i],
                showSourcePill: true,
                onTap: () => onEdit(people[i]),
              ),
            ],
            Divider(color: c.lineSubtle, height: 1),
            const SizedBox(height: 22),
          ],
          if (places.isNotEmpty) ...[
            _SectionHeading(label: l10n.places),
            for (var i = 0; i < places.length; i++) ...[
              if (i > 0) Divider(color: c.lineSubtle, height: 1),
              _NameRow(
                entry: places[i],
                showSourcePill: false,
                onTap: () => onEdit(places[i]),
              ),
            ],
            Divider(color: c.lineSubtle, height: 1),
            const SizedBox(height: 16),
          ],
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.namesFooterNote,
                  style: RosidTextTokens.uiCaption.copyWith(
                    color: c.inkSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Text(
        label,
        style: RosidTextTokens.uiHeading.copyWith(
          color: c.inkPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.entry,
    required this.showSourcePill,
    required this.onTap,
  });

  final NameBookRule entry;
  final bool showSourcePill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    final (String pillLabel, RosidTone pillTone) = switch (entry.source) {
      'passport' => (l10n.asInPassport, RosidTone.good),
      'nid' => (l10n.asInNid, RosidTone.good),
      'suggested' => (l10n.suggestedCheck, RosidTone.warn),
      _ => (l10n.confirmedSpelling, RosidTone.good),
    };

    return Material(
      color: c.bgCanvas,
      child: InkWell(
        key: ValueKey('name-row-${entry.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.english,
                      style: RosidTextTokens.uiBodyStrong.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.bangla,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showSourcePill) ...[
                const SizedBox(width: 10),
                RosidPill(label: pillLabel, tone: pillTone),
              ],
              const SizedBox(width: 8),
              RosidIcon(
                RosidIcons.chevronRight,
                size: 16,
                color: c.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameEditorResult {
  const _NameEditorResult({
    required this.action,
    this.bangla = '',
    this.english = '',
    this.category = 'person',
    this.source = 'passport',
  });

  final String action;
  final String bangla;
  final String english;
  final String category;
  final String source;
}

class _NameEditorSheet extends StatefulWidget {
  const _NameEditorSheet({
    required this.existing,
    required this.initialBangla,
    required this.initialEnglish,
    required this.initialCategory,
  });

  final NameBookRule? existing;
  final String? initialBangla;
  final String? initialEnglish;
  final String initialCategory;

  @override
  State<_NameEditorSheet> createState() => _NameEditorSheetState();
}

class _NameEditorSheetState extends State<_NameEditorSheet> {
  late final TextEditingController _bnCtrl;
  late final TextEditingController _enCtrl;
  late String _category;
  late String _source;

  @override
  void initState() {
    super.initState();
    _bnCtrl = TextEditingController(
      text: widget.existing?.bangla ?? widget.initialBangla ?? '',
    );
    _enCtrl = TextEditingController(
      text: widget.existing?.english ?? widget.initialEnglish ?? '',
    );
    _category = widget.existing?.category ?? widget.initialCategory;
    _source = widget.existing?.source ?? 'passport';
  }

  @override
  void dispose() {
    _bnCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? l10n.addName : l10n.editName,
              style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('name-editor-bangla'),
              controller: _bnCtrl,
              decoration: InputDecoration(labelText: l10n.banglaSpelling),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('name-editor-english'),
              controller: _enCtrl,
              decoration: InputDecoration(
                labelText: l10n.englishSpelling,
                hintText: _bnCtrl.text.trim().isEmpty
                    ? null
                    : BanglaTransliterator.transliterate(_bnCtrl.text),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                RosidChip(
                  key: const ValueKey('name-cat-person'),
                  label: l10n.people,
                  selected: _category == 'person',
                  onTap: () => setState(() => _category = 'person'),
                ),
                const SizedBox(width: 8),
                RosidChip(
                  key: const ValueKey('name-cat-place'),
                  label: l10n.places,
                  selected: _category == 'place',
                  onTap: () => setState(() => _category = 'place'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l10n.whereSpellingFrom,
              style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RosidChip(
                  key: const ValueKey('name-src-passport'),
                  label: l10n.asInPassport,
                  selected: _source == 'passport',
                  onTap: () => setState(() => _source = 'passport'),
                ),
                RosidChip(
                  key: const ValueKey('name-src-nid'),
                  label: l10n.asInNid,
                  selected: _source == 'nid',
                  onTap: () => setState(() => _source = 'nid'),
                ),
                RosidChip(
                  key: const ValueKey('name-src-suggested'),
                  label: l10n.suggestedCheck,
                  selected: _source == 'suggested',
                  onTap: () => setState(() => _source = 'suggested'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.existing != null) ...[
                  RosidButton(
                    key: const ValueKey('name-editor-delete'),
                    label: l10n.delete,
                    kind: RosidButtonKind.outline,
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(const _NameEditorResult(action: 'delete')),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: RosidButton(
                    key: const ValueKey('name-editor-save'),
                    label: l10n.save,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(
                      _NameEditorResult(
                        action: 'save',
                        bangla: _bnCtrl.text.trim(),
                        english: _enCtrl.text.trim(),
                        category: _category,
                        source: _source,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet to add or edit a Name Book entry.
/// Returns `true` if saved or deleted.
Future<bool> showNameEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  NameBookRule? existing,
  String? initialBangla,
  String? initialEnglish,
  String initialCategory = 'person',
}) async {
  final res = await showModalBottomSheet<_NameEditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _NameEditorSheet(
      existing: existing,
      initialBangla: initialBangla,
      initialEnglish: initialEnglish,
      initialCategory: initialCategory,
    ),
  );

  var changed = false;
  if (res?.action == 'delete' && existing != null) {
    await ref.read(translationRepositoryProvider).deleteName(existing.id);
    ref.invalidate(namesBookProvider);
    changed = true;
  } else if (res?.action == 'save' && res!.bangla.isNotEmpty) {
    await ref
        .read(translationRepositoryProvider)
        .upsertName(
          id: existing?.id,
          bangla: res.bangla,
          english: res.english,
          category: res.category,
          source: res.source,
          confirmed: res.source != 'suggested',
        );
    ref.invalidate(namesBookProvider);
    changed = true;
  }

  return changed;
}
