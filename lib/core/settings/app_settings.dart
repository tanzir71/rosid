import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.languageCode,
    required this.expenseTrackingEnabled,
    required this.currency,
  });

  final String languageCode;
  final bool expenseTrackingEnabled;
  final String currency;

  Locale get locale => Locale(languageCode);

  AppSettings copyWith({
    String? languageCode,
    bool? expenseTrackingEnabled,
    String? currency,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      expenseTrackingEnabled:
          expenseTrackingEnabled ?? this.expenseTrackingEnabled,
      currency: currency ?? this.currency,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'SharedPreferences must be initialized before Rosid starts.',
  );
});

final appProfileProvider = Provider<AppProfile>((ref) => AppProfile.resolve());

class AppSettingsController extends Notifier<AppSettings> {
  static const _languageKey = 'language_code';
  static const _expenseKey = 'expense_tracking_enabled';
  static const _currencyKey = 'currency';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final profile = ref.watch(appProfileProvider);
    return AppSettings(
      languageCode: _preferences.getString(_languageKey) ?? 'en',
      expenseTrackingEnabled: profile.expenseTrackingLocked
          ? profile.expenseTrackingDefault
          : _preferences.getBool(_expenseKey) ?? profile.expenseTrackingDefault,
      currency: _preferences.getString(_currencyKey) ?? 'BDT',
    );
  }

  Future<void> setLanguage(String languageCode) async {
    state = state.copyWith(languageCode: languageCode);
    await _preferences.setString(_languageKey, languageCode);
  }

  Future<void> setExpenseTracking(bool enabled) async {
    final profile = ref.read(appProfileProvider);
    if (profile.expenseTrackingLocked) return;
    state = state.copyWith(expenseTrackingEnabled: enabled);
    await _preferences.setBool(_expenseKey, enabled);
  }

  Future<void> setCurrency(String currency) async {
    state = state.copyWith(currency: currency);
    await _preferences.setString(_currencyKey, currency);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

final expenseTrackingEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appSettingsProvider).expenseTrackingEnabled,
);
