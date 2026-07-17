import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/utils/share_origin.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/features/export/export_service.dart';
import 'package:rosid/features/export/temporary_export.dart';
import 'package:share_plus/share_plus.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late DateTime _start;
  late DateTime _end;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month);
    _end = now;
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (range != null) {
      setState(() {
        _start = range.start;
        _end = range.end;
      });
    }
  }

  Future<void> _export() async {
    final shareOrigin = shareOriginFor(context);
    setState(() => _busy = true);
    try {
      await withTemporaryExport<void>(
        fileStore: ref.read(privateFileStoreProvider),
        create: () =>
            ref.read(exportServiceProvider).createExpenseCsv(_start, _end),
        use: (path) async {
          if (!mounted) return;
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'text/csv')],
              subject: 'Rosid expense export',
              sharePositionOrigin: shareOrigin,
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.export)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              onTap: _pickRange,
              leading: const Icon(Icons.date_range),
              title: Text(
                '${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(_start)} – ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(_end)}',
              ),
              subtitle: Text(context.l10n.filter),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.privacyDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(context.l10n.exportCsv),
          ),
        ],
      ),
    );
  }
}
