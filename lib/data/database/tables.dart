import 'package:drift/drift.dart';

class Scans extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get kind => text().withDefault(const Constant('document'))();
  TextColumn get language => text().withDefault(const Constant('bn'))();
  IntColumn get checkCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get renewBy => dateTime().nullable()();
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
  TextColumn get filter => text().withDefault(const Constant('auto'))();
  TextColumn get quadJson => text().nullable()();
  IntColumn get rotation => integer().withDefault(const Constant(0))();
  TextColumn get side => text().nullable()();

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

class TextLines extends Table {
  TextColumn get id => text()();
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();
  IntColumn get lineOrder => integer()();
  TextColumn get textContent => text()();
  TextColumn get boxJson => text().withDefault(const Constant('[]'))();
  RealColumn get confidence => real().withDefault(const Constant(1.0))();
  TextColumn get script => text().withDefault(const Constant('bn'))();
  BoolColumn get corrected => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Details extends Table {
  TextColumn get id => text()();
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  TextColumn get detailKey => text()();
  TextColumn get value => text()();
  TextColumn get sourceLineId => text().nullable().references(
    TextLines,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Translations extends Table {
  TextColumn get id => text()();
  TextColumn get scanId =>
      text().references(Scans, #id, onDelete: KeyAction.cascade)();
  TextColumn get lineId => text().nullable().references(
    TextLines,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get lineOrder => integer()();
  TextColumn get sourceText => text().withDefault(const Constant(''))();
  TextColumn get englishText => text()();
  TextColumn get flagsJson => text().withDefault(const Constant('{}'))();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Names extends Table {
  TextColumn get id => text()();
  TextColumn get bangla => text()();
  TextColumn get english => text()();
  TextColumn get category => text().withDefault(const Constant('person'))();
  TextColumn get source => text().withDefault(const Constant('suggested'))();
  BoolColumn get confirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Terms extends Table {
  TextColumn get id => text()();
  TextColumn get bangla => text()();
  TextColumn get transliteration => text().withDefault(const Constant(''))();
  TextColumn get english => text()();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get chosenForm => text().withDefault(const Constant('both'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Corrections extends Table {
  TextColumn get id => text()();
  TextColumn get wrongReading => text()();
  TextColumn get rightReading => text()();
  IntColumn get count => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Bundles extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get purpose => text().withDefault(const Constant('custom'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BundleItems extends Table {
  TextColumn get id => text()();
  TextColumn get bundleId =>
      text().references(Bundles, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get itemOrder => integer()();
  TextColumn get expectedKind =>
      text().withDefault(const Constant('document'))();
  TextColumn get linkedScanId =>
      text().nullable().references(Scans, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
