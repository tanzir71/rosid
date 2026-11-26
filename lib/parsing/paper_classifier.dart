import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/parsing/land_units.dart';
import 'package:rosid/parsing/receipt_parser.dart';

/// Supported paper kinds (`handover/02-architecture.md` Finding details).
enum PaperKind {
  land('land'),
  deed('deed'),
  certificate('certificate'),
  idCard('id'),
  licence('licence'),
  bill('bill'),
  receipt('receipt'),
  letter('letter'),
  notes('notes'),
  document('document');

  const PaperKind(this.code);

  final String code;

  static PaperKind byId(String? value) {
    for (final k in values) {
      if (k.code == value) return k;
    }
    return PaperKind.document;
  }
}

/// Extracted key detail linked back to the line index where it was read.
class ExtractedDetail {
  const ExtractedDetail({
    required this.key,
    required this.value,
    this.subtitle,
    this.sourceLineIndex,
  });

  final String key;
  final String value;
  final String? subtitle;
  final int? sourceLineIndex;
}

/// Keyword paper-kind classifier and per-kind Key Details extractor.
class PaperClassifier {
  const PaperClassifier();

  /// Classifies a paper's kind from its OCR lines.
  PaperKind classify(String fullText, {String? currentKind}) {
    if (currentKind == 'id') return PaperKind.idCard;
    final lower = fullText.toLowerCase();

    if (_hasAny(lower, const [
      'খতিয়ান',
      'খতিয়ান',
      'পর্চা',
      'দাগ নং',
      'মৌজা',
      'ভূমি রেকর্ড',
      'শতাংশ',
      'khatian',
      'mouza',
    ])) {
      return PaperKind.land;
    }
    if (_hasAny(lower, const ['দলিল', 'সাব-রেজিস্ট্রার', 'তফসিল', 'deed'])) {
      return PaperKind.deed;
    }
    if (_hasAny(lower, const [
      'জন্ম নিবন্ধন',
      'birth registration',
      'ওয়ারিশ সনদ',
      'নিকাহনামা',
      'certificate',
      'সনদ',
    ])) {
      return PaperKind.certificate;
    }
    if (_hasAny(lower, const [
          'জাতীয় পরিচয়পত্র',
          'national id',
          'nid no',
          'date of birth',
          'id no',
        ]) &&
        !lower.contains('birth registration')) {
      return PaperKind.idCard;
    }
    if (_hasAny(lower, const [
      'ট্রেড লাইসেন্স',
      'trade licence',
      'driving licence',
      'license',
    ])) {
      return PaperKind.licence;
    }
    if (_hasAny(lower, const [
      'বিদ্যুৎ',
      'ইলেকট্রিক',
      'desco',
      'dpdc',
      'wasa',
      'titas',
      'account no',
      'due date',
      'মোট বিল',
      'gas bill',
    ])) {
      return PaperKind.bill;
    }
    if (_hasAny(lower, const [
      'grand total',
      'সর্বমোট',
      'subtotal',
      'vat ',
      'ভ্যাট',
      'মূসক',
      'bin:',
      'super shop',
      'receipt',
    ])) {
      return PaperKind.receipt;
    }
    if (_hasAny(lower, const ['হাতে লেখা', 'notes'])) {
      return PaperKind.notes;
    }
    if (_hasAny(lower, const [
      'বিষয়:',
      'স্মারক নং',
      'subject:',
      'reference:',
      'sincerely',
    ])) {
      return PaperKind.letter;
    }
    return PaperKind.byId(currentKind);
  }

  /// Extracts structured Key Details with source line indices.
  List<ExtractedDetail> extractDetails(
    List<String> lines, {
    required PaperKind kind,
  }) {
    switch (kind) {
      case PaperKind.land:
      case PaperKind.deed:
        return _extractLandDetails(lines);
      case PaperKind.receipt:
        return _extractReceiptDetails(lines);
      case PaperKind.certificate:
        return _extractCertificateDetails(lines);
      case PaperKind.bill:
        return _extractBillDetails(lines);
      case PaperKind.idCard:
      case PaperKind.licence:
      case PaperKind.letter:
      case PaperKind.notes:
      case PaperKind.document:
        return _extractGenericDetails(lines);
    }
  }

