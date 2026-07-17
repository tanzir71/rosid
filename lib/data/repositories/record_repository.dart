import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:uuid/uuid.dart';

class RecordRepository {
  const RecordRepository(this.database);

  final AppDatabase database;

  Future<void> saveReceipt({
    required String scanId,
    required String merchant,
    required DateTime date,
    required double total,
    required String currency,
    required String categoryId,
    required List<ParsedLineItem> items,
    required Map<String, double> fieldConfidence,
    double? tax,
    String? paymentMethod,
    String? note,
  }) async {
    const uuid = Uuid();
    await database.transaction(() async {
      final existing = await (database.select(
        database.receipts,
      )..where((row) => row.scanId.equals(scanId))).getSingleOrNull();
      final receiptId = existing?.id ?? uuid.v7();
      if (existing == null) {
        await database
            .into(database.receipts)
            .insert(
              ReceiptsCompanion.insert(
                id: receiptId,
                scanId: scanId,
                merchant: merchant,
                dateOfPurchase: date,
                total: total,
                currency: Value(currency),
                tax: Value(tax),
                paymentMethod: Value(paymentMethod),
                categoryId: Value(categoryId),
                note: Value(note),
                fieldConfidenceJson: Value(jsonEncode(fieldConfidence)),
              ),
            );
      } else {
        await (database.update(
          database.receipts,
        )..where((row) => row.id.equals(receiptId))).write(
          ReceiptsCompanion(
            merchant: Value(merchant),
            dateOfPurchase: Value(date),
            total: Value(total),
            currency: Value(currency),
            tax: Value(tax),
            paymentMethod: Value(paymentMethod),
            categoryId: Value(categoryId),
            note: Value(note),
            fieldConfidenceJson: Value(jsonEncode(fieldConfidence)),
          ),
        );
        await (database.delete(
          database.lineItems,
        )..where((row) => row.receiptId.equals(receiptId))).go();
      }
      for (final item in items) {
        await database
            .into(database.lineItems)
            .insert(
              LineItemsCompanion.insert(
                id: uuid.v7(),
                receiptId: receiptId,
                name: item.name,
                qty: Value(item.quantity),
                unitPrice: Value(item.unitPrice),
                amount: item.amount,
              ),
            );
      }
      final scan = await (database.select(
        database.scans,
      )..where((row) => row.id.equals(scanId))).getSingle();
      await database.indexScan(
        scanId: scanId,
        text: [
          scan.ocrRawText,
          merchant,
          note,
          items.map((item) => item.name).join(' '),
        ],
      );
      await (database.update(database.scans)
            ..where((row) => row.id.equals(scanId)))
          .write(ScansCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  Future<void> saveDocument({
    required String scanId,
    required String title,
    required String body,
    required List<String> tags,
    bool pinned = false,
  }) async {
    const uuid = Uuid();
    await database.transaction(() async {
      final existing = await (database.select(
        database.documents,
      )..where((row) => row.scanId.equals(scanId))).getSingleOrNull();
      final documentId = existing?.id ?? uuid.v7();
      if (existing == null) {
        await database
            .into(database.documents)
            .insert(
              DocumentsCompanion.insert(
                id: documentId,
                scanId: scanId,
                title: title,
                body: Value(body),
                pinned: Value(pinned),
              ),
            );
      } else {
        await (database.update(
          database.documents,
        )..where((row) => row.id.equals(documentId))).write(
          DocumentsCompanion(
            title: Value(title),
            body: Value(body),
            pinned: Value(pinned),
          ),
        );
      }
      await (database.delete(
        database.scanTags,
      )..where((row) => row.scanId.equals(scanId))).go();
      final uniqueTags = tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet();
      for (final tagName in uniqueTags) {
        final existingTag = await (database.select(
          database.tags,
        )..where((row) => row.name.equals(tagName))).getSingleOrNull();
        final tagId = existingTag?.id ?? uuid.v7();
        if (existingTag == null) {
          await database
              .into(database.tags)
              .insert(TagsCompanion.insert(id: tagId, name: tagName));
        }
        await database
            .into(database.scanTags)
            .insert(ScanTagsCompanion.insert(scanId: scanId, tagId: tagId));
      }
      await database.customStatement('''
        DELETE FROM tags
        WHERE NOT EXISTS (
          SELECT 1 FROM scan_tags WHERE scan_tags.tag_id = tags.id
        )
      ''');
      final scan = await (database.select(
        database.scans,
      )..where((row) => row.id.equals(scanId))).getSingle();
      await database.indexScan(
        scanId: scanId,
        text: [scan.ocrRawText, title, body, uniqueTags.join(' ')],
      );
      await (database.update(database.scans)
            ..where((row) => row.id.equals(scanId)))
          .write(ScansCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  Future<List<Category>> categories() {
    return (database.select(
      database.categories,
    )..orderBy([(row) => OrderingTerm.asc(row.nameEn)])).get();
  }
}

final recordRepositoryProvider = Provider<RecordRepository>(
  (ref) => RecordRepository(ref.watch(databaseProvider)),
);
