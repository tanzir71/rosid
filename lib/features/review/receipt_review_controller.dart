import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/ocr_controller.dart';
import 'package:rosid/features/review/receipt_input_validation.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:rosid/parsing/normalizers/date_normalizer.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';
import 'package:rosid/parsing/receipt_parser.dart';

class EditableLineItem {
  const EditableLineItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.amount,
    this.unitPrice,
  });

  final String id;
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
    id: id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    amount: amount ?? this.amount,
  );
}

class ReceiptReviewState {
  const ReceiptReviewState({
    this.scanId,
    this.preprocessGeneration,
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
  final int? preprocessGeneration;
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
    int? preprocessGeneration,
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
    preprocessGeneration: preprocessGeneration ?? this.preprocessGeneration,
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
  var _nextManualItemId = 0;
  var _requestToken = 0;

  @override
  ReceiptReviewState build() => const ReceiptReviewState();

  Future<void> initialize({
    required CaptureSession session,
    required List<PreprocessedAsset> assets,
    required AppLocalizations localizations,
  }) async {
    final generation = assets.isEmpty ? null : assets.first.generation;
    if (session.scanId == null || generation == null) return;
    if (state.scanId == session.scanId &&
        state.preprocessGeneration == generation &&
        state.errorMessage == null) {
      return;
    }
    final token = ++_requestToken;
    final scanId = session.scanId!;
    state = ReceiptReviewState(
      scanId: scanId,
      preprocessGeneration: generation,
      isLoading: true,
    );
    final ocr = await ref
        .read(ocrControllerProvider.notifier)
        .recognize(session: session, assets: assets);
    if (!_isCurrent(token, scanId, generation)) return;
    if (ocr == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: localizations.processingFailed,
      );
      return;
    }
    final scan = await ref.read(scanRepositoryProvider).getScan(scanId);
    if (!_isCurrent(token, scanId, generation)) return;
    final parsed = const ReceiptParser().parse(
      ocr.text,
      scanTime: scan.createdAt,
    );
    double cappedConfidence(double parserConfidence, String rawText) => math
        .min(parserConfidence, _sourceConfidence(rawText: rawText, ocr: ocr));
    state = ReceiptReviewState(
      scanId: scanId,
      preprocessGeneration: generation,
      merchant: parsed.merchant.value,
      date: DateFormat('yyyy-MM-dd').format(parsed.date.value),
      total: parsed.total.value?.toStringAsFixed(2) ?? '',
      tax: parsed.tax.value?.toStringAsFixed(2) ?? '',
      paymentMethod: parsed.paymentMethod.value ?? '',
      categoryId: parsed.categoryId.value ?? 'other',
      items: parsed.lineItems.indexed
          .map(
            (entry) => EditableLineItem(
              id: 'parsed-${entry.$1}',
              name: entry.$2.name,
              quantity: entry.$2.quantity.toString(),
              unitPrice: entry.$2.unitPrice?.toStringAsFixed(2),
              amount: entry.$2.amount.toStringAsFixed(2),
            ),
          )
          .toList(),
      rawText: parsed.rawText,
      confidence: {
        'merchant': cappedConfidence(
          parsed.merchant.confidence,
          parsed.merchant.rawText,
        ),
        'date': cappedConfidence(parsed.date.confidence, parsed.date.rawText),
        'total': cappedConfidence(
          parsed.total.confidence,
          parsed.total.rawText,
        ),
        'tax': cappedConfidence(parsed.tax.confidence, parsed.tax.rawText),
        'paymentMethod': cappedConfidence(
          parsed.paymentMethod.confidence,
          parsed.paymentMethod.rawText,
        ),
        'category': cappedConfidence(
          parsed.categoryId.confidence,
          parsed.categoryId.rawText,
        ),
      },
    );
  }

  double _sourceConfidence({required String rawText, required OcrResult ocr}) {
    final blocks = ocr.blocks
        .where((block) => block.text.trim().isNotEmpty)
        .toList(growable: false);
    if (blocks.isEmpty) return 0;
    final rawLines = TextNormalizer.normalizeForParsing(rawText)
        .toLowerCase()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final relevant = rawLines.isEmpty
        ? const <OcrBlock>[]
        : blocks
              .where((block) {
                final blockText = TextNormalizer.normalizeForParsing(block.text)
                    .toLowerCase();
                return rawLines.any(
                  (line) =>
                      blockText.contains(line) || line.contains(blockText),
                );
              })
              .toList(growable: false);
    final sources = relevant.isEmpty ? blocks : relevant;
    return sources
        .map((block) => block.confidence.clamp(0, 1).toDouble())
        .reduce(math.min);
  }

  void setMerchant(String value) => state = state.copyWith(merchant: value);
  void setDate(String value) => state = state.copyWith(date: value);
  void setTotal(String value) => state = state.copyWith(total: value);
  void setTax(String value) => state = state.copyWith(tax: value);
  void setPaymentMethod(String value) =>
      state = state.copyWith(paymentMethod: value);
  void setCategory(String value) => state = state.copyWith(categoryId: value);
  void setNote(String value) => state = state.copyWith(note: value);

  bool _isCurrent(int token, String scanId, int generation) =>
      token == _requestToken &&
      state.scanId == scanId &&
      state.preprocessGeneration == generation;

  void reset() {
    _requestToken++;
    state = const ReceiptReviewState();
  }

  void setItem(int index, EditableLineItem item) {
    final items = [...state.items]..[index] = item;
    state = state.copyWith(items: items);
  }

  void addItem() => state = state.copyWith(
    items: [
      ...state.items,
      EditableLineItem(
        id: 'manual-${_nextManualItemId++}',
        name: '',
        quantity: '1',
        amount: '',
      ),
    ],
  );

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  Future<bool> save({required AppLocalizations localizations}) async {
    final scanId = state.scanId;
    final merchant = state.merchant.trim();
    final date = DateNormalizer.find(state.date)?.value;
    if (scanId == null || merchant.isEmpty || date == null) {
      state = state.copyWith(errorMessage: localizations.receiptFieldsRequired);
      return false;
    }
    late final double total;
    double? tax;
    try {
      total = ReceiptInputValidation.requiredNonNegativeAmount(state.total);
      tax = ReceiptInputValidation.optionalNonNegativeAmount(state.tax);
    } on ReceiptInputValidationException {
      state = state.copyWith(
        errorMessage: localizations.validTotalAndTaxRequired,
      );
      return false;
    }

    final parsedItems = <ParsedLineItem>[];
    for (final item in state.items) {
      try {
        final parsed = ReceiptInputValidation.lineItem(
          name: item.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice ?? '',
          amount: item.amount,
        );
        if (parsed != null) parsedItems.add(parsed);
      } on ReceiptInputValidationException {
        state = state.copyWith(
          errorMessage: localizations.validLineItemRequired,
        );
        return false;
      }
    }

    state = state.copyWith(isSaving: true);
    try {
      await ref
          .read(recordRepositoryProvider)
          .saveReceipt(
            scanId: scanId,
            merchant: merchant,
            date: date,
            total: total,
            currency: ref.read(appSettingsProvider).currency,
            tax: tax,
            paymentMethod: state.paymentMethod.trim().isEmpty
                ? null
                : state.paymentMethod.trim(),
            categoryId: state.categoryId,
            note: state.note.trim().isEmpty ? null : state.note.trim(),
            items: parsedItems,
            fieldConfidence: state.confidence,
          );
      state = state.copyWith(isSaving: false);
      return true;
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: localizations.saveFailed,
      );
      return false;
    }
  }
}

final receiptReviewProvider =
    NotifierProvider<ReceiptReviewController, ReceiptReviewState>(
      ReceiptReviewController.new,
    );
