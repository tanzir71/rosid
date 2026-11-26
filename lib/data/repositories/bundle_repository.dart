import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:uuid/uuid.dart';

class ChecklistTemplateItem {
  const ChecklistTemplateItem({
    required this.titleEn,
    required this.titleBn,
    required this.expectedKind,
  });

  final String titleEn;
  final String titleBn;
  final String expectedKind;

  String titleFor(String langCode) => langCode == 'bn' ? titleBn : titleEn;
}

class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.icon,
    required this.titleEn,
    required this.titleBn,
    required this.subtitleEn,
    required this.subtitleBn,
    required this.disclaimerEn,
    required this.disclaimerBn,
    required this.items,
  });

  final String id;
  final String icon;
  final String titleEn;
  final String titleBn;
  final String subtitleEn;
  final String subtitleBn;
  final String disclaimerEn;
  final String disclaimerBn;
  final List<ChecklistTemplateItem> items;

  String titleFor(String langCode) => langCode == 'bn' ? titleBn : titleEn;
  String subtitleFor(String langCode) =>
      langCode == 'bn' ? subtitleBn : subtitleEn;
  String disclaimerFor(String langCode) =>
      langCode == 'bn' ? disclaimerBn : disclaimerEn;
}

enum BundleItemStatus { ready, needsWork, missing }

class BundleItemView {
  const BundleItemView({
    required this.item,
    required this.status,
    required this.pageCount,
    required this.hasEnglishDraft,
    required this.wordsToCheck,
    this.linkedScan,
    this.linkedTitle,
  });

  final BundleItem item;
  final BundleItemStatus status;
  final int pageCount;
  final bool hasEnglishDraft;
  final int wordsToCheck;
  final Scan? linkedScan;
  final String? linkedTitle;
}

class BundleDetailView {
  const BundleDetailView({required this.bundle, required this.items});

  final Bundle bundle;
  final List<BundleItemView> items;

  int get totalCount => items.length;
  int get readyCount =>
      items.where((i) => i.status == BundleItemStatus.ready).length;
  int get needsWorkCount =>
      items.where((i) => i.status == BundleItemStatus.needsWork).length;
  int get missingCount =>
      items.where((i) => i.status == BundleItemStatus.missing).length;

  String? get firstMissingTitle {
    for (final i in items) {
      if (i.status == BundleItemStatus.missing) return i.item.title;
    }
    return null;
  }

  List<BundleItemView> get attachedItems =>
      items.where((i) => i.item.linkedScanId != null).toList();
}

/// Manages `bundles`, `bundle_items`, and editable `assets/data/checklists.json`.
class BundleRepository {
  BundleRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();
  List<ChecklistTemplate>? _templatesCache;

  Future<List<ChecklistTemplate>> loadTemplates() async {
    if (_templatesCache != null) return _templatesCache!;
    final raw = await rootBundle.loadString('assets/data/checklists.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final templates = <ChecklistTemplate>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final itemsRaw = (m['items'] as List<dynamic>? ?? const []);
      templates.add(
        ChecklistTemplate(
          id: m['id'] as String,
          icon: m['icon'] as String? ?? 'bundle',
          titleEn: m['titleEn'] as String,
          titleBn: m['titleBn'] as String,
          subtitleEn: m['subtitleEn'] as String? ?? '',
          subtitleBn: m['subtitleBn'] as String? ?? '',
          disclaimerEn:
              m['disclaimerEn'] as String? ??
              'Check the official list for your application.',
          disclaimerBn:
              m['disclaimerBn'] as String? ??
              'আপনার আবেদনের জন্য অফিসিয়াল তালিকাটি মিলিয়ে নিন।',
          items: [
            for (final it in itemsRaw)
              ChecklistTemplateItem(
                titleEn: (it as Map<String, dynamic>)['titleEn'] as String,
                titleBn: it['titleBn'] as String,
                expectedKind: it['expectedKind'] as String? ?? 'document',
              ),
          ],
        ),
      );
    }
    _templatesCache = templates;
    return templates;
  }

