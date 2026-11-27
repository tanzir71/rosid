import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/utils/money.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';
import 'package:rosid/features/history/history_state.dart';
import 'package:rosid/features/library/library_screen.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';

/// Check receipt screen (`/paper/:id/receipt`) matching
/// `design/screens/expenses-check-receipt.png`.
class CheckReceiptScreen extends ConsumerStatefulWidget {
  const CheckReceiptScreen({
    required this.scanId,
    this.previewView,
    this.previewDateUncertain = false,
    super.key,
  });

  final String scanId;

  @visibleForTesting
  final ReceiptCheckView? previewView;

  @visibleForTesting
  final bool previewDateUncertain;

  @override
  ConsumerState<CheckReceiptScreen> createState() => _CheckReceiptScreenState();
}

class _CheckReceiptScreenState extends ConsumerState<CheckReceiptScreen> {
  final _shopController = TextEditingController();
  final _totalController = TextEditingController();
  final _vatController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _dateUncertain = false;
  String? _paymentMethod;
  String _categoryId = 'cat_other';
  List<ParsedLineItem> _items = const [];
  bool _itemsExpanded = false;
  String _focusedField = 'total';
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _shopController.dispose();
    _totalController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  void _hydrateFrom(ReceiptCheckView view) {
    if (_initialized) return;
    _initialized = true;
    _shopController.text = view.receipt.merchant;
    _totalController.text = view.receipt.total.toStringAsFixed(2);
    _vatController.text = view.receipt.tax == null
        ? ''
        : view.receipt.tax!.toStringAsFixed(2);
    _date = view.receipt.dateOfPurchase;
    _paymentMethod = view.receipt.paymentMethod;
    _categoryId = view.receipt.categoryId ?? 'cat_other';
    _items = [
      for (final i in view.items)
        ParsedLineItem(
          name: i.name,
          quantity: i.qty,
          unitPrice: i.unitPrice,
          amount: i.amount,
          rawText: i.name,
        ),
    ];
    if (widget.previewDateUncertain) {
      _dateUncertain = true;
    } else {
      try {
        final conf = jsonDecode(
          view.receipt.fieldConfidenceJson,
        ) as Map<String, dynamic>;
        final dateConf = (conf['date'] as num?)?.toDouble() ?? 1.0;
        _dateUncertain = dateConf < 0.7;
      } on Object {
        _dateUncertain = false;
      }
    }
  }

  double get _parsedTotal =>
      double.tryParse(
        _totalController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
      ) ??
      0;

