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
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';

/// Monthly Expenses tab (`/expenses`) matching `design/screens/expenses.png`.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({
    this.previewView,
    this.onCsvExportedForTest,
    super.key,
  });

  @visibleForTesting
  final MonthlyExpensesView? previewView;

  @visibleForTesting
  final void Function(String filePath, String csvContent)? onCsvExportedForTest;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _exporting = false;

  Future<void> _exportCsv(MonthlyExpensesView view) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final l10n = context.l10n;
    final lang = ref.read(appSettingsProvider).languageCode;
    try {
      final result = await ref
          .read(expensesRepositoryProvider)
          .writeMonthCsvExport(view.month, languageCode: lang);
      widget.onCsvExportedForTest?.call(result.filePath, result.csvContent);
      final saved = await ref
          .read(platformFileServiceProvider)
          .saveFileToPhone(
            sourcePath: result.filePath,
            suggestedName: result.fileName,
            mimeType: 'text/csv',
          );
      if (!mounted) return;
      final name = saved.displayName ?? result.fileName;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.csvExported(name))));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _formatWholeTaka(double amount, Locale locale) {
    final rounded = amount.round();
    final formatted = NumberFormat('#,##0', 'en_US').format(rounded.abs());
    return localizeDigits('৳$formatted', locale);
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final DateTime selectedMonth =
        widget.previewView?.month ?? ref.watch(selectedExpenseMonthProvider);
    final asyncView = widget.previewView != null
        ? AsyncValue.data(widget.previewView!)
        : ref.watch(monthlyExpensesProvider);

    final monthLabel = localizeDigits(
      DateFormat('MMMM y', locale.toLanguageTag()).format(selectedMonth),
      locale,
    );

    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: asyncView.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              l10n.loadFailed,
              style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
            ),
          ),
          data: (view) {
            final prevMonthDate = DateTime(
              view.month.year,
              view.month.month - 1,
            );
            final prevMonthName = DateFormat(
              'MMMM',
              locale.toLanguageTag(),
            ).format(prevMonthDate);
            final delta = view.deltaFromPrevious;
            final showDelta = view.previousMonthTotal > 0;
            final deltaAmount = _formatWholeTaka(delta.abs(), locale);
            final deltaText = delta < -0.5
                ? l10n.lessThanMonth(deltaAmount, prevMonthName)
                : delta > 0.5
                ? l10n.moreThanMonth(deltaAmount, prevMonthName)
                : l10n.sameAsMonth(prevMonthName);
            final deltaColor = delta <= 0.5 ? c.goodBase : c.warnBase;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
              children: [
                Row(
                  children: [
                    Text(
                      l10n.expenses,
                      style: RosidTextTokens.uiTitleLg.copyWith(
                        color: c.inkPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('expenses-prev-month'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(selectedExpenseMonthProvider.notifier)
                          .previousMonth(),
                      icon: RosidIcon(
                        RosidIcons.chevronLeft,
                        size: 18,
                        color: c.inkPrimary,
                      ),
                    ),
                    Text(
                      monthLabel,
                      key: const ValueKey('expenses-month-label'),
                      style: RosidTextTokens.uiLabel.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('expenses-next-month'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(selectedExpenseMonthProvider.notifier)
                          .nextMonth(),
                      icon: RosidIcon(
                        RosidIcons.chevronRight,
                        size: 18,
                        color: c.inkSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.spentThisMonth,
                  style: RosidTextTokens.uiCaption.copyWith(
                    color: c.inkSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatWholeTaka(view.total, locale),
                  key: const ValueKey('expenses-month-total'),
                  style: RosidTextTokens.uiDisplay.copyWith(
                    color: c.inkPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                if (showDelta) ...[
                  const SizedBox(height: 4),
                  Text(
                    deltaText,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: deltaColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (view.categories.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  for (final cat in view.categories) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.name,
                            style: RosidTextTokens.uiBody.copyWith(
                              color: c.inkPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _formatWholeTaka(cat.amount, locale),
                          style: RosidTextTokens.uiBodyStrong.copyWith(
                            color: c.inkPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fillW = (constraints.maxWidth * cat.fractionOfMax)
                            .clamp(12.0, constraints.maxWidth);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 7,
                            color: c.bgSunken,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: fillW,
                              height: 7,
                              decoration: BoxDecoration(
                                color: c.accentBase,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.receiptsThisMonth,
                        style: RosidTextTokens.uiHeading.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('expenses-export-csv'),
                      onPressed: view.receipts.isEmpty || _exporting
                          ? null
                          : () => _exportCsv(view),
                      child: Text(
                        l10n.exportCsvAction,
                        style: RosidTextTokens.uiLabel.copyWith(
                          color: view.receipts.isEmpty
                              ? c.inkTertiary
                              : c.accentBase,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (view.receipts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
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
                          l10n.noReceiptsThisMonth,
                          style: RosidTextTokens.uiHeading.copyWith(
                            color: c.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.noReceiptsThisMonthSub,
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        RosidButton(
                          label: l10n.scan,
                          kind: RosidButtonKind.tonal,
                          icon: RosidIcons.scan,
                          onPressed: () => context.push('/scan?mode=receipt'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final row in view.receipts) ...[
                    _ExpenseReceiptTile(
                      row: row,
                      locale: locale,
                      formattedAmount: localizeDigits(
                        formatMoney(row.receipt.total, row.receipt.currency),
                        locale,
                      ),
                      onTap: () =>
                          context.push('/paper/${row.scan.id}/receipt'),
                    ),
                    Divider(color: c.lineSubtle, height: 1),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExpenseReceiptTile extends StatelessWidget {
  const _ExpenseReceiptTile({
    required this.row,
    required this.locale,
    required this.formattedAmount,
    required this.onTap,
  });

  final ExpenseReceiptRow row;
  final Locale locale;
  final String formattedAmount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final dateStr = localizeDigits(
      DateFormat(
        'd MMM',
        locale.toLanguageTag(),
      ).format(row.receipt.dateOfPurchase),
      locale,
    );
    return InkWell(
      key: ValueKey('expense-receipt-${row.scan.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const RosidPaperThumbnail(
              kind: RosidPaperKind.receipt,
              width: 36,
              height: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.receipt.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.categoryName}, $dateStr',
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formattedAmount,
              style: RosidTextTokens.uiBodyStrong.copyWith(color: c.inkPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