  List<ExtractedDetail> _extractLandDetails(List<String> lines) {
    final details = <ExtractedDetail>[];

    // 1. Khatian number (supports fuzzy OCR variants like খতিয়ান / খতিয়ান / খাতয়ান)
    final khatian = _findMatch(
      lines,
      RegExp(
        r'(?:খতি[যয়]়?ান|খাত[যয়]়?ান|khatian)[^0-9০-৯]{0,12}([0-9০-৯]{2,7})',
        caseSensitive: false,
      ),
    );
    if (khatian != null) {
      details.add(
        ExtractedDetail(
          key: 'khatian_no',
          value: khatian.$1,
          sourceLineIndex: khatian.$2,
        ),
      );
    }

    // 2. Plot (dag) number
    final plot = _findMatch(
      lines,
      RegExp(
        r'(?:দাগ|dag|plot)[^0-9০-৯]{0,12}([0-9০-৯]{1,6})',
        caseSensitive: false,
      ),
    );
    if (plot != null) {
      details.add(
        ExtractedDetail(
          key: 'plot_no',
          value: plot.$1,
          sourceLineIndex: plot.$2,
        ),
      );
    }

    // 3. Owner name
    final owner = _findLabeledValue(
      lines,
      RegExp(
        r'(?:মালিকের\s*নাম|মালিক|owner)\s*[:：\-]?\s*(.+)',
        caseSensitive: false,
      ),
    );
    if (owner != null) {
      details.add(
        ExtractedDetail(
          key: 'owner',
          value: owner.$1,
          sourceLineIndex: owner.$2,
        ),
      );
    }

    // 4. Area + converted units subtitle
    for (var i = 0; i < lines.length; i++) {
      final area = LandUnits.parseFromText(lines[i]);
      if (area != null) {
        details.add(
          ExtractedDetail(
            key: 'area',
            value: area.originalRawText,
            subtitle: area.detailSubtitle,
            sourceLineIndex: i,
          ),
        );
        break;
      }
    }

    // 5. Mouza
    final mouza = _findLabeledValue(
      lines,
      RegExp(
        r'(?:মৌজা|মোজা|mouza)\s*[:：\-]?\s*([^,\n]+)',
        caseSensitive: false,
      ),
    );
    if (mouza != null) {
      details.add(
        ExtractedDetail(
          key: 'mouza',
          value: mouza.$1
              .split(RegExp(r'জে\.?এল|j\.?l\.?', caseSensitive: false))
              .first
              .trim(),
          sourceLineIndex: mouza.$2,
        ),
      );
    }

    // 6. J.L. number
    final jl = _findMatch(
      lines,
      RegExp(
        r'(?:জে\.?\s*এল\.?|j\.?\s*l\.?)[^0-9০-৯]{0,10}([0-9০-৯]{1,5})',
        caseSensitive: false,
      ),
    );
    if (jl != null) {
      details.add(
        ExtractedDetail(key: 'jl_no', value: jl.$1, sourceLineIndex: jl.$2),
      );
    }

    // 7. Father
    final father = _findLabeledValue(
      lines,
      RegExp(r'(?:পিতা|father)\s*[:：\-]?\s*(.+)', caseSensitive: false),
    );
    if (father != null) {
      details.add(
        ExtractedDetail(
          key: 'father',
          value: father.$1,
          sourceLineIndex: father.$2,
        ),
      );
    }

    return details;
  }

  List<ExtractedDetail> _extractReceiptDetails(List<String> lines) {
    final parsed = const ReceiptParser().parse(lines.join('\n'));
    final details = <ExtractedDetail>[];
    if (parsed.merchant.value.isNotEmpty &&
        parsed.merchant.value != 'Unknown merchant') {
      details.add(
        ExtractedDetail(
          key: 'shop',
          value: parsed.merchant.value,
          sourceLineIndex: _lineIndexContaining(lines, parsed.merchant.rawText),
        ),
      );
    }
    if (parsed.total.value != null) {
      details.add(
        ExtractedDetail(
          key: 'total',
          value: '৳ ${parsed.total.value!.toStringAsFixed(2)}',
          sourceLineIndex: _lineIndexContaining(lines, parsed.total.rawText),
        ),
      );
    }
    if (parsed.tax.value != null) {
      details.add(
        ExtractedDetail(
          key: 'vat',
          value: '৳ ${parsed.tax.value!.toStringAsFixed(2)}',
          sourceLineIndex: _lineIndexContaining(lines, parsed.tax.rawText),
        ),
      );
    }
    if (parsed.paymentMethod.value != null) {
      details.add(
        ExtractedDetail(
          key: 'payment_method',
          value: parsed.paymentMethod.value!,
          sourceLineIndex: _lineIndexContaining(
            lines,
            parsed.paymentMethod.rawText,
          ),
        ),
      );
    }
    return details;
  }

