import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/ocr_controller.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:rosid/parsing/receipt_parser.dart';

class EditableLineItem {
  const EditableLineItem({
    required this.name,
    required this.quantity,
    required this.amount,
    this.unitPrice,
  });

  final String name;
  final String quantity;
  final String? unitPrice;
  final String amount;

  EditableLineItem copyWith({
    String? name,
    String? quantity,
    String? unitPrice,
    String? amount,
  }) => EditableLineItem(
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    amount: amount ?? this.amount,
  );
}

class ReceiptReviewState {
  const ReceiptReviewState({
    this.scanId,
    this.merchant = '',
    this.date = '',
    this.total = '',
    this.tax = '',
    this.paymentMethod = '',
    this.categoryId = 'other',
    this.note = '',
    this.items = const [],
    this.rawText = '',
    this.confidence = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final String? scanId;
  final String merchant;
  final String date;
  final String total;
  final String tax;
  final String paymentMethod;
  final String categoryId;
  final String note;
  final List<EditableLineItem> items;
  final String rawText;
  final Map<String, double> confidence;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  ReceiptReviewState copyWith({
    String? scanId,
    String? merchant,
    String? date,
    String? total,
    String? tax,
    String? paymentMethod,
    String? categoryId,
    String? note,
    List<EditableLineItem>? items,
    String? rawText,
    Map<String, double>? confidence,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) => ReceiptReviewState(
    scanId: scanId ?? this.scanId,
    merchant: merchant ?? this.merchant,
    date: date ?? this.date,
    total: total ?? this.total,
    tax: tax ?? this.tax,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    categoryId: categoryId ?? this.categoryId,
    note: note ?? this.note,
    items: items ?? this.items,
    rawText: rawText ?? this.rawText,
    confidence: confidence ?? this.confidence,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: errorMessage,
  );
}

class ReceiptReviewController extends Notifier<ReceiptReviewState> {
  @override
  ReceiptReviewState build() => const ReceiptReviewState();

  Future<void> initialize({
    required CaptureSession session,
    required List<PreprocessedAsset> assets,
  }) async {
    if (session.scanId == null || state.scanId == session.scanId) return;
    state = ReceiptReviewState(scanId: session.scanId, isLoading: true);
    final ocr = await ref
        .read(ocrControllerProvider.notifier)
        .recognize(session: session, assets: assets);
    if (ocr == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.read(ocrControllerProvider).errorMessage,
      );
      return;
    }
    final parsed = const ReceiptParser().parse(
      ocr.text,
      scanTime: DateTime.now(),
    );
    state = ReceiptReviewState(
      scanId: session.scanId,
      merchant: parsed.merchant.value,
      date: DateFormat('yyyy-MM-dd').format(parsed.date.value),
      total: parsed.total.value?.toStringAsFixed(2) ?? '',
      tax: parsed.tax.value?.toStringAsFixed(2) ?? '',
      paymentMethod: parsed.paymentMethod.value ?? '',
      categoryId: parsed.categoryId.value ?? 'other',
      items: parsed.lineItems
          .map(
            (item) => EditableLineItem(
              name: item.name,
              quantity: item.quantity.toString(),
              unitPrice: item.unitPrice?.toStringAsFixed(2),
              amount: item.amount.toStringAsFixed(2),
            ),
          )
          .toList(),
      rawText: parsed.rawText,
      confidence: {
        'merchant': parsed.merchant.confidence,
        'date': parsed.date.confidence,
        'total': parsed.total.confidence,
        'tax': parsed.tax.confidence,
        'paymentMethod': parsed.paymentMethod.confidence,
        'category': parsed.categoryId.confidence,
      },
    );
  }

  void setMerchant(String value) => state = state.copyWith(merchant: value);
  void setDate(String value) => state = state.copyWith(date: value);
  void setTotal(String value) => state = state.copyWith(total: value);
  void setTax(String value) => state = state.copyWith(tax: value);
  void setPaymentMethod(String value) =>
      state = state.copyWith(paymentMethod: value);
  void setCategory(String value) => state = state.copyWith(categoryId: value);
  void setNote(String value) => state = state.copyWith(note: value);

  void setItem(int index, EditableLineItem item) {
    final items = [...state.items]..[index] = item;
    state = state.copyWith(items: items);
  }

  void addItem() => state = state.copyWith(
    items: [
      ...state.items,
      const EditableLineItem(name: '', quantity: '1', amount: ''),
    ],
  );

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  Future<bool> save() async {
    final scanId = state.scanId;
    final date = DateTime.tryParse(state.date);
    final total = double.tryParse(state.total.replaceAll(',', ''));
    if (scanId == null || date == null || total == null) {
      state = state.copyWith(
        errorMessage: 'Merchant, date, and total are required.',
      );
      return false;
    }
    state = state.copyWith(isSaving: true);
    try {
      await ref
          .read(recordRepositoryProvider)
          .saveReceipt(
            scanId: scanId,
            merchant: state.merchant.trim(),
            date: date,
            total: total,
            currency: ref.read(appSettingsProvider).currency,
            tax: double.tryParse(state.tax),
            paymentMethod: state.paymentMethod.trim().isEmpty
                ? null
                : state.paymentMethod.trim(),
            categoryId: state.categoryId,
            note: state.note.trim().isEmpty ? null : state.note.trim(),
            items: state.items
                .where(
                  (item) =>
                      item.name.trim().isNotEmpty &&
                      double.tryParse(item.amount) != null,
                )
                .map(
                  (item) => ParsedLineItem(
                    name: item.name.trim(),
                    quantity: double.tryParse(item.quantity) ?? 1,
                    unitPrice: double.tryParse(item.unitPrice ?? ''),
                    amount: double.parse(item.amount),
                    rawText: '',
                  ),
                )
                .toList(),
            fieldConfidence: state.confidence,
          );
      state = state.copyWith(isSaving: false);
      return true;
    } on Object catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }
}

final receiptReviewProvider =
    NotifierProvider<ReceiptReviewController, ReceiptReviewState>(
      ReceiptReviewController.new,
    );
