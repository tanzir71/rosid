import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_engine.dart';
import 'package:rosid/translation/translation_repository.dart';

class _FakeTranslationEngine implements TranslationEngine {
  int translateCalls = 0;
  int releaseCalls = 0;

  @override
  Future<void> warmUp() async {}

  @override
  Future<List<String>> translateBatch(List<String> lines) async {
    translateCalls++;
    return [for (final line in lines) 'Translated: $line'];
  }

  @override
  Future<void> release() async {
    releaseCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeTranslationEngine engine;
  late TranslationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = _FakeTranslationEngine();
    repo = TranslationRepository(db, engine);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'seeds 19 terms from assets/data/terms.json and persists user form choice',
    () async {
      final terms = await repo.loadTerms();
      expect(terms.length, 19);

      final khatian = terms.firstWhere((t) => t.id == 'khatian');
      expect(khatian.chosenForm, TermForm.both);
      expect(khatian.render(), 'Khatian (record of rights)');

      await repo.updateTermChoice('khatian', TermForm.english);
      final refreshed = await repo.loadTerms();
      final updated = refreshed.firstWhere((t) => t.id == 'khatian');
      expect(updated.chosenForm, TermForm.english);
      expect(updated.render(), 'Record of rights');
    },
  );

  test('generates draft with Name Book spellings, records new suggested names, and preserves user edits on remake', () async {
    final scans = ScanRepository(db);
    await scans.createScan(
      id: 'scan-1',
      mode: ScanMode.document,
      imagePath: '/tmp/land.jpg',
      langHint: 'bn',
      createdAt: DateTime.now(),
    );
    const lines = [
      ('l0', 'খতিয়ান নং ১২৪৫'),
      ('l1', 'মালিকের নাম: মোঃ আব্দুর রহমান'),
      ('l2', 'পিতা: মৃত আব্দুল করিম'),
      ('l3', 'উক্ত জমি বর্তমানে মালিকের দখলে আছে।'),
    ];
    for (var i = 0; i < lines.length; i++) {
      await db
          .into(db.textLines)
          .insert(
            TextLinesCompanion.insert(
              id: lines[i].$1,
              scanId: 'scan-1',
              pageIndex: 0,
              lineOrder: i,
              textContent: lines[i].$2,
            ),
          );
    }

    await repo.upsertName(
      bangla: 'মোঃ আব্দুর রহমান',
      english: 'MD ABDUR RAHMAN',
      category: 'person',
      source: 'passport',
    );

    final firstDraft = await repo.generateOrRefreshDraft('scan-1');
    expect(firstDraft.length, 4);
    expect(firstDraft[0].englishText, 'Khatian (record of rights) No. 1245');
    expect(firstDraft[1].englishText, 'Owner: MD ABDUR RAHMAN');
    expect(firstDraft[1].nameMarks.first.status, DraftNameStatus.fromNameBook);
    expect(firstDraft[2].englishText, 'Father: Late Abdul Karim');
    expect(firstDraft[2].nameMarks.first.status, DraftNameStatus.newNameCheck);
    expect(engine.translateCalls, 1); // Only free-text line l3 hit the model.

    // New suggested name (`আব্দুল করিম`) should be saved to `names` automatically.
    final names = await repo.loadNames();
    expect(
      names.any((n) => n.bangla == 'আব্দুল করিম' && n.source == 'suggested'),
      isTrue,
    );

    // User edits line 3 manually.
    await repo.updateDraftLine(
      scanId: 'scan-1',
      translationId: firstDraft[3].translationId,
      newEnglishText: 'The said land is currently in the owner\'s possession.',
    );

    // Change term choice (`khatian` -> `english`) and remake the draft.
    await repo.updateTermChoice('khatian', TermForm.english);
    final remade = await repo.generateOrRefreshDraft('scan-1');
    expect(remade[0].englishText, 'Record of rights No. 1245');
    // Edited line MUST survive remake when its Bangla source did not change.
    expect(remade[3].edited, isTrue);
    expect(
      remade[3].englishText,
      'The said land is currently in the owner\'s possession.',
    );

    // If the source Bangla line changes, remake re-translates it instead of keeping stale edit.
    await (db.update(db.textLines)..where((t) => t.id.equals('l3'))).write(
      const TextLinesCompanion(textContent: Value('জমির পরিমাণ: ১২.৫০ শতাংশ')),
    );
    final afterSourceChange = await repo.generateOrRefreshDraft('scan-1');
    expect(afterSourceChange[3].edited, isFalse);
    expect(
      afterSourceChange[3].englishText,
      'Area: 12.50 decimals (about 5,445 sq ft)',
    );
  });
}
