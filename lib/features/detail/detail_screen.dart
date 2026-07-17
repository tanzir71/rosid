import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/utils/money.dart';
import 'package:rosid/core/utils/share_origin.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/features/history/record_view_cache.dart';
import 'package:rosid/features/export/document_pdf_service.dart';
import 'package:rosid/features/export/temporary_export.dart';
import 'package:share_plus/share_plus.dart';

class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({required this.scanId, super.key});

  final String scanId;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  late Future<ScanDetail?> _detail;
  bool _deleteBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detail = ref.read(historyRepositoryProvider).detail(widget.scanId);
  }

  Future<void> _share(ScanDetail detail) async {
    final paths = detail.pages.map(
      (page) => page.processedPath ?? page.imagePath,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: paths.map(XFile.new).toList(),
        subject: detail.entry.title,
        sharePositionOrigin: shareOriginFor(context),
      ),
    );
  }

  Future<void> _sharePdf(ScanDetail detail) async {
    final shareOrigin = shareOriginFor(context);
    await withTemporaryExport<void>(
      fileStore: ref.read(privateFileStoreProvider),
      create: () => ref.read(documentPdfServiceProvider).create(detail),
      use: (path) async {
        if (!mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'application/pdf')],
            subject: detail.entry.title,
            sharePositionOrigin: shareOrigin,
          ),
        );
      },
    );
  }

  Future<void> _delete(ScanDetail detail) async {
    if (_deleteBusy) return;
    final historyRepository = ref.read(historyRepositoryProvider);
    final fileStore = ref.read(privateFileStoreProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.delete),
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
    if (mounted) setState(() => _deleteBusy = true);
    try {
      final paths = await historyRepository.delete(widget.scanId);
      await fileStore.deleteRecordArtifacts(
        scanId: widget.scanId,
        knownPaths: paths,
      );
      if (!mounted) return;
      invalidateRecordViews(ref);
      setState(() => _deleteBusy = false);
      context.pop();
    } on Object {
      if (mounted) setState(() => _deleteBusy = false);
      rethrow;
    }
  }

  Future<void> _edit() async {
    final changed = await context.push<bool>('/detail/${widget.scanId}/edit');
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    return FutureBuilder<ScanDetail?>(
      future: _detail,
      builder: (context, snapshot) {
        final loadedDetail = snapshot.data;
        final detail =
            !expenseEnabled && (loadedDetail?.entry.isReceipt ?? false)
            ? null
            : loadedDetail;
        return PopScope(
          canPop: !_deleteBusy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(detail?.entry.title ?? context.l10n.document),
              actions: [
                if (detail != null) ...[
                  IconButton(
                    onPressed: _deleteBusy ? null : _edit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: _deleteBusy ? null : () => _share(detail),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  if (detail.entry.document != null)
                    IconButton(
                      onPressed: _deleteBusy ? null : () => _sharePdf(detail),
                      tooltip: context.l10n.exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  IconButton(
                    onPressed: _deleteBusy ? null : () => _delete(detail),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            body: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : detail == null
                ? Center(child: Text(context.l10n.noResults))
                : _DetailBody(
                    detail: detail,
                    onPin: detail.entry.document == null
                        ? null
                        : () async {
                            await ref
                                .read(historyRepositoryProvider)
                                .setPinned(
                                  widget.scanId,
                                  !detail.entry.document!.pinned,
                                );
                            invalidateRecordViews(ref);
                            setState(_reload);
                          },
                  ),
          ),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onPin});

  final ScanDetail detail;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    final receipt = detail.entry.receipt;
    final document = detail.entry.document;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (detail.pages.isNotEmpty)
          SizedBox(
            height: 340,
            child: PageView(
              children: [
                for (final page in detail.pages)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                      child: Image.file(
                        File(page.processedPath ?? page.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (receipt != null) ...[
          _ValueRow(label: context.l10n.merchant, value: receipt.merchant),
          _ValueRow(
            label: context.l10n.purchaseDate,
            value: DateFormat.yMMMd(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(receipt.dateOfPurchase),
          ),
          _ValueRow(
            label: context.l10n.total,
            value: formatMoney(receipt.total, receipt.currency),
          ),
          if (receipt.tax != null)
            _ValueRow(
              label: context.l10n.tax,
              value: formatMoney(receipt.tax!, receipt.currency),
            ),
          for (final item in detail.lineItems)
            _ValueRow(
              label: '${item.name} × ${item.qty}',
              value: formatMoney(item.amount, receipt.currency),
            ),
        ],
        if (document != null) ...[
          ListTile(
            title: Text(document.title),
            subtitle: SelectableText(document.body),
            trailing: IconButton(
              onPressed: onPin,
              icon: Icon(
                document.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
          ),
          if (detail.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final tag in detail.tags) Chip(label: Text(tag.name)),
              ],
            ),
        ],
        ExpansionTile(
          title: Text(context.l10n.rawOcrText),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(detail.entry.scan.ocrRawText),
            ),
          ],
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(label), trailing: Text(value));
  }
}
