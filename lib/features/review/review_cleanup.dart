import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/ocr_controller.dart';

void clearCompletedReview(WidgetRef ref) {
  ref.read(captureSessionProvider.notifier).clearAfterSave();
  ref.read(preprocessProvider.notifier).reset();
  ref.read(ocrControllerProvider.notifier).reset();
}
