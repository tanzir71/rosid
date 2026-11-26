import 'package:intl/intl.dart';
import 'package:rosid/core/utils/bangla_digits.dart';

/// Standard Bangladeshi land measurement units (`handover/01-product.md`):
/// - 1 decimal (শতাংশ / শতক) = 1/100 acre = 435.6 sq ft (exact)
/// - 1 acre (একর) = 100 decimals = 43,560 sq ft (exact)
/// - 1 katha (কাঠা) = 720 sq ft ≈ 1.65 decimals (standard; regional varies -> "about")
/// - 1 bigha (বিঘা) = 20 katha = 14,400 sq ft ≈ 33 decimals (standard -> "about")
enum LandUnit { decimal, acre, katha, bigha, sqFt }

/// Converted land area values derived from an original measurement.
class LandAreaConversion {
  const LandAreaConversion({
    required this.originalValue,
    required this.originalUnit,
    required this.originalRawText,
    required this.decimals,
    required this.sqFt,
    required this.acres,
    required this.katha,
    required this.bigha,
  });

  final double originalValue;
  final LandUnit originalUnit;
  final String originalRawText;
  final double decimals;
  final double sqFt;
  final double acres;
  final double katha;
  final double bigha;

  String get formattedDecimals => '${decimals.toStringAsFixed(2)} decimals';

  String get formattedSqFt {
    final rounded = sqFt.round();
    final isExact = (sqFt - rounded).abs() < 0.05;
    final numStr = isExact
        ? NumberFormat('#,##0', 'en_US').format(rounded)
        : NumberFormat('#,##0.##', 'en_US').format(sqFt);
    return '$numStr sq ft';
  }

  String get formattedAcres {
    final raw = acres.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
    final clean = raw.endsWith('.') ? '${raw}0' : raw;
    return '$clean acre';
  }

  /// Katha always displays with "about" because district standards vary.
  String get formattedKatha => 'about ${katha.toStringAsFixed(2)} katha';

  /// Bigha always displays with "about" because district standards vary.
  String get formattedBigha => 'about ${bigha.toStringAsFixed(2)} bigha';

  /// Concise Key Details subtitle (e.g. "12.50 decimals, about 5,445 sq ft").
  String get detailSubtitle => '$formattedDecimals, about $formattedSqFt';

  /// Chip list for the Scan tap-a-line bottom sheet (`read-scan-tap-line.png`).
  List<String> get chipLabels => <String>[
    formattedDecimals,
    formattedSqFt,
    formattedAcres,
    formattedKatha,
    if (bigha >= 0.5) formattedBigha,
  ];
}

abstract final class LandUnits {
  static const double sqFtPerDecimal = 435.6;
  static const double sqFtPerAcre = 43560.0;
  static const double sqFtPerKatha = 720.0;
  static const double sqFtPerBigha = 14400.0;

  static final RegExp _areaPattern = RegExp(
    r'([0-9০-৯]+(?:,[0-9০-৯]{3})*(?:\.[0-9০-৯]+)?)\s*'
    r'(শতাংশ|শতক|শতাং|decimals?|dec\.?|একর|acres?|কাঠা|kathas?|বিঘা|bighas?|বর্গফুট|sq\.?\s*ft\.?|sft)',
    caseSensitive: false,
  );

  /// Converts a known numeric value and [unit] into all standard land units.
  static LandAreaConversion convert(
    double value,
    LandUnit unit, {
    String? rawText,
  }) {
    final sqFt = switch (unit) {
      LandUnit.decimal => value * sqFtPerDecimal,
      LandUnit.acre => value * sqFtPerAcre,
      LandUnit.katha => value * sqFtPerKatha,
      LandUnit.bigha => value * sqFtPerBigha,
      LandUnit.sqFt => value,
    };
    return LandAreaConversion(
      originalValue: value,
      originalUnit: unit,
      originalRawText: rawText ?? value.toString(),
      decimals: sqFt / sqFtPerDecimal,
      sqFt: sqFt,
      acres: sqFt / sqFtPerAcre,
      katha: sqFt / sqFtPerKatha,
      bigha: sqFt / sqFtPerBigha,
    );
  }

  /// Parses the first land area mention found in [text] (Bangla or English
  /// numerals and unit names). Returns `null` if no land area is present.
  static LandAreaConversion? parseFromText(String text) {
    final match = _areaPattern.firstMatch(text);
    if (match == null) return null;
    final rawNum = toLatinDigits(match.group(1)!).replaceAll(',', '');
    final value = double.tryParse(rawNum);
    if (value == null || value <= 0) return null;
    final unitToken = match.group(2)!.toLowerCase();

    final LandUnit unit;
    if (unitToken.startsWith('শত') || unitToken.startsWith('dec')) {
      unit = LandUnit.decimal;
    } else if (unitToken.startsWith('একর') || unitToken.startsWith('acre')) {
      unit = LandUnit.acre;
    } else if (unitToken.startsWith('কাঠ') || unitToken.startsWith('katha')) {
      unit = LandUnit.katha;
    } else if (unitToken.startsWith('বিঘ') || unitToken.startsWith('bigha')) {
      unit = LandUnit.bigha;
    } else {
      unit = LandUnit.sqFt;
    }

    return convert(value, unit, rawText: match.group(0)!);
  }
}
