import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/confidence_field.dart';
import 'package:rosid/features/review/document_review_controller.dart';
import 'package:rosid/features/review/review_cleanup.dart';

class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({super.key});

  @override
  ConsumerState<DocumentReviewScreen> createState() =>
      _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends ConsumerState<DocumentReviewScreen> {
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final localizations = context.l10n;
    Future.microtask(() {
      ref
          .read(documentReviewProvider.notifier)
          .initialize(
            session: ref.read(captureSessionProvider),
            assets: ref.read(preprocessProvider).assets,
            localizations: localizations,
          );
    });
  }

  Future<void> _save() async {
    final saved = await ref
        .read(documentReviewProvider.notifier)
        .save(localizations: context.l10n);
    if (!mounted || !saved) return;
    clearCompletedReview(ref);
    context.go('/');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentReviewProvider);
    final assets = ref.watch(preprocessProvider).assets;
    return PopScope<void>(
      canPop: !state.isLoading && !state.isSaving,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.reviewDocument)),
        body: state.isLoading
            ? Center(child: Text(context.l10n.processing))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.confidence < 0.6)
                    Card(
                      color: Colors.amber.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.draw_outlined),
                        title: Text(context.l10n.verifyHandwriting),
                      ),
                    ),
                  if (assets.isNotEmpty)
                    SizedBox(
                      height: 260,
                      child: PageView(
                        children: [
                          for (final asset in assets)
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(
                                File(asset.colorPath),
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  ConfidenceField(
                    label: context.l10n.title,
                    initialValue: state.title,
                    confidence: state.confidence,
                    onChanged: ref
                        .read(documentReviewProvider.notifier)
                        .setTitle,
                  ),
                  const SizedBox(height: 12),
                  ConfidenceField(
                    label: context.l10n.body,
                    initialValue: state.body,
                    confidence: state.confidence,
                    maxLines: 12,
                    onChanged: ref
                        .read(documentReviewProvider.notifier)
                        .setBody,
                  ),
                  const SizedBox(height: 12),
                  ConfidenceField(
                    label: context.l10n.tags,
                    initialValue: state.tags,
                    onChanged: ref
                        .read(documentReviewProvider.notifier)
                        .setTags,
                  ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.isSaving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(context.l10n.save),
                  ),
                ],
              ),
      ),
    );
  }
}
