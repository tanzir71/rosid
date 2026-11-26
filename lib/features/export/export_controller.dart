import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/export/export_models.dart';

class PaperExportSessionState {
  const PaperExportSessionState({
    required this.config,
    this.lastResult,
    this.savedUri,
    this.savedLocationLabel,
  });

  final PaperExportConfig config;
  final PaperExportResult? lastResult;
  final String? savedUri;
  final String? savedLocationLabel;

  PaperExportSessionState copyWith({
    PaperExportConfig? config,
    PaperExportResult? lastResult,
    String? savedUri,
    String? savedLocationLabel,
  }) {
    return PaperExportSessionState(
      config: config ?? this.config,
      lastResult: lastResult ?? this.lastResult,
      savedUri: savedUri ?? this.savedUri,
      savedLocationLabel: savedLocationLabel ?? this.savedLocationLabel,
    );
  }
}

class PaperExportController extends Notifier<PaperExportSessionState> {
  @override
  PaperExportSessionState build() {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());
    return PaperExportSessionState(
      config: PaperExportConfig(
        includeScan: true,
        includeEnglish: true,
        includeBangla: false,
        fileType: ExportFileType.pdf,
        pageSize: ExportPageSize.a4,
        maxSizeBytes: 2 * 1024 * 1024,
        watermarkEnabled: false,
        watermarkText: 'For visa application only',
        watermarkDateText: today,
        includeTranslatorPage: true,
      ),
    );
  }

  void updateConfig(PaperExportConfig next) {
    state = state.copyWith(config: next);
  }

  void setCoverRegions(List<CoverRegion> regions) {
    state = state.copyWith(
      config: state.config.copyWith(coverRegions: regions),
    );
  }

  void recordExport({
    required PaperExportResult result,
    String? savedUri,
    String? savedLocationLabel,
  }) {
    state = state.copyWith(
      lastResult: result,
      savedUri: savedUri,
      savedLocationLabel: savedLocationLabel,
    );
  }
}

final paperExportControllerProvider =
    NotifierProvider<PaperExportController, PaperExportSessionState>(
      PaperExportController.new,
    );
