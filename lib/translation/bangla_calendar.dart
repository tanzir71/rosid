import 'package:rosid/core/utils/bangla_digits.dart';

/// Pure-Dart conversion for Bangladesh's revised Bangla calendar (Bangla Academy
/// 2019 reform, effective from 1426 BS / 14 April 2019):
/// - 1 Boishakh is always 14 April.
/// - Boishakh through Ashwin have 31 days each (6 months).
/// - Kartik through Magh have 30 days each (4 months).
/// - Falgun has 29 days, or 30 days in a Gregorian leap year (the Gregorian year
///   in which Falgun falls, i.e. `banglaYear + 594`).
/// - Choitro has 30 days.
/// - Earlier documents (before 14 April 2019) used pre-2019 rules that can differ
///   by a day, so their Gregorian equivalents are prefixed with `"about "`.
class BanglaDateMatch {
  const BanglaDateMatch({
    required this.rawMatch,
    required this.banglaDay,
    required this.banglaMonthIndex,
    required this.banglaYear,
    required this.gregorianDate,
    required this.isApproximate,
  });

  final String rawMatch;
  final int banglaDay;

  /// 1-based month index (1 = Boishakh .. 12 = Choitro).
  final int banglaMonthIndex;
  final int banglaYear;
  final DateTime gregorianDate;
  final bool isApproximate;

  String get banglaMonthEnglish =>
      BanglaCalendar.englishMonthNames[banglaMonthIndex - 1];

  /// e.g. `12 Falgun 1430`
  String get formattedBanglaDate =>
      '$banglaDay $banglaMonthEnglish $banglaYear';

  /// e.g. `25 February 2024` or `about 14 April 2018`
  String get formattedGregorian {
    final m = BanglaCalendar.gregorianMonthNames[gregorianDate.month - 1];
    final core = '${gregorianDate.day} $m ${gregorianDate.year}';
    return isApproximate ? 'about $core' : core;
  }

  /// e.g. `12 Falgun 1430 (25 February 2024)`
  String get formattedWithGregorian =>
      '$formattedBanglaDate ($formattedGregorian)';
}

/// Gregorian date parsed from Bangla digits / Bangla-spelled English month names.
class GregorianDateMatch {
  const GregorianDateMatch({required this.rawMatch, required this.date});

  final String rawMatch;
  final DateTime date;

  String get formattedEnglish {
    final m = BanglaCalendar.gregorianMonthNames[date.month - 1];
    return '${date.day} $m ${date.year}';
  }
}

abstract final class BanglaCalendar {
  static const List<String> englishMonthNames = <String>[
    'Boishakh',
    'Joishtho',
    'Asharh',
    'Srabon',
    'Bhadro',
    'Ashwin',
    'Kartik',
    'Ograhayon',
    'Poush',
    'Magh',
    'Falgun',
    'Choitro',
  ];

  static const List<String> gregorianMonthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Maps Bangla & Latin spellings of Bangla calendar months to 1..12.
  static const Map<String, int> _banglaMonthLookup = <String, int>{
    'বৈশাখ': 1,
    'boishakh': 1,
    'baishakh': 1,
    'জ্যৈষ্ঠ': 2,
    'জৈষ্ঠ্য': 2,
    'জৈষ্ঠ': 2,
    'joishtho': 2,
    'jaishtha': 2,
    'jyaishtha': 2,
    'আষাঢ়': 3,
    'আষাঢ়': 3,
    'asharh': 3,
    'ashar': 3,
    'শ্রাবণ': 4,
    'শ্রাবন': 4,
    'srabon': 4,
    'shrabon': 4,
    'ভাদ্র': 5,
    'bhadro': 5,
    'bhadra': 5,
    'আশ্বিন': 6,
    'ashwin': 6,
    'ashin': 6,
    'কার্তিক': 7,
    'কার্ত্তিক': 7,
    'kartik': 7,
    'অগ্রহায়ণ': 8,
    'অগ্রহায়ণ': 8,
    'অগ্রহায়ন': 8,
    'অগ্রহায়ন': 8,
    'ograhayon': 8,
    'agrahayan': 8,
    'পৌষ': 9,
    'poush': 9,
    'paush': 9,
    'মাঘ': 10,
    'magh': 10,
    'ফাল্গুন': 11,
    'ফাগুন': 11,
    'falgun': 11,
    'phalguna': 11,
    'চৈত্র': 12,
    'choitro': 12,
    'chaitra': 12,
  };