  double? get _parsedVat {
    final cleaned = _vatController.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _pickDate() async {
    setState(() => _focusedField = 'date');
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateUncertain = false;
      });
    }
  }

  Future<void> _save(ReceiptCheckView view) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(expensesRepositoryProvider)
          .saveCheckedReceipt(
            scanId: widget.scanId,
            merchant: _shopController.text,
            date: _date,
            total: _parsedTotal,
            categoryId: _categoryId,
            items: _items,
            tax: _parsedVat,
            paymentMethod: _paymentMethod,
          );
      ref
        ..read(selectedExpenseMonthProvider.notifier).select(_date)
        ..invalidate(monthlyExpensesProvider)
        ..invalidate(receiptCheckProvider(widget.scanId))
        ..invalidate(paperViewProvider(widget.scanId))
        ..invalidate(libraryPapersProvider)
        ..invalidate(historyResultsProvider)
        ..invalidate(dashboardSummaryProvider);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/expenses');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final asyncView = widget.previewView != null
        ? AsyncValue.data(widget.previewView!)
        : ref.watch(receiptCheckProvider(widget.scanId));

    return asyncView.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.checkReceiptTitle),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.checkReceiptTitle),
        body: Center(
          child: Text(
            l10n.loadFailed,
            style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
          ),
        ),
      ),
      data: (view) {
        if (view == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.checkReceiptTitle),
            body: Center(child: Text(l10n.loadFailed)),
          );
        }
        _hydrateFrom(view);

        final sumCheck = evaluateReceiptItemsSum(
          total: _parsedTotal,
          itemAmounts: [for (final i in _items) i.amount],
          tax: _parsedVat,
        );
        final formattedTotal = localizeDigits(
          '৳${NumberFormat('#,##0.00', 'en_US').format(_parsedTotal)}',
          locale,
        );
        final formattedDate = localizeDigits(
          DateFormat('d MMM y', locale.toLanguageTag()).format(_date),
          locale,
        );
        final focusedLine = view.sourceLineByField[_focusedField];
        final imagePath = view.pages.isNotEmpty
            ? (view.pages.first.processedPath ?? view.pages.first.imagePath)
            : view.scan.imagePath;

        final paymentOptions = [
          ('Cash', l10n.paidCash),
          ('Card', l10n.paidCard),
          ('bKash', l10n.paidBkash),
          ('Nagad', l10n.paidNagad),
          ('Rocket', l10n.paidRocket),
        ];

        final itemsPreview = _items.isEmpty
            ? ''
            : _items.length <= 3
            ? _items.map((i) => i.name).join(', ')
            : l10n.andMoreItems(
                _items.take(3).map((i) => i.name).join(', '),
                _items.length - 3,
              );

        return Scaffold(
          backgroundColor: c.bgCanvas,
          appBar: RosidTopBar(
            title: l10n.checkReceiptTitle,
            leading: IconButton(
              key: const ValueKey('check-receipt-close'),
              icon: RosidIcon(RosidIcons.close, size: 22, color: c.inkPrimary),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/expenses');
                }
              },
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReceiptSourcePreview(
                          imagePath: imagePath,
                          focusedField: _focusedField,
                          focusedLine: focusedLine,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.total,
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              InkWell(
                                key: const ValueKey('check-receipt-total-tap'),
                                onTap: () => _editTotalDialog(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Text(
                                  formattedTotal,
                                  key: const ValueKey(
                                    'check-receipt-total-value',
                                  ),
                                  style: RosidTextTokens.uiDisplay.copyWith(
                                    color: c.inkPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (sumCheck.itemCount > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: RosidIcon(
                                        sumCheck.matchesTotal
                                            ? RosidIcons.checkCircle
                                            : RosidIcons.alert,
                                        size: 16,
                                        color: sumCheck.matchesTotal
                                            ? c.goodBase
                                            : c.warnBase,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sumCheck.matchesTotal
                                            ? localizeDigits(
                                                l10n.itemsAddUpToTotal(
                                                  sumCheck.itemCount,
                                                ),
                                                locale,
                                              )
                                            : localizeDigits(
                                                l10n.itemsDoNotAddUp(
                                                  sumCheck.itemCount,
                                                  formatMoney(
                                                    sumCheck.itemsSum,
                                                    'BDT',
                                                  ),
                                                ),
                                                locale,
                                              ),
                                        key: const ValueKey(
                                          'check-receipt-sum-status',
                                        ),
                                        style: RosidTextTokens.uiCaption
                                            .copyWith(
                                              color: sumCheck.matchesTotal
                                                  ? c.goodBase
                                                  : c.warnBase,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                l10n.tapFieldToSeeSource,
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.shopLabel,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                    TextField(
                      key: const ValueKey('check-receipt-shop'),
                      controller: _shopController,
                      onTap: () => setState(() => _focusedField = 'shop'),
                      style: RosidTextTokens.uiBody.copyWith(
                        color: c.inkPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: c.lineStrong),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: c.lineStrong),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: c.accentBase, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dateFieldLabel,
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                key: const ValueKey('check-receipt-date'),
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: c.lineStrong),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: _dateUncertain
                                            ? const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              )
                                            : const EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                        decoration: _dateUncertain
                                            ? BoxDecoration(
                                                color: c.warnSoft,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              )
                                            : null,
                                        child: Text(
                                          formattedDate,
                                          style: RosidTextTokens.uiBody
                                              .copyWith(color: c.inkPrimary),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_dateUncertain)
                                        RosidIcon(
                                          RosidIcons.alert,
                                          size: 18,
                                          color: c.warnBase,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.vatLabel,
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                              TextField(
                                key: const ValueKey('check-receipt-vat'),
                                controller: _vatController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onTap: () =>
                                    setState(() => _focusedField = 'vat'),
                                onChanged: (_) => setState(() {}),
                                style: RosidTextTokens.uiBody.copyWith(
                                  color: c.inkPrimary,
                                ),
                                decoration: InputDecoration(
                                  filled: false,
                                  prefixText: '৳',
                                  prefixStyle: RosidTextTokens.uiBody.copyWith(
                                    color: c.inkPrimary,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: c.lineStrong),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: c.lineStrong),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: c.accentBase,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.paidWithLabel,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opt in paymentOptions)
                          _ReceiptChoiceChip(
                            label: opt.$2,
                            selected:
                                (_paymentMethod ?? '').toLowerCase() ==
                                opt.$1.toLowerCase(),
                            onTap: () => setState(() {
                              _paymentMethod =
                                  (_paymentMethod ?? '').toLowerCase() ==
                                      opt.$1.toLowerCase()
                                  ? null
                                  : opt.$1;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.category,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in view.categories)
                          _ReceiptChoiceChip(
                            label: locale.languageCode == 'bn'
                                ? cat.nameBn
                                : cat.nameEn,
                            selected: _categoryId == cat.id,
                            onTap: () => setState(() => _categoryId = cat.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      key: const ValueKey('check-receipt-items-toggle'),
                      onTap: () =>
                          setState(() => _itemsExpanded = !_itemsExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizeDigits(
                                      l10n.itemsCountLabel(_items.length),
                                      locale,
                                    ),
                                    style: RosidTextTokens.uiBodyStrong
                                        .copyWith(color: c.inkPrimary),
                                  ),
                                  if (itemsPreview.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      itemsPreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RosidTextTokens.uiCaption.copyWith(
                                        color: c.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Transform.rotate(
                              angle: _itemsExpanded ? 3.14159265 : 0,
                              child: RosidIcon(
                                RosidIcons.chevronDown,
                                size: 18,
                                color: c.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: c.lineSubtle, height: 1),
                    if (_itemsExpanded) ...[
                      for (var i = 0; i < _items.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _items[i].name,
                                  style: RosidTextTokens.uiBody.copyWith(
                                    color: c.inkPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                localizeDigits(
                                  formatMoney(_items[i].amount, 'BDT'),
                                  locale,
                                ),
                                style: RosidTextTokens.uiBodyStrong.copyWith(
                                  color: c.inkPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: c.lineSubtle, height: 1),
                      ],
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: BoxDecoration(
                  color: c.bgCanvas,
                  border: Border(top: BorderSide(color: c.lineSubtle)),
                ),
                child: SafeArea(
                  top: false,
                  child: RosidButton(
                    key: const ValueKey('check-receipt-save'),
                    label: l10n.saveReceiptAction,
                    expand: true,
                    onPressed: _saving ? null : () => _save(view),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTotalDialog(BuildContext context) async {
    setState(() => _focusedField = 'total');
    final controller = TextEditingController(text: _totalController.text);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.total),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: '৳'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated != null && mounted) {
      setState(() => _totalController.text = updated);
    }
  }
}

class _ReceiptChoiceChip extends StatelessWidget {
  const _ReceiptChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : c.bgCanvas,
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
          border: Border.all(color: selected ? c.accentSoft : c.lineStrong),
        ),
        child: Text(
          label,
          style: RosidTextTokens.uiLabel.copyWith(
            color: selected ? c.accentBase : c.inkPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ReceiptSourcePreview extends StatelessWidget {
  const _ReceiptSourcePreview({
    required this.imagePath,
    required this.focusedField,
    required this.focusedLine,
  });

  final String imagePath;
  final String focusedField;
  final TextLine? focusedLine;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final hasFile = imagePath.isNotEmpty && File(imagePath).existsSync();
    final highlightTopFrac = switch (focusedField) {
      'shop' => 0.08,
      'date' => 0.24,
      'vat' => 0.66,
      _ => 0.78,
    };

    return Container(
      width: 118,
      height: 156,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.bgSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasFile)
              Image.file(File(imagePath), fit: BoxFit.cover)
            else
              Container(
                color: c.paperSheet,
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  children: [
                    Container(
                      height: 6,
                      width: 48,
                      decoration: BoxDecoration(
                        color: c.inkPrimary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 6; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: c.lineStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: c.lineStrong,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.inkPrimary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.inkPrimary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 4,
              right: 4,
              top: 140 * highlightTopFrac,
              child: Container(
                key: ValueKey('receipt-source-highlight-$focusedField'),
                height: 20,
                decoration: BoxDecoration(
                  color: c.accentSoft.withValues(alpha: 0.45),
                  border: Border.all(color: c.accentBase, width: 1.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: focusedLine != null && hasFile
                    ? Text(
                        focusedLine!.textContent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RosidTextTokens.uiMicro.copyWith(
                          color: c.inkPrimary,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
