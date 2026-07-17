import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/features/history/history_state.dart';
import 'package:rosid/features/export/document_pdf_service.dart';
import 'package:share_plus/share_plus.dart';

class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({required this.scanId, super.key});

  final String scanId;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  late Future<ScanDetail?> _detail;

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
      ),
    );
  }

  Future<void> _sharePdf(ScanDetail detail) async {
    final path = await ref.read(documentPdfServiceProvider).create(detail);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/pdf')],
        subject: detail.entry.title,
      ),
    );
  }

  Future<void> _delete(ScanDetail detail) async {
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
    final paths = await ref
        .read(historyRepositoryProvider)
        .delete(widget.scanId);
    for (final path in paths) {
      await ref.read(privateFileStoreProvider).deleteIfPresent(path);
      await ref
          .read(privateFileStoreProvider)
          .deleteIfPresent(path.replaceFirst('_color.jpg', '_bw.jpg'));
    }
    ref.invalidate(historyResultsProvider);
    if (mounted) context.pop();
  }

  Future<void> _rename(ScanDetail detail) async {
    final controller = TextEditingController(text: detail.entry.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.edit),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: detail.entry.isReceipt
                ? context.l10n.merchant
                : context.l10n.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await ref.read(historyRepositoryProvider).rename(widget.scanId, value);
    ref.invalidate(historyResultsProvider);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScanDetail?>(
      future: _detail,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(detail?.entry.title ?? context.l10n.document),
            actions: [
              if (detail != null) ...[
                IconButton(
                  onPressed: () => _rename(detail),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _share(detail),
                  icon: const Icon(Icons.share_outlined),
                ),
                if (detail.entry.document != null)
                  IconButton(
                    onPressed: () => _sharePdf(detail),
                    tooltip: context.l10n.exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                IconButton(
                  onPressed: () => _delete(detail),
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
                          setState(_reload);
                        },
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
            value: DateFormat.yMMMd().format(receipt.dateOfPurchase),
          ),
          _ValueRow(
            label: context.l10n.total,
            value: '৳${receipt.total.toStringAsFixed(2)}',
          ),
          if (receipt.tax != null)
            _ValueRow(
              label: context.l10n.tax,
              value: '৳${receipt.tax!.toStringAsFixed(2)}',
            ),
          for (final item in detail.lineItems)
            _ValueRow(
              label: '${item.name} × ${item.qty}',
              value: '৳${item.amount.toStringAsFixed(2)}',
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
