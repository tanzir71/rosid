import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/features/history/record_view_cache.dart';
import 'package:rosid/features/review/receipt_input_validation.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:rosid/parsing/normalizers/date_normalizer.dart';

class DetailEditScreen extends ConsumerStatefulWidget {
  const DetailEditScreen({required this.scanId, super.key});

  final String scanId;

  @override
  ConsumerState<DetailEditScreen> createState() => _DetailEditScreenState();
}

class _DetailEditScreenState extends ConsumerState<DetailEditScreen> {
  ScanDetail? _detail;
  List<Category> _categories = const [];
  final _controllers = <TextEditingController>[];
  final _items = <_LineItemControllers>[];
  TextEditingController? _merchant;
  TextEditingController? _date;
  TextEditingController? _total;
  TextEditingController? _tax;
  TextEditingController? _paymentMethod;
  TextEditingController? _note;
  TextEditingController? _title;
  TextEditingController? _body;
  TextEditingController? _tags;
  String? _categoryId;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  TextEditingController _controller([String? text]) {
    final controller = TextEditingController(text: text);
    _controllers.add(controller);
    return controller;
  }

  Future<void> _load() async {
    final detail = await ref
        .read(historyRepositoryProvider)
        .detail(widget.scanId);
    if (detail == null || !mounted) return;
    final receipt = detail.entry.receipt;
    final document = detail.entry.document;
    if (receipt != null) {
      _merchant = _controller(receipt.merchant);
      _date = _controller(
        DateFormat('yyyy-MM-dd').format(receipt.dateOfPurchase),
      );
      _total = _controller(receipt.total.toStringAsFixed(2));
      _tax = _controller(receipt.tax?.toStringAsFixed(2));
      _paymentMethod = _controller(receipt.paymentMethod);
      _note = _controller(receipt.note);
      _categoryId = receipt.categoryId ?? 'other';
      for (final item in detail.lineItems) {
        _items.add(
          _LineItemControllers(
            name: _controller(item.name),
            quantity: _controller(item.qty.toString()),
            unitPrice: _controller(item.unitPrice?.toStringAsFixed(2)),
            amount: _controller(item.amount.toStringAsFixed(2)),
          ),
        );
      }
    } else if (document != null) {
      _title = _controller(document.title);
      _body = _controller(document.body);
      _tags = _controller(detail.tags.map((tag) => tag.name).join(', '));
    }
    final categories = receipt == null
        ? const <Category>[]
        : await ref.read(recordRepositoryProvider).categories();
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _categories = categories;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(
        _LineItemControllers(
          name: _controller(),
          quantity: _controller('1'),
          unitPrice: _controller(),
          amount: _controller(),
        ),
      );
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _save() async {
    final detail = _detail;
    if (detail == null || _isSaving) return;
    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });
    try {
      final receipt = detail.entry.receipt;
      final document = detail.entry.document;
      if (receipt != null) {
        await _saveReceipt(receipt);
      } else if (document != null) {
        final title = _title!.text.trim();
        if (title.isEmpty) {
          throw FormatException(context.l10n.documentTitleRequired);
        }
        await ref
            .read(recordRepositoryProvider)
            .saveDocument(
              scanId: widget.scanId,
              title: title,
              body: _body!.text.trim(),
              tags: _tags!.text.split(','),
              pinned: document.pinned,
            );
      }
      if (!mounted) return;
      invalidateRecordViews(ref);
      context.pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error is FormatException
              ? error.message.toString()
              : context.l10n.saveFailed;
        });
      }
    }
  }

  Future<void> _saveReceipt(Receipt receipt) async {
    final merchant = _merchant!.text.trim();
    final date = DateNormalizer.find(_date!.text)?.value;
    if (merchant.isEmpty || date == null) {
      throw FormatException(context.l10n.receiptFieldsRequired);
    }
    late final double total;
    double? tax;
    try {
      total = ReceiptInputValidation.requiredNonNegativeAmount(_total!.text);
      tax = ReceiptInputValidation.optionalNonNegativeAmount(_tax!.text);
    } on ReceiptInputValidationException {
      throw FormatException(context.l10n.validTotalAndTaxRequired);
    }
    final items = <ParsedLineItem>[];
    for (final item in _items) {
      try {
        final parsed = ReceiptInputValidation.lineItem(
          name: item.name.text,
          quantity: item.quantity.text,
          unitPrice: item.unitPrice.text,
          amount: item.amount.text,
        );
        if (parsed != null) items.add(parsed);
      } on ReceiptInputValidationException {
        throw FormatException(context.l10n.validLineItemRequired);
      }
    }
    final decoded = jsonDecode(receipt.fieldConfidenceJson);
    final confidence = <String, double>{};
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        confidence[entry.key.toString()] = entry.value is num
            ? (entry.value as num).toDouble()
            : 0;
      }
    }
    await ref
        .read(recordRepositoryProvider)
        .saveReceipt(
          scanId: widget.scanId,
          merchant: merchant,
          date: date,
          total: total,
          currency: receipt.currency,
          categoryId: _categoryId ?? 'other',
          items: items,
          fieldConfidence: confidence,
          tax: tax,
          paymentMethod: _paymentMethod!.text.trim().isEmpty
              ? null
              : _paymentMethod!.text.trim(),
          note: _note!.text.trim().isEmpty ? null : _note!.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.edit)),
        body: detail == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (detail.entry.receipt != null) _receiptForm(context),
                  if (detail.entry.document != null) _documentForm(context),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(context.l10n.save),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _receiptForm(BuildContext context) {
    final bangla = Localizations.localeOf(context).languageCode == 'bn';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_merchant!, context.l10n.merchant),
        _field(_date!, context.l10n.purchaseDate, type: TextInputType.datetime),
        _field(_total!, context.l10n.total, type: TextInputType.number),
        _field(_tax!, context.l10n.tax, type: TextInputType.number),
        _field(_paymentMethod!, context.l10n.paymentMethod),
        DropdownButtonFormField<String>(
          initialValue: _categoryId,
          decoration: InputDecoration(labelText: context.l10n.category),
          items: _categories
              .map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(bangla ? category.nameBn : category.nameEn),
                ),
              )
              .toList(),
          onChanged: (value) => _categoryId = value,
        ),
        const SizedBox(height: 12),
        _field(_note!, context.l10n.notes, maxLines: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.lineItems,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: _addItem,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        for (var index = 0; index < _items.length; index++)
          _lineItemCard(context, index),
      ],
    );
  }

  Widget _documentForm(BuildContext context) => Column(
    children: [
      _field(_title!, context.l10n.title),
      _field(_body!, context.l10n.body, maxLines: 12),
      _field(_tags!, context.l10n.tags),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? type,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _lineItemCard(BuildContext context, int index) {
    final item = _items[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _field(item.name, context.l10n.title),
            Row(
              children: [
                Expanded(child: _field(item.quantity, context.l10n.quantity)),
                const SizedBox(width: 8),
                Expanded(child: _field(item.unitPrice, context.l10n.unitPrice)),
                const SizedBox(width: 8),
                Expanded(child: _field(item.amount, context.l10n.total)),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineItemControllers {
  const _LineItemControllers({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController amount;
}
