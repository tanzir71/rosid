import 'dart:typed_data';

enum ExportFileType {
  pdf('pdf', 'application/pdf', '.pdf'),
  docx(
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.docx',
  ),
  txt('txt', 'text/plain', '.txt'),
  jpg('jpg', 'image/jpeg', '.jpg'),
  csv('csv', 'text/csv', '.csv');

  const ExportFileType(this.code, this.mimeType, this.extension);

  final String code;
  final String mimeType;
  final String extension;
}

enum ExportPageSize {
  a4('a4'),
  letter('letter'),
  asScanned('as_scanned');

  const ExportPageSize(this.code);
  final String code;
}

enum CoverStyle { blackBar, blur }

/// A normalized rectangle `[0..1]` on a specific scan page to redact
/// destructively in exported copies only.
class CoverRegion {
  const CoverRegion({
    required this.pageIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.style = CoverStyle.blackBar,
  });

  final int pageIndex;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final CoverStyle style;

  double get width => (right - left).clamp(0.0, 1.0);
  double get height => (bottom - top).clamp(0.0, 1.0);
}

class PaperExportConfig {
  const PaperExportConfig({
    this.includeScan = true,
    this.includeEnglish = true,
    this.includeBangla = false,
    this.fileType = ExportFileType.pdf,
    this.pageSize = ExportPageSize.a4,
    this.maxSizeBytes,
    this.watermarkEnabled = false,
    this.watermarkText = 'For visa application only',
    this.watermarkDateText = '',
    this.includeTranslatorPage = false,
    this.blackAndWhite = false,
    this.coverRegions = const [],
  });

  final bool includeScan;
  final bool includeEnglish;
  final bool includeBangla;
  final ExportFileType fileType;
  final ExportPageSize pageSize;

  /// Optional maximum output file size in bytes (e.g. `2 * 1024 * 1024` for 2 MB).
  final int? maxSizeBytes;
  final bool watermarkEnabled;
  final String watermarkText;
  final String watermarkDateText;
  final bool includeTranslatorPage;
  final bool blackAndWhite;
  final List<CoverRegion> coverRegions;

  String get fullWatermarkLine {
    final text = watermarkText.trim();
    final date = watermarkDateText.trim();
    if (text.isEmpty && date.isEmpty) return '';
    if (date.isEmpty) return text;
    if (text.isEmpty) return date;
    return '$text, $date';
  }

  PaperExportConfig copyWith({
    bool? includeScan,
    bool? includeEnglish,
    bool? includeBangla,
    ExportFileType? fileType,
    ExportPageSize? pageSize,
    int? maxSizeBytes,
    bool clearMaxSize = false,
    bool? watermarkEnabled,
    String? watermarkText,
    String? watermarkDateText,
    bool? includeTranslatorPage,
    bool? blackAndWhite,
    List<CoverRegion>? coverRegions,
  }) {
    return PaperExportConfig(
      includeScan: includeScan ?? this.includeScan,
      includeEnglish: includeEnglish ?? this.includeEnglish,
      includeBangla: includeBangla ?? this.includeBangla,
      fileType: fileType ?? this.fileType,
      pageSize: pageSize ?? this.pageSize,
      maxSizeBytes: clearMaxSize ? null : (maxSizeBytes ?? this.maxSizeBytes),
      watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
      watermarkText: watermarkText ?? this.watermarkText,
      watermarkDateText: watermarkDateText ?? this.watermarkDateText,
      includeTranslatorPage:
          includeTranslatorPage ?? this.includeTranslatorPage,
      blackAndWhite: blackAndWhite ?? this.blackAndWhite,
      coverRegions: coverRegions ?? this.coverRegions,
    );
  }
}

class BuiltExportBytes {
  const BuiltExportBytes({
    required this.bytes,
    required this.pageCount,
    required this.exceededSizeLimit,
    this.extraPages = const [],
  });

  final Uint8List bytes;
  final int pageCount;
  final bool exceededSizeLimit;
  final List<Uint8List> extraPages;
}

class PaperExportResult {
  const PaperExportResult({
    required this.tempFilePath,
    required this.fileName,
    required this.mimeType,
    required this.pageCount,
    required this.sizeBytes,
    required this.exceededSizeLimit,
    this.extraFilePaths = const [],
    this.savedDisplayLocation,
  });

  final String tempFilePath;
  final String fileName;
  final String mimeType;
  final int pageCount;
  final int sizeBytes;
  final bool exceededSizeLimit;
  final List<String> extraFilePaths;
  final String? savedDisplayLocation;
}
