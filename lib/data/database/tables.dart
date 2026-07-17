import 'package:drift/drift.dart';

class Scans extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get imagePath => text()();
  TextColumn get thumbPath => text().nullable()();
  TextColumn get ocrRawText => text().withDefault(const Constant(''))();
  TextColumn get ocrEngine => text().nullable()();
  RealColumn get ocrMeanConfidence => real().nullable()();
  TextColumn get langHint => text().withDefault(const Constant('auto'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ScanPages extends Table {
  TextColumn get id => text()();
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  TextColumn get imagePath => text()();
  TextColumn get processedPath => text().nullable()();
  IntColumn get pageIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get nameEn => text()();
  TextColumn get nameBn => text()();
  TextColumn get icon => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Receipts extends Table {
  TextColumn get id => text()();
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  TextColumn get merchant => text()();
  DateTimeColumn get dateOfPurchase => dateTime()();
  RealColumn get total => real()();
  TextColumn get currency => text().withDefault(const Constant('BDT'))();
  RealColumn get tax => real().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get note => text().nullable()();
  TextColumn get fieldConfidenceJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LineItems extends Table {
  TextColumn get id => text()();
  TextColumn get receiptId =>
      text().references(Receipts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get qty => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().nullable()();
  RealColumn get amount => real()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ScanTags extends Table {
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {scanId, tagId};
}
