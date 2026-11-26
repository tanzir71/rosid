import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/id_card_composer.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_cleaner.dart';
import 'package:uuid/uuid.dart';

/// Modes available on the v2 Scan screen (`design/screens.md` section 03).
enum V2ScanMode { document, idCard, receipt, translate }

/// One page in an active v2 capture/adjust session. Original photo is never
/// overwritten; all edits live as non-destructive metadata.
class CapturedPageDraft {
  const CapturedPageDraft({
    required this.pageId,
    required this.originalPath,
    this.quad = const DocumentQuad.inset(),
    this.rotationQuarterTurns = 0,
    this.filter = PageFilterMode.auto,
    this.side,
    this.cleanedColorPath,
    this.cleanedGreyPath,
  });

  final String pageId;
  final String originalPath;
  final DocumentQuad quad;
  final int rotationQuarterTurns;
  final PageFilterMode filter;
  final String? side; // 'front' or 'back' for ID cards
  final String? cleanedColorPath;
  final String? cleanedGreyPath;

  CapturedPageDraft copyWith({
    String? originalPath,
    DocumentQuad? quad,
    int? rotationQuarterTurns,
    PageFilterMode? filter,
    String? side,
    String? cleanedColorPath,
    String? cleanedGreyPath,
  }) {
    return CapturedPageDraft(
      pageId: pageId,
      originalPath: originalPath ?? this.originalPath,
      quad: quad ?? this.quad,
      rotationQuarterTurns: rotationQuarterTurns ?? this.rotationQuarterTurns,
      filter: filter ?? this.filter,
      side: side ?? this.side,
      cleanedColorPath: cleanedColorPath ?? this.cleanedColorPath,
      cleanedGreyPath: cleanedGreyPath ?? this.cleanedGreyPath,
    );
  }

  String quadToJson() => jsonEncode([
    [quad.topLeft.x, quad.topLeft.y],
    [quad.topRight.x, quad.topRight.y],
    [quad.bottomRight.x, quad.bottomRight.y],
    [quad.bottomLeft.x, quad.bottomLeft.y],
  ]);

  static DocumentQuad quadFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return const DocumentQuad.inset();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      if (list.length != 4) return const DocumentQuad.inset();
      NormalizedPoint pt(dynamic v) {
        final pair = v as List<dynamic>;
        return NormalizedPoint(
          (pair[0] as num).toDouble(),
          (pair[1] as num).toDouble(),
        );
      }

      return DocumentQuad(
        topLeft: pt(list[0]),
        topRight: pt(list[1]),
        bottomRight: pt(list[2]),
        bottomLeft: pt(list[3]),
      );
    } on Object {
      return const DocumentQuad.inset();
    }
  }
}

/// Active multi-page v2 scan workflow state.
class V2ScanState {
  const V2ScanState({
    this.mode = V2ScanMode.document,
    this.scanId,
    this.pages = const [],
    this.selectedIndex = 0,
    this.autoCapture = true,
    this.isBusy = false,
    this.composedIdCardPath,
  });

  final V2ScanMode mode;
  final String? scanId;
  final List<CapturedPageDraft> pages;
  final int selectedIndex;
  final bool autoCapture;
  final bool isBusy;
  final String? composedIdCardPath;

  bool get isIdBackStep =>
      mode == V2ScanMode.idCard &&
      pages.length == 1 &&
      pages.first.side == 'front';

  bool get isIdComplete =>
      mode == V2ScanMode.idCard &&
      pages.length >= 2 &&
      pages.any((p) => p.side == 'front') &&
      pages.any((p) => p.side == 'back');

  CapturedPageDraft? get currentPage =>
      pages.isEmpty ? null : pages[selectedIndex.clamp(0, pages.length - 1)];

  V2ScanState copyWith({
    V2ScanMode? mode,
    String? scanId,
    List<CapturedPageDraft>? pages,
    int? selectedIndex,
    bool? autoCapture,
    bool? isBusy,
    String? composedIdCardPath,
  }) {
    return V2ScanState(
      mode: mode ?? this.mode,
      scanId: scanId ?? this.scanId,
      pages: pages ?? this.pages,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      autoCapture: autoCapture ?? this.autoCapture,
      isBusy: isBusy ?? this.isBusy,
      composedIdCardPath: composedIdCardPath ?? this.composedIdCardPath,
    );
  }
}

class V2ScanController extends Notifier<V2ScanState> {
  static const _uuid = Uuid();

  @override
  V2ScanState build() => const V2ScanState();

  void startSession(V2ScanMode mode) {
    state = V2ScanState(mode: mode, autoCapture: state.autoCapture);
  }

  void setMode(V2ScanMode mode) {
    if (state.pages.isNotEmpty) return;
    state = state.copyWith(mode: mode);
  }

  void setAutoCapture(bool enabled) {
    state = state.copyWith(autoCapture: enabled);
  }

  void selectPage(int index) {
    if (state.pages.isEmpty) return;
    state = state.copyWith(
      selectedIndex: index.clamp(0, state.pages.length - 1),
    );
  }