  List<ExtractedDetail> _extractCertificateDetails(List<String> lines) {
    final details = <ExtractedDetail>[];
    final reg = _findMatch(
      lines,
      RegExp(
        r'(?:নিবন্ধন\s*নং|registration\s*no\.?)\s*[:：\-]?\s*([0-9০-৯]{6,20})',
        caseSensitive: false,
      ),
    );
    if (reg != null) {
      details.add(
        ExtractedDetail(
          key: 'registration_no',
          value: reg.$1,
          sourceLineIndex: reg.$2,
        ),
      );
    }
    final name = _findLabeledValue(
      lines,
      RegExp(r'^(?:নাম|name)\s*[:：\-]\s*(.+)', caseSensitive: false),
    );
    if (name != null) {
      details.add(
        ExtractedDetail(key: 'owner', value: name.$1, sourceLineIndex: name.$2),
      );
    }
    final dob = _findLabeledValue(
      lines,
      RegExp(
        r'(?:জন্ম\s*তারিখ|date\s*of\s*birth)\s*[:：\-]\s*(.+)',
        caseSensitive: false,
      ),
    );
    if (dob != null) {
      details.add(
        ExtractedDetail(key: 'date', value: dob.$1, sourceLineIndex: dob.$2),
      );
    }
    return details;
  }

  List<ExtractedDetail> _extractBillDetails(List<String> lines) {
    final details = <ExtractedDetail>[];
    final acct = _findLabeledValue(
      lines,
      RegExp(
        r'(?:account\s*no\.?|হিসাব\s*নং)\s*[:：\-]?\s*([A-Za-z0-9০-৯\-]+)',
        caseSensitive: false,
      ),
    );
    if (acct != null) {
      details.add(
        ExtractedDetail(
          key: 'account',
          value: acct.$1,
          sourceLineIndex: acct.$2,
        ),
      );
    }
    final total = _findMatch(
      lines,
      RegExp(
        r'(?:মোট\s*বিল|total)\s*[:：\-]?\s*([0-9০-৯,.]+)',
        caseSensitive: false,
      ),
    );
    if (total != null) {
      details.add(
        ExtractedDetail(
          key: 'total',
          value: total.$1,
          sourceLineIndex: total.$2,
        ),
      );
    }
    final due = _findLabeledValue(
      lines,
      RegExp(
        r'(?:due\s*date|শেষ\s*তারিখ)\s*[:：\-]?\s*(.+)',
        caseSensitive: false,
      ),
    );
    if (due != null) {
      details.add(
        ExtractedDetail(key: 'date', value: due.$1, sourceLineIndex: due.$2),
      );
    }
    return details;
  }

  List<ExtractedDetail> _extractGenericDetails(List<String> lines) {
    final details = <ExtractedDetail>[];
    for (var i = 0; i < lines.length; i++) {
      final area = LandUnits.parseFromText(lines[i]);
      if (area != null) {
        details.add(
          ExtractedDetail(
            key: 'area',
            value: area.originalRawText,
            subtitle: area.detailSubtitle,
            sourceLineIndex: i,
          ),
        );
        break;
      }
    }
    return details;
  }

  (String, int)? _findMatch(List<String> lines, RegExp pattern) {
    for (var i = 0; i < lines.length; i++) {
      final m = pattern.firstMatch(lines[i]);
      if (m != null && m.group(1) != null) {
        return (m.group(1)!.trim(), i);
      }
    }
    return null;
  }

  (String, int)? _findLabeledValue(List<String> lines, RegExp pattern) {
    for (var i = 0; i < lines.length; i++) {
      final m = pattern.firstMatch(lines[i]);
      if (m != null && m.group(1) != null) {
        final v = m.group(1)!.trim();
        if (v.isNotEmpty) return (v, i);
      }
    }
    return null;
  }

  int? _lineIndexContaining(List<String> lines, String needle) {
    if (needle.isEmpty) return null;
    final first = needle.split('\n').first.trim();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(first)) return i;
    }
    return null;
  }

  bool _hasAny(String text, List<String> needles) => needles.any(text.contains);

  /// Helper for tests & scoring: normalizes extracted numeric values to Latin.
  static String normalizeDigits(String s) => toLatinDigits(s).trim();
}
