import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/features/history/history_state.dart';
import 'package:rosid/features/history/record_view_cache.dart';

void main() {
  testWidgets('invalidates every record-backed view cache', (tester) async {
    var historyBuilds = 0;
    var dashboardBuilds = 0;
    var documentsBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyResultsProvider.overrideWith((ref) async {
            historyBuilds++;
            return const <HistoryEntry>[];
          }),
          dashboardSummaryProvider.overrideWith((ref) async {
            dashboardBuilds++;
            return const DashboardSummary(
              total: 0,
              currency: 'BDT',
              byCategory: {},
              recent: [],
            );
          }),
          homeDocumentsProvider.overrideWith((ref) async {
            documentsBuilds++;
            return const <HistoryEntry>[];
          }),
        ],
        child: const _CacheHarness(),
      ),
    );
    await tester.pumpAndSettle();
    expect((historyBuilds, dashboardBuilds, documentsBuilds), (1, 1, 1));

    await tester.tap(find.text('Invalidate'));
    await tester.pumpAndSettle();

    expect((historyBuilds, dashboardBuilds, documentsBuilds), (2, 2, 2));
  });
}

class _CacheHarness extends ConsumerWidget {
  const _CacheHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(historyResultsProvider)
      ..watch(dashboardSummaryProvider)
      ..watch(homeDocumentsProvider);
    return MaterialApp(
      home: Scaffold(
        body: TextButton(
          onPressed: () => invalidateRecordViews(ref),
          child: const Text('Invalidate'),
        ),
      ),
    );
  }
}