  Future<CapturedPageDraft?> addCapturedFile(
    String sourcePath, {
    DocumentQuad? detectedQuad,
  }) async {
    return _addCapturedInternal(
      persist: (store, scanId, pageIndex) => store.persistCapture(
        sourcePath: sourcePath,
        scanId: scanId,
        pageIndex: pageIndex,
      ),
      detectedQuad: detectedQuad,
    );
  }

  Future<CapturedPageDraft?> addCapturedBytes(
    Uint8List bytes, {
    DocumentQuad? detectedQuad,
    String extension = '.jpg',
  }) async {
    return _addCapturedInternal(
      persist: (store, scanId, pageIndex) => store.persistCaptureBytes(
        bytes: bytes,
        scanId: scanId,
        pageIndex: pageIndex,
        extension: extension,
      ),
      detectedQuad: detectedQuad,
    );
  }

  Future<CapturedPageDraft?> _addCapturedInternal({
    required Future<String> Function(
      PrivateFileStore store,
      String scanId,
      int pageIndex,
    )
    persist,
    DocumentQuad? detectedQuad,
  }) async {
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true);
    try {
      final scanId = state.scanId ?? _uuid.v7();
      final pageIndex = state.pages.length;
      final side = state.mode == V2ScanMode.idCard
          ? (pageIndex == 0 ? 'front' : 'back')
          : null;
      final persistedPath = await persist(
        ref.read(privateFileStoreProvider),
        scanId,
        pageIndex,
      );

      final db = ref.read(databaseProvider);
      final repo = ref.read(scanRepositoryProvider);
      final pageId = _uuid.v7();
      final scanMode = state.mode == V2ScanMode.receipt
          ? ScanMode.receipt
          : ScanMode.document;
      final kind = switch (state.mode) {
        V2ScanMode.receipt => 'receipt',
        V2ScanMode.idCard => 'id',
        V2ScanMode.document || V2ScanMode.translate => 'document',
      };

      if (state.scanId == null) {
        await repo.createScan(
          id: scanId,
          mode: scanMode,
          imagePath: persistedPath,
          langHint: 'automatic',
          createdAt: DateTime.now(),
        );
        await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
          ScansCompanion(kind: Value(kind)),
        );
        // Update first scan_page metadata.
        final existingPages = await repo.getPages(scanId);
        if (existingPages.isNotEmpty) {
          final firstId = existingPages.first.id;
          final draft = CapturedPageDraft(
            pageId: firstId,
            originalPath: persistedPath,
            quad: detectedQuad ?? const DocumentQuad.inset(),
            side: side,
          );
          await _persistPageMeta(db, draft, 0);
          state = state.copyWith(
            scanId: scanId,
            pages: [draft],
            selectedIndex: 0,
            isBusy: false,
          );
          return draft;
        }
      } else {
        await repo.addPage(
          id: pageId,
          scanId: scanId,
          imagePath: persistedPath,
          pageIndex: pageIndex,
        );
      }

