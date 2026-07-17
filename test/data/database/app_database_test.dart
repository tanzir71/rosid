import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/data/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('creates and seeds the seven default categories', () async {
    final categories = await database.select(database.categories).get();

    expect(categories, hasLength(7));
    expect(
      categories.map((category) => category.nameBn),
      containsAll(['মুদি', 'খাবার', 'যাতায়াত', 'অন্যান্য']),
    );
  });

  test('FTS index finds English and Bangla content', () async {
    await database.indexScan(
      scanId: 'scan-1',
      text: ['Dhaka Grocery', 'সর্বমোট ১২৫০ টাকা'],
    );

    expect(await database.searchScanIds('Grocery'), ['scan-1']);
    expect(await database.searchScanIds('সর্বমোট'), ['scan-1']);
  });

  test('reindex replaces stale content', () async {
    await database.indexScan(scanId: 'scan-1', text: ['old merchant']);
    await database.indexScan(scanId: 'scan-1', text: ['new merchant']);

    expect(await database.searchScanIds('old'), isEmpty);
    expect(await database.searchScanIds('new'), ['scan-1']);
  });
}
