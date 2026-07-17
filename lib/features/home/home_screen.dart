import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/data/repositories/history_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.appName),
            Text(
              context.l10n.offlineTagline,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Tooltip(
              message: 'Offline',
              child: Icon(Icons.shield_outlined, color: AppTheme.leaf),
            ),
          ),
        ],
      ),
      body: expenseEnabled ? const _DashboardHome() : const _DocumentsHome(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/capture'),
        icon: const Icon(Icons.document_scanner_outlined),
        label: Text(context.l10n.scan),
      ),
    );
  }
}

class _DashboardHome extends ConsumerWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (value) => RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Card(
              color: AppTheme.ink,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.thisMonth,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '৳${value.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.spendByCategory,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/export'),
                  icon: const Icon(Icons.ios_share),
                  label: Text(context.l10n.export),
                ),
              ],
            ),
            if (value.byCategory.isEmpty)
              Text(context.l10n.noReceipts)
            else
              for (final entry in value.byCategory.entries)
                _CategoryBar(
                  name: entry.key,
                  amount: entry.value,
                  maximum: value.byCategory.values.reduce(
                    (current, next) => current > next ? current : next,
                  ),
                ),
            const SizedBox(height: 20),
            Text(
              context.l10n.recentReceipts,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (value.recent.isEmpty)
              Text(context.l10n.noReceipts)
            else
              for (final entry in value.recent) _RecentTile(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.amount,
    required this.maximum,
  });

  final String name;
  final double amount;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(name)),
              Text('৳${amount.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: maximum <= 0 ? 0 : amount / maximum,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/detail/${entry.scan.id}'),
        leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text(entry.title),
        subtitle: Text(
          DateFormat.yMMMd().format(entry.receipt!.dateOfPurchase),
        ),
        trailing: Text('৳${entry.receipt!.total.toStringAsFixed(2)}'),
      ),
    );
  }
}

class _DocumentsHome extends ConsumerWidget {
  const _DocumentsHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(homeDocumentsProvider);
    return documents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(error.toString())),
      data: (entries) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: TextField(
                readOnly: true,
                onTap: () => context.go('/history'),
                decoration: InputDecoration(
                  hintText: context.l10n.search,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 72),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.noDocuments,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        context.l10n.scanFirstDocument,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.recentDocuments,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) =>
                    _DocumentCard(entry: entries[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/detail/${entry.scan.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(entry.scan.thumbPath ?? entry.scan.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const ColoredBox(color: AppTheme.mint),
                  ),
                  if (entry.document?.pinned ?? false)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 15,
                        child: Icon(Icons.push_pin, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