      final draft = CapturedPageDraft(
        pageId: pageId,
        originalPath: persistedPath,
        quad: detectedQuad ?? const DocumentQuad.inset(),
        side: side,
      );
      await _persistPageMeta(db, draft, pageIndex);
      final updated = [...state.pages, draft];
      state = state.copyWith(
        scanId: scanId,
        pages: updated,
        selectedIndex: updated.length - 1,
        isBusy: false,
      );
      return draft;
    } on Object {
      state = state.copyWith(isBusy: false);
      rethrow;
    }
  }

  /// Runs the M2 cleaning pipeline on every page in a background isolate,
  /// saving colour-corrected and greyscale JPEGs without ever overwriting the
  /// original photo. For ID card sessions with both sides, also composes an A4
  /// two-sided JPEG at true ISO ID-1 size (85.6 x 54 mm).
  Future<String?> cleanAllPages({
    void Function(int completed, int total)? onProgress,
  }) async {
    final scanId = state.scanId;
    if (scanId == null || state.pages.isEmpty) return scanId;
    final store = ref.read(privateFileStoreProvider);
    final db = ref.read(databaseProvider);
    final updatedPages = <CapturedPageDraft>[];
    final total = state.pages.length;

    Uint8List? frontClean;
    Uint8List? backClean;

    for (var i = 0; i < total; i++) {
      final page = state.pages[i];
      final rawBytes = await File(page.originalPath).readAsBytes();
      final quad = page.quad;
      final turns = page.rotationQuarterTurns;
      final filter = page.filter;

      final cleaned = await Isolate.run(
        () => const ImageCleaner().clean(
          rawBytes,
          quad: quad,
          rotationQuarterTurns: turns,
          filter: filter,
        ),
      );

      final colorPath = await store.writeProcessed(
        bytes: cleaned.colorCorrectedJpeg,
        scanId: scanId,
        pageIndex: i,
        suffix: 'color',
      );
      final greyPath = await store.writeProcessed(
        bytes: cleaned.greyJpeg,
        scanId: scanId,
        pageIndex: i,
        suffix: 'grey',
      );

      if (i == 0) {
        final thumbPath = await store.writeThumbnail(
          bytes: cleaned.colorCorrectedJpeg,
          scanId: scanId,
        );
        await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
          ScansCompanion(thumbPath: Value(thumbPath)),
        );
      }

      await (db.update(db.scanPages)..where((p) => p.id.equals(page.pageId)))
          .write(ScanPagesCompanion(processedPath: Value(colorPath)));

      if (page.side == 'front') frontClean = cleaned.colorCorrectedJpeg;
      if (page.side == 'back') backClean = cleaned.colorCorrectedJpeg;

      updatedPages.add(
        page.copyWith(cleanedColorPath: colorPath, cleanedGreyPath: greyPath),
      );
      onProgress?.call(i + 1, total);
    }

    String? composedPath = state.composedIdCardPath;
    if (state.isIdComplete && frontClean != null && backClean != null) {
      final f = frontClean;
      final b = backClean;
      final composedBytes = await Isolate.run(
        () => const IdCardComposer().composeA4Jpeg(frontBytes: f, backBytes: b),
      );
      composedPath = await store.writeProcessed(
        bytes: composedBytes,
        scanId: scanId,
        pageIndex: 0,
        suffix: 'id_a4',
      );
    }

    state = state.copyWith(
      pages: updatedPages,
      composedIdCardPath: composedPath,
    );
    return scanId;
  }

  void clearSession() {
    state = V2ScanState(autoCapture: state.autoCapture);
  }

  /// Adds an in-memory draft page (used in unit/widget tests without disk DB).
  void setPagesForTesting(List<CapturedPageDraft> pages, {int selected = 0}) {
    state = state.copyWith(
      pages: List<CapturedPageDraft>.unmodifiable(pages),
      selectedIndex: pages.isEmpty ? 0 : selected.clamp(0, pages.length - 1),
    );
  }

  Future<void> updateCurrentQuad(DocumentQuad quad) async {
    final page = state.currentPage;
    if (page == null) return;
    final idx = state.selectedIndex;
    final updatedPage = page.copyWith(quad: quad);
    final updated = [...state.pages]..[idx] = updatedPage;
    state = state.copyWith(pages: updated);
    if (state.scanId != null) {
      await _persistPageMeta(ref.read(databaseProvider), updatedPage, idx);
    }
  }

  Future<void> rotateCurrentPage() async {
    final page = state.currentPage;
    if (page == null) return;
    final idx = state.selectedIndex;
    final updatedPage = page.copyWith(
      rotationQuarterTurns: (page.rotationQuarterTurns + 1) % 4,
    );
    final updated = [...state.pages]..[idx] = updatedPage;
    state = state.copyWith(pages: updated);
    if (state.scanId != null) {
      await _persistPageMeta(ref.read(databaseProvider), updatedPage, idx);
    }
  }

  Future<void> setCurrentFilter(PageFilterMode filter) async {
    final page = state.currentPage;
    if (page == null) return;
    final idx = state.selectedIndex;
    final updatedPage = page.copyWith(filter: filter);
    final updated = [...state.pages]..[idx] = updatedPage;
    state = state.copyWith(pages: updated);
    if (state.scanId != null) {
      await _persistPageMeta(ref.read(databaseProvider), updatedPage, idx);
    }
  }

  Future<void> deleteCurrentPage() async {
    if (state.pages.isEmpty) return;
    final idx = state.selectedIndex;
    final removed = state.pages[idx];
    final updated = [...state.pages]..removeAt(idx);
    state = state.copyWith(
      pages: updated,
      selectedIndex: updated.isEmpty ? 0 : idx.clamp(0, updated.length - 1),
    );
    if (state.scanId != null) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.scanPages,
      )..where((p) => p.id.equals(removed.pageId))).go();
      for (var i = 0; i < updated.length; i++) {
        await _persistPageMeta(db, updated[i], i);
      }
    }
  }

  Future<void> reorderPages(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.pages.length) return;
    var target = newIndex;
    if (target > oldIndex) target--;
    target = target.clamp(0, state.pages.length - 1);
    final updated = [...state.pages];
    final moved = updated.removeAt(oldIndex);
    updated.insert(target, moved);
    state = state.copyWith(pages: updated, selectedIndex: target);
    if (state.scanId != null) {
      final db = ref.read(databaseProvider);
      for (var i = 0; i < updated.length; i++) {
        await _persistPageMeta(db, updated[i], i);
      }
    }
  }

  Future<void> _persistPageMeta(
    AppDatabase db,
    CapturedPageDraft draft,
    int pageIndex,
  ) async {
    await (db.update(
      db.scanPages,
    )..where((p) => p.id.equals(draft.pageId))).write(
      ScanPagesCompanion(
        pageIndex: Value(pageIndex),
        filter: Value(draft.filter.id),
        quadJson: Value(draft.quadToJson()),
        rotation: Value(draft.rotationQuarterTurns * 90),
        side: Value(draft.side),
      ),
    );
  }
}

final v2ScanProvider = NotifierProvider<V2ScanController, V2ScanState>(
  V2ScanController.new,
);
