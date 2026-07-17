import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/app_metadata.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/data/repositories/settings_repository.dart';
import 'package:rosid/features/history/history_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<List<Category>> _categories;
  bool _deleteAllBusy = false;

  @override
  void initState() {
    super.initState();
    _reloadCategories();
  }

  void _reloadCategories() {
    _categories = ref.read(settingsRepositoryProvider).categories();
  }

  Future<void> _editCategory([Category? category]) async {
    final en = TextEditingController(text: category?.nameEn);
    final bn = TextEditingController(text: category?.nameBn);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.categories),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: en,
              decoration: const InputDecoration(labelText: 'English'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bn,
              decoration: const InputDecoration(labelText: 'বাংলা'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    final nameEn = en.text.trim();
    final nameBn = bn.text.trim();
    en.dispose();
    bn.dispose();
    if (save != true || nameEn.isEmpty || nameBn.isEmpty) return;
    if (category == null) {
      await ref.read(settingsRepositoryProvider).addCategory(nameEn, nameBn);
    } else {
      await ref
          .read(settingsRepositoryProvider)
          .updateCategory(category, nameEn, nameBn);
    }
    setState(_reloadCategories);
  }

  Future<void> _deleteAll() async {
    if (_deleteAllBusy) return;
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final fileStore = ref.read(privateFileStoreProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteAllData),
        content: Text(context.l10n.deleteAllDataDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (mounted) setState(() => _deleteAllBusy = true);
    try {
      await settingsRepository.deleteAllData();
      await fileStore.deleteAllAppData();
      if (!mounted) return;
      ref
        ..invalidate(historyResultsProvider)
        ..invalidate(dashboardSummaryProvider)
        ..invalidate(homeDocumentsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saved)));
    } finally {
      if (mounted) setState(() => _deleteAllBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final profile = ref.watch(appProfileProvider);
    final appMetadata = ref.watch(appMetadataProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    return PopScope(
      canPop: !_deleteAllBusy,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.settings)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Text(
              context.l10n.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'en', label: Text(context.l10n.english)),
                ButtonSegment(value: 'bn', label: Text(context.l10n.bangla)),
              ],
              selected: {settings.languageCode},
              onSelectionChanged: (value) =>
                  controller.setLanguage(value.single),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.expenseTracking),
              subtitle: Text(context.l10n.expenseTrackingDescription),
              value: settings.expenseTrackingEnabled,
              onChanged: profile.expenseTrackingLocked
                  ? null
                  : controller.setExpenseTracking,
            ),
            if (settings.expenseTrackingEnabled) ...[
              const Divider(),
              DropdownButtonFormField<String>(
                initialValue: settings.currency,
                decoration: InputDecoration(
                  labelText: context.l10n.defaultCurrency,
                ),
                items: const [
                  DropdownMenuItem(value: 'BDT', child: Text('৳ BDT')),
                  DropdownMenuItem(value: 'USD', child: Text(r'$ USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('€ EUR')),
                ],
                onChanged: (value) {
                  if (value != null) controller.setCurrency(value);
                },
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.l10n.categories),
                trailing: IconButton(
                  onPressed: _editCategory,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                children: [
                  FutureBuilder<List<Category>>(
                    future: _categories,
                    builder: (context, snapshot) => Column(
                      children: [
                        for (final category
                            in snapshot.data ?? const <Category>[])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(category.nameEn),
                            subtitle: Text(category.nameBn),
                            onTap: () => _editCategory(category),
                            trailing: category.isDefault
                                ? const Icon(Icons.lock_outline, size: 18)
                                : IconButton(
                                    onPressed: () async {
                                      await ref
                                          .read(settingsRepositoryProvider)
                                          .deleteCategory(category);
                                      setState(_reloadCategories);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Card(
              color: AppTheme.mint,
              child: ListTile(
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.leaf,
                ),
                title: Text(context.l10n.privacyTitle),
                subtitle: Text(context.l10n.privacyDescription),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.about),
              isThreeLine: true,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appMetadata.when(
                      data: (metadata) =>
                          '${context.l10n.version} ${metadata.displayVersion}',
                      loading: () => '${context.l10n.version}…',
                      error: (error, stackTrace) =>
                          context.l10n.versionUnavailable,
                    ),
                  ),
                  SelectableText(
                    '${context.l10n.releasesAndUpdates}: '
                    '$rosidLatestReleaseUrl',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _deleteAllBusy ? null : _deleteAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(context.l10n.deleteAllData),
            ),
          ],
        ),
      ),
    );
  }
}
