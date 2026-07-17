import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/confidence_field.dart';
import 'package:rosid/features/review/receipt_review_controller.dart';
import 'package:rosid/features/review/review_cleanup.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key});

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  late final Future<List<Category>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = ref.read(recordRepositoryProvider).categories();
    Future.microtask(() {
      ref
          .read(receiptReviewProvider.notifier)
          .initialize(
            session: ref.read(captureSessionProvider),
            assets: ref.read(preprocessProvider).assets,
          );
    });
  }

  Future<void> _save() async {
    final saved = await ref.read(receiptReviewProvider.notifier).save();
    if (!mounted || !saved) return;
    clearCompletedReview(ref);
    context.go('/');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptReviewProvider);
    final assets = ref.watch(preprocessProvider).assets;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reviewReceipt)),
      body: state.isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(context.l10n.processing),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.confidence.values.any((value) => value < 0.6))
                  Card(
                    color: Colors.amber.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: Colors.amber,
                      ),
                      title: Text(context.l10n.verifyLowConfidence),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final image = _ReceiptImage(
                      path: assets.isEmpty ? null : assets.first.colorPath,
                    );
                    final form = _ReceiptForm(
                      state: state,
                      categories: _categories,
                    );
                    if (constraints.maxWidth > 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: image),
                          const SizedBox(width: 20),
                          Expanded(child: form),
                        ],
                      );
                    }
                    return Column(
                      children: [image, const SizedBox(height: 16), form],
                    );
                  },
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: Text(context.l10n.rawOcrText),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(state.rawText),
                    ),
                  ],
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.isSaving ? null : _save,
                  icon: state.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.l10n.save),
                ),
              ],
            ),
    );
  }
}

class _ReceiptImage extends StatelessWidget {
  const _ReceiptImage({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: path == null
            ? const Center(child: Icon(Icons.receipt_long, size: 64))
            : InteractiveViewer(
                child: Image.file(File(path!), fit: BoxFit.contain),
              ),
      ),
    );
  }
}

class _ReceiptForm extends ConsumerWidget {
  const _ReceiptForm({required this.state, required this.categories});

  final ReceiptReviewState state;
  final Future<List<Category>> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(receiptReviewProvider.notifier);
    double confidence(String field) => state.confidence[field] ?? 0;
    return Column(
      children: [
        ConfidenceField(
          label: context.l10n.merchant,
          initialValue: state.merchant,
          confidence: confidence('merchant'),
          onChanged: controller.setMerchant,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ConfidenceField(
                label: context.l10n.purchaseDate,
                initialValue: state.date,
                confidence: confidence('date'),
                keyboardType: TextInputType.datetime,
                onChanged: controller.setDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ConfidenceField(
                label: context.l10n.total,
                initialValue: state.total,
                confidence: confidence('total'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: controller.setTotal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ConfidenceField(
                label: context.l10n.tax,
                initialValue: state.tax,
                confidence: confidence('tax'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: controller.setTax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ConfidenceField(
                label: context.l10n.paymentMethod,
                initialValue: state.paymentMethod,
                confidence: confidence('paymentMethod'),
                onChanged: controller.setPaymentMethod,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Category>>(
          future: categories,
          builder: (context, snapshot) {
            final values = snapshot.data ?? const <Category>[];
            final selected =
                values.any((category) => category.id == state.categoryId)
                ? state.categoryId
                : null;
            return DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: InputDecoration(labelText: context.l10n.category),
              items: values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.nameEn),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.setCategory(value);
              },
            );
          },
        ),
        const SizedBox(height: 12),
        ConfidenceField(
          label: context.l10n.notes,
          initialValue: state.note,
          onChanged: controller.setNote,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.lineItems,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: controller.addItem,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        for (var index = 0; index < state.items.length; index++)
          _LineItemEditor(index: index, item: state.items[index]),
      ],
    );
  }
}

class _LineItemEditor extends ConsumerWidget {
  const _LineItemEditor({required this.index, required this.item});

  final int index;
  final EditableLineItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(receiptReviewProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: item.name,
              decoration: InputDecoration(labelText: context.l10n.title),
              onChanged: (value) =>
                  controller.setItem(index, item.copyWith(name: value)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    onChanged: (value) => controller.setItem(
                      index,
                      item.copyWith(quantity: value),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.amount,
                    decoration: InputDecoration(labelText: context.l10n.total),
                    onChanged: (value) =>
                        controller.setItem(index, item.copyWith(amount: value)),
                  ),
                ),
                IconButton(
                  onPressed: () => controller.removeItem(index),
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
