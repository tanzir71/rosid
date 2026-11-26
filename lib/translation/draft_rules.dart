import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/parsing/land_units.dart';
import 'package:rosid/translation/bangla_calendar.dart';
import 'package:rosid/translation/bangla_transliterator.dart';

/// How a legal/land term should be rendered in English drafts.
enum TermForm {
  both('both'),
  english('english'),
  bangla('bangla');

  const TermForm(this.code);
  final String code;

  static TermForm fromCode(String? value) {
    for (final f in values) {
      if (f.code == value) return f;
    }
    return TermForm.both;
  }
}

/// A term from `terms` / `assets/data/terms.json`.
class TermRule {
  const TermRule({
    required this.id,
    required this.bangla,
    required this.transliteration,
    required this.english,
    required this.both,
    required this.explanation,
    required this.chosenForm,
    this.aliases = const [],
  });

  final String id;
  final String bangla;
  final String transliteration;
  final String english;
  final String both;
  final String explanation;
  final TermForm chosenForm;
  final List<String> aliases;

  List<String> get allBanglaForms => <String>[bangla, ...aliases];

  String render([TermForm? overrideForm]) {
    final form = overrideForm ?? chosenForm;
    return switch (form) {
      TermForm.both => both.isNotEmpty ? both : '$transliteration ($english)',
      TermForm.english => english,
      TermForm.bangla => transliteration.isNotEmpty ? transliteration : bangla,
    };
  }
}

/// A person or place entry from the Name Book (`names` table).
class NameBookRule {
  const NameBookRule({
    required this.id,
    required this.bangla,
    required this.english,
    required this.category,
    required this.source,
    required this.confirmed,
  });

  final String id;
  final String bangla;
  final String english;

  /// `'person'` or `'place'`
  final String category;

  /// `'passport'`, `'nid'`, `'manual'`, or `'suggested'`
  final String source;
  final bool confirmed;

  bool get isVerified =>
      confirmed ||
      source == 'passport' ||
      source == 'nid' ||
      source == 'manual';
}

/// Metadata badge attached to a translated draft line.
enum DraftNameStatus {
  /// Matched a confirmed/passport/NID entry in the user's Name Book.
  fromNameBook,

  /// New or unconfirmed name transliterated by rule — prompt the user to check.
  newNameCheck,
}

class DraftNameMark {
  const DraftNameMark({
    required this.bangla,
    required this.english,
    required this.category,
    required this.status,
  });

  final String bangla;
  final String english;
  final String category;
  final DraftNameStatus status;
}

class DraftTermMention {
  const DraftTermMention({required this.termId, required this.renderedText});

  final String termId;
  final String renderedText;
}

/// Prepared representation of a line before passing free text to the NMT model.
class PreparedLine {
  const PreparedLine({
    required this.originalBangla,
    required this.maskedForModel,
    required this.placeholders,
    required this.ruleOnlyDraft,
    required this.nameMarks,
    required this.termMentions,
    required this.hasFreeTextForModel,
  });

  final String originalBangla;

  /// Text with protected placeholders (`__NM0__`, `__TM0__`, `__DT0__`, etc.)
  /// for the translation model.
  final String maskedForModel;
  final Map<String, String> placeholders;

  /// Pure rule-based draft (used for structured label-value lines where rules
  /// produce exact official wording, and as fallback when no NMT model is used).
  final String? ruleOnlyDraft;
  final List<DraftNameMark> nameMarks;
  final List<DraftTermMention> termMentions;
  final bool hasFreeTextForModel;
}

/// Final English draft result for one Bangla source line.
class DraftLineResult {
  const DraftLineResult({
    required this.sourceBangla,
    required this.englishDraft,
    required this.nameMarks,
    required this.termMentions,
    required this.usedModel,
  });

  final String sourceBangla;
  final String englishDraft;
  final List<DraftNameMark> nameMarks;
  final List<DraftTermMention> termMentions;
  final bool usedModel;
}

