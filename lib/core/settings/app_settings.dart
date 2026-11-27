import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The six purposes offered during First run / Settings.
enum RosidPurpose {
  visa('visa'),
  land('land'),
  receipts('receipts'),
  study('study'),
  office('office'),
  family('family');

  const RosidPurpose(this.id);

  final String id;

  static RosidPurpose? byId(String value) {
    for (final item in values) {
      if (item.id == value) return item;
    }
    return null;
  }
}

class AppSettings {
  const AppSettings({
    required this.languageCode,
    required this.expenseTrackingEnabled,
    required this.currency,
    this.onboardingComplete = false,
    this.purposes = const {
      RosidPurpose.visa,
      RosidPurpose.land,
      RosidPurpose.family,
    },
    this.appLockEnabled = false,
    this.backupReminderEnabled = true,
    this.termDefaultForm = 'both',
    this.themeMode = ThemeMode.system,
    this.lastBackupAt,
    this.lastBackupPaperCount = 0,
  });

  final String languageCode;
  final bool expenseTrackingEnabled;
  final String currency;
  final bool onboardingComplete;
  final Set<RosidPurpose> purposes;
  final bool appLockEnabled;
  final bool backupReminderEnabled;
  final String termDefaultForm;
  final ThemeMode themeMode;
  final DateTime? lastBackupAt;
  final int lastBackupPaperCount;

  Locale get locale => Locale(languageCode);

  AppSettings copyWith({
    String? languageCode,
    bool? expenseTrackingEnabled,
    String? currency,
    bool? onboardingComplete,
    Set<RosidPurpose>? purposes,
    bool? appLockEnabled,
    bool? backupReminderEnabled,
    String? termDefaultForm,
    ThemeMode? themeMode,
    DateTime? lastBackupAt,
    int? lastBackupPaperCount,
    bool clearLastBackup = false,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      expenseTrackingEnabled:
          expenseTrackingEnabled ?? this.expenseTrackingEnabled,
      currency: currency ?? this.currency,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      purposes: purposes ?? this.purposes,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      backupReminderEnabled:
          backupReminderEnabled ?? this.backupReminderEnabled,
      termDefaultForm: termDefaultForm ?? this.termDefaultForm,
      themeMode: themeMode ?? this.themeMode,
      lastBackupAt: clearLastBackup ? null : lastBackupAt ?? this.lastBackupAt,
      lastBackupPaperCount: clearLastBackup
          ? 0
          : lastBackupPaperCount ?? this.lastBackupPaperCount,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'SharedPreferences must be initialized before Rosid starts.',
  );
});

/// Retained for legacy compatibility where platform facts are queried; home
/// screen behaviour is now governed by [AppSettings.purposes] and
/// [AppSettings.expenseTrackingEnabled].
final appProfileProvider = Provider<AppProfile>((ref) => AppProfile.resolve());

class AppSettingsController extends Notifier<AppSettings> {
  static const _languageKey = 'language_code';
  static const _expenseKey = 'expense_tracking_enabled';
  static const _currencyKey = 'currency';
  static const _onboardingKey = 'onboarding_complete';
  static const _purposesKey = 'user_purposes';
  static const _appLockKey = 'app_lock_enabled';
  static const _backupReminderKey = 'backup_reminder_enabled';
  static const _termDefaultKey = 'term_default_form';
  static const _themeModeKey = 'theme_mode';
  static const _lastBackupKey = 'last_backup_at';
  static const _lastBackupCountKey = 'last_backup_paper_count';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final storedPurposes = _preferences.getStringList(_purposesKey);
    final purposes = storedPurposes == null
        ? const {RosidPurpose.visa, RosidPurpose.land, RosidPurpose.family}
        : storedPurposes
              .map(RosidPurpose.byId)
              .whereType<RosidPurpose>()
              .toSet();
    final expenseDefault = purposes.contains(RosidPurpose.receipts);
    final lastBackupMs = _preferences.getInt(_lastBackupKey);
    return AppSettings(
      languageCode: _preferences.getString(_languageKey) ?? 'bn',
      expenseTrackingEnabled:
          _preferences.getBool(_expenseKey) ?? expenseDefault,
      currency: _preferences.getString(_currencyKey) ?? 'BDT',
      onboardingComplete: _preferences.getBool(_onboardingKey) ?? false,
      purposes: purposes,
      appLockEnabled: _preferences.getBool(_appLockKey) ?? false,
      backupReminderEnabled: _preferences.getBool(_backupReminderKey) ?? true,
      termDefaultForm: _preferences.getString(_termDefaultKey) ?? 'both',
      themeMode: _parseThemeMode(_preferences.getString(_themeModeKey)),
      lastBackupAt: lastBackupMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastBackupMs),
      lastBackupPaperCount: _preferences.getInt(_lastBackupCountKey) ?? 0,
    );
  }

  static ThemeMode _parseThemeMode(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setLanguage(String languageCode) async {
    state = state.copyWith(languageCode: languageCode);
    await _preferences.setString(_languageKey, languageCode);
  }

  Future<void> setPurposes(Set<RosidPurpose> purposes) async {
    final receiptsOn = purposes.contains(RosidPurpose.receipts);
    state = state.copyWith(
      purposes: Set<RosidPurpose>.unmodifiable(purposes),
      expenseTrackingEnabled: receiptsOn,
    );
    await _preferences.setStringList(
      _purposesKey,
      purposes.map((p) => p.id).toList(),
    );
    await _preferences.setBool(_expenseKey, receiptsOn);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _preferences.setBool(_onboardingKey, true);
  }

  Future<void> setExpenseTracking(bool enabled) async {
    state = state.copyWith(expenseTrackingEnabled: enabled);
    await _preferences.setBool(_expenseKey, enabled);
  }

  Future<void> setCurrency(String currency) async {
    state = state.copyWith(currency: currency);
    await _preferences.setString(_currencyKey, currency);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    state = state.copyWith(appLockEnabled: enabled);
    await _preferences.setBool(_appLockKey, enabled);
  }

  Future<void> setBackupReminderEnabled(bool enabled) async {
    state = state.copyWith(backupReminderEnabled: enabled);
    await _preferences.setBool(_backupReminderKey, enabled);
  }

  Future<void> setTermDefaultForm(String form) async {
    state = state.copyWith(termDefaultForm: form);
    await _preferences.setString(_termDefaultKey, form);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _preferences.setString(_themeModeKey, mode.name);
  }

  Future<void> recordBackup(DateTime timestamp, {int paperCount = 0}) async {
    state = state.copyWith(
      lastBackupAt: timestamp,
      lastBackupPaperCount: paperCount,
    );
    await _preferences.setInt(_lastBackupKey, timestamp.millisecondsSinceEpoch);
    await _preferences.setInt(_lastBackupCountKey, paperCount);
  }

  Future<void> clearBackupHistory() async {
    state = state.copyWith(clearLastBackup: true);
    await _preferences.remove(_lastBackupKey);
    await _preferences.remove(_lastBackupCountKey);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

final expenseTrackingEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appSettingsProvider).expenseTrackingEnabled,
);