  Future<String> createFromTemplate(
    ChecklistTemplate template, {
    required String title,
    required String langCode,
    DateTime? dueDate,
  }) async {
    final bundleId = _uuid.v7();
    final now = DateTime.now();
    await db.transaction(() async {
      await db
          .into(db.bundles)
          .insert(
            BundlesCompanion.insert(
              id: bundleId,
              title: title.trim().isEmpty
                  ? template.titleFor(langCode)
                  : title.trim(),
              purpose: Value(template.id),
              dueDate: Value(dueDate),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (var i = 0; i < template.items.length; i++) {
        final it = template.items[i];
        await db
            .into(db.bundleItems)
            .insert(
              BundleItemsCompanion.insert(
                id: _uuid.v7(),
                bundleId: bundleId,
                title: it.titleFor(langCode),
                itemOrder: i,
                expectedKind: Value(it.expectedKind),
              ),
            );
      }
    });
    return bundleId;
  }

  Future<List<BundleDetailView>> loadAllBundles() async {
    final rows = await (db.select(
      db.bundles,
    )..orderBy([(b) => OrderingTerm.desc(b.updatedAt)])).get();
    final out = <BundleDetailView>[];
    for (final b in rows) {
      final detail = await loadBundleDetail(b.id);
      if (detail != null) out.add(detail);
    }
    return out;
  }

  Future<BundleDetailView?> loadBundleDetail(String bundleId) async {
    final bundle = await (db.select(
      db.bundles,
    )..where((b) => b.id.equals(bundleId))).getSingleOrNull();
    if (bundle == null) return null;

    final itemRows =
        await (db.select(db.bundleItems)
              ..where((i) => i.bundleId.equals(bundleId))
              ..orderBy([(i) => OrderingTerm.asc(i.itemOrder)]))
            .get();

    final views = <BundleItemView>[];
    for (final it in itemRows) {
      if (it.linkedScanId == null) {
        views.add(
          BundleItemView(
            item: it,
            status: BundleItemStatus.missing,
            pageCount: 0,
            hasEnglishDraft: false,
            wordsToCheck: 0,
          ),
        );
        continue;
      }

      final scan = await (db.select(
        db.scans,
      )..where((s) => s.id.equals(it.linkedScanId!))).getSingleOrNull();
      if (scan == null) {
        views.add(
          BundleItemView(
            item: it,
            status: BundleItemStatus.missing,
            pageCount: 0,
            hasEnglishDraft: false,
            wordsToCheck: 0,
          ),
        );
        continue;
      }

      final pages = await (db.select(
        db.scanPages,
      )..where((p) => p.scanId.equals(scan.id))).get();
      final doc = await (db.select(
        db.documents,
      )..where((d) => d.scanId.equals(scan.id))).getSingleOrNull();
      final translations = await (db.select(
        db.translations,
      )..where((t) => t.scanId.equals(scan.id))).get();

      final hasDraft = translations.isNotEmpty;
      final wordsToCheck = scan.checkCount;
      final status = wordsToCheck > 0
          ? BundleItemStatus.needsWork
          : BundleItemStatus.ready;

      views.add(
        BundleItemView(
          item: it,
          status: status,
          pageCount: pages.isEmpty ? 1 : pages.length,
          hasEnglishDraft: hasDraft,
          wordsToCheck: wordsToCheck,
          linkedScan: scan,
          linkedTitle: doc?.title,
        ),
      );
    }

    return BundleDetailView(bundle: bundle, items: views);
  }

  Future<void> linkScanToItem({
    required String bundleId,
    required String itemId,
    required String? scanId,
  }) async {
    await db.transaction(() async {
      await (db.update(db.bundleItems)..where((i) => i.id.equals(itemId)))
          .write(BundleItemsCompanion(linkedScanId: Value(scanId)));
      await (db.update(db.bundles)..where((b) => b.id.equals(bundleId))).write(
        BundlesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<void> addItem({
    required String bundleId,
    required String title,
    String expectedKind = 'document',
    String? linkedScanId,
  }) async {
    final existing = await (db.select(
      db.bundleItems,
    )..where((i) => i.bundleId.equals(bundleId))).get();
    await db.transaction(() async {
      await db
          .into(db.bundleItems)
          .insert(
            BundleItemsCompanion.insert(
              id: _uuid.v7(),
              bundleId: bundleId,
              title: title.trim(),
              itemOrder: existing.length,
              expectedKind: Value(expectedKind),
              linkedScanId: Value(linkedScanId),
            ),
          );
      await (db.update(db.bundles)..where((b) => b.id.equals(bundleId))).write(
        BundlesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<void> removeItem(String bundleId, String itemId) async {
    await db.transaction(() async {
      await (db.delete(db.bundleItems)..where((i) => i.id.equals(itemId))).go();
      await (db.update(db.bundles)..where((b) => b.id.equals(bundleId))).write(
        BundlesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<void> reorderItems(
    String bundleId,
    List<String> orderedItemIds,
  ) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedItemIds.length; i++) {
        await (db.update(db.bundleItems)
              ..where((row) => row.id.equals(orderedItemIds[i])))
            .write(BundleItemsCompanion(itemOrder: Value(i)));
      }
      await (db.update(db.bundles)..where((b) => b.id.equals(bundleId))).write(
        BundlesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<void> updateDueDate(String bundleId, DateTime? dueDate) async {
    await (db.update(db.bundles)..where((b) => b.id.equals(bundleId))).write(
      BundlesCompanion(
        dueDate: Value(dueDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteBundle(String bundleId) async {
    await (db.delete(db.bundles)..where((b) => b.id.equals(bundleId))).go();
  }
}

final bundleRepositoryProvider = Provider<BundleRepository>(
  (ref) => BundleRepository(ref.watch(databaseProvider)),
);

final checklistTemplatesProvider = FutureProvider<List<ChecklistTemplate>>(
  (ref) => ref.watch(bundleRepositoryProvider).loadTemplates(),
);

final allBundlesProvider = FutureProvider<List<BundleDetailView>>(
  (ref) => ref.watch(bundleRepositoryProvider).loadAllBundles(),
);

final bundleDetailProvider = FutureProvider.family<BundleDetailView?, String>(
  (ref, id) => ref.watch(bundleRepositoryProvider).loadBundleDetail(id),
);
