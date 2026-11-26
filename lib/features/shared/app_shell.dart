import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  RosidNavTab get _activeTab {
    if (location.startsWith('/library') || location.startsWith('/history')) {
      return RosidNavTab.library;
    }
    if (location.startsWith('/bundles')) return RosidNavTab.bundles;
    if (location.startsWith('/expenses')) return RosidNavTab.expenses;
    return RosidNavTab.home;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    final l10n = context.l10n;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: RosidNavDock(
        activeTab: _activeTab,
        showExpenses: expenseEnabled,
        homeLabel: l10n.home,
        libraryLabel: l10n.library,
        bundlesLabel: l10n.bundles,
        expensesLabel: l10n.expenses,
        scanTooltip: l10n.scan,
        onSelectTab: (tab) {
          switch (tab) {
            case RosidNavTab.home:
              context.go('/');
            case RosidNavTab.library:
              context.go('/library');
            case RosidNavTab.bundles:
              context.go('/bundles');
            case RosidNavTab.expenses:
              context.go('/expenses');
          }
        },
        onScanPressed: () => context.push('/scan?mode=document'),
      ),
    );
  }
}
