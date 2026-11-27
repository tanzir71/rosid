import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Salted slow key-derivation hasher (Argon2id) for the fallback App lock PIN.
/// Never stores plaintext PINs.
class PinHasher {
  const PinHasher({
    this.memoryKiB = 8192,
    this.iterations = 2,
    this.parallelism = 1,
    this.hashLength = 32,
  });

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;

  static final Random _secureRandom = Random.secure();

  Future<String> hashPin(String pin) async {
    final salt = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final derived = await _derive(
      pin,
      salt: salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
    return 'argon2id\$$memoryKiB\$$iterations\$$parallelism\$'
        '${base64Url.encode(salt)}\$${base64Url.encode(derived)}';
  }

  Future<bool> verifyPin(String pin, String encodedHash) async {
    final parts = encodedHash.split(r'$');
    if (parts.length != 6 || parts[0] != 'argon2id') return false;
    final mem = int.tryParse(parts[1]);
    final iter = int.tryParse(parts[2]);
    final par = int.tryParse(parts[3]);
    if (mem == null || iter == null || par == null) return false;
    final salt = base64Url.decode(parts[4]);
    final expected = base64Url.decode(parts[5]);
    final actual = await _derive(
      pin,
      salt: salt,
      memoryKiB: mem,
      iterations: iter,
      parallelism: par,
      hashLength: expected.length,
    );
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  Future<List<int>> _derive(
    String pin, {
    required List<int> salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
    required int hashLength,
  }) async {
    final algo = Argon2id(
      memory: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
    final key = await algo.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }
}

/// Abstracts biometric authentication so widget tests can exercise the
/// fingerprint path with a fake authenticator per M8 fallback rules.
abstract class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate({required String reason});
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      return false;
    }
  }
}

/// Toggles Android `WindowManager.LayoutParams.FLAG_SECURE` ONLY while locked
/// so recent-apps hides private papers when locked while unlocked screenshots
/// still work.
class PlatformSecurityService {
  static const MethodChannel _channel = MethodChannel(
    'app.rosid.rosid/security',
  );

  Future<void> setSecure(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setSecure', {'enabled': enabled});
    } on Object {
      // No-op on host tests / unsupported platforms.
    }
  }
}

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.hasPin,
    required this.isLocked,
    this.backgroundedAt,
  });

  final bool enabled;
  final bool hasPin;
  final bool isLocked;
  final DateTime? backgroundedAt;

  AppLockState copyWith({
    bool? enabled,
    bool? hasPin,
    bool? isLocked,
    DateTime? backgroundedAt,
    bool clearBackgroundedAt = false,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      hasPin: hasPin ?? this.hasPin,
      isLocked: isLocked ?? this.isLocked,
      backgroundedAt: clearBackgroundedAt
          ? null
          : backgroundedAt ?? this.backgroundedAt,
    );
  }
}

final pinHasherProvider = Provider<PinHasher>((ref) => const PinHasher());

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometricAuthenticator(),
);

final platformSecurityServiceProvider = Provider<PlatformSecurityService>(
  (ref) => PlatformSecurityService(),
);

final appLockTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);

class AppLockController extends Notifier<AppLockState> {
  static const pinHashKey = 'app_lock_pin_hash';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  PinHasher get _hasher => ref.read(pinHasherProvider);
  PlatformSecurityService get _security =>
      ref.read(platformSecurityServiceProvider);
  BiometricAuthenticator get _biometric =>
      ref.read(biometricAuthenticatorProvider);

  @override
  AppLockState build() {
    final settings = ref.read(appSettingsProvider);
    final hash = _prefs.getString(pinHashKey);
    final hasPin = hash != null && hash.isNotEmpty;
    final shouldLockOnStart = settings.appLockEnabled && hasPin;
    _security.setSecure(shouldLockOnStart);
    return AppLockState(
      enabled: settings.appLockEnabled && hasPin,
      hasPin: hasPin,
      isLocked: shouldLockOnStart,
    );
  }

  Future<void> enableWithPin(String pin) async {
    final hash = await _hasher.hashPin(pin);
    await _prefs.setString(pinHashKey, hash);
    await ref.read(appSettingsProvider.notifier).setAppLockEnabled(true);
    state = const AppLockState(enabled: true, hasPin: true, isLocked: false);
    await _security.setSecure(false);
  }

  Future<void> changePin(String newPin) async {
    final hash = await _hasher.hashPin(newPin);
    await _prefs.setString(pinHashKey, hash);
    state = state.copyWith(hasPin: true);
  }

  Future<void> disable() async {
    await ref.read(appSettingsProvider.notifier).setAppLockEnabled(false);
    await _prefs.remove(pinHashKey);
    state = const AppLockState(enabled: false, hasPin: false, isLocked: false);
    await _security.setSecure(false);
  }

  Future<void> lockNow() async {
    if (!state.enabled || !state.hasPin) return;
    state = state.copyWith(isLocked: true, clearBackgroundedAt: true);
    await _security.setSecure(true);
  }

  void onAppBackgrounded([DateTime? now]) {
    if (!state.enabled || !state.hasPin) return;
    state = state.copyWith(backgroundedAt: now ?? DateTime.now());
  }

  Future<void> onAppResumed([DateTime? now]) async {
    if (!state.enabled || !state.hasPin) return;
    final bgAt = state.backgroundedAt;
    if (bgAt == null) return;
    final elapsed = (now ?? DateTime.now()).difference(bgAt);
    final timeout = ref.read(appLockTimeoutProvider);
    if (elapsed >= timeout) {
      await lockNow();
    } else {
      state = state.copyWith(clearBackgroundedAt: true);
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final stored = _prefs.getString(pinHashKey);
    if (stored == null || stored.isEmpty) return false;
    final ok = await _hasher.verifyPin(pin, stored);
    if (ok) {
      state = state.copyWith(isLocked: false, clearBackgroundedAt: true);
      await _security.setSecure(false);
    }
    return ok;
  }

  Future<bool> unlockWithBiometrics({required String reason}) async {
    if (!state.enabled) return true;
    final ok = await _biometric.authenticate(reason: reason);
    if (ok) {
      state = state.copyWith(isLocked: false, clearBackgroundedAt: true);
      await _security.setSecure(false);
    }
    return ok;
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
