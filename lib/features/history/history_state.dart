import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/repositories/history_repository.dart';

class HistoryFilterController extends Notifier<HistoryQuery> {
  @override
  HistoryQuery build() => const HistoryQuery();

  void setText(String text) => state = state.copyWith(text: text);
  void setType(HistoryTypeFilter type) => state = state.copyWith(type: type);
  void setCategory(String? categoryId) => state = categoryId == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(categoryId: categoryId);
  void setDates(DateTime? start, DateTime? end) => start == null || end == null
      ? state.copyWith(clearDates: true)
      : state.copyWith(start: start, end: end);
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryQuery>(
      HistoryFilterController.new,
    );

final historyResultsProvider = FutureProvider<List<HistoryEntry>>((ref) {
  final filter = ref.watch(historyFilterProvider);
  return ref.watch(historyRepositoryProvider).list(filter);
});