/// Pure rules engine that runs BEFORE and AFTER the translation model
/// (`handover/02-architecture.md` "Rules before models").
///
/// Guarantees 100% preservation of:
/// - Name Book spellings ("As in passport" / "As in NID" always win)
/// - User's chosen Term forms (`both`, `english`, `bangla`)
/// - Numerals (Bangla -> Latin)
/// - Bangla calendar dates -> Gregorian date appended in brackets
/// - Land area values -> secondary unit appended in brackets
class DraftRulesEngine {
  const DraftRulesEngine();

  /// Prepares a Bangla line: extracts structured rule-only drafts when the line
  /// is a standard official record field, or builds placeholder-protected text
  /// for neural translation of free sentences.
  PreparedLine prepareLine(
    String sourceBangla, {
    required List<NameBookRule> names,
    required List<TermRule> terms,
  }) {
    final trimmed = sourceBangla.trim();
    if (trimmed.isEmpty) {
      return const PreparedLine(
        originalBangla: '',
        maskedForModel: '',
        placeholders: {},
        ruleOnlyDraft: '',
        nameMarks: [],
        termMentions: [],
        hasFreeTextForModel: false,
      );
    }

    // Already pure English/Latin? Just preserve and normalize any Bangla digits.
    if (!RegExp(r'[\u0980-\u09FF]').hasMatch(trimmed)) {
      return PreparedLine(
        originalBangla: trimmed,
        maskedForModel: trimmed,
        placeholders: const {},
        ruleOnlyDraft: toLatinDigits(trimmed),
        nameMarks: const [],
        termMentions: const [],
        hasFreeTextForModel: false,
      );
    }

    final nameMarks = <DraftNameMark>[];
    final termMentions = <DraftTermMention>[];

    // 1. Try deterministic official-record structured patterns first (produces
    // clean, exact legal formatting matching `translate-english-draft.png` and
    // guarantees 100% fidelity on key fields).
    final structured = _tryStructuredLine(
      trimmed,
      names: names,
      terms: terms,
      nameMarks: nameMarks,
      termMentions: termMentions,
    );
    if (structured != null) {
      return PreparedLine(
        originalBangla: trimmed,
        maskedForModel: structured,
        placeholders: const {},
        ruleOnlyDraft: structured,
        nameMarks: nameMarks,
        termMentions: termMentions,
        hasFreeTextForModel: false,
      );
    }

    // 2. General sentence / mixed line: mask names, dates, land areas, terms,
    // and numbers with ASCII placeholder tokens so the NMT model cannot corrupt
    // or drop any of them.
    var masked = trimmed;
    final placeholders = <String, String>{};
    var idx = 0;

    String addPlaceholder(String value) {
      // Use a stable numeric-looking token that Marian/SentencePiece keeps intact.
      final token = 'XRO${idx}X';
      idx++;
      placeholders[token] = value;
      return token;
    }

    // 2a. Name Book entries (longest first so full names match before parts).
    final sortedNames = List<NameBookRule>.from(names)
      ..sort((a, b) => b.bangla.length.compareTo(a.bangla.length));
    for (final n in sortedNames) {
      if (n.bangla.trim().isEmpty || n.english.trim().isEmpty) continue;
      if (masked.contains(n.bangla)) {
        final token = addPlaceholder(n.english);
        masked = masked.replaceAll(n.bangla, token);
        nameMarks.add(
          DraftNameMark(
            bangla: n.bangla,
            english: n.english,
            category: n.category,
            status: n.isVerified
                ? DraftNameStatus.fromNameBook
                : DraftNameStatus.newNameCheck,
          ),
        );
      }
    }

    // 2b. Bangla calendar dates -> `12 Falgun 1430 (25 February 2024)`
    for (final dm in BanglaCalendar.findBanglaDates(masked)) {
      final token = addPlaceholder(dm.formattedWithGregorian);
      masked = masked.replaceFirst(dm.rawMatch, token);
    }

    // 2c. Gregorian dates in Bangla script/digits -> `25 February 2024`
    for (final gm in BanglaCalendar.findGregorianBanglaDates(masked)) {
      if (masked.contains(gm.rawMatch)) {
        final token = addPlaceholder(gm.formattedEnglish);
        masked = masked.replaceFirst(gm.rawMatch, token);
      }
    }

    // 2d. Land areas -> `12.50 decimals (about 5,445 sq ft)`
    final area = LandUnits.parseFromText(masked);
    if (area != null && masked.contains(area.originalRawText)) {
      final formatted = formatLandAreaForDraft(area);
      final token = addPlaceholder(formatted);
      masked = masked.replaceFirst(area.originalRawText, token);
    }

    // 2e. Known terms from Term Book (longest form first).
    final termMatches = <(String, TermRule)>[];
    for (final t in terms) {
      for (final form in t.allBanglaForms) {
        if (form.trim().isNotEmpty) {
          termMatches.add((form, t));
        }
      }
    }
    termMatches.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    for (final (form, rule) in termMatches) {
      if (masked.contains(form)) {
        final rendered = rule.render();
        final token = addPlaceholder(rendered);
        masked = masked.replaceAll(form, token);
        if (!termMentions.any((m) => m.termId == rule.id)) {
          termMentions.add(
            DraftTermMention(termId: rule.id, renderedText: rendered),
          );
        }
      }
    }

    // 2f. Convert remaining Bangla digits to Latin numerals and protect
    // standalone numbers (IDs, plot numbers, money amounts).
    masked = toLatinDigits(masked);
    final numRe = RegExp(r'\b\d+(?:[.,:/-]\d+)*\b');
    masked = masked.replaceAllMapped(numRe, (m) => addPlaceholder(m.group(0)!));

    final hasBanglaRemaining = RegExp(r'[\u0980-\u09FF]').hasMatch(masked);
    return PreparedLine(
      originalBangla: trimmed,
      maskedForModel: masked,
      placeholders: placeholders,
      ruleOnlyDraft: hasBanglaRemaining
          ? null
          : restorePlaceholders(masked, placeholders),
      nameMarks: nameMarks,
      termMentions: termMentions,
      hasFreeTextForModel: hasBanglaRemaining,
    );
  }

