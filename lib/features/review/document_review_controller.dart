import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/ocr_controller.dart';

class DocumentReviewState {
  const DocumentReviewState({
    this.scanId,
    this.title = '',
    this.body = '',
    this.tags = '',
    this.confidence = 1,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final String? scanId;
  final String title;
  final String body;
  final String tags;
  final double confidence;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  DocumentReviewState copyWith({
    String? scanId,
    String? title,
    String? body,
    String? tags,
    double? confidence,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) => DocumentReviewState(
    scanId: scanId ?? this.scanId,
    title: title ?? this.title,
    body: body ?? this.body,
    tags: tags ?? this.tags,
    confidence: confidence ?? this.confidence,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: errorMessage,
  );
}

class DocumentReviewController extends Notifier<DocumentReviewState> {
  @override
  DocumentReviewState build() => const DocumentReviewState();

  Future<void> initialize({
    required CaptureSession session,
    required List<PreprocessedAsset> assets,
  }) async {
    if (session.scanId == null || state.scanId == session.scanId) return;
    state = DocumentReviewState(scanId: session.scanId, isLoading: true);
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
    final lines = ocr.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    state = DocumentReviewState(
      scanId: session.scanId,
      title: lines.isEmpty ? 'Untitled document' : lines.first,
      body: ocr.text,
      confidence: ocr.meanConfidence,
    );
  }

  void setTitle(String value) => state = state.copyWith(title: value);
  void setBody(String value) => state = state.copyWith(body: value);
  void setTags(String value) => state = state.copyWith(tags: value);

  Future<bool> save() async {
    final scanId = state.scanId;
    if (scanId == null || state.title.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'A document title is required.');
      return false;
    }
    state = state.copyWith(isSaving: true);
    try {
      await ref
          .read(recordRepositoryProvider)
          .saveDocument(
            scanId: scanId,
            title: state.title.trim(),
            body: state.body.trim(),
            tags: state.tags.split(','),
          );
      state = state.copyWith(isSaving: false);
      return true;
    } on Object catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }
}

final documentReviewProvider =
    NotifierProvider<DocumentReviewController, DocumentReviewState>(
      DocumentReviewController.new,
    );
