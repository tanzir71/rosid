import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/features/history/history_state.dart';

void invalidateRecordViews(WidgetRef ref) {
  ref
    ..invalidate(historyResultsProvider)
    ..invalidate(dashboardSummaryProvider)
    ..invalidate(homeDocumentsProvider);
}
