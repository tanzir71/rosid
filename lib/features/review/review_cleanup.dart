import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/history/record_view_cache.dart';
import 'package:rosid/features/review/document_review_controller.dart';
import 'package:rosid/features/review/ocr_controller.dart';
import 'package:rosid/features/review/receipt_review_controller.dart';

void clearProcessingAndReview(WidgetRef ref) {
  ref.read(preprocessProvider.notifier).reset();
  ref.read(ocrControllerProvider.notifier).reset();
  ref.read(receiptReviewProvider.notifier).reset();
  ref.read(documentReviewProvider.notifier).reset();
}

void clearCompletedReview(WidgetRef ref) {
  ref.read(captureSessionProvider.notifier).clearAfterSave();
  clearProcessingAndReview(ref);
  invalidateRecordViews(ref);
}
