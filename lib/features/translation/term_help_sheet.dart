import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Bottom sheet matching `design/screens/translate-term-help.png`.
/// Shows a Bangla legal/land term, its plain explanation, and three choices
/// (`both`, `english`, `bangla`) applied across all land papers.
class TermHelpSheet extends StatefulWidget {
  const TermHelpSheet({required this.term, required this.onApply, super.key});

  final TermRule term;
  final ValueChanged<TermForm> onApply;

  @override
  State<TermHelpSheet> createState() => _TermHelpSheetState();
}

class _TermHelpSheetState extends State<TermHelpSheet> {
  late TermForm _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.term.chosenForm;
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final term = widget.term;

    final choices = <(TermForm, String, String)>[
      (TermForm.both, term.render(TermForm.both), l10n.termBothDesc),
      (
        TermForm.english,
        term.render(TermForm.english),
        l10n.termEnglishOnlyDesc,
      ),
      (TermForm.bangla, term.render(TermForm.bangla), l10n.termBanglaOnlyDesc),
    ];

    return Container(
      key: const ValueKey('term-help-sheet'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bgSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RosidSizeTokens.radiusSheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: c.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  term.bangla,
                  style: RosidTextTokens.uiDisplay.copyWith(
                    color: c.inkPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    term.transliteration,
                    style: RosidTextTokens.uiHeading.copyWith(
                      color: c.inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (term.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                term.explanation,
                style: RosidTextTokens.uiBody.copyWith(
                  color: c.inkPrimary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              l10n.howShouldTermAppear,
              style: RosidTextTokens.uiCaption.copyWith(
                color: c.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < choices.length; i++) ...[
              if (i > 0) Divider(color: c.lineSubtle, height: 1),
              InkWell(
                key: ValueKey('term-choice-${choices[i].$1.code}'),
                onTap: () => setState(() => _selected = choices[i].$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: RosidRadio(selected: _selected == choices[i].$1),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              choices[i].$2,
                              style: RosidTextTokens.uiBodyStrong.copyWith(
                                color: c.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              choices[i].$3,
                              style: RosidTextTokens.uiCaption.copyWith(
                                color: c.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Divider(color: c.lineSubtle, height: 1),
            const SizedBox(height: 16),
            Text(
              l10n.termChoiceAppliesAll,
              style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
            ),
            const SizedBox(height: 16),
            RosidButton(
              key: const ValueKey('term-help-use-this'),
              label: l10n.useThis,
              expand: true,
              onPressed: () => widget.onApply(_selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [TermHelpSheet] as a modal sheet and persists the chosen form to `terms`.
/// Returns `true` if the user applied a choice.
Future<bool> showTermHelpSheet(
  BuildContext context,
  WidgetRef ref,
  TermRule term,
) async {
  final chosen = await showModalBottomSheet<TermForm>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => TermHelpSheet(
      term: term,
      onApply: (form) => Navigator.of(ctx).pop(form),
    ),
  );
  if (chosen == null) return false;
  await ref
      .read(translationRepositoryProvider)
      .updateTermChoice(term.id, chosen);
  ref.invalidate(termsListProvider);
  return true;
}

/// Opens a scrollable list of all legal/land terms so the user can review or
/// change any term choice from the English tab or Settings.
Future<bool> showTermsPickerSheet(BuildContext context, WidgetRef ref) async {
  var anyChanged = false;
  final terms = await ref.read(translationRepositoryProvider).loadTerms();
  if (!context.mounted) return false;

  final picked = await showModalBottomSheet<TermRule>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = RosidColors.of(ctx);
      final l10n = ctx.l10n;
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.wordChoices,
                          style: RosidTextTokens.uiTitle.copyWith(
                            color: c.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.wordChoicesSub,
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.lineSubtle, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                itemCount: terms.length,
                separatorBuilder: (_, _) => Divider(
                  color: c.lineSubtle,
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                itemBuilder: (_, index) {
                  final t = terms[index];
                  return ListTile(
                    key: ValueKey('terms-picker-row-${t.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    title: Text(
                      t.render(),
                      style: RosidTextTokens.uiBodyStrong.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    subtitle: Text(
                      t.bangla,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                    trailing: RosidIcon(
                      RosidIcons.chevronRight,
                      size: 18,
                      color: c.inkTertiary,
                    ),
                    onTap: () => Navigator.of(ctx).pop(t),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  if (picked != null && context.mounted) {
    anyChanged = await showTermHelpSheet(context, ref, picked);
  }
  return anyChanged;
}
