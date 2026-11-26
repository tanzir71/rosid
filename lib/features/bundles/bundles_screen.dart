import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';

/// Shared segmented progress bar matching `bundles.png` & `bundle-checklist.png`.
class RosidSegmentedProgress extends StatelessWidget {
  const RosidSegmentedProgress({
    required this.readyCount,
    required this.needsWorkCount,
    required this.missingCount,
    super.key,
  });

  final int readyCount;
  final int needsWorkCount;
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final total = readyCount + needsWorkCount + missingCount;
    if (total <= 0) return const SizedBox.shrink();

    final segments = <Color>[
      for (var i = 0; i < readyCount; i++) c.goodBase,
      for (var i = 0; i < needsWorkCount; i++) c.warnBase,
      for (var i = 0; i < missingCount; i++) c.lineSubtle,
    ];

    return Row(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: segments[i],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bundles list screen (`/bundles`) matching `design/screens/bundles.png`.
class BundlesScreen extends ConsumerWidget {
  const BundlesScreen({this.previewBundles, this.previewTemplates, super.key});

  @visibleForTesting
  final List<BundleDetailView>? previewBundles;

  @visibleForTesting
  final List<ChecklistTemplate>? previewTemplates;

  Future<void> _startFromTemplate(
    BuildContext context,
    WidgetRef ref,
    ChecklistTemplate template,
  ) async {
    final locale = Localizations.localeOf(context);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => _NewBundleDialog(
        initialTitle: template.titleFor(locale.languageCode),
        disclaimer: template.disclaimerFor(locale.languageCode),
      ),
    );
    if (title == null) return;
    final bundleId = await ref
        .read(bundleRepositoryProvider)
        .createFromTemplate(
          template,
          title: title,
          langCode: locale.languageCode,
        );
    ref.invalidate(allBundlesProvider);
    if (!context.mounted) return;
    context.push('/bundles/$bundleId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    final bundlesWidget = previewBundles != null
        ? _BundleCardsColumn(bundles: previewBundles!, locale: locale)
        : ref
              .watch(allBundlesProvider)
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Text(l10n.loadFailed),
                data: (list) =>
                    _BundleCardsColumn(bundles: list, locale: locale),
              );

    final templatesWidget = previewTemplates != null
        ? _TemplatesList(
            templates: previewTemplates!,
            langCode: locale.languageCode,
            onPick: (t) => _startFromTemplate(context, ref, t),
          )
        : ref
              .watch(checklistTemplatesProvider)
              .when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (templates) => _TemplatesList(
                  templates: templates,
                  langCode: locale.languageCode,
                  onPick: (t) => _startFromTemplate(context, ref, t),
                ),
              );

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: l10n.bundles),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 112),
        children: [
          Text(
            l10n.bundlesIntro,
            style: RosidTextTokens.uiBody.copyWith(
              color: c.inkSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          bundlesWidget,
          const SizedBox(height: 22),
          Text(
            l10n.startFromChecklist,
            style: RosidTextTokens.uiHeading.copyWith(
              color: c.inkPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          templatesWidget,
        ],
      ),
    );
  }
}

class _BundleCardsColumn extends StatelessWidget {
  const _BundleCardsColumn({required this.bundles, required this.locale});

  final List<BundleDetailView> bundles;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    if (bundles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.bgSheet,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.lineSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.noBundlesYet,
              style: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.startBundlePrompt,
              style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < bundles.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _BundleCard(detail: bundles[i], locale: locale),
        ],
      ],
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.detail, required this.locale});

  final BundleDetailView detail;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final dueDate = detail.bundle.dueDate;
    final missingTitle = detail.firstMissingTitle;

    return Material(
      color: c.bgSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.lineSubtle),
      ),
      child: InkWell(
        key: ValueKey('bundle-card-${detail.bundle.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/bundles/${detail.bundle.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.bundle.title,
                style: RosidTextTokens.uiHeading.copyWith(
                  color: c.inkPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                localizeDigits(
                  l10n.bundleProgress(detail.readyCount, detail.totalCount),
                  locale,
                ),
                style: RosidTextTokens.uiCaption.copyWith(
                  color: c.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              RosidSegmentedProgress(
                readyCount: detail.readyCount,
                needsWorkCount: detail.needsWorkCount,
                missingCount: detail.missingCount,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (dueDate != null) ...[
                    RosidIcon(
                      RosidIcons.calendar,
                      size: 16,
                      color: c.inkSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizeDigits(
                          l10n.neededByDate(
                            DateFormat(
                              'd MMM yyyy',
                              locale.toLanguageTag(),
                            ).format(dueDate),
                          ),
                          locale,
                        ),
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                    ),
                  ] else if (missingTitle != null) ...[
                    RosidIcon(RosidIcons.alert, size: 16, color: c.warnBase),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.itemIsMissing(missingTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  RosidIcon(
                    RosidIcons.chevronRight,
                    size: 16,
                    color: c.inkTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplatesList extends StatelessWidget {
  const _TemplatesList({
    required this.templates,
    required this.langCode,
    required this.onPick,
  });

  final List<ChecklistTemplate> templates;
  final String langCode;
  final ValueChanged<ChecklistTemplate> onPick;

  RosidIcons _iconFor(String name) => switch (name) {
    'seal' => RosidIcons.seal,
    'land' => RosidIcons.land,
    'wallet' => RosidIcons.wallet,
    'plus' => RosidIcons.plus,
    _ => RosidIcons.bundle,
  };

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < templates.length; i++) ...[
          if (i > 0) Divider(color: c.lineSubtle, height: 1),
          InkWell(
            key: ValueKey('bundle-template-${templates[i].id}'),
            onTap: () => onPick(templates[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  RosidIcon(
                    _iconFor(templates[i].icon),
                    size: 20,
                    color: c.inkPrimary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          templates[i].titleFor(langCode),
                          style: RosidTextTokens.uiBodyStrong.copyWith(
                            color: c.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          templates[i].subtitleFor(langCode),
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RosidIcon(
                    RosidIcons.chevronRight,
                    size: 16,
                    color: c.inkTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
        Divider(color: c.lineSubtle, height: 1),
      ],
    );
  }
}

class _NewBundleDialog extends StatefulWidget {
  const _NewBundleDialog({
    required this.initialTitle,
    required this.disclaimer,
  });

  final String initialTitle;
  final String disclaimer;

  @override
  State<_NewBundleDialog> createState() => _NewBundleDialogState();
}

class _NewBundleDialogState extends State<_NewBundleDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.createBundle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('new-bundle-title-field'),
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.bundleTitleHint),
          ),
          const SizedBox(height: 12),
          Text(
            widget.disclaimer,
            style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('new-bundle-confirm'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: Text(l10n.createBundle),
        ),
      ],
    );
  }
}