  /// Restores protected placeholders after neural model translation, guaranteeing
  /// that even if the model altered whitespace/case around a placeholder, every
  /// number, date, term, and name spelling survives 100% intact.
  String restorePlaceholders(
    String translated,
    Map<String, String> placeholders,
  ) {
    var out = toLatinDigits(translated);
    final missing = <String>[];

    for (final entry in placeholders.entries) {
      final token = entry.key;
      final value = entry.value;
      final ciPattern = RegExp(RegExp.escape(token), caseSensitive: false);
      if (ciPattern.hasMatch(out)) {
        out = out.replaceAll(ciPattern, value);
      } else {
        missing.add(value);
      }
    }

    // Safety net: if the NMT model dropped a placeholder token, append the
    // preserved value so no number, date, or passport name is ever lost.
    if (missing.isNotEmpty) {
      final extra = missing.where((v) => !out.contains(v)).join(' ');
      if (extra.isNotEmpty) {
        out = '${out.trim()} $extra'.trim();
      }
    }

    return out
        .replaceAll(RegExp(r'\s+([.,;:])'), r'$1')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Combines prepared line metadata with an optional NMT [modelOutput].
  DraftLineResult finalizeLine(PreparedLine prepared, {String? modelOutput}) {
    if (prepared.ruleOnlyDraft != null && !prepared.hasFreeTextForModel) {
      return DraftLineResult(
        sourceBangla: prepared.originalBangla,
        englishDraft: prepared.ruleOnlyDraft!,
        nameMarks: prepared.nameMarks,
        termMentions: prepared.termMentions,
        usedModel: false,
      );
    }

    if (modelOutput != null && modelOutput.trim().isNotEmpty) {
      final restored = restorePlaceholders(modelOutput, prepared.placeholders);
      return DraftLineResult(
        sourceBangla: prepared.originalBangla,
        englishDraft: restored,
        nameMarks: prepared.nameMarks,
        termMentions: prepared.termMentions,
        usedModel: true,
      );
    }

    // Pure-rule fallback for any remaining Bangla words (transliterate).
    final fallback = restorePlaceholders(
      prepared.maskedForModel,
      prepared.placeholders,
    );
    final transliterated = fallback.replaceAllMapped(
      RegExp(r'[\u0980-\u09FF]+(?:\s+[\u0980-\u09FF]+)*'),
      (m) => BanglaTransliterator.transliterate(m.group(0)!),
    );
    return DraftLineResult(
      sourceBangla: prepared.originalBangla,
      englishDraft: transliterated.trim(),
      nameMarks: prepared.nameMarks,
      termMentions: prepared.termMentions,
      usedModel: false,
    );
  }

  /// Formats a [LandAreaConversion] for the English draft line:
  /// e.g. `12.50 decimals (about 5,445 sq ft)`.
  static String formatLandAreaForDraft(LandAreaConversion area) {
    return switch (area.originalUnit) {
      LandUnit.decimal =>
        '${area.formattedDecimals} (about ${area.formattedSqFt})',
      LandUnit.acre => '${area.formattedAcres} (${area.formattedDecimals})',
      LandUnit.katha =>
        '${area.originalValue.toStringAsFixed(area.originalValue == area.originalValue.roundToDouble() ? 0 : 2)} katha (${area.formattedDecimals}, about ${area.formattedSqFt})',
      LandUnit.bigha =>
        '${area.originalValue.toStringAsFixed(area.originalValue == area.originalValue.roundToDouble() ? 0 : 2)} bigha (${area.formattedDecimals}, about ${area.formattedSqFt})',
      LandUnit.sqFt => '${area.formattedSqFt} (${area.formattedDecimals})',
    };
  }

  /// Attempts deterministic translation for structured official record lines
  /// (land records, certificates, deeds, receipts) matching `design/screens/translate-english-draft.png`.
  String? _tryStructuredLine(
    String line, {
    required List<NameBookRule> names,
    required List<TermRule> terms,
    required List<DraftNameMark> nameMarks,
    required List<DraftTermMention> termMentions,
  }) {
    TermRule? findTerm(String id) {
      for (final t in terms) {
        if (t.id == id) return t;
      }
      return null;
    }

    String useTerm(String id, String fallback) {
      final rule = findTerm(id);
      if (rule == null) return fallback;
      final rendered = rule.render();
      if (!termMentions.any((m) => m.termId == rule.id)) {
        termMentions.add(
          DraftTermMention(termId: rule.id, renderedText: rendered),
        );
      }
      return rendered;
    }

    String resolveName(String rawBangla, {required String category}) {
      final clean = rawBangla.trim();
      if (clean.isEmpty) return '';
      // Check for "মৃত" prefix ("Late ...").
      final lateMatch = RegExp(r'^মৃতঃ?\s+(.+)$').firstMatch(clean);
      if (lateMatch != null) {
        final lateText = useTerm('mrito', 'Late');
        final rest = resolveName(lateMatch.group(1)!, category: category);
        return '$lateText $rest';
      }

      for (final n in names) {
        if (n.bangla.trim() == clean && n.english.trim().isNotEmpty) {
          nameMarks.add(
            DraftNameMark(
              bangla: clean,
              english: n.english,
              category: n.category,
              status: n.isVerified
                  ? DraftNameStatus.fromNameBook
                  : DraftNameStatus.newNameCheck,
            ),
          );
          return n.english;
        }
      }

      final suggested = BanglaTransliterator.transliterate(clean);
      nameMarks.add(
        DraftNameMark(
          bangla: clean,
          english: suggested,
          category: category,
          status: DraftNameStatus.newNameCheck,
        ),
      );
      return suggested;
    }

    // A. Khatian No. line: `খতিয়ান নং ১২৪৫` or `খতিয়ান নং: ১২৪৫`
    final khatianM = RegExp(
      r'^(?:খতি[যয়]়?ান)\s*(?:নং|নম্বর)?\s*[:：\-]?\s*([0-9০-৯A-Za-z/\-]+)$',
    ).firstMatch(line);
    if (khatianM != null) {
      final termText = useTerm('khatian', 'Khatian (record of rights)');
      final num = toLatinDigits(khatianM.group(1)!);
      return '$termText No. $num';
    }

    // B. Plot (Dag) No. line: `দাগ নং ৪৮২` or `দাগ নং: ৪৮২`
    final dagM = RegExp(
      r'^দাগ\s*(?:নং|নম্বর)?\s*[:：\-]?\s*([0-9০-৯A-Za-z,/\-\s]+)$',
    ).firstMatch(line);
    if (dagM != null) {
      final termText = useTerm('dag_no', 'Plot (Dag) No.');
      final num = toLatinDigits(dagM.group(1)!.trim());
      return '$termText $num';
    }

    // C. District + Upazila combined line: `জেলা: ঢাকা, উপজেলা: সাভার`
    final distUpazilaM = RegExp(
      r'^জেলা\s*[:：\-]\s*([^,]+)[,।]\s*উপজেলা\s*[:：\-]\s*(.+)$',
    ).firstMatch(line);
    if (distUpazilaM != null) {
      final dist = resolvePlaceQuietly(distUpazilaM.group(1)!, names);
      final upazila = resolvePlaceQuietly(distUpazilaM.group(2)!, names);
      return 'District: $dist. Upazila: $upazila';
    }

    // D. Mouza + J.L. No. combined line: `মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫`
    final mouzaJlM = RegExp(
      r'^(?:মৌজা|মোজা)\s*[:：\-]\s*([^,]+)[,।]\s*(?:জে\.?\s*এল\.?\s*(?:নং|নম্বর)?)\s*[:：\-]?\s*([0-9০-৯]+)$',
    ).firstMatch(line);
    if (mouzaJlM != null) {
      final mouzaLabel = useTerm('mouza', 'Mouza');
      final jlLabel = useTerm('jl_no', 'J.L. No.');
      final mouza = resolvePlaceQuietly(mouzaJlM.group(1)!, names);
      final jl = toLatinDigits(mouzaJlM.group(2)!);
      return '$mouzaLabel: $mouza. $jlLabel $jl';
    }

    // E. Owner / Name line: `মালিকের নাম: মোঃ আব্দুর রহমান` or `নাম: ফারহানা রহমান`
    final ownerM = RegExp(
      r'^(মালিকের\s*নাম|মালিক|নাম|আবেদনকারীর\s*নাম)\s*[:：\-]\s*(.+)$',
    ).firstMatch(line);
    if (ownerM != null) {
      final labelRaw = ownerM.group(1)!;
      final label = labelRaw.contains('মালিক')
          ? 'Owner'
          : (labelRaw.contains('আবেদনকারী') ? 'Applicant' : 'Name');
      final person = resolveName(ownerM.group(2)!, category: 'person');
      return '$label: $person';
    }

    // F. Father / Mother / Husband line: `পিতা: মৃত আব্দুল করিম`
    final relM = RegExp(
      r'^(পিতার\s*নাম|পিতা|মাতার\s*নাম|মাতা|স্বামীর\s*নাম|স্বামী)\s*[:：\-]\s*(.+)$',
    ).firstMatch(line);
    if (relM != null) {
      final rawRel = relM.group(1)!;
      final label = rawRel.startsWith('পিতা')
          ? 'Father'
          : (rawRel.startsWith('মাতা') ? 'Mother' : 'Husband');
      final person = resolveName(relM.group(2)!, category: 'person');
      return '$label: $person';
    }

    // G. Area line: `জমির পরিমাণ: ১২.৫০ শতাংশ`
    final areaLabelM = RegExp(
      r'^(?:জমির\s*পরিমাণ|মোট\s*জমি|পরিমাণ|জমি)\s*[:：\-]\s*(.+)$',
    ).firstMatch(line);
    if (areaLabelM != null) {
      final parsed = LandUnits.parseFromText(areaLabelM.group(1)!);
      if (parsed != null) {
        return 'Area: ${formatLandAreaForDraft(parsed)}';
      }
    }

    // H. Date line: `তারিখ: ১২ ফাল্গুন ১৪৩০` or `জন্ম তারিখ: ১৫/০৮/১৯৯৫`
    final dateLabelM = RegExp(
      r'^(জন্ম\s*তারিখ|ইস্যু\s*তারিখ|তারিখ)\s*[:：\-]\s*(.+)$',
    ).firstMatch(line);
    if (dateLabelM != null) {
      final labelRaw = dateLabelM.group(1)!;
      final label = labelRaw.contains('জন্ম')
          ? 'Date of birth'
          : (labelRaw.contains('ইস্যু') ? 'Issue date' : 'Date');
      final val = dateLabelM.group(2)!.trim();
      final bnDates = BanglaCalendar.findBanglaDates(val);
      if (bnDates.isNotEmpty) {
        return '$label: ${bnDates.first.formattedWithGregorian}';
      }
      final gregDates = BanglaCalendar.findGregorianBanglaDates(val);
      if (gregDates.isNotEmpty) {
        return '$label: ${gregDates.first.formattedEnglish}';
      }
      return '$label: ${toLatinDigits(val)}';
    }

    // I. Registration / Certificate No. / NID No. / Deed No. / JL / Mouza / District / Upazila single fields
    final singleFieldM = RegExp(
      r'^(নিবন্ধন\s*নং|জন্ম\s*নিবন্ধন\s*নং|পরিচয়পত্র\s*নং|দলিল\s*নং|স্মারক\s*নং|জে\.?\s*এল\.?\s*নং|মৌজা|জেলা|উপজেলা|ইউনিয়ন|ইউনিয়ন|সাং|গ্রাম|ঠিকানা)\s*[:：\-]?\s*(.+)$',
    ).firstMatch(line);
    if (singleFieldM != null) {
      final key = singleFieldM.group(1)!;
      final val = singleFieldM.group(2)!.trim();
      if (key.contains('নিবন্ধন')) {
        return 'Registration No.: ${toLatinDigits(val)}';
      }
      if (key.contains('পরিচয়পত্র')) {
        return 'National ID No.: ${toLatinDigits(val)}';
      }
      if (key.contains('দলিল')) {
        return '${useTerm('dolil', 'Deed')} No.: ${toLatinDigits(val)}';
      }
      if (key.contains('স্মারক')) {
        return 'Memo No.: ${toLatinDigits(val)}';
      }
      if (key.startsWith('জে')) {
        return '${useTerm('jl_no', 'J.L. No.')} ${toLatinDigits(val)}';
      }
      if (key == 'মৌজা') {
        return '${useTerm('mouza', 'Mouza')}: ${resolvePlaceQuietly(val, names)}';
      }
      if (key == 'জেলা') {
        return 'District: ${resolvePlaceQuietly(val, names)}';
      }
      if (key == 'উপজেলা') {
        return 'Upazila: ${resolvePlaceQuietly(val, names)}';
      }
      if (key.startsWith('ইউনি')) {
        return 'Union: ${resolvePlaceQuietly(val, names)}';
      }
      if (key == 'সাং' || key == 'গ্রাম') {
        return '${useTerm('sang', 'Village')}: ${resolvePlaceQuietly(val, names)}';
      }
    }

    // J. Document header titles (exact/short headers)
    if (line == 'জন্ম নিবন্ধন সনদ' || line == 'জন্ম ও মৃত্যু নিবন্ধন সনদ') {
      return useTerm('jonmo_nibondhon', 'Birth registration certificate');
    }
    if (line == 'ওয়ারিশ সনদ' || line == 'ওয়ারিশ সনদ') {
      return useTerm('warish_sonod', 'Succession (warish) certificate');
    }
    if (line == 'জাতীয় পরিচয়পত্র' || line == 'জাতীয় পরিচয়পত্র') {
      return useTerm('jatio_porichoypotro', 'National ID card');
    }
    if (line == 'ট্রেড লাইসেন্স') {
      return useTerm('trade_licence', 'Trade licence');
    }
    if (line == 'ভূমি উন্নয়ন কর দাখিলা' || line == 'ভূমি উন্নয়ন কর দাখিলা') {
      return '${useTerm('bhumi_unnayan_kor', 'Land development tax')} — ${useTerm('dakhila', 'Land tax receipt (dakhila)')}';
    }
    if (line == 'গণপ্রজাতন্ত্রী বাংলাদেশ সরকার') {
      return "Government of the People's Republic of Bangladesh";
    }

    return null;
  }

  String resolvePlaceQuietly(String rawBangla, List<NameBookRule> names) {
    final clean = rawBangla.trim();
    for (final n in names) {
      if (n.bangla.trim() == clean && n.english.trim().isNotEmpty) {
        return n.english;
      }
    }
    return BanglaTransliterator.transliterate(clean);
  }
}
