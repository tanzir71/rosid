import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:uuid/uuid.dart';

enum CaptureLanguageHint { automatic, banglaEnglish, english }

class CaptureSession {
  const CaptureSession({
    required this.mode,
    required this.languageHint,
    this.scanId,
    this.pagePaths = const [],
    this.isBusy = false,
    this.errorMessage,
  });

  final ScanMode mode;
  final CaptureLanguageHint languageHint;
  final String? scanId;
  final List<String> pagePaths;
  final bool isBusy;
  final String? errorMessage;

  CaptureSession copyWith({
    ScanMode? mode,
    CaptureLanguageHint? languageHint,
    String? scanId,
    List<String>? pagePaths,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CaptureSession(
      mode: mode ?? this.mode,
      languageHint: languageHint ?? this.languageHint,
      scanId: scanId ?? this.scanId,
      pagePaths: pagePaths ?? this.pagePaths,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CaptureSessionController extends Notifier<CaptureSession> {
  @override
  CaptureSession build() {
    final profile = ref.watch(appProfileProvider);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    return CaptureSession(
      mode: expenseEnabled ? profile.defaultScanMode : ScanMode.document,
      languageHint: CaptureLanguageHint.automatic,
    );
  }

  void startNew() {
    if (state.pagePaths.isNotEmpty) return;
    final profile = ref.read(appProfileProvider);
    final expenseEnabled = ref.read(expenseTrackingEnabledProvider);
    state = CaptureSession(
      mode: expenseEnabled ? profile.defaultScanMode : ScanMode.document,
      languageHint: CaptureLanguageHint.automatic,
    );
  }

  void setMode(ScanMode mode) {
    if (state.pagePaths.isNotEmpty ||
        !ref.read(expenseTrackingEnabledProvider)) {
      return;
    }
    state = state.copyWith(mode: mode, clearError: true);
  }

  void setLanguageHint(CaptureLanguageHint hint) {
    state = state.copyWith(languageHint: hint, clearError: true);
  }

  Future<bool> addSourcePath(String sourcePath) async {
    if (state.isBusy) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      const uuid = Uuid();
      final scanId = state.scanId ?? uuid.v7();
      final pageIndex = state.pagePaths.length;
      final persistedPath = await ref
          .read(privateFileStoreProvider)
          .persistCapture(
            sourcePath: sourcePath,
            scanId: scanId,
            pageIndex: pageIndex,
          );
      final repository = ref.read(scanRepositoryProvider);
      if (state.scanId == null) {
        await repository.createScan(
          id: scanId,
          mode: state.mode,
          imagePath: persistedPath,
          langHint: state.languageHint.name,
          createdAt: DateTime.now(),
        );
      } else {
        await repository.addPage(
          id: uuid.v7(),
          scanId: scanId,
          imagePath: persistedPath,
          pageIndex: pageIndex,
        );
      }
      state = state.copyWith(
        scanId: scanId,
        pagePaths: [...state.pagePaths, persistedPath],
        isBusy: false,
        clearError: true,
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<void> discard() async {
    final current = state;
    if (current.scanId != null) {
      await ref.read(scanRepositoryProvider).deleteScan(current.scanId!);
    }
    for (final page in current.pagePaths) {
      await ref.read(privateFileStoreProvider).deleteIfPresent(page);
    }
    state = CaptureSession(
      mode: current.mode,
      languageHint: current.languageHint,
    );
  }

  void clearAfterSave() {
    final profile = ref.read(appProfileProvider);
    final expenseEnabled = ref.read(expenseTrackingEnabledProvider);
    state = CaptureSession(
      mode: expenseEnabled ? profile.defaultScanMode : ScanMode.document,
      languageHint: CaptureLanguageHint.automatic,
    );
  }
}

final captureSessionProvider =
    NotifierProvider<CaptureSessionController, CaptureSession>(
      CaptureSessionController.new,
    );
