import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';
import 'package:rosid/features/history/history_state.dart';
import 'package:rosid/features/library/library_screen.dart';
import 'package:rosid/safety/backup_service.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Optional test hooks so Flow 10 E2E can pass deterministic backup paths
/// without opening the external Android SAF DocumentsUI picker.
class BackupIoHooks {
  const BackupIoHooks({this.saveOverride, this.pickOverride});

  final Future<String?> Function(String tempBackupPath, String suggestedName)?
  saveOverride;
  final Future<String?> Function()? pickOverride;
}

final backupIoHooksProvider = Provider<BackupIoHooks>(
  (ref) => const BackupIoHooks(),
);

final totalPaperCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final scans = await db.select(db.scans).get();
  return scans.length;
});

/// Back up and move screen (`/settings/backup`) matching
/// `design/screens/settings-backup.png`.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({
    this.previewLastBackupAt,
    this.previewBackedUpCount,
    this.previewNotBackedUpCount,
    super.key,
  });

  @visibleForTesting
  final DateTime? previewLastBackupAt;

  @visibleForTesting
  final int? previewBackedUpCount;

  @visibleForTesting
  final int? previewNotBackedUpCount;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _makeBackup() async {
    if (_busy) return;
    final password = await _showPasswordSheet(context, requireConfirm: true);
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final db = ref.read(databaseProvider);
      final fileStore = ref.read(privateFileStoreProvider);
      final backupSvc = ref.read(backupServiceProvider);
      final slug = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'Rosid-Backup-$slug.rosidbackup';
      final tempPath = await fileStore.createExportPath(fileName);

      final result = await backupSvc.createBackup(
        db: db,
        password: password,
        outputFilePath: tempPath,
        appDocsDir: fileStore.rootDirectory,
      );

      final hooks = ref.read(backupIoHooksProvider);
      bool saved;
      if (hooks.saveOverride != null) {
        final dest = await hooks.saveOverride!(
          result.filePath,
          result.fileName,
        );
        saved = dest != null && dest.isNotEmpty;
      } else {
        final res = await ref
            .read(platformFileServiceProvider)
            .saveFileToPhone(
              sourcePath: result.filePath,
              suggestedName: result.fileName,
              mimeType: 'application/octet-stream',
            );
        saved = res.saved;
      }
      await fileStore.deleteExportIfPresent(result.filePath);

      if (saved) {
        await ref
            .read(appSettingsProvider.notifier)
            .recordBackup(
              result.createdAt.toLocal(),
              paperCount: result.paperCount,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.backupCreated)));
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    final hooks = ref.read(backupIoHooksProvider);
    final pickedPath = hooks.pickOverride != null
        ? await hooks.pickOverride!()
        : await ref.read(platformFileServiceProvider).pickFile();
    if (pickedPath == null || pickedPath.isEmpty || !mounted) return;

    final password = await _showPasswordSheet(context, requireConfirm: false);
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final fileStore = ref.read(privateFileStoreProvider);
      final targetDocs =
          fileStore.rootDirectory ?? await getApplicationDocumentsDirectory();
      final dbPath = await BackupService.defaultDatabasePath();
      final liveDb = ref.read(databaseProvider);

      final res = await ref
          .read(backupServiceProvider)
          .restoreBackup(
            backupFilePath: pickedPath,
            password: password,
            targetDatabasePath: dbPath,
            targetAppDocsDir: targetDocs,
            closeLiveDatabase: () async => liveDb.close(),
            reopenLiveDatabase: () async {
              ref.read(databaseEpochProvider.notifier).bump();
            },
          );

      await ref
          .read(appSettingsProvider.notifier)
          .recordBackup(
            res.backupCreatedAt?.toLocal() ?? DateTime.now(),
            paperCount: res.paperCount,
          );
      ref
        ..invalidate(totalPaperCountProvider)
        ..invalidate(libraryPapersProvider)
        ..invalidate(allBundlesProvider)
        ..invalidate(monthlyExpensesProvider)
        ..invalidate(historyResultsProvider)
        ..invalidate(dashboardSummaryProvider)
        ..invalidate(namesBookProvider)
        ..invalidate(storageUsedBytesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
    } on BackupWrongPasswordException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupWrongPassword)));
    } on BackupFormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupDamagedFile)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final settings = ref.watch(appSettingsProvider);
    final totalPapersAsync = ref.watch(totalPaperCountProvider);
    final totalPapers = totalPapersAsync.asData?.value ?? 0;

    final lastBackupAt = widget.previewLastBackupAt ?? settings.lastBackupAt;
    final backedUpCount =
        widget.previewBackedUpCount ?? settings.lastBackupPaperCount;
    final notBackedUpCount =
        widget.previewNotBackedUpCount ??
        (lastBackupAt == null
            ? totalPapers
            : (totalPapers - backedUpCount).clamp(0, totalPapers));

    final lastBackupText = lastBackupAt == null
        ? l10n.lastBackupNever
        : localizeDigits(
            l10n.lastBackupSummary(
              DateFormat(
                'd MMM y',
                locale.toLanguageTag(),
              ).format(lastBackupAt),
              backedUpCount,
            ),
            locale,
          );

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: l10n.backUpAndMove, showBack: true),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  l10n.backupHeroTitle,
                  style: RosidTextTokens.uiTitle.copyWith(
                    color: c.inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.backupHeroBody,
                  style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.bgSheet,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.lineSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.lastBackupLabel,
                            style: RosidTextTokens.uiCaption.copyWith(
                              color: c.inkSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            lastBackupText,
                            style: RosidTextTokens.uiBodyStrong.copyWith(
                              color: c.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          RosidIcon(
                            notBackedUpCount > 0
                                ? RosidIcons.alert
                                : RosidIcons.checkCircle,
                            size: 18,
                            color: notBackedUpCount > 0
                                ? c.warnBase
                                : c.goodBase,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notBackedUpCount > 0
                                  ? localizeDigits(
                                      l10n.papersNotBackedUp(notBackedUpCount),
                                      locale,
                                    )
                                  : l10n.allPapersBackedUp,
                              style: RosidTextTokens.uiBody.copyWith(
                                color: c.inkPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.remindMeEveryMonth,
                        style: RosidTextTokens.uiBody.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                    ),
                    RosidToggle(
                      key: const ValueKey('backup-reminder-toggle'),
                      value: settings.backupReminderEnabled,
                      semanticLabel: l10n.remindMeEveryMonth,
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setBackupReminderEnabled(v),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: c.lineSubtle, height: 1),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: RosidIcon(
                        RosidIcons.lock,
                        size: 18,
                        color: c.inkSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.backupPasswordWarning,
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RosidButton(
                    key: const ValueKey('backup-make-btn'),
                    label: l10n.makeBackupFile,
                    icon: RosidIcons.backup,
                    expand: true,
                    onPressed: _busy ? null : _makeBackup,
                  ),
                  const SizedBox(height: 10),
                  RosidButton(
                    key: const ValueKey('backup-restore-btn'),
                    label: l10n.bringFromBackupFile,
                    icon: RosidIcons.phone,
                    kind: RosidButtonKind.outline,
                    expand: true,
                    onPressed: _busy ? null : _restoreBackup,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showPasswordSheet(
  BuildContext context, {
  required bool requireConfirm,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _BackupPasswordSheet(requireConfirm: requireConfirm),
  );
}

class _BackupPasswordSheet extends StatefulWidget {
  const _BackupPasswordSheet({required this.requireConfirm});

  final bool requireConfirm;

  @override
  State<_BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<_BackupPasswordSheet> {
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final p1 = _pass1.text;
    if (p1.length < 4) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    if (widget.requireConfirm && p1 != _pass2.text) {
      setState(() => _error = l10n.passwordsDoNotMatch);
      return;
    }
    Navigator.of(context).pop(p1);
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.requireConfirm
                  ? l10n.chooseBackupPassword
                  : l10n.enterBackupPassword,
              style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('backup-password-input'),
              controller: _pass1,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.passwordLabel),
              onSubmitted: (_) {
                if (!widget.requireConfirm) _submit();
              },
            ),
            if (widget.requireConfirm) ...[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('backup-password-confirm'),
                controller: _pass2,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmPasswordLabel,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: RosidTextTokens.uiCaption.copyWith(color: c.badBase),
              ),
            ],
            const SizedBox(height: 16),
            RosidButton(
              key: const ValueKey('backup-password-submit'),
              label: l10n.continueLabel,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to read a file length safely when formatting storage usage.
String formatStorageSize(int bytes) {
  if (bytes < 1024 * 1024) {
    final kb = (bytes / 1024).ceil().clamp(0, 999999);
    return '$kb KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Ensures backup files picked from cache are cleaned up safely if needed.
Future<void> deleteTempPickedFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } on Object {
    // Ignore cleanup errors.
  }
}
