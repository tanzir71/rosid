import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/utils/money.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/features/history/history_state.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final Future<List<Category>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = ref.read(recordRepositoryProvider).categories();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      ref
          .read(historyFilterProvider.notifier)
          .setDates(result.start, result.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final results = ref.watch(historyResultsProvider);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.history)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(historyResultsProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.search,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: ref
                          .read(historyFilterProvider.notifier)
                          .setText,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (expenseEnabled)
                            for (final type in HistoryTypeFilter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: filter.type == type,
                                  label: Text(switch (type) {
                                    HistoryTypeFilter.all => context.l10n.all,
                                    HistoryTypeFilter.receipt =>
                                      context.l10n.receipt,
                                    HistoryTypeFilter.document =>
                                      context.l10n.document,
                                  }),
                                  onSelected: (_) => ref
                                      .read(historyFilterProvider.notifier)
                                      .setType(type),
                                ),
                              ),
                          InputChip(
                            avatar: const Icon(Icons.date_range, size: 18),
                            label: Text(
                              filter.start == null
                                  ? context.l10n.filter
                                  : '${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(filter.start!)} – ${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(filter.end!)}',
                            ),
                            onPressed: _pickDates,
                            onDeleted: filter.start == null
                                ? null
                                : () => ref
                                      .read(historyFilterProvider.notifier)
                                      .setDates(null, null),
                          ),
                        ],
                      ),
                    ),
                    if (expenseEnabled &&
                        filter.type != HistoryTypeFilter.document)
                      FutureBuilder<List<Category>>(
                        future: _categories,
                        builder: (context, snapshot) {
                          final categories =
                              snapshot.data ?? const <Category>[];
                          final bangla =
                              Localizations.localeOf(context).languageCode ==
                              'bn';
                          return DropdownButtonFormField<String?>(
                            initialValue: filter.categoryId,
                            decoration: InputDecoration(
                              labelText: context.l10n.category,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                child: Text(context.l10n.all),
                              ),
                              ...categories.map(
                                (category) => DropdownMenuItem<String?>(
                                  value: category.id,
                                  child: Text(
                                    bangla ? category.nameBn : category.nameEn,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: ref
                                .read(historyFilterProvider.notifier)
                                .setCategory,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            results.when(
              data: (entries) => entries.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text(context.l10n.noResults)),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      sliver: SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _HistoryTile(entry: entries[index]),
                      ),
                    ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(child: Text(context.l10n.loadFailed)),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final bangla = Localizations.localeOf(context).languageCode == 'bn';
    final category = entry.category;
    return Card(
      child: ListTile(
        onTap: () => context.push('/detail/${entry.scan.id}'),
        leading: CircleAvatar(
          child: Icon(
            entry.isReceipt ? Icons.receipt_long : Icons.description_outlined,
          ),
        ),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          entry.receipt == null
              ? DateFormat.yMMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(entry.scan.createdAt)
              : '${category == null
                    ? context.l10n.category
                    : bangla
                    ? category.nameBn
                    : category.nameEn} • ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(entry.receipt!.dateOfPurchase)}',
        ),
        trailing: entry.receipt == null
            ? (entry.document?.pinned ?? false)
                  ? const Icon(Icons.push_pin)
                  : null
            : Text(
                formatMoney(entry.receipt!.total, entry.receipt!.currency),
                style: Theme.of(context).textTheme.titleMedium,
              ),
      ),
    );
  }
}