  /// Maps Bangla spellings of Gregorian months to 1..12.
  static const Map<String, int> _gregorianBanglaMonthLookup = <String, int>{
    'জানুয়ারি': 1,
    'জানুয়ারি': 1,
    'জানুয়ারী': 1,
    'জানুয়ারী': 1,
    'ফেব্রুয়ারি': 2,
    'ফেব্রুয়ারি': 2,
    'ফেব্রুয়ারী': 2,
    'ফেব্রুয়ারী': 2,
    'মার্চ': 3,
    'এপ্রিল': 4,
    'মে': 5,
    'জুন': 6,
    'জুলাই': 7,
    'আগস্ট': 8,
    'আগষ্ট': 8,
    'সেপ্টেম্বর': 9,
    'অক্টোবর': 10,
    'নভেম্বর': 11,
    'ডিসেম্বর': 12,
  };

  static bool isGregorianLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Returns the length of Bangla month [month] (1..12) in Bangla year [banglaYear].
  static int daysInBanglaMonth(int banglaYear, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12');
    }
    if (month <= 6) return 31;
    if (month <= 10 || month == 12) return 30;
    // Falgun (month 11) falls in Gregorian year (banglaYear + 594).
    return isGregorianLeapYear(banglaYear + 594) ? 30 : 29;
  }

  /// Converts a revised Bangladesh Bangla calendar date into its Gregorian
  /// [DateTime] (UTC). Returns `null` if the date is invalid.
  static DateTime? toGregorian(int banglaYear, int banglaMonth, int banglaDay) {
    if (banglaMonth < 1 || banglaMonth > 12) return null;
    if (banglaYear < 1200 || banglaYear > 1700) return null;
    final maxDay = daysInBanglaMonth(banglaYear, banglaMonth);
    if (banglaDay < 1 || banglaDay > maxDay) return null;

    var dayOffset = banglaDay - 1;
    for (var m = 1; m < banglaMonth; m++) {
      dayOffset += daysInBanglaMonth(banglaYear, m);
    }
    final boishakh1 = DateTime.utc(banglaYear + 593, 4, 14);
    return boishakh1.add(Duration(days: dayOffset));
  }

  /// Whether [gregorian] predates the 2019 Bangla Academy reform (14 April 2019).
  static bool isPre2019(DateTime gregorian) {
    return gregorian.isBefore(DateTime.utc(2019, 4, 14));
  }

  static final RegExp _banglaDatePattern = RegExp(
    r'([0-9০-৯]{1,2})\s*'
    r'(বৈশাখ|জ্যৈষ্ঠ|জৈষ্ঠ্য|জৈষ্ঠ|আষাঢ়|আষাঢ়|শ্রাবণ|শ্রাবন|ভাদ্র|আশ্বিন|কার্তিক|কার্ত্তিক|অগ্রহায়ণ|অগ্রহায়ণ|অগ্রহায়ন|অগ্রহায়ন|পৌষ|মাঘ|ফাল্গুন|ফাগুন|চৈত্র|Boishakh|Baishakh|Joishtho|Jaishtha|Asharh|Ashar|Srabon|Shrabon|Bhadro|Bhadra|Ashwin|Kartik|Ograhayon|Agrahayan|Poush|Magh|Falgun|Choitro|Chaitra)'
    r'[,\s]+([0-9০-৯]{4})(?:\s*(?:বঙ্গাব্দ|বাংলা|বং|সাল|BS))?',
    caseSensitive: false,
  );

  static final RegExp _gregorianBanglaMonthPattern = RegExp(
    r'([0-9০-৯]{1,2})\s*'
    r'(জানুয়ারি|জানুয়ারি|জানুয়ারী|জানুয়ারী|ফেব্রুয়ারি|ফেব্রুয়ারি|ফেব্রুয়ারী|ফেব্রুয়ারী|মার্চ|এপ্রিল|মে|জুন|জুলাই|আগস্ট|আগষ্ট|সেপ্টেম্বর|অক্টোবর|নভেম্বর|ডিসেম্বর)'
    r'[,\s]+([0-9০-৯]{4})(?:\s*(?:খ্রিঃ|খ্রিস্টাব্দ|ইং|সাল))?',
  );

  /// Matches numeric dates like `২৫/০২/২০২৪`, `২৫-০২-২০২৪`, `25.02.2024`.
  static final RegExp _numericDatePattern = RegExp(
    r'(?<![0-9০-৯])([0-9০-৯]{1,2})[/\-.]([0-9০-৯]{1,2})[/\-.]([0-9০-৯]{4})(?![0-9০-৯])',
  );

  /// Finds all Bangla calendar dates in [text].
  static List<BanglaDateMatch> findBanglaDates(String text) {
    final results = <BanglaDateMatch>[];
    for (final m in _banglaDatePattern.allMatches(text)) {
      final day = int.tryParse(toLatinDigits(m.group(1)!));
      final monthKey = m.group(2)!.toLowerCase();
      final month =
          _banglaMonthLookup[m.group(2)!] ?? _banglaMonthLookup[monthKey];
      final year = int.tryParse(toLatinDigits(m.group(3)!));
      if (day == null || month == null || year == null) continue;
      final greg = toGregorian(year, month, day);
      if (greg == null) continue;
      results.add(
        BanglaDateMatch(
          rawMatch: m.group(0)!,
          banglaDay: day,
          banglaMonthIndex: month,
          banglaYear: year,
          gregorianDate: greg,
          isApproximate: isPre2019(greg),
        ),
      );
    }
    return results;
  }

  /// Finds Gregorian dates written with Bangla month names or Bangla digits.
  static List<GregorianDateMatch> findGregorianBanglaDates(String text) {
    final results = <GregorianDateMatch>[];
    for (final m in _gregorianBanglaMonthPattern.allMatches(text)) {
      final day = int.tryParse(toLatinDigits(m.group(1)!));
      final month = _gregorianBanglaMonthLookup[m.group(2)!];
      final year = int.tryParse(toLatinDigits(m.group(3)!));
      if (day == null || month == null || year == null) continue;
      if (day < 1 || day > 31 || year < 1850 || year > 2150) continue;
      final dt = DateTime.utc(year, month, day);
      if (dt.month != month || dt.day != day) continue;
      results.add(GregorianDateMatch(rawMatch: m.group(0)!, date: dt));
    }
    for (final m in _numericDatePattern.allMatches(text)) {
      final raw = m.group(0)!;
      // Only treat numeric date as Bangla-formatted if it contains Bangla digits
      // or accompanies a date label (the caller decides formatting).
      final day = int.tryParse(toLatinDigits(m.group(1)!));
      final month = int.tryParse(toLatinDigits(m.group(2)!));
      final year = int.tryParse(toLatinDigits(m.group(3)!));
      if (day == null || month == null || year == null) continue;
      if (day < 1 || day > 31 || month < 1 || month > 12) continue;
      if (year < 1850 || year > 2150) continue;
      final dt = DateTime.utc(year, month, day);
      if (dt.month != month || dt.day != day) continue;
      results.add(GregorianDateMatch(rawMatch: raw, date: dt));
    }
    return results;
  }
}
