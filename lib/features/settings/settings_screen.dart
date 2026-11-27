import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/app_metadata.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/data/repositories/settings_repository.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';
import 'package:rosid/features/history/history_state.dart';
import 'package:rosid/features/library/library_screen.dart';
import 'package:rosid/features/safety/backup_screen.dart';
import 'package:rosid/features/safety/lock_screen.dart';
import 'package:rosid/features/translation/term_help_sheet.dart';
import 'package:rosid/safety/app_lock_service.dart';
import 'package:rosid/safety/backup_service.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Settings screen (`design/screens/settings.png`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleteAllBusy = false;

  Future<void> _toggleAppLock(bool enable) async {
    final lockController = ref.read(appLockControllerProvider.notifier);
    if (!enable) {
      await lockController.disable();
      return;
    }
    final pin = await showPinSetupSheet(context);
    if (pin == null || !mounted) return;
    await lockController.enableWithPin(pin);
  }

  Future<void> _changePin() async {
    final pin = await showPinSetupSheet(context);
    if (pin == null || !mounted) return;
    await ref.read(appLockControllerProvider.notifier).changePin(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.saved)));
  }

  Future<void> _deleteAll() async {
    if (_deleteAllBusy) return;
    final l10n = context.l10n;
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final fileStore = ref.read(privateFileStoreProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAllData),
        content: Text(l10n.deleteAllDataDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('settings-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (mounted) setState(() => _deleteAllBusy = true);
    try {
      await settingsRepository.deleteAllData();
      await fileStore.deleteAllAppData();
      await ref.read(appSettingsProvider.notifier).clearBackupHistory();
      if (!mounted) return;
      ref
        ..invalidate(historyResultsProvider)
        ..invalidate(dashboardSummaryProvider)
        ..invalidate(homeDocumentsProvider)
        ..invalidate(libraryPapersProvider)
        ..invalidate(allBundlesProvider)
        ..invalidate(monthlyExpensesProvider)
        ..invalidate(totalPaperCountProvider)
        ..invalidate(namesBookProvider)
        ..invalidate(storageUsedBytesProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.saved)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
    } finally {
      if (mounted) setState(() => _deleteAllBusy = false);
    }
  }

  Future<void> _pickThemeMode() async {
    final l10n = context.l10n;
    final current = ref.read(appSettingsProvider).themeMode;
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) {
        final c = RosidColors.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.themeLabel,
                  style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
                ),
                const SizedBox(height: 12),
                for (final option in [
                  (ThemeMode.system, l10n.themeSystem, 'system'),
                  (ThemeMode.light, l10n.themeLight, 'light'),
                  (ThemeMode.dark, l10n.themeDark, 'dark'),
                ])
                  ListTile(
                    key: ValueKey('theme-option-${option.$3}'),
                    contentPadding: EdgeInsets.zero,
                    leading: RosidRadio(selected: current == option.$1),
                    title: Text(option.$2),
                    onTap: () => Navigator.pop(context, option.$1),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      await ref.read(appSettingsProvider.notifier).setThemeMode(chosen);
    }
  }

  String _purposeSummary(BuildContext context, Set<RosidPurpose> purposes) {
    final l10n = context.l10n;
    if (purposes.isEmpty) return l10n.all;
    final names = <String>[
      if (purposes.contains(RosidPurpose.visa)) l10n.purposeVisaTitle,
      if (purposes.contains(RosidPurpose.land)) l10n.purposeLandTitle,
      if (purposes.contains(RosidPurpose.receipts)) l10n.purposeReceiptsTitle,
      if (purposes.contains(RosidPurpose.study)) l10n.purposeStudyTitle,
      if (purposes.contains(RosidPurpose.office)) l10n.purposeOfficeTitle,
      if (purposes.contains(RosidPurpose.family)) l10n.purposeFamilyTitle,
    ];
    return names.take(3).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final settings = ref.watch(appSettingsProvider);
    final lockState = ref.watch(appLockControllerProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final appMetadata = ref.watch(appMetadataProvider);
    final totalPapers = ref.watch(totalPaperCountProvider).asData?.value ?? 0;
    final storageBytes = ref.watch(storageUsedBytesProvider).asData?.value;

    final isBangla = settings.languageCode == 'bn';
    final themeLabel = switch (settings.themeMode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };

    final notBackedUp = settings.lastBackupAt == null
        ? totalPapers
        : (totalPapers - settings.lastBackupPaperCount).clamp(0, totalPapers);
    final backupSubtitle = settings.lastBackupAt == null
        ? l10n.backUpNeverSub
        : localizeDigits(
            l10n.lastBackupShortSub(
              DateFormat(
                'd MMM',
                locale.toLanguageTag(),
              ).format(settings.lastBackupAt!),
              notBackedUp,
            ),
            locale,
          );

    final storageSubtitle = storageBytes == null
        ? l10n.storageOnDevice
        : localizeDigits(
            l10n.storageUsedMb(formatStorageSize(storageBytes)),
            locale,
          );

    return PopScope(
      canPop: !_deleteAllBusy,
      child: Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.settings, showBack: true),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          children: [
            _GroupHeader(label: l10n.languageAndReading),
            _SettingsRow(
              icon: RosidIcons.translate,
              title: l10n.language,
              subtitle: isBangla ? l10n.bangla : l10n.english,
              trailing: TextButton(
                key: const ValueKey('settings-language-toggle'),
                onPressed: () => controller.setLanguage(isBangla ? 'en' : 'bn'),
                child: Text(
                  isBangla ? l10n.english : l10n.bangla,
                  style: RosidTextTokens.uiLabel.copyWith(
                    color: c.accentBase,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () => controller.setLanguage(isBangla ? 'en' : 'bn'),
            ),
            _SettingsRow(
              icon: RosidIcons.home,
              title: l10n.whatYouUseRosidFor,
              subtitle: _purposeSummary(context, settings.purposes),
              onTap: () => context.push('/settings/purposes'),
            ),
            _SettingsRow(
              icon: RosidIcons.people,
              title: l10n.names,
              subtitle: ref
                  .watch(namesBookProvider)
                  .when(
                    data: (list) {
                      if (list.isEmpty) return l10n.namesEmpty;
                      final people = list
                          .where((n) => n.category != 'place')
                          .length;
                      final places = list
                          .where((n) => n.category == 'place')
                          .length;
                      return localizeDigits(
                        l10n.namesPeoplePlacesCount(people, places),
                        locale,
                      );
                    },
                    loading: () => l10n.namesEmpty,
                    error: (_, _) => l10n.namesEmpty,
                  ),
              onTap: () => context.push('/names'),
            ),
            _SettingsRow(
              icon: RosidIcons.book,
              title: l10n.wordChoices,
              subtitle: l10n.wordChoicesSub,
              onTap: () => showTermsPickerSheet(context, ref),
            ),
            _SettingsRow(
              key: const ValueKey('settings-theme-row'),
              icon: RosidIcons.filter,
              title: l10n.themeLabel,
              subtitle: themeLabel,
              onTap: _pickThemeMode,
            ),
            const SizedBox(height: 16),
            _GroupHeader(label: l10n.safety),
            _SettingsRow(
              icon: RosidIcons.lock,
              title: l10n.appLock,
              subtitle: lockState.enabled
                  ? l10n.appLockEnabledSub
                  : l10n.appLockSub,
              trailing: RosidToggle(
                key: const ValueKey('settings-applock-toggle'),
                value: lockState.enabled,
                semanticLabel: l10n.appLock,
                onChanged: _toggleAppLock,
              ),
            ),
            if (lockState.enabled)
              _SettingsRow(
                key: const ValueKey('settings-change-pin'),
                icon: RosidIcons.lock,
                title: l10n.appLockChangePin,
                subtitle: l10n.appLockPinHint,
                onTap: _changePin,
              ),
            _SettingsRow(
              key: const ValueKey('settings-backup-row'),
              icon: RosidIcons.backup,
              title: l10n.backUpAndMove,
              subtitle: backupSubtitle,
              onTap: () => context.push('/settings/backup'),
            ),
            _SettingsRow(
              icon: RosidIcons.shield,
              title: l10n.worksOffline,
              subtitle: l10n.worksOfflineSub,
              trailing: RosidIcon(
                RosidIcons.check,
                size: 20,
                color: c.goodBase,
              ),
            ),
            const SizedBox(height: 16),
            _GroupHeader(label: l10n.expenses),
            _SettingsRow(
              icon: RosidIcons.wallet,
              title: l10n.expenseTracking,
              subtitle: l10n.expenseTrackingDescription,
              trailing: RosidToggle(
                key: const ValueKey('settings-expenses-toggle'),
                value: settings.expenseTrackingEnabled,
                semanticLabel: l10n.expenseTracking,
                onChanged: controller.setExpenseTracking,
              ),
            ),
            _SettingsRow(
              icon: RosidIcons.tag,
              title: l10n.currency,
              subtitle: l10n.currencyTaka,
            ),
            if (settings.expenseTrackingEnabled)
              _SettingsRow(
                key: const ValueKey('settings-categories-row'),
                icon: RosidIcons.tag,
                title: l10n.categoriesLabel,
                subtitle: l10n.categoriesSub,
                onTap: () => context.push('/settings/categories'),
              ),
            const SizedBox(height: 16),
            _GroupHeader(label: l10n.thisPhone),
            _SettingsRow(
              icon: RosidIcons.file,
              title: l10n.storage,
              subtitle: storageSubtitle,
            ),
            _SettingsRow(
              icon: RosidIcons.info,
              title: l10n.about,
              subtitle: appMetadata.when(
                data: (m) => '${l10n.version} ${m.displayVersion}',
                loading: () => l10n.version,
                error: (_, _) => l10n.versionUnavailable,
              ),
            ),
            _SettingsRow(
              key: const ValueKey('settings-delete-all'),
              icon: RosidIcons.trash,
              title: l10n.deleteAllData,
              subtitle: l10n.deleteAllDataDescription,
              destructive: true,
              onTap: _deleteAllBusy ? null : _deleteAll,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        label,
        style: RosidTextTokens.uiLabel.copyWith(
          color: c.accentBase,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    super.key,
  });

  final RosidIcons icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final titleColor = destructive ? c.badBase : c.inkPrimary;
    final iconColor = destructive ? c.badBase : c.inkSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            RosidIcon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              RosidIcon(
                RosidIcons.chevronRight,
                size: 18,
                color: c.inkTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
