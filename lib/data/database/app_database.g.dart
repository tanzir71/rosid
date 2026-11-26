// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ScansTable extends Scans with TableInfo<$ScansTable, Scan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('document'),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bn'),
  );
  static const VerificationMeta _checkCountMeta = const VerificationMeta(
    'checkCount',
  );
  @override
  late final GeneratedColumn<int> checkCount = GeneratedColumn<int>(
    'check_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _renewByMeta = const VerificationMeta(
    'renewBy',
  );
  @override
  late final GeneratedColumn<DateTime> renewBy = GeneratedColumn<DateTime>(
    'renew_by',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  @override
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrRawTextMeta = const VerificationMeta(
    'ocrRawText',
  );
  @override
  late final GeneratedColumn<String> ocrRawText = GeneratedColumn<String>(
    'ocr_raw_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ocrEngineMeta = const VerificationMeta(
    'ocrEngine',
  );
  @override
  late final GeneratedColumn<String> ocrEngine = GeneratedColumn<String>(
    'ocr_engine',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrMeanConfidenceMeta = const VerificationMeta(
    'ocrMeanConfidence',
  );
  @override
  late final GeneratedColumn<double> ocrMeanConfidence =
      GeneratedColumn<double>(
        'ocr_mean_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _langHintMeta = const VerificationMeta(
    'langHint',
  );
  @override
  late final GeneratedColumn<String> langHint = GeneratedColumn<String>(
    'lang_hint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    kind,
    language,
    checkCount,
    renewBy,
    imagePath,
    thumbPath,
    ocrRawText,
    ocrEngine,
    ocrMeanConfidence,
    langHint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('check_count')) {
      context.handle(
        _checkCountMeta,
        checkCount.isAcceptableOrUnknown(data['check_count']!, _checkCountMeta),
      );
    }
    if (data.containsKey('renew_by')) {
      context.handle(
        _renewByMeta,
        renewBy.isAcceptableOrUnknown(data['renew_by']!, _renewByMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    }
    if (data.containsKey('ocr_raw_text')) {
      context.handle(
        _ocrRawTextMeta,
        ocrRawText.isAcceptableOrUnknown(
          data['ocr_raw_text']!,
          _ocrRawTextMeta,
        ),
      );
    }
    if (data.containsKey('ocr_engine')) {
      context.handle(
        _ocrEngineMeta,
        ocrEngine.isAcceptableOrUnknown(data['ocr_engine']!, _ocrEngineMeta),
      );
    }
    if (data.containsKey('ocr_mean_confidence')) {
      context.handle(
        _ocrMeanConfidenceMeta,
        ocrMeanConfidence.isAcceptableOrUnknown(
          data['ocr_mean_confidence']!,
          _ocrMeanConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('lang_hint')) {
      context.handle(
        _langHintMeta,
        langHint.isAcceptableOrUnknown(data['lang_hint']!, _langHintMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      checkCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}check_count'],
      )!,
      renewBy: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}renew_by'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      ),
      ocrRawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_raw_text'],
      )!,
      ocrEngine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_engine'],
      ),
      ocrMeanConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ocr_mean_confidence'],
      ),
      langHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang_hint'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScansTable createAlias(String alias) {
    return $ScansTable(attachedDatabase, alias);
  }
}

class Scan extends DataClass implements Insertable<Scan> {
  final String id;
  final String type;
  final String kind;
  final String language;
  final int checkCount;
  final DateTime? renewBy;
  final String imagePath;
  final String? thumbPath;
  final String ocrRawText;
  final String? ocrEngine;
  final double? ocrMeanConfidence;
  final String langHint;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Scan({
    required this.id,
    required this.type,
    required this.kind,
    required this.language,
    required this.checkCount,
    this.renewBy,
    required this.imagePath,
    this.thumbPath,
    required this.ocrRawText,
    this.ocrEngine,
    this.ocrMeanConfidence,
    required this.langHint,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['kind'] = Variable<String>(kind);
    map['language'] = Variable<String>(language);
    map['check_count'] = Variable<int>(checkCount);
    if (!nullToAbsent || renewBy != null) {
      map['renew_by'] = Variable<DateTime>(renewBy);
    }
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || thumbPath != null) {
      map['thumb_path'] = Variable<String>(thumbPath);
    }
    map['ocr_raw_text'] = Variable<String>(ocrRawText);
    if (!nullToAbsent || ocrEngine != null) {
      map['ocr_engine'] = Variable<String>(ocrEngine);
    }
    if (!nullToAbsent || ocrMeanConfidence != null) {
      map['ocr_mean_confidence'] = Variable<double>(ocrMeanConfidence);
    }
    map['lang_hint'] = Variable<String>(langHint);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScansCompanion toCompanion(bool nullToAbsent) {
    return ScansCompanion(
      id: Value(id),
      type: Value(type),
      kind: Value(kind),
      language: Value(language),
      checkCount: Value(checkCount),
      renewBy: renewBy == null && nullToAbsent
          ? const Value.absent()
          : Value(renewBy),
      imagePath: Value(imagePath),
      thumbPath: thumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbPath),
      ocrRawText: Value(ocrRawText),
      ocrEngine: ocrEngine == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrEngine),
      ocrMeanConfidence: ocrMeanConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrMeanConfidence),
      langHint: Value(langHint),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Scan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scan(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      kind: serializer.fromJson<String>(json['kind']),
      language: serializer.fromJson<String>(json['language']),
      checkCount: serializer.fromJson<int>(json['checkCount']),
      renewBy: serializer.fromJson<DateTime?>(json['renewBy']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      thumbPath: serializer.fromJson<String?>(json['thumbPath']),
      ocrRawText: serializer.fromJson<String>(json['ocrRawText']),
      ocrEngine: serializer.fromJson<String?>(json['ocrEngine']),
      ocrMeanConfidence: serializer.fromJson<double?>(
        json['ocrMeanConfidence'],
      ),
      langHint: serializer.fromJson<String>(json['langHint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'kind': serializer.toJson<String>(kind),
      'language': serializer.toJson<String>(language),
      'checkCount': serializer.toJson<int>(checkCount),
      'renewBy': serializer.toJson<DateTime?>(renewBy),
      'imagePath': serializer.toJson<String>(imagePath),
      'thumbPath': serializer.toJson<String?>(thumbPath),
      'ocrRawText': serializer.toJson<String>(ocrRawText),
      'ocrEngine': serializer.toJson<String?>(ocrEngine),
      'ocrMeanConfidence': serializer.toJson<double?>(ocrMeanConfidence),
      'langHint': serializer.toJson<String>(langHint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Scan copyWith({
    String? id,
    String? type,
    String? kind,
    String? language,
    int? checkCount,
    Value<DateTime?> renewBy = const Value.absent(),
    String? imagePath,
    Value<String?> thumbPath = const Value.absent(),
    String? ocrRawText,
    Value<String?> ocrEngine = const Value.absent(),
    Value<double?> ocrMeanConfidence = const Value.absent(),
    String? langHint,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Scan(
    id: id ?? this.id,
    type: type ?? this.type,
    kind: kind ?? this.kind,
    language: language ?? this.language,
    checkCount: checkCount ?? this.checkCount,
    renewBy: renewBy.present ? renewBy.value : this.renewBy,
    imagePath: imagePath ?? this.imagePath,
    thumbPath: thumbPath.present ? thumbPath.value : this.thumbPath,
    ocrRawText: ocrRawText ?? this.ocrRawText,
    ocrEngine: ocrEngine.present ? ocrEngine.value : this.ocrEngine,
    ocrMeanConfidence: ocrMeanConfidence.present
        ? ocrMeanConfidence.value
        : this.ocrMeanConfidence,
    langHint: langHint ?? this.langHint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Scan copyWithCompanion(ScansCompanion data) {
    return Scan(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      kind: data.kind.present ? data.kind.value : this.kind,
      language: data.language.present ? data.language.value : this.language,
      checkCount: data.checkCount.present
          ? data.checkCount.value
          : this.checkCount,
      renewBy: data.renewBy.present ? data.renewBy.value : this.renewBy,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
      ocrRawText: data.ocrRawText.present
          ? data.ocrRawText.value
          : this.ocrRawText,
      ocrEngine: data.ocrEngine.present ? data.ocrEngine.value : this.ocrEngine,
      ocrMeanConfidence: data.ocrMeanConfidence.present
          ? data.ocrMeanConfidence.value
          : this.ocrMeanConfidence,
      langHint: data.langHint.present ? data.langHint.value : this.langHint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scan(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('kind: $kind, ')
          ..write('language: $language, ')
          ..write('checkCount: $checkCount, ')
          ..write('renewBy: $renewBy, ')
          ..write('imagePath: $imagePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('ocrRawText: $ocrRawText, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('ocrMeanConfidence: $ocrMeanConfidence, ')
          ..write('langHint: $langHint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    kind,
    language,
    checkCount,
    renewBy,
    imagePath,
    thumbPath,
    ocrRawText,
    ocrEngine,
    ocrMeanConfidence,
    langHint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scan &&
          other.id == this.id &&
          other.type == this.type &&
          other.kind == this.kind &&
          other.language == this.language &&
          other.checkCount == this.checkCount &&
          other.renewBy == this.renewBy &&
          other.imagePath == this.imagePath &&
          other.thumbPath == this.thumbPath &&
          other.ocrRawText == this.ocrRawText &&
          other.ocrEngine == this.ocrEngine &&
          other.ocrMeanConfidence == this.ocrMeanConfidence &&
          other.langHint == this.langHint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScansCompanion extends UpdateCompanion<Scan> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> kind;
  final Value<String> language;
  final Value<int> checkCount;
  final Value<DateTime?> renewBy;
  final Value<String> imagePath;
  final Value<String?> thumbPath;
  final Value<String> ocrRawText;
  final Value<String?> ocrEngine;
  final Value<double?> ocrMeanConfidence;
  final Value<String> langHint;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ScansCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.kind = const Value.absent(),
    this.language = const Value.absent(),
    this.checkCount = const Value.absent(),
    this.renewBy = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.ocrRawText = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrMeanConfidence = const Value.absent(),
    this.langHint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScansCompanion.insert({
    required String id,
    required String type,
    this.kind = const Value.absent(),
    this.language = const Value.absent(),
    this.checkCount = const Value.absent(),
    this.renewBy = const Value.absent(),
    required String imagePath,
    this.thumbPath = const Value.absent(),
    this.ocrRawText = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrMeanConfidence = const Value.absent(),
    this.langHint = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       imagePath = Value(imagePath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Scan> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? kind,
    Expression<String>? language,
    Expression<int>? checkCount,
    Expression<DateTime>? renewBy,
    Expression<String>? imagePath,
    Expression<String>? thumbPath,
    Expression<String>? ocrRawText,
    Expression<String>? ocrEngine,
    Expression<double>? ocrMeanConfidence,
    Expression<String>? langHint,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (kind != null) 'kind': kind,
      if (language != null) 'language': language,
      if (checkCount != null) 'check_count': checkCount,
      if (renewBy != null) 'renew_by': renewBy,
      if (imagePath != null) 'image_path': imagePath,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (ocrRawText != null) 'ocr_raw_text': ocrRawText,
      if (ocrEngine != null) 'ocr_engine': ocrEngine,
      if (ocrMeanConfidence != null) 'ocr_mean_confidence': ocrMeanConfidence,
      if (langHint != null) 'lang_hint': langHint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScansCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? kind,
    Value<String>? language,
    Value<int>? checkCount,
    Value<DateTime?>? renewBy,
    Value<String>? imagePath,
    Value<String?>? thumbPath,
    Value<String>? ocrRawText,
    Value<String?>? ocrEngine,
    Value<double?>? ocrMeanConfidence,
    Value<String>? langHint,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ScansCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      language: language ?? this.language,
      checkCount: checkCount ?? this.checkCount,
      renewBy: renewBy ?? this.renewBy,
      imagePath: imagePath ?? this.imagePath,
      thumbPath: thumbPath ?? this.thumbPath,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      ocrEngine: ocrEngine ?? this.ocrEngine,
      ocrMeanConfidence: ocrMeanConfidence ?? this.ocrMeanConfidence,
      langHint: langHint ?? this.langHint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (checkCount.present) {
      map['check_count'] = Variable<int>(checkCount.value);
    }
    if (renewBy.present) {
      map['renew_by'] = Variable<DateTime>(renewBy.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (ocrRawText.present) {
      map['ocr_raw_text'] = Variable<String>(ocrRawText.value);
    }
    if (ocrEngine.present) {
      map['ocr_engine'] = Variable<String>(ocrEngine.value);
    }
    if (ocrMeanConfidence.present) {
      map['ocr_mean_confidence'] = Variable<double>(ocrMeanConfidence.value);
    }
    if (langHint.present) {
      map['lang_hint'] = Variable<String>(langHint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScansCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('kind: $kind, ')
          ..write('language: $language, ')
          ..write('checkCount: $checkCount, ')
          ..write('renewBy: $renewBy, ')
          ..write('imagePath: $imagePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('ocrRawText: $ocrRawText, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('ocrMeanConfidence: $ocrMeanConfidence, ')
          ..write('langHint: $langHint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanPagesTable extends ScanPages
    with TableInfo<$ScanPagesTable, ScanPage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processedPathMeta = const VerificationMeta(
    'processedPath',
  );
  @override
  late final GeneratedColumn<String> processedPath = GeneratedColumn<String>(
    'processed_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filterMeta = const VerificationMeta('filter');
  @override
  late final GeneratedColumn<String> filter = GeneratedColumn<String>(
    'filter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _quadJsonMeta = const VerificationMeta(
    'quadJson',
  );
  @override
  late final GeneratedColumn<String> quadJson = GeneratedColumn<String>(
    'quad_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<int> rotation = GeneratedColumn<int>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanId,
    imagePath,
    processedPath,
    pageIndex,
    filter,
    quadJson,
    rotation,
    side,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanPage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('processed_path')) {
      context.handle(
        _processedPathMeta,
        processedPath.isAcceptableOrUnknown(
          data['processed_path']!,
          _processedPathMeta,
        ),
      );
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('filter')) {
      context.handle(
        _filterMeta,
        filter.isAcceptableOrUnknown(data['filter']!, _filterMeta),
      );
    }
    if (data.containsKey('quad_json')) {
      context.handle(
        _quadJsonMeta,
        quadJson.isAcceptableOrUnknown(data['quad_json']!, _quadJsonMeta),
      );
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanPage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanPage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      processedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processed_path'],
      ),
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      filter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter'],
      )!,
      quadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quad_json'],
      ),
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rotation'],
      )!,
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      ),
    );
  }

  @override
  $ScanPagesTable createAlias(String alias) {
    return $ScanPagesTable(attachedDatabase, alias);
  }
}

class ScanPage extends DataClass implements Insertable<ScanPage> {
  final String id;
  final String scanId;
  final String imagePath;
  final String? processedPath;
  final int pageIndex;
  final String filter;
  final String? quadJson;
  final int rotation;
  final String? side;
  const ScanPage({
    required this.id,
    required this.scanId,
    required this.imagePath,
    this.processedPath,
    required this.pageIndex,
    required this.filter,
    this.quadJson,
    required this.rotation,
    this.side,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scan_id'] = Variable<String>(scanId);
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || processedPath != null) {
      map['processed_path'] = Variable<String>(processedPath);
    }
    map['page_index'] = Variable<int>(pageIndex);
    map['filter'] = Variable<String>(filter);
    if (!nullToAbsent || quadJson != null) {
      map['quad_json'] = Variable<String>(quadJson);
    }
    map['rotation'] = Variable<int>(rotation);
    if (!nullToAbsent || side != null) {
      map['side'] = Variable<String>(side);
    }
    return map;
  }

  ScanPagesCompanion toCompanion(bool nullToAbsent) {
    return ScanPagesCompanion(
      id: Value(id),
      scanId: Value(scanId),
      imagePath: Value(imagePath),
      processedPath: processedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(processedPath),
      pageIndex: Value(pageIndex),
      filter: Value(filter),
      quadJson: quadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(quadJson),
      rotation: Value(rotation),
      side: side == null && nullToAbsent ? const Value.absent() : Value(side),
    );
  }

  factory ScanPage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanPage(
      id: serializer.fromJson<String>(json['id']),
      scanId: serializer.fromJson<String>(json['scanId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      processedPath: serializer.fromJson<String?>(json['processedPath']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      filter: serializer.fromJson<String>(json['filter']),
      quadJson: serializer.fromJson<String?>(json['quadJson']),
      rotation: serializer.fromJson<int>(json['rotation']),
      side: serializer.fromJson<String?>(json['side']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scanId': serializer.toJson<String>(scanId),
      'imagePath': serializer.toJson<String>(imagePath),
      'processedPath': serializer.toJson<String?>(processedPath),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'filter': serializer.toJson<String>(filter),
      'quadJson': serializer.toJson<String?>(quadJson),
      'rotation': serializer.toJson<int>(rotation),
      'side': serializer.toJson<String?>(side),
    };
  }

  ScanPage copyWith({
    String? id,
    String? scanId,
    String? imagePath,
    Value<String?> processedPath = const Value.absent(),
    int? pageIndex,
    String? filter,
    Value<String?> quadJson = const Value.absent(),
    int? rotation,
    Value<String?> side = const Value.absent(),
  }) => ScanPage(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    imagePath: imagePath ?? this.imagePath,
    processedPath: processedPath.present
        ? processedPath.value
        : this.processedPath,
    pageIndex: pageIndex ?? this.pageIndex,
    filter: filter ?? this.filter,
    quadJson: quadJson.present ? quadJson.value : this.quadJson,
    rotation: rotation ?? this.rotation,
    side: side.present ? side.value : this.side,
  );
  ScanPage copyWithCompanion(ScanPagesCompanion data) {
    return ScanPage(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      processedPath: data.processedPath.present
          ? data.processedPath.value
          : this.processedPath,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      filter: data.filter.present ? data.filter.value : this.filter,
      quadJson: data.quadJson.present ? data.quadJson.value : this.quadJson,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      side: data.side.present ? data.side.value : this.side,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanPage(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('imagePath: $imagePath, ')
          ..write('processedPath: $processedPath, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('filter: $filter, ')
          ..write('quadJson: $quadJson, ')
          ..write('rotation: $rotation, ')
          ..write('side: $side')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scanId,
    imagePath,
    processedPath,
    pageIndex,
    filter,
    quadJson,
    rotation,
    side,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanPage &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.imagePath == this.imagePath &&
          other.processedPath == this.processedPath &&
          other.pageIndex == this.pageIndex &&
          other.filter == this.filter &&
          other.quadJson == this.quadJson &&
          other.rotation == this.rotation &&
          other.side == this.side);
}

class ScanPagesCompanion extends UpdateCompanion<ScanPage> {
  final Value<String> id;
  final Value<String> scanId;
  final Value<String> imagePath;
  final Value<String?> processedPath;
  final Value<int> pageIndex;
  final Value<String> filter;
  final Value<String?> quadJson;
  final Value<int> rotation;
  final Value<String?> side;
  final Value<int> rowid;
  const ScanPagesCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.processedPath = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.filter = const Value.absent(),
    this.quadJson = const Value.absent(),
    this.rotation = const Value.absent(),
    this.side = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanPagesCompanion.insert({
    required String id,
    required String scanId,
    required String imagePath,
    this.processedPath = const Value.absent(),
    required int pageIndex,
    this.filter = const Value.absent(),
    this.quadJson = const Value.absent(),
    this.rotation = const Value.absent(),
    this.side = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scanId = Value(scanId),
       imagePath = Value(imagePath),
       pageIndex = Value(pageIndex);
  static Insertable<ScanPage> custom({
    Expression<String>? id,
    Expression<String>? scanId,
    Expression<String>? imagePath,
    Expression<String>? processedPath,
    Expression<int>? pageIndex,
    Expression<String>? filter,
    Expression<String>? quadJson,
    Expression<int>? rotation,
    Expression<String>? side,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (imagePath != null) 'image_path': imagePath,
      if (processedPath != null) 'processed_path': processedPath,
      if (pageIndex != null) 'page_index': pageIndex,
      if (filter != null) 'filter': filter,
      if (quadJson != null) 'quad_json': quadJson,
      if (rotation != null) 'rotation': rotation,
      if (side != null) 'side': side,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanPagesCompanion copyWith({
    Value<String>? id,
    Value<String>? scanId,
    Value<String>? imagePath,
    Value<String?>? processedPath,
    Value<int>? pageIndex,
    Value<String>? filter,
    Value<String?>? quadJson,
    Value<int>? rotation,
    Value<String?>? side,
    Value<int>? rowid,
  }) {
    return ScanPagesCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      imagePath: imagePath ?? this.imagePath,
      processedPath: processedPath ?? this.processedPath,
      pageIndex: pageIndex ?? this.pageIndex,
      filter: filter ?? this.filter,
      quadJson: quadJson ?? this.quadJson,
      rotation: rotation ?? this.rotation,
      side: side ?? this.side,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (processedPath.present) {
      map['processed_path'] = Variable<String>(processedPath.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (filter.present) {
      map['filter'] = Variable<String>(filter.value);
    }
    if (quadJson.present) {
      map['quad_json'] = Variable<String>(quadJson.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<int>(rotation.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanPagesCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('imagePath: $imagePath, ')
          ..write('processedPath: $processedPath, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('filter: $filter, ')
          ..write('quadJson: $quadJson, ')
          ..write('rotation: $rotation, ')
          ..write('side: $side, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameBnMeta = const VerificationMeta('nameBn');
  @override
  late final GeneratedColumn<String> nameBn = GeneratedColumn<String>(
    'name_bn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, nameEn, nameBn, icon, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name_en')) {
      context.handle(
        _nameEnMeta,
        nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameEnMeta);
    }
    if (data.containsKey('name_bn')) {
      context.handle(
        _nameBnMeta,
        nameBn.isAcceptableOrUnknown(data['name_bn']!, _nameBnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameBnMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_en'],
      )!,
      nameBn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_bn'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String nameEn;
  final String nameBn;
  final String icon;
  final bool isDefault;
  const Category({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.icon,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name_en'] = Variable<String>(nameEn);
    map['name_bn'] = Variable<String>(nameBn);
    map['icon'] = Variable<String>(icon);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      nameEn: Value(nameEn),
      nameBn: Value(nameBn),
      icon: Value(icon),
      isDefault: Value(isDefault),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      nameBn: serializer.fromJson<String>(json['nameBn']),
      icon: serializer.fromJson<String>(json['icon']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nameEn': serializer.toJson<String>(nameEn),
      'nameBn': serializer.toJson<String>(nameBn),
      'icon': serializer.toJson<String>(icon),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  Category copyWith({
    String? id,
    String? nameEn,
    String? nameBn,
    String? icon,
    bool? isDefault,
  }) => Category(
    id: id ?? this.id,
    nameEn: nameEn ?? this.nameEn,
    nameBn: nameBn ?? this.nameBn,
    icon: icon ?? this.icon,
    isDefault: isDefault ?? this.isDefault,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      nameBn: data.nameBn.present ? data.nameBn.value : this.nameBn,
      icon: data.icon.present ? data.icon.value : this.icon,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('nameEn: $nameEn, ')
          ..write('nameBn: $nameBn, ')
          ..write('icon: $icon, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nameEn, nameBn, icon, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.nameEn == this.nameEn &&
          other.nameBn == this.nameBn &&
          other.icon == this.icon &&
          other.isDefault == this.isDefault);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> nameEn;
  final Value<String> nameBn;
  final Value<String> icon;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.nameBn = const Value.absent(),
    this.icon = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String nameEn,
    required String nameBn,
    required String icon,
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nameEn = Value(nameEn),
       nameBn = Value(nameBn),
       icon = Value(icon);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? nameEn,
    Expression<String>? nameBn,
    Expression<String>? icon,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nameEn != null) 'name_en': nameEn,
      if (nameBn != null) 'name_bn': nameBn,
      if (icon != null) 'icon': icon,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? nameEn,
    Value<String>? nameBn,
    Value<String>? icon,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameBn: nameBn ?? this.nameBn,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (nameBn.present) {
      map['name_bn'] = Variable<String>(nameBn.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('nameEn: $nameEn, ')
          ..write('nameBn: $nameBn, ')
          ..write('icon: $icon, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptsTable extends Receipts with TableInfo<$ReceiptsTable, Receipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateOfPurchaseMeta = const VerificationMeta(
    'dateOfPurchase',
  );
  @override
  late final GeneratedColumn<DateTime> dateOfPurchase =
      GeneratedColumn<DateTime>(
        'date_of_purchase',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('BDT'),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<double> tax = GeneratedColumn<double>(
    'tax',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldConfidenceJsonMeta =
      const VerificationMeta('fieldConfidenceJson');
  @override
  late final GeneratedColumn<String> fieldConfidenceJson =
      GeneratedColumn<String>(
        'field_confidence_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanId,
    merchant,
    dateOfPurchase,
    total,
    currency,
    tax,
    paymentMethod,
    categoryId,
    note,
    fieldConfidenceJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Receipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantMeta);
    }
    if (data.containsKey('date_of_purchase')) {
      context.handle(
        _dateOfPurchaseMeta,
        dateOfPurchase.isAcceptableOrUnknown(
          data['date_of_purchase']!,
          _dateOfPurchaseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateOfPurchaseMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('field_confidence_json')) {
      context.handle(
        _fieldConfidenceJsonMeta,
        fieldConfidenceJson.isAcceptableOrUnknown(
          data['field_confidence_json']!,
          _fieldConfidenceJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Receipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Receipt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      )!,
      dateOfPurchase: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_of_purchase'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      fieldConfidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_confidence_json'],
      )!,
    );
  }

  @override
  $ReceiptsTable createAlias(String alias) {
    return $ReceiptsTable(attachedDatabase, alias);
  }
}

class Receipt extends DataClass implements Insertable<Receipt> {
  final String id;
  final String scanId;
  final String merchant;
  final DateTime dateOfPurchase;
  final double total;
  final String currency;
  final double? tax;
  final String? paymentMethod;
  final String? categoryId;
  final String? note;
  final String fieldConfidenceJson;
  const Receipt({
    required this.id,
    required this.scanId,
    required this.merchant,
    required this.dateOfPurchase,
    required this.total,
    required this.currency,
    this.tax,
    this.paymentMethod,
    this.categoryId,
    this.note,
    required this.fieldConfidenceJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scan_id'] = Variable<String>(scanId);
    map['merchant'] = Variable<String>(merchant);
    map['date_of_purchase'] = Variable<DateTime>(dateOfPurchase);
    map['total'] = Variable<double>(total);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || tax != null) {
      map['tax'] = Variable<double>(tax);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['field_confidence_json'] = Variable<String>(fieldConfidenceJson);
    return map;
  }

  ReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptsCompanion(
      id: Value(id),
      scanId: Value(scanId),
      merchant: Value(merchant),
      dateOfPurchase: Value(dateOfPurchase),
      total: Value(total),
      currency: Value(currency),
      tax: tax == null && nullToAbsent ? const Value.absent() : Value(tax),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      fieldConfidenceJson: Value(fieldConfidenceJson),
    );
  }

  factory Receipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Receipt(
      id: serializer.fromJson<String>(json['id']),
      scanId: serializer.fromJson<String>(json['scanId']),
      merchant: serializer.fromJson<String>(json['merchant']),
      dateOfPurchase: serializer.fromJson<DateTime>(json['dateOfPurchase']),
      total: serializer.fromJson<double>(json['total']),
      currency: serializer.fromJson<String>(json['currency']),
      tax: serializer.fromJson<double?>(json['tax']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      note: serializer.fromJson<String?>(json['note']),
      fieldConfidenceJson: serializer.fromJson<String>(
        json['fieldConfidenceJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scanId': serializer.toJson<String>(scanId),
      'merchant': serializer.toJson<String>(merchant),
      'dateOfPurchase': serializer.toJson<DateTime>(dateOfPurchase),
      'total': serializer.toJson<double>(total),
      'currency': serializer.toJson<String>(currency),
      'tax': serializer.toJson<double?>(tax),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'categoryId': serializer.toJson<String?>(categoryId),
      'note': serializer.toJson<String?>(note),
      'fieldConfidenceJson': serializer.toJson<String>(fieldConfidenceJson),
    };
  }

  Receipt copyWith({
    String? id,
    String? scanId,
    String? merchant,
    DateTime? dateOfPurchase,
    double? total,
    String? currency,
    Value<double?> tax = const Value.absent(),
    Value<String?> paymentMethod = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? fieldConfidenceJson,
  }) => Receipt(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    merchant: merchant ?? this.merchant,
    dateOfPurchase: dateOfPurchase ?? this.dateOfPurchase,
    total: total ?? this.total,
    currency: currency ?? this.currency,
    tax: tax.present ? tax.value : this.tax,
    paymentMethod: paymentMethod.present
        ? paymentMethod.value
        : this.paymentMethod,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    note: note.present ? note.value : this.note,
    fieldConfidenceJson: fieldConfidenceJson ?? this.fieldConfidenceJson,
  );
  Receipt copyWithCompanion(ReceiptsCompanion data) {
    return Receipt(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      dateOfPurchase: data.dateOfPurchase.present
          ? data.dateOfPurchase.value
          : this.dateOfPurchase,
      total: data.total.present ? data.total.value : this.total,
      currency: data.currency.present ? data.currency.value : this.currency,
      tax: data.tax.present ? data.tax.value : this.tax,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      note: data.note.present ? data.note.value : this.note,
      fieldConfidenceJson: data.fieldConfidenceJson.present
          ? data.fieldConfidenceJson.value
          : this.fieldConfidenceJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Receipt(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('merchant: $merchant, ')
          ..write('dateOfPurchase: $dateOfPurchase, ')
          ..write('total: $total, ')
          ..write('currency: $currency, ')
          ..write('tax: $tax, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('fieldConfidenceJson: $fieldConfidenceJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scanId,
    merchant,
    dateOfPurchase,
    total,
    currency,
    tax,
    paymentMethod,
    categoryId,
    note,
    fieldConfidenceJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Receipt &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.merchant == this.merchant &&
          other.dateOfPurchase == this.dateOfPurchase &&
          other.total == this.total &&
          other.currency == this.currency &&
          other.tax == this.tax &&
          other.paymentMethod == this.paymentMethod &&
          other.categoryId == this.categoryId &&
          other.note == this.note &&
          other.fieldConfidenceJson == this.fieldConfidenceJson);
}

class ReceiptsCompanion extends UpdateCompanion<Receipt> {
  final Value<String> id;
  final Value<String> scanId;
  final Value<String> merchant;
  final Value<DateTime> dateOfPurchase;
  final Value<double> total;
  final Value<String> currency;
  final Value<double?> tax;
  final Value<String?> paymentMethod;
  final Value<String?> categoryId;
  final Value<String?> note;
  final Value<String> fieldConfidenceJson;
  final Value<int> rowid;
  const ReceiptsCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.dateOfPurchase = const Value.absent(),
    this.total = const Value.absent(),
    this.currency = const Value.absent(),
    this.tax = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.fieldConfidenceJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptsCompanion.insert({
    required String id,
    required String scanId,
    required String merchant,
    required DateTime dateOfPurchase,
    required double total,
    this.currency = const Value.absent(),
    this.tax = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.fieldConfidenceJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scanId = Value(scanId),
       merchant = Value(merchant),
       dateOfPurchase = Value(dateOfPurchase),
       total = Value(total);
  static Insertable<Receipt> custom({
    Expression<String>? id,
    Expression<String>? scanId,
    Expression<String>? merchant,
    Expression<DateTime>? dateOfPurchase,
    Expression<double>? total,
    Expression<String>? currency,
    Expression<double>? tax,
    Expression<String>? paymentMethod,
    Expression<String>? categoryId,
    Expression<String>? note,
    Expression<String>? fieldConfidenceJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (merchant != null) 'merchant': merchant,
      if (dateOfPurchase != null) 'date_of_purchase': dateOfPurchase,
      if (total != null) 'total': total,
      if (currency != null) 'currency': currency,
      if (tax != null) 'tax': tax,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null) 'note': note,
      if (fieldConfidenceJson != null)
        'field_confidence_json': fieldConfidenceJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptsCompanion copyWith({
    Value<String>? id,
    Value<String>? scanId,
    Value<String>? merchant,
    Value<DateTime>? dateOfPurchase,
    Value<double>? total,
    Value<String>? currency,
    Value<double?>? tax,
    Value<String?>? paymentMethod,
    Value<String?>? categoryId,
    Value<String?>? note,
    Value<String>? fieldConfidenceJson,
    Value<int>? rowid,
  }) {
    return ReceiptsCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      merchant: merchant ?? this.merchant,
      dateOfPurchase: dateOfPurchase ?? this.dateOfPurchase,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      tax: tax ?? this.tax,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      fieldConfidenceJson: fieldConfidenceJson ?? this.fieldConfidenceJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (dateOfPurchase.present) {
      map['date_of_purchase'] = Variable<DateTime>(dateOfPurchase.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (tax.present) {
      map['tax'] = Variable<double>(tax.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (fieldConfidenceJson.present) {
      map['field_confidence_json'] = Variable<String>(
        fieldConfidenceJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('merchant: $merchant, ')
          ..write('dateOfPurchase: $dateOfPurchase, ')
          ..write('total: $total, ')
          ..write('currency: $currency, ')
          ..write('tax: $tax, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('fieldConfidenceJson: $fieldConfidenceJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LineItemsTable extends LineItems
    with TableInfo<$LineItemsTable, LineItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LineItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    receiptId,
    name,
    qty,
    unitPrice,
    amount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'line_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LineItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LineItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LineItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $LineItemsTable createAlias(String alias) {
    return $LineItemsTable(attachedDatabase, alias);
  }
}

class LineItem extends DataClass implements Insertable<LineItem> {
  final String id;
  final String receiptId;
  final String name;
  final double qty;
  final double? unitPrice;
  final double amount;
  const LineItem({
    required this.id,
    required this.receiptId,
    required this.name,
    required this.qty,
    this.unitPrice,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['receipt_id'] = Variable<String>(receiptId);
    map['name'] = Variable<String>(name);
    map['qty'] = Variable<double>(qty);
    if (!nullToAbsent || unitPrice != null) {
      map['unit_price'] = Variable<double>(unitPrice);
    }
    map['amount'] = Variable<double>(amount);
    return map;
  }

  LineItemsCompanion toCompanion(bool nullToAbsent) {
    return LineItemsCompanion(
      id: Value(id),
      receiptId: Value(receiptId),
      name: Value(name),
      qty: Value(qty),
      unitPrice: unitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPrice),
      amount: Value(amount),
    );
  }

  factory LineItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LineItem(
      id: serializer.fromJson<String>(json['id']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      name: serializer.fromJson<String>(json['name']),
      qty: serializer.fromJson<double>(json['qty']),
      unitPrice: serializer.fromJson<double?>(json['unitPrice']),
      amount: serializer.fromJson<double>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'receiptId': serializer.toJson<String>(receiptId),
      'name': serializer.toJson<String>(name),
      'qty': serializer.toJson<double>(qty),
      'unitPrice': serializer.toJson<double?>(unitPrice),
      'amount': serializer.toJson<double>(amount),
    };
  }

  LineItem copyWith({
    String? id,
    String? receiptId,
    String? name,
    double? qty,
    Value<double?> unitPrice = const Value.absent(),
    double? amount,
  }) => LineItem(
    id: id ?? this.id,
    receiptId: receiptId ?? this.receiptId,
    name: name ?? this.name,
    qty: qty ?? this.qty,
    unitPrice: unitPrice.present ? unitPrice.value : this.unitPrice,
    amount: amount ?? this.amount,
  );
  LineItem copyWithCompanion(LineItemsCompanion data) {
    return LineItem(
      id: data.id.present ? data.id.value : this.id,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      name: data.name.present ? data.name.value : this.name,
      qty: data.qty.present ? data.qty.value : this.qty,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LineItem(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, receiptId, name, qty, unitPrice, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LineItem &&
          other.id == this.id &&
          other.receiptId == this.receiptId &&
          other.name == this.name &&
          other.qty == this.qty &&
          other.unitPrice == this.unitPrice &&
          other.amount == this.amount);
}

class LineItemsCompanion extends UpdateCompanion<LineItem> {
  final Value<String> id;
  final Value<String> receiptId;
  final Value<String> name;
  final Value<double> qty;
  final Value<double?> unitPrice;
  final Value<double> amount;
  final Value<int> rowid;
  const LineItemsCompanion({
    this.id = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.name = const Value.absent(),
    this.qty = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LineItemsCompanion.insert({
    required String id,
    required String receiptId,
    required String name,
    this.qty = const Value.absent(),
    this.unitPrice = const Value.absent(),
    required double amount,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       receiptId = Value(receiptId),
       name = Value(name),
       amount = Value(amount);
  static Insertable<LineItem> custom({
    Expression<String>? id,
    Expression<String>? receiptId,
    Expression<String>? name,
    Expression<double>? qty,
    Expression<double>? unitPrice,
    Expression<double>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiptId != null) 'receipt_id': receiptId,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LineItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? receiptId,
    Value<String>? name,
    Value<double>? qty,
    Value<double?>? unitPrice,
    Value<double>? amount,
    Value<int>? rowid,
  }) {
    return LineItemsCompanion(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LineItemsCompanion(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, scanId, title, body, pinned];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final String id;
  final String scanId;
  final String title;
  final String body;
  final bool pinned;
  const Document({
    required this.id,
    required this.scanId,
    required this.title,
    required this.body,
    required this.pinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scan_id'] = Variable<String>(scanId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['pinned'] = Variable<bool>(pinned);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      scanId: Value(scanId),
      title: Value(title),
      body: Value(body),
      pinned: Value(pinned),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<String>(json['id']),
      scanId: serializer.fromJson<String>(json['scanId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      pinned: serializer.fromJson<bool>(json['pinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scanId': serializer.toJson<String>(scanId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'pinned': serializer.toJson<bool>(pinned),
    };
  }

  Document copyWith({
    String? id,
    String? scanId,
    String? title,
    String? body,
    bool? pinned,
  }) => Document(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    title: title ?? this.title,
    body: body ?? this.body,
    pinned: pinned ?? this.pinned,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scanId, title, body, pinned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.title == this.title &&
          other.body == this.body &&
          other.pinned == this.pinned);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String> id;
  final Value<String> scanId;
  final Value<String> title;
  final Value<String> body;
  final Value<bool> pinned;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required String scanId,
    required String title,
    this.body = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scanId = Value(scanId),
       title = Value(title);
  static Insertable<Document> custom({
    Expression<String>? id,
    Expression<String>? scanId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<bool>? pinned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (pinned != null) 'pinned': pinned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? scanId,
    Value<String>? title,
    Value<String>? body,
    Value<bool>? pinned,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      title: title ?? this.title,
      body: body ?? this.body,
      pinned: pinned ?? this.pinned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('pinned: $pinned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  const Tag({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(id: Value(id), name: Value(name));
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Tag copyWith({String? id, String? name}) =>
      Tag(id: id ?? this.id, name: name ?? this.name);
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag && other.id == this.id && other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanTagsTable extends ScanTags with TableInfo<$ScanTagsTable, ScanTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [scanId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scanId, tagId};
  @override
  ScanTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanTag(
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $ScanTagsTable createAlias(String alias) {
    return $ScanTagsTable(attachedDatabase, alias);
  }
}

class ScanTag extends DataClass implements Insertable<ScanTag> {
  final String scanId;
  final String tagId;
  const ScanTag({required this.scanId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scan_id'] = Variable<String>(scanId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  ScanTagsCompanion toCompanion(bool nullToAbsent) {
    return ScanTagsCompanion(scanId: Value(scanId), tagId: Value(tagId));
  }

  factory ScanTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanTag(
      scanId: serializer.fromJson<String>(json['scanId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scanId': serializer.toJson<String>(scanId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  ScanTag copyWith({String? scanId, String? tagId}) =>
      ScanTag(scanId: scanId ?? this.scanId, tagId: tagId ?? this.tagId);
  ScanTag copyWithCompanion(ScanTagsCompanion data) {
    return ScanTag(
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanTag(')
          ..write('scanId: $scanId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scanId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanTag &&
          other.scanId == this.scanId &&
          other.tagId == this.tagId);
}

class ScanTagsCompanion extends UpdateCompanion<ScanTag> {
  final Value<String> scanId;
  final Value<String> tagId;
  final Value<int> rowid;
  const ScanTagsCompanion({
    this.scanId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanTagsCompanion.insert({
    required String scanId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : scanId = Value(scanId),
       tagId = Value(tagId);
  static Insertable<ScanTag> custom({
    Expression<String>? scanId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scanId != null) 'scan_id': scanId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanTagsCompanion copyWith({
    Value<String>? scanId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return ScanTagsCompanion(
      scanId: scanId ?? this.scanId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanTagsCompanion(')
          ..write('scanId: $scanId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TextLinesTable extends TextLines
    with TableInfo<$TextLinesTable, TextLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineOrderMeta = const VerificationMeta(
    'lineOrder',
  );
  @override
  late final GeneratedColumn<int> lineOrder = GeneratedColumn<int>(
    'line_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxJsonMeta = const VerificationMeta(
    'boxJson',
  );
  @override
  late final GeneratedColumn<String> boxJson = GeneratedColumn<String>(
    'box_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _scriptMeta = const VerificationMeta('script');
  @override
  late final GeneratedColumn<String> script = GeneratedColumn<String>(
    'script',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bn'),
  );
  static const VerificationMeta _correctedMeta = const VerificationMeta(
    'corrected',
  );
  @override
  late final GeneratedColumn<bool> corrected = GeneratedColumn<bool>(
    'corrected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("corrected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanId,
    pageIndex,
    lineOrder,
    textContent,
    boxJson,
    confidence,
    script,
    corrected,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('line_order')) {
      context.handle(
        _lineOrderMeta,
        lineOrder.isAcceptableOrUnknown(data['line_order']!, _lineOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_lineOrderMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('box_json')) {
      context.handle(
        _boxJsonMeta,
        boxJson.isAcceptableOrUnknown(data['box_json']!, _boxJsonMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('script')) {
      context.handle(
        _scriptMeta,
        script.isAcceptableOrUnknown(data['script']!, _scriptMeta),
      );
    }
    if (data.containsKey('corrected')) {
      context.handle(
        _correctedMeta,
        corrected.isAcceptableOrUnknown(data['corrected']!, _correctedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TextLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      lineOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_order'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      )!,
      boxJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}box_json'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      script: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script'],
      )!,
      corrected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}corrected'],
      )!,
    );
  }

  @override
  $TextLinesTable createAlias(String alias) {
    return $TextLinesTable(attachedDatabase, alias);
  }
}

class TextLine extends DataClass implements Insertable<TextLine> {
  final String id;
  final String scanId;
  final int pageIndex;
  final int lineOrder;
  final String textContent;
  final String boxJson;
  final double confidence;
  final String script;
  final bool corrected;
  const TextLine({
    required this.id,
    required this.scanId,
    required this.pageIndex,
    required this.lineOrder,
    required this.textContent,
    required this.boxJson,
    required this.confidence,
    required this.script,
    required this.corrected,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scan_id'] = Variable<String>(scanId);
    map['page_index'] = Variable<int>(pageIndex);
    map['line_order'] = Variable<int>(lineOrder);
    map['text_content'] = Variable<String>(textContent);
    map['box_json'] = Variable<String>(boxJson);
    map['confidence'] = Variable<double>(confidence);
    map['script'] = Variable<String>(script);
    map['corrected'] = Variable<bool>(corrected);
    return map;
  }

  TextLinesCompanion toCompanion(bool nullToAbsent) {
    return TextLinesCompanion(
      id: Value(id),
      scanId: Value(scanId),
      pageIndex: Value(pageIndex),
      lineOrder: Value(lineOrder),
      textContent: Value(textContent),
      boxJson: Value(boxJson),
      confidence: Value(confidence),
      script: Value(script),
      corrected: Value(corrected),
    );
  }

  factory TextLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextLine(
      id: serializer.fromJson<String>(json['id']),
      scanId: serializer.fromJson<String>(json['scanId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      lineOrder: serializer.fromJson<int>(json['lineOrder']),
      textContent: serializer.fromJson<String>(json['textContent']),
      boxJson: serializer.fromJson<String>(json['boxJson']),
      confidence: serializer.fromJson<double>(json['confidence']),
      script: serializer.fromJson<String>(json['script']),
      corrected: serializer.fromJson<bool>(json['corrected']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scanId': serializer.toJson<String>(scanId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'lineOrder': serializer.toJson<int>(lineOrder),
      'textContent': serializer.toJson<String>(textContent),
      'boxJson': serializer.toJson<String>(boxJson),
      'confidence': serializer.toJson<double>(confidence),
      'script': serializer.toJson<String>(script),
      'corrected': serializer.toJson<bool>(corrected),
    };
  }

  TextLine copyWith({
    String? id,
    String? scanId,
    int? pageIndex,
    int? lineOrder,
    String? textContent,
    String? boxJson,
    double? confidence,
    String? script,
    bool? corrected,
  }) => TextLine(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    pageIndex: pageIndex ?? this.pageIndex,
    lineOrder: lineOrder ?? this.lineOrder,
    textContent: textContent ?? this.textContent,
    boxJson: boxJson ?? this.boxJson,
    confidence: confidence ?? this.confidence,
    script: script ?? this.script,
    corrected: corrected ?? this.corrected,
  );
  TextLine copyWithCompanion(TextLinesCompanion data) {
    return TextLine(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      lineOrder: data.lineOrder.present ? data.lineOrder.value : this.lineOrder,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      boxJson: data.boxJson.present ? data.boxJson.value : this.boxJson,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      script: data.script.present ? data.script.value : this.script,
      corrected: data.corrected.present ? data.corrected.value : this.corrected,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextLine(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('lineOrder: $lineOrder, ')
          ..write('textContent: $textContent, ')
          ..write('boxJson: $boxJson, ')
          ..write('confidence: $confidence, ')
          ..write('script: $script, ')
          ..write('corrected: $corrected')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scanId,
    pageIndex,
    lineOrder,
    textContent,
    boxJson,
    confidence,
    script,
    corrected,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextLine &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.pageIndex == this.pageIndex &&
          other.lineOrder == this.lineOrder &&
          other.textContent == this.textContent &&
          other.boxJson == this.boxJson &&
          other.confidence == this.confidence &&
          other.script == this.script &&
          other.corrected == this.corrected);
}

class TextLinesCompanion extends UpdateCompanion<TextLine> {
  final Value<String> id;
  final Value<String> scanId;
  final Value<int> pageIndex;
  final Value<int> lineOrder;
  final Value<String> textContent;
  final Value<String> boxJson;
  final Value<double> confidence;
  final Value<String> script;
  final Value<bool> corrected;
  final Value<int> rowid;
  const TextLinesCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.lineOrder = const Value.absent(),
    this.textContent = const Value.absent(),
    this.boxJson = const Value.absent(),
    this.confidence = const Value.absent(),
    this.script = const Value.absent(),
    this.corrected = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextLinesCompanion.insert({
    required String id,
    required String scanId,
    required int pageIndex,
    required int lineOrder,
    required String textContent,
    this.boxJson = const Value.absent(),
    this.confidence = const Value.absent(),
    this.script = const Value.absent(),
    this.corrected = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scanId = Value(scanId),
       pageIndex = Value(pageIndex),
       lineOrder = Value(lineOrder),
       textContent = Value(textContent);
  static Insertable<TextLine> custom({
    Expression<String>? id,
    Expression<String>? scanId,
    Expression<int>? pageIndex,
    Expression<int>? lineOrder,
    Expression<String>? textContent,
    Expression<String>? boxJson,
    Expression<double>? confidence,
    Expression<String>? script,
    Expression<bool>? corrected,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (lineOrder != null) 'line_order': lineOrder,
      if (textContent != null) 'text_content': textContent,
      if (boxJson != null) 'box_json': boxJson,
      if (confidence != null) 'confidence': confidence,
      if (script != null) 'script': script,
      if (corrected != null) 'corrected': corrected,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? scanId,
    Value<int>? pageIndex,
    Value<int>? lineOrder,
    Value<String>? textContent,
    Value<String>? boxJson,
    Value<double>? confidence,
    Value<String>? script,
    Value<bool>? corrected,
    Value<int>? rowid,
  }) {
    return TextLinesCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      pageIndex: pageIndex ?? this.pageIndex,
      lineOrder: lineOrder ?? this.lineOrder,
      textContent: textContent ?? this.textContent,
      boxJson: boxJson ?? this.boxJson,
      confidence: confidence ?? this.confidence,
      script: script ?? this.script,
      corrected: corrected ?? this.corrected,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (lineOrder.present) {
      map['line_order'] = Variable<int>(lineOrder.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (boxJson.present) {
      map['box_json'] = Variable<String>(boxJson.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (script.present) {
      map['script'] = Variable<String>(script.value);
    }
    if (corrected.present) {
      map['corrected'] = Variable<bool>(corrected.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextLinesCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('lineOrder: $lineOrder, ')
          ..write('textContent: $textContent, ')
          ..write('boxJson: $boxJson, ')
          ..write('confidence: $confidence, ')
          ..write('script: $script, ')
          ..write('corrected: $corrected, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DetailsTable extends Details with TableInfo<$DetailsTable, Detail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _detailKeyMeta = const VerificationMeta(
    'detailKey',
  );
  @override
  late final GeneratedColumn<String> detailKey = GeneratedColumn<String>(
    'detail_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceLineIdMeta = const VerificationMeta(
    'sourceLineId',
  );
  @override
  late final GeneratedColumn<String> sourceLineId = GeneratedColumn<String>(
    'source_line_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES text_lines (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanId,
    detailKey,
    value,
    sourceLineId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'details';
  @override
  VerificationContext validateIntegrity(
    Insertable<Detail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('detail_key')) {
      context.handle(
        _detailKeyMeta,
        detailKey.isAcceptableOrUnknown(data['detail_key']!, _detailKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_detailKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('source_line_id')) {
      context.handle(
        _sourceLineIdMeta,
        sourceLineId.isAcceptableOrUnknown(
          data['source_line_id']!,
          _sourceLineIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Detail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Detail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      detailKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      sourceLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_line_id'],
      ),
    );
  }

  @override
  $DetailsTable createAlias(String alias) {
    return $DetailsTable(attachedDatabase, alias);
  }
}

class Detail extends DataClass implements Insertable<Detail> {
  final String id;
  final String scanId;
  final String detailKey;
  final String value;
  final String? sourceLineId;
  const Detail({
    required this.id,
    required this.scanId,
    required this.detailKey,
    required this.value,
    this.sourceLineId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scan_id'] = Variable<String>(scanId);
    map['detail_key'] = Variable<String>(detailKey);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || sourceLineId != null) {
      map['source_line_id'] = Variable<String>(sourceLineId);
    }
    return map;
  }

  DetailsCompanion toCompanion(bool nullToAbsent) {
    return DetailsCompanion(
      id: Value(id),
      scanId: Value(scanId),
      detailKey: Value(detailKey),
      value: Value(value),
      sourceLineId: sourceLineId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceLineId),
    );
  }

  factory Detail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Detail(
      id: serializer.fromJson<String>(json['id']),
      scanId: serializer.fromJson<String>(json['scanId']),
      detailKey: serializer.fromJson<String>(json['detailKey']),
      value: serializer.fromJson<String>(json['value']),
      sourceLineId: serializer.fromJson<String?>(json['sourceLineId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scanId': serializer.toJson<String>(scanId),
      'detailKey': serializer.toJson<String>(detailKey),
      'value': serializer.toJson<String>(value),
      'sourceLineId': serializer.toJson<String?>(sourceLineId),
    };
  }

  Detail copyWith({
    String? id,
    String? scanId,
    String? detailKey,
    String? value,
    Value<String?> sourceLineId = const Value.absent(),
  }) => Detail(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    detailKey: detailKey ?? this.detailKey,
    value: value ?? this.value,
    sourceLineId: sourceLineId.present ? sourceLineId.value : this.sourceLineId,
  );
  Detail copyWithCompanion(DetailsCompanion data) {
    return Detail(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      detailKey: data.detailKey.present ? data.detailKey.value : this.detailKey,
      value: data.value.present ? data.value.value : this.value,
      sourceLineId: data.sourceLineId.present
          ? data.sourceLineId.value
          : this.sourceLineId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Detail(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('detailKey: $detailKey, ')
          ..write('value: $value, ')
          ..write('sourceLineId: $sourceLineId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scanId, detailKey, value, sourceLineId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Detail &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.detailKey == this.detailKey &&
          other.value == this.value &&
          other.sourceLineId == this.sourceLineId);
}

class DetailsCompanion extends UpdateCompanion<Detail> {
  final Value<String> id;
  final Value<String> scanId;
  final Value<String> detailKey;
  final Value<String> value;
  final Value<String?> sourceLineId;
  final Value<int> rowid;
  const DetailsCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.detailKey = const Value.absent(),
    this.value = const Value.absent(),
    this.sourceLineId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DetailsCompanion.insert({
    required String id,
    required String scanId,
    required String detailKey,
    required String value,
    this.sourceLineId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scanId = Value(scanId),
       detailKey = Value(detailKey),
       value = Value(value);
  static Insertable<Detail> custom({
    Expression<String>? id,
    Expression<String>? scanId,
    Expression<String>? detailKey,
    Expression<String>? value,
    Expression<String>? sourceLineId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (detailKey != null) 'detail_key': detailKey,
      if (value != null) 'value': value,
      if (sourceLineId != null) 'source_line_id': sourceLineId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DetailsCompanion copyWith({
    Value<String>? id,
    Value<String>? scanId,
    Value<String>? detailKey,
    Value<String>? value,
    Value<String?>? sourceLineId,
    Value<int>? rowid,
  }) {
    return DetailsCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      detailKey: detailKey ?? this.detailKey,
      value: value ?? this.value,
      sourceLineId: sourceLineId ?? this.sourceLineId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (detailKey.present) {
      map['detail_key'] = Variable<String>(detailKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (sourceLineId.present) {
      map['source_line_id'] = Variable<String>(sourceLineId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DetailsCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('detailKey: $detailKey, ')
          ..write('value: $value, ')
          ..write('sourceLineId: $sourceLineId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranslationsTable extends Translations
    with TableInfo<$TranslationsTable, Translation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<String> scanId = GeneratedColumn<String>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES text_lines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lineOrderMeta = const VerificationMeta(
    'lineOrder',
  );
  @override
  late final GeneratedColumn<int> lineOrder = GeneratedColumn<int>(
    'line_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _englishTextMeta = const VerificationMeta(
    'englishText',
  );
  @override
  late final GeneratedColumn<String> englishText = GeneratedColumn<String>(
    'english_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flagsJsonMeta = const VerificationMeta(
    'flagsJson',
  );
  @override
  late final GeneratedColumn<String> flagsJson = GeneratedColumn<String>(
    'flags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
    'edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanId,
    lineId,
    lineOrder,
    sourceText,
    englishText,
    flagsJson,
    edited,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Translation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    }
    if (data.containsKey('line_order')) {
      context.handle(
        _lineOrderMeta,
        lineOrder.isAcceptableOrUnknown(data['line_order']!, _lineOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_lineOrderMeta);
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('english_text')) {
      context.handle(
        _englishTextMeta,
        englishText.isAcceptableOrUnknown(
          data['english_text']!,
          _englishTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_englishTextMeta);
    }
    if (data.containsKey('flags_json')) {
      context.handle(
        _flagsJsonMeta,
        flagsJson.isAcceptableOrUnknown(data['flags_json']!, _flagsJsonMeta),
      );
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Translation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Translation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_id'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      ),
      lineOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_order'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      )!,
      englishText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}english_text'],
      )!,
      flagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flags_json'],
      )!,
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
    );
  }

  @override
  $TranslationsTable createAlias(String alias) {
    return $TranslationsTable(attachedDatabase, alias);
  }
}

class Translation extends DataClass implements Insertable<Translation> {
  final String id;
  final String scanId;
  final String? lineId;
  final int lineOrder;
  final String sourceText;
  final String englishText;
  final String flagsJson;
  final bool edited;
  const Translation({
    required this.id,
    required this.scanId,
    this.lineId,
    required this.lineOrder,
    required this.sourceText,
    required this.englishText,
    required this.flagsJson,
    required this.edited,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scan_id'] = Variable<String>(scanId);
    if (!nullToAbsent || lineId != null) {
      map['line_id'] = Variable<String>(lineId);
    }
    map['line_order'] = Variable<int>(lineOrder);
    map['source_text'] = Variable<String>(sourceText);
    map['english_text'] = Variable<String>(englishText);
    map['flags_json'] = Variable<String>(flagsJson);
    map['edited'] = Variable<bool>(edited);
    return map;
  }

  TranslationsCompanion toCompanion(bool nullToAbsent) {
    return TranslationsCompanion(
      id: Value(id),
      scanId: Value(scanId),
      lineId: lineId == null && nullToAbsent
          ? const Value.absent()
          : Value(lineId),
      lineOrder: Value(lineOrder),
      sourceText: Value(sourceText),
      englishText: Value(englishText),
      flagsJson: Value(flagsJson),
      edited: Value(edited),
    );
  }

  factory Translation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Translation(
      id: serializer.fromJson<String>(json['id']),
      scanId: serializer.fromJson<String>(json['scanId']),
      lineId: serializer.fromJson<String?>(json['lineId']),
      lineOrder: serializer.fromJson<int>(json['lineOrder']),
      sourceText: serializer.fromJson<String>(json['sourceText']),
      englishText: serializer.fromJson<String>(json['englishText']),
      flagsJson: serializer.fromJson<String>(json['flagsJson']),
      edited: serializer.fromJson<bool>(json['edited']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scanId': serializer.toJson<String>(scanId),
      'lineId': serializer.toJson<String?>(lineId),
      'lineOrder': serializer.toJson<int>(lineOrder),
      'sourceText': serializer.toJson<String>(sourceText),
      'englishText': serializer.toJson<String>(englishText),
      'flagsJson': serializer.toJson<String>(flagsJson),
      'edited': serializer.toJson<bool>(edited),
    };
  }

  Translation copyWith({
    String? id,
    String? scanId,
    Value<String?> lineId = const Value.absent(),
    int? lineOrder,
    String? sourceText,
    String? englishText,
    String? flagsJson,
    bool? edited,
  }) => Translation(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    lineId: lineId.present ? lineId.value : this.lineId,
    lineOrder: lineOrder ?? this.lineOrder,
    sourceText: sourceText ?? this.sourceText,
    englishText: englishText ?? this.englishText,
    flagsJson: flagsJson ?? this.flagsJson,
    edited: edited ?? this.edited,
  );
  Translation copyWithCompanion(TranslationsCompanion data) {
    return Translation(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      lineOrder: data.lineOrder.present ? data.lineOrder.value : this.lineOrder,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      englishText: data.englishText.present
          ? data.englishText.value
          : this.englishText,
      flagsJson: data.flagsJson.present ? data.flagsJson.value : this.flagsJson,
      edited: data.edited.present ? data.edited.value : this.edited,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Translation(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('lineId: $lineId, ')
          ..write('lineOrder: $lineOrder, ')
          ..write('sourceText: $sourceText, ')
          ..write('englishText: $englishText, ')
          ..write('flagsJson: $flagsJson, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scanId,
    lineId,
    lineOrder,
    sourceText,
    englishText,
    flagsJson,
    edited,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Translation &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.lineId == this.lineId &&
          other.lineOrder == this.lineOrder &&
          other.sourceText == this.sourceText &&
          other.englishText == this.englishText &&
          other.flagsJson == this.flagsJson &&
          other.edited == this.edited);
}

class TranslationsCompanion extends UpdateCompanion<Translation> {
  final Value<String> id;
  final Value<String> scanId;
  final Value<String?> lineId;
  final Value<int> lineOrder;
  final Value<String> sourceText;
  final Value<String> englishText;
  final Value<String> flagsJson;
  final Value<bool> edited;
  final Value<int> rowid;
  const TranslationsCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.lineOrder = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.englishText = const Value.absent(),
    this.flagsJson = const Value.absent(),
    this.edited = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranslationsCompanion.insert({
    required String id,
    required String scanId,
    this.lineId = const Value.absent(),
    required int lineOrder,
    this.sourceText = const Value.absent(),
    required String englishText,
    this.flagsJson = const Value.absent(),
    this.edited = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scanId = Value(scanId),
       lineOrder = Value(lineOrder),
       englishText = Value(englishText);
  static Insertable<Translation> custom({
    Expression<String>? id,
    Expression<String>? scanId,
    Expression<String>? lineId,
    Expression<int>? lineOrder,
    Expression<String>? sourceText,
    Expression<String>? englishText,
    Expression<String>? flagsJson,
    Expression<bool>? edited,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (lineId != null) 'line_id': lineId,
      if (lineOrder != null) 'line_order': lineOrder,
      if (sourceText != null) 'source_text': sourceText,
      if (englishText != null) 'english_text': englishText,
      if (flagsJson != null) 'flags_json': flagsJson,
      if (edited != null) 'edited': edited,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranslationsCompanion copyWith({
    Value<String>? id,
    Value<String>? scanId,
    Value<String?>? lineId,
    Value<int>? lineOrder,
    Value<String>? sourceText,
    Value<String>? englishText,
    Value<String>? flagsJson,
    Value<bool>? edited,
    Value<int>? rowid,
  }) {
    return TranslationsCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      lineId: lineId ?? this.lineId,
      lineOrder: lineOrder ?? this.lineOrder,
      sourceText: sourceText ?? this.sourceText,
      englishText: englishText ?? this.englishText,
      flagsJson: flagsJson ?? this.flagsJson,
      edited: edited ?? this.edited,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<String>(scanId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (lineOrder.present) {
      map['line_order'] = Variable<int>(lineOrder.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (englishText.present) {
      map['english_text'] = Variable<String>(englishText.value);
    }
    if (flagsJson.present) {
      map['flags_json'] = Variable<String>(flagsJson.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationsCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('lineId: $lineId, ')
          ..write('lineOrder: $lineOrder, ')
          ..write('sourceText: $sourceText, ')
          ..write('englishText: $englishText, ')
          ..write('flagsJson: $flagsJson, ')
          ..write('edited: $edited, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NamesTable extends Names with TableInfo<$NamesTable, Name> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _banglaMeta = const VerificationMeta('bangla');
  @override
  late final GeneratedColumn<String> bangla = GeneratedColumn<String>(
    'bangla',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _englishMeta = const VerificationMeta(
    'english',
  );
  @override
  late final GeneratedColumn<String> english = GeneratedColumn<String>(
    'english',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('person'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('suggested'),
  );
  static const VerificationMeta _confirmedMeta = const VerificationMeta(
    'confirmed',
  );
  @override
  late final GeneratedColumn<bool> confirmed = GeneratedColumn<bool>(
    'confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("confirmed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bangla,
    english,
    category,
    source,
    confirmed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'names';
  @override
  VerificationContext validateIntegrity(
    Insertable<Name> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bangla')) {
      context.handle(
        _banglaMeta,
        bangla.isAcceptableOrUnknown(data['bangla']!, _banglaMeta),
      );
    } else if (isInserting) {
      context.missing(_banglaMeta);
    }
    if (data.containsKey('english')) {
      context.handle(
        _englishMeta,
        english.isAcceptableOrUnknown(data['english']!, _englishMeta),
      );
    } else if (isInserting) {
      context.missing(_englishMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('confirmed')) {
      context.handle(
        _confirmedMeta,
        confirmed.isAcceptableOrUnknown(data['confirmed']!, _confirmedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Name map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Name(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bangla: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bangla'],
      )!,
      english: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}english'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      confirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}confirmed'],
      )!,
    );
  }

  @override
  $NamesTable createAlias(String alias) {
    return $NamesTable(attachedDatabase, alias);
  }
}

class Name extends DataClass implements Insertable<Name> {
  final String id;
  final String bangla;
  final String english;
  final String category;
  final String source;
  final bool confirmed;
  const Name({
    required this.id,
    required this.bangla,
    required this.english,
    required this.category,
    required this.source,
    required this.confirmed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bangla'] = Variable<String>(bangla);
    map['english'] = Variable<String>(english);
    map['category'] = Variable<String>(category);
    map['source'] = Variable<String>(source);
    map['confirmed'] = Variable<bool>(confirmed);
    return map;
  }

  NamesCompanion toCompanion(bool nullToAbsent) {
    return NamesCompanion(
      id: Value(id),
      bangla: Value(bangla),
      english: Value(english),
      category: Value(category),
      source: Value(source),
      confirmed: Value(confirmed),
    );
  }

  factory Name.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Name(
      id: serializer.fromJson<String>(json['id']),
      bangla: serializer.fromJson<String>(json['bangla']),
      english: serializer.fromJson<String>(json['english']),
      category: serializer.fromJson<String>(json['category']),
      source: serializer.fromJson<String>(json['source']),
      confirmed: serializer.fromJson<bool>(json['confirmed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bangla': serializer.toJson<String>(bangla),
      'english': serializer.toJson<String>(english),
      'category': serializer.toJson<String>(category),
      'source': serializer.toJson<String>(source),
      'confirmed': serializer.toJson<bool>(confirmed),
    };
  }

  Name copyWith({
    String? id,
    String? bangla,
    String? english,
    String? category,
    String? source,
    bool? confirmed,
  }) => Name(
    id: id ?? this.id,
    bangla: bangla ?? this.bangla,
    english: english ?? this.english,
    category: category ?? this.category,
    source: source ?? this.source,
    confirmed: confirmed ?? this.confirmed,
  );
  Name copyWithCompanion(NamesCompanion data) {
    return Name(
      id: data.id.present ? data.id.value : this.id,
      bangla: data.bangla.present ? data.bangla.value : this.bangla,
      english: data.english.present ? data.english.value : this.english,
      category: data.category.present ? data.category.value : this.category,
      source: data.source.present ? data.source.value : this.source,
      confirmed: data.confirmed.present ? data.confirmed.value : this.confirmed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Name(')
          ..write('id: $id, ')
          ..write('bangla: $bangla, ')
          ..write('english: $english, ')
          ..write('category: $category, ')
          ..write('source: $source, ')
          ..write('confirmed: $confirmed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bangla, english, category, source, confirmed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Name &&
          other.id == this.id &&
          other.bangla == this.bangla &&
          other.english == this.english &&
          other.category == this.category &&
          other.source == this.source &&
          other.confirmed == this.confirmed);
}

class NamesCompanion extends UpdateCompanion<Name> {
  final Value<String> id;
  final Value<String> bangla;
  final Value<String> english;
  final Value<String> category;
  final Value<String> source;
  final Value<bool> confirmed;
  final Value<int> rowid;
  const NamesCompanion({
    this.id = const Value.absent(),
    this.bangla = const Value.absent(),
    this.english = const Value.absent(),
    this.category = const Value.absent(),
    this.source = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NamesCompanion.insert({
    required String id,
    required String bangla,
    required String english,
    this.category = const Value.absent(),
    this.source = const Value.absent(),
    this.confirmed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bangla = Value(bangla),
       english = Value(english);
  static Insertable<Name> custom({
    Expression<String>? id,
    Expression<String>? bangla,
    Expression<String>? english,
    Expression<String>? category,
    Expression<String>? source,
    Expression<bool>? confirmed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bangla != null) 'bangla': bangla,
      if (english != null) 'english': english,
      if (category != null) 'category': category,
      if (source != null) 'source': source,
      if (confirmed != null) 'confirmed': confirmed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NamesCompanion copyWith({
    Value<String>? id,
    Value<String>? bangla,
    Value<String>? english,
    Value<String>? category,
    Value<String>? source,
    Value<bool>? confirmed,
    Value<int>? rowid,
  }) {
    return NamesCompanion(
      id: id ?? this.id,
      bangla: bangla ?? this.bangla,
      english: english ?? this.english,
      category: category ?? this.category,
      source: source ?? this.source,
      confirmed: confirmed ?? this.confirmed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bangla.present) {
      map['bangla'] = Variable<String>(bangla.value);
    }
    if (english.present) {
      map['english'] = Variable<String>(english.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (confirmed.present) {
      map['confirmed'] = Variable<bool>(confirmed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NamesCompanion(')
          ..write('id: $id, ')
          ..write('bangla: $bangla, ')
          ..write('english: $english, ')
          ..write('category: $category, ')
          ..write('source: $source, ')
          ..write('confirmed: $confirmed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TermsTable extends Terms with TableInfo<$TermsTable, Term> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TermsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _banglaMeta = const VerificationMeta('bangla');
  @override
  late final GeneratedColumn<String> bangla = GeneratedColumn<String>(
    'bangla',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transliterationMeta = const VerificationMeta(
    'transliteration',
  );
  @override
  late final GeneratedColumn<String> transliteration = GeneratedColumn<String>(
    'transliteration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _englishMeta = const VerificationMeta(
    'english',
  );
  @override
  late final GeneratedColumn<String> english = GeneratedColumn<String>(
    'english',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _chosenFormMeta = const VerificationMeta(
    'chosenForm',
  );
  @override
  late final GeneratedColumn<String> chosenForm = GeneratedColumn<String>(
    'chosen_form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('both'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bangla,
    transliteration,
    english,
    explanation,
    chosenForm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'terms';
  @override
  VerificationContext validateIntegrity(
    Insertable<Term> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bangla')) {
      context.handle(
        _banglaMeta,
        bangla.isAcceptableOrUnknown(data['bangla']!, _banglaMeta),
      );
    } else if (isInserting) {
      context.missing(_banglaMeta);
    }
    if (data.containsKey('transliteration')) {
      context.handle(
        _transliterationMeta,
        transliteration.isAcceptableOrUnknown(
          data['transliteration']!,
          _transliterationMeta,
        ),
      );
    }
    if (data.containsKey('english')) {
      context.handle(
        _englishMeta,
        english.isAcceptableOrUnknown(data['english']!, _englishMeta),
      );
    } else if (isInserting) {
      context.missing(_englishMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('chosen_form')) {
      context.handle(
        _chosenFormMeta,
        chosenForm.isAcceptableOrUnknown(data['chosen_form']!, _chosenFormMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Term map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Term(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bangla: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bangla'],
      )!,
      transliteration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transliteration'],
      )!,
      english: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}english'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      chosenForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen_form'],
      )!,
    );
  }

  @override
  $TermsTable createAlias(String alias) {
    return $TermsTable(attachedDatabase, alias);
  }
}

class Term extends DataClass implements Insertable<Term> {
  final String id;
  final String bangla;
  final String transliteration;
  final String english;
  final String explanation;
  final String chosenForm;
  const Term({
    required this.id,
    required this.bangla,
    required this.transliteration,
    required this.english,
    required this.explanation,
    required this.chosenForm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bangla'] = Variable<String>(bangla);
    map['transliteration'] = Variable<String>(transliteration);
    map['english'] = Variable<String>(english);
    map['explanation'] = Variable<String>(explanation);
    map['chosen_form'] = Variable<String>(chosenForm);
    return map;
  }

  TermsCompanion toCompanion(bool nullToAbsent) {
    return TermsCompanion(
      id: Value(id),
      bangla: Value(bangla),
      transliteration: Value(transliteration),
      english: Value(english),
      explanation: Value(explanation),
      chosenForm: Value(chosenForm),
    );
  }

  factory Term.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Term(
      id: serializer.fromJson<String>(json['id']),
      bangla: serializer.fromJson<String>(json['bangla']),
      transliteration: serializer.fromJson<String>(json['transliteration']),
      english: serializer.fromJson<String>(json['english']),
      explanation: serializer.fromJson<String>(json['explanation']),
      chosenForm: serializer.fromJson<String>(json['chosenForm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bangla': serializer.toJson<String>(bangla),
      'transliteration': serializer.toJson<String>(transliteration),
      'english': serializer.toJson<String>(english),
      'explanation': serializer.toJson<String>(explanation),
      'chosenForm': serializer.toJson<String>(chosenForm),
    };
  }

  Term copyWith({
    String? id,
    String? bangla,
    String? transliteration,
    String? english,
    String? explanation,
    String? chosenForm,
  }) => Term(
    id: id ?? this.id,
    bangla: bangla ?? this.bangla,
    transliteration: transliteration ?? this.transliteration,
    english: english ?? this.english,
    explanation: explanation ?? this.explanation,
    chosenForm: chosenForm ?? this.chosenForm,
  );
  Term copyWithCompanion(TermsCompanion data) {
    return Term(
      id: data.id.present ? data.id.value : this.id,
      bangla: data.bangla.present ? data.bangla.value : this.bangla,
      transliteration: data.transliteration.present
          ? data.transliteration.value
          : this.transliteration,
      english: data.english.present ? data.english.value : this.english,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      chosenForm: data.chosenForm.present
          ? data.chosenForm.value
          : this.chosenForm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Term(')
          ..write('id: $id, ')
          ..write('bangla: $bangla, ')
          ..write('transliteration: $transliteration, ')
          ..write('english: $english, ')
          ..write('explanation: $explanation, ')
          ..write('chosenForm: $chosenForm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bangla,
    transliteration,
    english,
    explanation,
    chosenForm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Term &&
          other.id == this.id &&
          other.bangla == this.bangla &&
          other.transliteration == this.transliteration &&
          other.english == this.english &&
          other.explanation == this.explanation &&
          other.chosenForm == this.chosenForm);
}

class TermsCompanion extends UpdateCompanion<Term> {
  final Value<String> id;
  final Value<String> bangla;
  final Value<String> transliteration;
  final Value<String> english;
  final Value<String> explanation;
  final Value<String> chosenForm;
  final Value<int> rowid;
  const TermsCompanion({
    this.id = const Value.absent(),
    this.bangla = const Value.absent(),
    this.transliteration = const Value.absent(),
    this.english = const Value.absent(),
    this.explanation = const Value.absent(),
    this.chosenForm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TermsCompanion.insert({
    required String id,
    required String bangla,
    this.transliteration = const Value.absent(),
    required String english,
    this.explanation = const Value.absent(),
    this.chosenForm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bangla = Value(bangla),
       english = Value(english);
  static Insertable<Term> custom({
    Expression<String>? id,
    Expression<String>? bangla,
    Expression<String>? transliteration,
    Expression<String>? english,
    Expression<String>? explanation,
    Expression<String>? chosenForm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bangla != null) 'bangla': bangla,
      if (transliteration != null) 'transliteration': transliteration,
      if (english != null) 'english': english,
      if (explanation != null) 'explanation': explanation,
      if (chosenForm != null) 'chosen_form': chosenForm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TermsCompanion copyWith({
    Value<String>? id,
    Value<String>? bangla,
    Value<String>? transliteration,
    Value<String>? english,
    Value<String>? explanation,
    Value<String>? chosenForm,
    Value<int>? rowid,
  }) {
    return TermsCompanion(
      id: id ?? this.id,
      bangla: bangla ?? this.bangla,
      transliteration: transliteration ?? this.transliteration,
      english: english ?? this.english,
      explanation: explanation ?? this.explanation,
      chosenForm: chosenForm ?? this.chosenForm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bangla.present) {
      map['bangla'] = Variable<String>(bangla.value);
    }
    if (transliteration.present) {
      map['transliteration'] = Variable<String>(transliteration.value);
    }
    if (english.present) {
      map['english'] = Variable<String>(english.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (chosenForm.present) {
      map['chosen_form'] = Variable<String>(chosenForm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TermsCompanion(')
          ..write('id: $id, ')
          ..write('bangla: $bangla, ')
          ..write('transliteration: $transliteration, ')
          ..write('english: $english, ')
          ..write('explanation: $explanation, ')
          ..write('chosenForm: $chosenForm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CorrectionsTable extends Corrections
    with TableInfo<$CorrectionsTable, Correction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CorrectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrongReadingMeta = const VerificationMeta(
    'wrongReading',
  );
  @override
  late final GeneratedColumn<String> wrongReading = GeneratedColumn<String>(
    'wrong_reading',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rightReadingMeta = const VerificationMeta(
    'rightReading',
  );
  @override
  late final GeneratedColumn<String> rightReading = GeneratedColumn<String>(
    'right_reading',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [id, wrongReading, rightReading, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'corrections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Correction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('wrong_reading')) {
      context.handle(
        _wrongReadingMeta,
        wrongReading.isAcceptableOrUnknown(
          data['wrong_reading']!,
          _wrongReadingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrongReadingMeta);
    }
    if (data.containsKey('right_reading')) {
      context.handle(
        _rightReadingMeta,
        rightReading.isAcceptableOrUnknown(
          data['right_reading']!,
          _rightReadingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rightReadingMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Correction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Correction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      wrongReading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrong_reading'],
      )!,
      rightReading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}right_reading'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $CorrectionsTable createAlias(String alias) {
    return $CorrectionsTable(attachedDatabase, alias);
  }
}

class Correction extends DataClass implements Insertable<Correction> {
  final String id;
  final String wrongReading;
  final String rightReading;
  final int count;
  const Correction({
    required this.id,
    required this.wrongReading,
    required this.rightReading,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['wrong_reading'] = Variable<String>(wrongReading);
    map['right_reading'] = Variable<String>(rightReading);
    map['count'] = Variable<int>(count);
    return map;
  }

  CorrectionsCompanion toCompanion(bool nullToAbsent) {
    return CorrectionsCompanion(
      id: Value(id),
      wrongReading: Value(wrongReading),
      rightReading: Value(rightReading),
      count: Value(count),
    );
  }

  factory Correction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Correction(
      id: serializer.fromJson<String>(json['id']),
      wrongReading: serializer.fromJson<String>(json['wrongReading']),
      rightReading: serializer.fromJson<String>(json['rightReading']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'wrongReading': serializer.toJson<String>(wrongReading),
      'rightReading': serializer.toJson<String>(rightReading),
      'count': serializer.toJson<int>(count),
    };
  }

  Correction copyWith({
    String? id,
    String? wrongReading,
    String? rightReading,
    int? count,
  }) => Correction(
    id: id ?? this.id,
    wrongReading: wrongReading ?? this.wrongReading,
    rightReading: rightReading ?? this.rightReading,
    count: count ?? this.count,
  );
  Correction copyWithCompanion(CorrectionsCompanion data) {
    return Correction(
      id: data.id.present ? data.id.value : this.id,
      wrongReading: data.wrongReading.present
          ? data.wrongReading.value
          : this.wrongReading,
      rightReading: data.rightReading.present
          ? data.rightReading.value
          : this.rightReading,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Correction(')
          ..write('id: $id, ')
          ..write('wrongReading: $wrongReading, ')
          ..write('rightReading: $rightReading, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, wrongReading, rightReading, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Correction &&
          other.id == this.id &&
          other.wrongReading == this.wrongReading &&
          other.rightReading == this.rightReading &&
          other.count == this.count);
}

class CorrectionsCompanion extends UpdateCompanion<Correction> {
  final Value<String> id;
  final Value<String> wrongReading;
  final Value<String> rightReading;
  final Value<int> count;
  final Value<int> rowid;
  const CorrectionsCompanion({
    this.id = const Value.absent(),
    this.wrongReading = const Value.absent(),
    this.rightReading = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CorrectionsCompanion.insert({
    required String id,
    required String wrongReading,
    required String rightReading,
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       wrongReading = Value(wrongReading),
       rightReading = Value(rightReading);
  static Insertable<Correction> custom({
    Expression<String>? id,
    Expression<String>? wrongReading,
    Expression<String>? rightReading,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wrongReading != null) 'wrong_reading': wrongReading,
      if (rightReading != null) 'right_reading': rightReading,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CorrectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? wrongReading,
    Value<String>? rightReading,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return CorrectionsCompanion(
      id: id ?? this.id,
      wrongReading: wrongReading ?? this.wrongReading,
      rightReading: rightReading ?? this.rightReading,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (wrongReading.present) {
      map['wrong_reading'] = Variable<String>(wrongReading.value);
    }
    if (rightReading.present) {
      map['right_reading'] = Variable<String>(rightReading.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CorrectionsCompanion(')
          ..write('id: $id, ')
          ..write('wrongReading: $wrongReading, ')
          ..write('rightReading: $rightReading, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BundlesTable extends Bundles with TableInfo<$BundlesTable, Bundle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BundlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('custom'),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    purpose,
    dueDate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bundles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bundle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bundle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bundle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BundlesTable createAlias(String alias) {
    return $BundlesTable(attachedDatabase, alias);
  }
}

class Bundle extends DataClass implements Insertable<Bundle> {
  final String id;
  final String title;
  final String purpose;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Bundle({
    required this.id,
    required this.title,
    required this.purpose,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['purpose'] = Variable<String>(purpose);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BundlesCompanion toCompanion(bool nullToAbsent) {
    return BundlesCompanion(
      id: Value(id),
      title: Value(title),
      purpose: Value(purpose),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Bundle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bundle(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      purpose: serializer.fromJson<String>(json['purpose']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'purpose': serializer.toJson<String>(purpose),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Bundle copyWith({
    String? id,
    String? title,
    String? purpose,
    Value<DateTime?> dueDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Bundle(
    id: id ?? this.id,
    title: title ?? this.title,
    purpose: purpose ?? this.purpose,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Bundle copyWithCompanion(BundlesCompanion data) {
    return Bundle(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bundle(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('purpose: $purpose, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, purpose, dueDate, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bundle &&
          other.id == this.id &&
          other.title == this.title &&
          other.purpose == this.purpose &&
          other.dueDate == this.dueDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BundlesCompanion extends UpdateCompanion<Bundle> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> purpose;
  final Value<DateTime?> dueDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BundlesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.purpose = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BundlesCompanion.insert({
    required String id,
    required String title,
    this.purpose = const Value.absent(),
    this.dueDate = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Bundle> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? purpose,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (purpose != null) 'purpose': purpose,
      if (dueDate != null) 'due_date': dueDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BundlesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? purpose,
    Value<DateTime?>? dueDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BundlesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      purpose: purpose ?? this.purpose,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BundlesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('purpose: $purpose, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BundleItemsTable extends BundleItems
    with TableInfo<$BundleItemsTable, BundleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BundleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bundleIdMeta = const VerificationMeta(
    'bundleId',
  );
  @override
  late final GeneratedColumn<String> bundleId = GeneratedColumn<String>(
    'bundle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bundles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemOrderMeta = const VerificationMeta(
    'itemOrder',
  );
  @override
  late final GeneratedColumn<int> itemOrder = GeneratedColumn<int>(
    'item_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedKindMeta = const VerificationMeta(
    'expectedKind',
  );
  @override
  late final GeneratedColumn<String> expectedKind = GeneratedColumn<String>(
    'expected_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('document'),
  );
  static const VerificationMeta _linkedScanIdMeta = const VerificationMeta(
    'linkedScanId',
  );
  @override
  late final GeneratedColumn<String> linkedScanId = GeneratedColumn<String>(
    'linked_scan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scans (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bundleId,
    title,
    itemOrder,
    expectedKind,
    linkedScanId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bundle_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<BundleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bundle_id')) {
      context.handle(
        _bundleIdMeta,
        bundleId.isAcceptableOrUnknown(data['bundle_id']!, _bundleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bundleIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('item_order')) {
      context.handle(
        _itemOrderMeta,
        itemOrder.isAcceptableOrUnknown(data['item_order']!, _itemOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_itemOrderMeta);
    }
    if (data.containsKey('expected_kind')) {
      context.handle(
        _expectedKindMeta,
        expectedKind.isAcceptableOrUnknown(
          data['expected_kind']!,
          _expectedKindMeta,
        ),
      );
    }
    if (data.containsKey('linked_scan_id')) {
      context.handle(
        _linkedScanIdMeta,
        linkedScanId.isAcceptableOrUnknown(
          data['linked_scan_id']!,
          _linkedScanIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BundleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BundleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bundleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bundle_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      itemOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_order'],
      )!,
      expectedKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_kind'],
      )!,
      linkedScanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_scan_id'],
      ),
    );
  }

  @override
  $BundleItemsTable createAlias(String alias) {
    return $BundleItemsTable(attachedDatabase, alias);
  }
}

class BundleItem extends DataClass implements Insertable<BundleItem> {
  final String id;
  final String bundleId;
  final String title;
  final int itemOrder;
  final String expectedKind;
  final String? linkedScanId;
  const BundleItem({
    required this.id,
    required this.bundleId,
    required this.title,
    required this.itemOrder,
    required this.expectedKind,
    this.linkedScanId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bundle_id'] = Variable<String>(bundleId);
    map['title'] = Variable<String>(title);
    map['item_order'] = Variable<int>(itemOrder);
    map['expected_kind'] = Variable<String>(expectedKind);
    if (!nullToAbsent || linkedScanId != null) {
      map['linked_scan_id'] = Variable<String>(linkedScanId);
    }
    return map;
  }

  BundleItemsCompanion toCompanion(bool nullToAbsent) {
    return BundleItemsCompanion(
      id: Value(id),
      bundleId: Value(bundleId),
      title: Value(title),
      itemOrder: Value(itemOrder),
      expectedKind: Value(expectedKind),
      linkedScanId: linkedScanId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedScanId),
    );
  }

  factory BundleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BundleItem(
      id: serializer.fromJson<String>(json['id']),
      bundleId: serializer.fromJson<String>(json['bundleId']),
      title: serializer.fromJson<String>(json['title']),
      itemOrder: serializer.fromJson<int>(json['itemOrder']),
      expectedKind: serializer.fromJson<String>(json['expectedKind']),
      linkedScanId: serializer.fromJson<String?>(json['linkedScanId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bundleId': serializer.toJson<String>(bundleId),
      'title': serializer.toJson<String>(title),
      'itemOrder': serializer.toJson<int>(itemOrder),
      'expectedKind': serializer.toJson<String>(expectedKind),
      'linkedScanId': serializer.toJson<String?>(linkedScanId),
    };
  }

  BundleItem copyWith({
    String? id,
    String? bundleId,
    String? title,
    int? itemOrder,
    String? expectedKind,
    Value<String?> linkedScanId = const Value.absent(),
  }) => BundleItem(
    id: id ?? this.id,
    bundleId: bundleId ?? this.bundleId,
    title: title ?? this.title,
    itemOrder: itemOrder ?? this.itemOrder,
    expectedKind: expectedKind ?? this.expectedKind,
    linkedScanId: linkedScanId.present ? linkedScanId.value : this.linkedScanId,
  );
  BundleItem copyWithCompanion(BundleItemsCompanion data) {
    return BundleItem(
      id: data.id.present ? data.id.value : this.id,
      bundleId: data.bundleId.present ? data.bundleId.value : this.bundleId,
      title: data.title.present ? data.title.value : this.title,
      itemOrder: data.itemOrder.present ? data.itemOrder.value : this.itemOrder,
      expectedKind: data.expectedKind.present
          ? data.expectedKind.value
          : this.expectedKind,
      linkedScanId: data.linkedScanId.present
          ? data.linkedScanId.value
          : this.linkedScanId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BundleItem(')
          ..write('id: $id, ')
          ..write('bundleId: $bundleId, ')
          ..write('title: $title, ')
          ..write('itemOrder: $itemOrder, ')
          ..write('expectedKind: $expectedKind, ')
          ..write('linkedScanId: $linkedScanId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bundleId, title, itemOrder, expectedKind, linkedScanId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BundleItem &&
          other.id == this.id &&
          other.bundleId == this.bundleId &&
          other.title == this.title &&
          other.itemOrder == this.itemOrder &&
          other.expectedKind == this.expectedKind &&
          other.linkedScanId == this.linkedScanId);
}

class BundleItemsCompanion extends UpdateCompanion<BundleItem> {
  final Value<String> id;
  final Value<String> bundleId;
  final Value<String> title;
  final Value<int> itemOrder;
  final Value<String> expectedKind;
  final Value<String?> linkedScanId;
  final Value<int> rowid;
  const BundleItemsCompanion({
    this.id = const Value.absent(),
    this.bundleId = const Value.absent(),
    this.title = const Value.absent(),
    this.itemOrder = const Value.absent(),
    this.expectedKind = const Value.absent(),
    this.linkedScanId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BundleItemsCompanion.insert({
    required String id,
    required String bundleId,
    required String title,
    required int itemOrder,
    this.expectedKind = const Value.absent(),
    this.linkedScanId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bundleId = Value(bundleId),
       title = Value(title),
       itemOrder = Value(itemOrder);
  static Insertable<BundleItem> custom({
    Expression<String>? id,
    Expression<String>? bundleId,
    Expression<String>? title,
    Expression<int>? itemOrder,
    Expression<String>? expectedKind,
    Expression<String>? linkedScanId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bundleId != null) 'bundle_id': bundleId,
      if (title != null) 'title': title,
      if (itemOrder != null) 'item_order': itemOrder,
      if (expectedKind != null) 'expected_kind': expectedKind,
      if (linkedScanId != null) 'linked_scan_id': linkedScanId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BundleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? bundleId,
    Value<String>? title,
    Value<int>? itemOrder,
    Value<String>? expectedKind,
    Value<String?>? linkedScanId,
    Value<int>? rowid,
  }) {
    return BundleItemsCompanion(
      id: id ?? this.id,
      bundleId: bundleId ?? this.bundleId,
      title: title ?? this.title,
      itemOrder: itemOrder ?? this.itemOrder,
      expectedKind: expectedKind ?? this.expectedKind,
      linkedScanId: linkedScanId ?? this.linkedScanId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bundleId.present) {
      map['bundle_id'] = Variable<String>(bundleId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (itemOrder.present) {
      map['item_order'] = Variable<int>(itemOrder.value);
    }
    if (expectedKind.present) {
      map['expected_kind'] = Variable<String>(expectedKind.value);
    }
    if (linkedScanId.present) {
      map['linked_scan_id'] = Variable<String>(linkedScanId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BundleItemsCompanion(')
          ..write('id: $id, ')
          ..write('bundleId: $bundleId, ')
          ..write('title: $title, ')
          ..write('itemOrder: $itemOrder, ')
          ..write('expectedKind: $expectedKind, ')
          ..write('linkedScanId: $linkedScanId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScansTable scans = $ScansTable(this);
  late final $ScanPagesTable scanPages = $ScanPagesTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ReceiptsTable receipts = $ReceiptsTable(this);
  late final $LineItemsTable lineItems = $LineItemsTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $ScanTagsTable scanTags = $ScanTagsTable(this);
  late final $TextLinesTable textLines = $TextLinesTable(this);
  late final $DetailsTable details = $DetailsTable(this);
  late final $TranslationsTable translations = $TranslationsTable(this);
  late final $NamesTable names = $NamesTable(this);
  late final $TermsTable terms = $TermsTable(this);
  late final $CorrectionsTable corrections = $CorrectionsTable(this);
  late final $BundlesTable bundles = $BundlesTable(this);
  late final $BundleItemsTable bundleItems = $BundleItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    scans,
    scanPages,
    categories,
    receipts,
    lineItems,
    documents,
    tags,
    scanTags,
    textLines,
    details,
    translations,
    names,
    terms,
    corrections,
    bundles,
    bundleItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scan_pages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('receipts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('receipts', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'receipts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('line_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('documents', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scan_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scan_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('text_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('details', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'text_lines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('details', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('translations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'text_lines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('translations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'bundles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bundle_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bundle_items', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$ScansTableCreateCompanionBuilder = ScansCompanion Function({
  required String id,
  required String type,
  Value<String> kind,
  Value<String> language,
  Value<int> checkCount,
  Value<DateTime?> renewBy,
  required String imagePath,
  Value<String?> thumbPath,
  Value<String> ocrRawText,
  Value<String?> ocrEngine,
  Value<double?> ocrMeanConfidence,
  Value<String> langHint,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ScansTableUpdateCompanionBuilder = ScansCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> kind,
  Value<String> language,
  Value<int> checkCount,
  Value<DateTime?> renewBy,
  Value<String> imagePath,
  Value<String?> thumbPath,
  Value<String> ocrRawText,
  Value<String?> ocrEngine,
  Value<double?> ocrMeanConfidence,
  Value<String> langHint,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ScansTableReferences
    extends BaseReferences<_$AppDatabase, $ScansTable, Scan> {
  $$ScansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ScanPagesTable, List<ScanPage>>
  _scanPagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scanPages,
    aliasName: 'scans__id__scan_pages__scan_id',
  );

  $$ScanPagesTableProcessedTableManager get scanPagesRefs {
    final manager = $$ScanPagesTableTableManager(
      $_db,
      $_db.scanPages,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scanPagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReceiptsTable, List<Receipt>> _receiptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.receipts,
    aliasName: 'scans__id__receipts__scan_id',
  );

  $$ReceiptsTableProcessedTableManager get receiptsRefs {
    final manager = $$ReceiptsTableTableManager(
      $_db,
      $_db.receipts,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentsTable, List<Document>>
  _documentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documents,
    aliasName: 'scans__id__documents__scan_id',
  );

  $$DocumentsTableProcessedTableManager get documentsRefs {
    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScanTagsTable, List<ScanTag>> _scanTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scanTags,
    aliasName: 'scans__id__scan_tags__scan_id',
  );

  $$ScanTagsTableProcessedTableManager get scanTagsRefs {
    final manager = $$ScanTagsTableTableManager(
      $_db,
      $_db.scanTags,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scanTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TextLinesTable, List<TextLine>>
  _textLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.textLines,
    aliasName: 'scans__id__text_lines__scan_id',
  );

  $$TextLinesTableProcessedTableManager get textLinesRefs {
    final manager = $$TextLinesTableTableManager(
      $_db,
      $_db.textLines,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_textLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DetailsTable, List<Detail>> _detailsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.details,
    aliasName: 'scans__id__details__scan_id',
  );

  $$DetailsTableProcessedTableManager get detailsRefs {
    final manager = $$DetailsTableTableManager(
      $_db,
      $_db.details,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_detailsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranslationsTable, List<Translation>>
  _translationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.translations,
    aliasName: 'scans__id__translations__scan_id',
  );

  $$TranslationsTableProcessedTableManager get translationsRefs {
    final manager = $$TranslationsTableTableManager(
      $_db,
      $_db.translations,
    ).filter((f) => f.scanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_translationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BundleItemsTable, List<BundleItem>>
  _bundleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bundleItems,
    aliasName: 'scans__id__bundle_items__linked_scan_id',
  );

  $$BundleItemsTableProcessedTableManager get bundleItemsRefs {
    final manager = $$BundleItemsTableTableManager(
      $_db,
      $_db.bundleItems,
    ).filter((f) => f.linkedScanId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bundleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScansTableFilterComposer extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkCount => $composableBuilder(
    column: $table.checkCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get renewBy => $composableBuilder(
    column: $table.renewBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrRawText => $composableBuilder(
    column: $table.ocrRawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrEngine => $composableBuilder(
    column: $table.ocrEngine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ocrMeanConfidence => $composableBuilder(
    column: $table.ocrMeanConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get langHint => $composableBuilder(
    column: $table.langHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> scanPagesRefs(
    Expression<bool> Function($$ScanPagesTableFilterComposer f) f,
  ) {
    final $$ScanPagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanPages,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScanPagesTableFilterComposer(
            $db: $db,
            $table: $db.scanPages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> receiptsRefs(
    Expression<bool> Function($$ReceiptsTableFilterComposer f) f,
  ) {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentsRefs(
    Expression<bool> Function($$DocumentsTableFilterComposer f) f,
  ) {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scanTagsRefs(
    Expression<bool> Function($$ScanTagsTableFilterComposer f) f,
  ) {
    final $$ScanTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanTags,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScanTagsTableFilterComposer(
            $db: $db,
            $table: $db.scanTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> textLinesRefs(
    Expression<bool> Function($$TextLinesTableFilterComposer f) f,
  ) {
    final $$TextLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableFilterComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> detailsRefs(
    Expression<bool> Function($$DetailsTableFilterComposer f) f,
  ) {
    final $$DetailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.details,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DetailsTableFilterComposer(
            $db: $db,
            $table: $db.details,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> translationsRefs(
    Expression<bool> Function($$TranslationsTableFilterComposer f) f,
  ) {
    final $$TranslationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.translations,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranslationsTableFilterComposer(
            $db: $db,
            $table: $db.translations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bundleItemsRefs(
    Expression<bool> Function($$BundleItemsTableFilterComposer f) f,
  ) {
    final $$BundleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.linkedScanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableFilterComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScansTableOrderingComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkCount => $composableBuilder(
    column: $table.checkCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get renewBy => $composableBuilder(
    column: $table.renewBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrRawText => $composableBuilder(
    column: $table.ocrRawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrEngine => $composableBuilder(
    column: $table.ocrEngine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ocrMeanConfidence => $composableBuilder(
    column: $table.ocrMeanConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get langHint => $composableBuilder(
    column: $table.langHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScansTable> {
  $$ScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get checkCount => $composableBuilder(
    column: $table.checkCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get renewBy =>
      $composableBuilder(column: $table.renewBy, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get thumbPath =>
      $composableBuilder(column: $table.thumbPath, builder: (column) => column);

  GeneratedColumn<String> get ocrRawText => $composableBuilder(
    column: $table.ocrRawText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrEngine =>
      $composableBuilder(column: $table.ocrEngine, builder: (column) => column);

  GeneratedColumn<double> get ocrMeanConfidence => $composableBuilder(
    column: $table.ocrMeanConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get langHint =>
      $composableBuilder(column: $table.langHint, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> scanPagesRefs<T extends Object>(
    Expression<T> Function($$ScanPagesTableAnnotationComposer a) f,
  ) {
    final $$ScanPagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanPages,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScanPagesTableAnnotationComposer(
            $db: $db,
            $table: $db.scanPages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> receiptsRefs<T extends Object>(
    Expression<T> Function($$ReceiptsTableAnnotationComposer a) f,
  ) {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> documentsRefs<T extends Object>(
    Expression<T> Function($$DocumentsTableAnnotationComposer a) f,
  ) {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scanTagsRefs<T extends Object>(
    Expression<T> Function($$ScanTagsTableAnnotationComposer a) f,
  ) {
    final $$ScanTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanTags,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScanTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.scanTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> textLinesRefs<T extends Object>(
    Expression<T> Function($$TextLinesTableAnnotationComposer a) f,
  ) {
    final $$TextLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> detailsRefs<T extends Object>(
    Expression<T> Function($$DetailsTableAnnotationComposer a) f,
  ) {
    final $$DetailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.details,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DetailsTableAnnotationComposer(
            $db: $db,
            $table: $db.details,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> translationsRefs<T extends Object>(
    Expression<T> Function($$TranslationsTableAnnotationComposer a) f,
  ) {
    final $$TranslationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.translations,
      getReferencedColumn: (t) => t.scanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranslationsTableAnnotationComposer(
            $db: $db,
            $table: $db.translations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bundleItemsRefs<T extends Object>(
    Expression<T> Function($$BundleItemsTableAnnotationComposer a) f,
  ) {
    final $$BundleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.linkedScanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScansTable,
          Scan,
          $$ScansTableFilterComposer,
          $$ScansTableOrderingComposer,
          $$ScansTableAnnotationComposer,
          $$ScansTableCreateCompanionBuilder,
          $$ScansTableUpdateCompanionBuilder,
          (Scan, $$ScansTableReferences),
          Scan,
          PrefetchHooks Function({
            bool scanPagesRefs,
            bool receiptsRefs,
            bool documentsRefs,
            bool scanTagsRefs,
            bool textLinesRefs,
            bool detailsRefs,
            bool translationsRefs,
            bool bundleItemsRefs,
          })
        > {
  $$ScansTableTableManager(_$AppDatabase db, $ScansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> checkCount = const Value.absent(),
                Value<DateTime?> renewBy = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<String> ocrRawText = const Value.absent(),
                Value<String?> ocrEngine = const Value.absent(),
                Value<double?> ocrMeanConfidence = const Value.absent(),
                Value<String> langHint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScansCompanion(
                id: id,
                type: type,
                kind: kind,
                language: language,
                checkCount: checkCount,
                renewBy: renewBy,
                imagePath: imagePath,
                thumbPath: thumbPath,
                ocrRawText: ocrRawText,
                ocrEngine: ocrEngine,
                ocrMeanConfidence: ocrMeanConfidence,
                langHint: langHint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<String> kind = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> checkCount = const Value.absent(),
                Value<DateTime?> renewBy = const Value.absent(),
                required String imagePath,
                Value<String?> thumbPath = const Value.absent(),
                Value<String> ocrRawText = const Value.absent(),
                Value<String?> ocrEngine = const Value.absent(),
                Value<double?> ocrMeanConfidence = const Value.absent(),
                Value<String> langHint = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ScansCompanion.insert(
                id: id,
                type: type,
                kind: kind,
                language: language,
                checkCount: checkCount,
                renewBy: renewBy,
                imagePath: imagePath,
                thumbPath: thumbPath,
                ocrRawText: ocrRawText,
                ocrEngine: ocrEngine,
                ocrMeanConfidence: ocrMeanConfidence,
                langHint: langHint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ScansTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                scanPagesRefs = false,
                receiptsRefs = false,
                documentsRefs = false,
                scanTagsRefs = false,
                textLinesRefs = false,
                detailsRefs = false,
                translationsRefs = false,
                bundleItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (scanPagesRefs) db.scanPages,
                    if (receiptsRefs) db.receipts,
                    if (documentsRefs) db.documents,
                    if (scanTagsRefs) db.scanTags,
                    if (textLinesRefs) db.textLines,
                    if (detailsRefs) db.details,
                    if (translationsRefs) db.translations,
                    if (bundleItemsRefs) db.bundleItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (scanPagesRefs)
                        await $_getPrefetchedData<Scan, $ScansTable, ScanPage>(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._scanPagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).scanPagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (receiptsRefs)
                        await $_getPrefetchedData<Scan, $ScansTable, Receipt>(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._receiptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).receiptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentsRefs)
                        await $_getPrefetchedData<Scan, $ScansTable, Document>(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._documentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).documentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scanTagsRefs)
                        await $_getPrefetchedData<Scan, $ScansTable, ScanTag>(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._scanTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).scanTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (textLinesRefs)
                        await $_getPrefetchedData<Scan, $ScansTable, TextLine>(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._textLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).textLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (detailsRefs)
                        await $_getPrefetchedData<Scan, $ScansTable, Detail>(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._detailsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(db, table, p0).detailsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (translationsRefs)
                        await $_getPrefetchedData<
                          Scan,
                          $ScansTable,
                          Translation
                        >(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._translationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).translationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bundleItemsRefs)
                        await $_getPrefetchedData<
                          Scan,
                          $ScansTable,
                          BundleItem
                        >(
                          currentTable: table,
                          referencedTable: $$ScansTableReferences
                              ._bundleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScansTableReferences(
                                db,
                                table,
                                p0,
                              ).bundleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedScanId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ScansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScansTable,
      Scan,
      $$ScansTableFilterComposer,
      $$ScansTableOrderingComposer,
      $$ScansTableAnnotationComposer,
      $$ScansTableCreateCompanionBuilder,
      $$ScansTableUpdateCompanionBuilder,
      (Scan, $$ScansTableReferences),
      Scan,
      PrefetchHooks Function({
        bool scanPagesRefs,
        bool receiptsRefs,
        bool documentsRefs,
        bool scanTagsRefs,
        bool textLinesRefs,
        bool detailsRefs,
        bool translationsRefs,
        bool bundleItemsRefs,
      })
    >;
typedef $$ScanPagesTableCreateCompanionBuilder = ScanPagesCompanion Function({
  required String id,
  required String scanId,
  required String imagePath,
  Value<String?> processedPath,
  required int pageIndex,
  Value<String> filter,
  Value<String?> quadJson,
  Value<int> rotation,
  Value<String?> side,
  Value<int> rowid,
});
typedef $$ScanPagesTableUpdateCompanionBuilder = ScanPagesCompanion Function({
  Value<String> id,
  Value<String> scanId,
  Value<String> imagePath,
  Value<String?> processedPath,
  Value<int> pageIndex,
  Value<String> filter,
  Value<String?> quadJson,
  Value<int> rotation,
  Value<String?> side,
  Value<int> rowid,
});

final class $$ScanPagesTableReferences
    extends BaseReferences<_$AppDatabase, $ScanPagesTable, ScanPage> {
  $$ScanPagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('scan_pages__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScanPagesTableFilterComposer
    extends Composer<_$AppDatabase, $ScanPagesTable> {
  $$ScanPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processedPath => $composableBuilder(
    column: $table.processedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filter => $composableBuilder(
    column: $table.filter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quadJson => $composableBuilder(
    column: $table.quadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScanPagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanPagesTable> {
  $$ScanPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processedPath => $composableBuilder(
    column: $table.processedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filter => $composableBuilder(
    column: $table.filter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quadJson => $composableBuilder(
    column: $table.quadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScanPagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanPagesTable> {
  $$ScanPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get processedPath => $composableBuilder(
    column: $table.processedPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get filter =>
      $composableBuilder(column: $table.filter, builder: (column) => column);

  GeneratedColumn<String> get quadJson =>
      $composableBuilder(column: $table.quadJson, builder: (column) => column);

  GeneratedColumn<int> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScanPagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanPagesTable,
          ScanPage,
          $$ScanPagesTableFilterComposer,
          $$ScanPagesTableOrderingComposer,
          $$ScanPagesTableAnnotationComposer,
          $$ScanPagesTableCreateCompanionBuilder,
          $$ScanPagesTableUpdateCompanionBuilder,
          (ScanPage, $$ScanPagesTableReferences),
          ScanPage,
          PrefetchHooks Function({bool scanId})
        > {
  $$ScanPagesTableTableManager(_$AppDatabase db, $ScanPagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scanId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> processedPath = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> filter = const Value.absent(),
                Value<String?> quadJson = const Value.absent(),
                Value<int> rotation = const Value.absent(),
                Value<String?> side = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanPagesCompanion(
                id: id,
                scanId: scanId,
                imagePath: imagePath,
                processedPath: processedPath,
                pageIndex: pageIndex,
                filter: filter,
                quadJson: quadJson,
                rotation: rotation,
                side: side,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scanId,
                required String imagePath,
                Value<String?> processedPath = const Value.absent(),
                required int pageIndex,
                Value<String> filter = const Value.absent(),
                Value<String?> quadJson = const Value.absent(),
                Value<int> rotation = const Value.absent(),
                Value<String?> side = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanPagesCompanion.insert(
                id: id,
                scanId: scanId,
                imagePath: imagePath,
                processedPath: processedPath,
                pageIndex: pageIndex,
                filter: filter,
                quadJson: quadJson,
                rotation: rotation,
                side: side,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScanPagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $$ScanPagesTableReferences
                            ._scanIdTable(db),
                        referencedColumn: $$ScanPagesTableReferences
                            ._scanIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ScanPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanPagesTable,
      ScanPage,
      $$ScanPagesTableFilterComposer,
      $$ScanPagesTableOrderingComposer,
      $$ScanPagesTableAnnotationComposer,
      $$ScanPagesTableCreateCompanionBuilder,
      $$ScanPagesTableUpdateCompanionBuilder,
      (ScanPage, $$ScanPagesTableReferences),
      ScanPage,
      PrefetchHooks Function({bool scanId})
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String nameEn,
  required String nameBn,
  required String icon,
  Value<bool> isDefault,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> nameEn,
  Value<String> nameBn,
  Value<String> icon,
  Value<bool> isDefault,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReceiptsTable, List<Receipt>> _receiptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.receipts,
    aliasName: 'categories__id__receipts__category_id',
  );

  $$ReceiptsTableProcessedTableManager get receiptsRefs {
    final manager = $$ReceiptsTableTableManager(
      $_db,
      $_db.receipts,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameBn => $composableBuilder(
    column: $table.nameBn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> receiptsRefs(
    Expression<bool> Function($$ReceiptsTableFilterComposer f) f,
  ) {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameBn => $composableBuilder(
    column: $table.nameBn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<String> get nameBn =>
      $composableBuilder(column: $table.nameBn, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  Expression<T> receiptsRefs<T extends Object>(
    Expression<T> Function($$ReceiptsTableAnnotationComposer a) f,
  ) {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool receiptsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nameEn = const Value.absent(),
                Value<String> nameBn = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                nameEn: nameEn,
                nameBn: nameBn,
                icon: icon,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nameEn,
                required String nameBn,
                required String icon,
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                nameEn: nameEn,
                nameBn: nameBn,
                icon: icon,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (receiptsRefs) db.receipts],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (receiptsRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      Receipt
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._receiptsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).receiptsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool receiptsRefs})
    >;
typedef $$ReceiptsTableCreateCompanionBuilder = ReceiptsCompanion Function({
  required String id,
  required String scanId,
  required String merchant,
  required DateTime dateOfPurchase,
  required double total,
  Value<String> currency,
  Value<double?> tax,
  Value<String?> paymentMethod,
  Value<String?> categoryId,
  Value<String?> note,
  Value<String> fieldConfidenceJson,
  Value<int> rowid,
});
typedef $$ReceiptsTableUpdateCompanionBuilder = ReceiptsCompanion Function({
  Value<String> id,
  Value<String> scanId,
  Value<String> merchant,
  Value<DateTime> dateOfPurchase,
  Value<double> total,
  Value<String> currency,
  Value<double?> tax,
  Value<String?> paymentMethod,
  Value<String?> categoryId,
  Value<String?> note,
  Value<String> fieldConfidenceJson,
  Value<int> rowid,
});

final class $$ReceiptsTableReferences
    extends BaseReferences<_$AppDatabase, $ReceiptsTable, Receipt> {
  $$ReceiptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('receipts__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('receipts__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LineItemsTable, List<LineItem>>
  _lineItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lineItems,
    aliasName: 'receipts__id__line_items__receipt_id',
  );

  $$LineItemsTableProcessedTableManager get lineItemsRefs {
    final manager = $$LineItemsTableTableManager(
      $_db,
      $_db.lineItems,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_lineItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateOfPurchase => $composableBuilder(
    column: $table.dateOfPurchase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldConfidenceJson => $composableBuilder(
    column: $table.fieldConfidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> lineItemsRefs(
    Expression<bool> Function($$LineItemsTableFilterComposer f) f,
  ) {
    final $$LineItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineItems,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineItemsTableFilterComposer(
            $db: $db,
            $table: $db.lineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateOfPurchase => $composableBuilder(
    column: $table.dateOfPurchase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldConfidenceJson => $composableBuilder(
    column: $table.fieldConfidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<DateTime> get dateOfPurchase => $composableBuilder(
    column: $table.dateOfPurchase,
    builder: (column) => column,
  );

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get fieldConfidenceJson => $composableBuilder(
    column: $table.fieldConfidenceJson,
    builder: (column) => column,
  );

  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> lineItemsRefs<T extends Object>(
    Expression<T> Function($$LineItemsTableAnnotationComposer a) f,
  ) {
    final $$LineItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineItems,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.lineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptsTable,
          Receipt,
          $$ReceiptsTableFilterComposer,
          $$ReceiptsTableOrderingComposer,
          $$ReceiptsTableAnnotationComposer,
          $$ReceiptsTableCreateCompanionBuilder,
          $$ReceiptsTableUpdateCompanionBuilder,
          (Receipt, $$ReceiptsTableReferences),
          Receipt,
          PrefetchHooks Function({
            bool scanId,
            bool categoryId,
            bool lineItemsRefs,
          })
        > {
  $$ReceiptsTableTableManager(_$AppDatabase db, $ReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scanId = const Value.absent(),
                Value<String> merchant = const Value.absent(),
                Value<DateTime> dateOfPurchase = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double?> tax = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> fieldConfidenceJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptsCompanion(
                id: id,
                scanId: scanId,
                merchant: merchant,
                dateOfPurchase: dateOfPurchase,
                total: total,
                currency: currency,
                tax: tax,
                paymentMethod: paymentMethod,
                categoryId: categoryId,
                note: note,
                fieldConfidenceJson: fieldConfidenceJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scanId,
                required String merchant,
                required DateTime dateOfPurchase,
                required double total,
                Value<String> currency = const Value.absent(),
                Value<double?> tax = const Value.absent(),
                Value<String?> paymentMethod = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> fieldConfidenceJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptsCompanion.insert(
                id: id,
                scanId: scanId,
                merchant: merchant,
                dateOfPurchase: dateOfPurchase,
                total: total,
                currency: currency,
                tax: tax,
                paymentMethod: paymentMethod,
                categoryId: categoryId,
                note: note,
                fieldConfidenceJson: fieldConfidenceJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReceiptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({scanId = false, categoryId = false, lineItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (lineItemsRefs) db.lineItems],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (scanId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.scanId,
                            referencedTable: $$ReceiptsTableReferences
                                ._scanIdTable(db),
                            referencedColumn: $$ReceiptsTableReferences
                                ._scanIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$ReceiptsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$ReceiptsTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (lineItemsRefs)
                        await $_getPrefetchedData<
                          Receipt,
                          $ReceiptsTable,
                          LineItem
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptsTableReferences
                              ._lineItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptsTableReferences(
                                db,
                                table,
                                p0,
                              ).lineItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.receiptId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptsTable,
      Receipt,
      $$ReceiptsTableFilterComposer,
      $$ReceiptsTableOrderingComposer,
      $$ReceiptsTableAnnotationComposer,
      $$ReceiptsTableCreateCompanionBuilder,
      $$ReceiptsTableUpdateCompanionBuilder,
      (Receipt, $$ReceiptsTableReferences),
      Receipt,
      PrefetchHooks Function({bool scanId, bool categoryId, bool lineItemsRefs})
    >;
typedef $$LineItemsTableCreateCompanionBuilder = LineItemsCompanion Function({
  required String id,
  required String receiptId,
  required String name,
  Value<double> qty,
  Value<double?> unitPrice,
  required double amount,
  Value<int> rowid,
});
typedef $$LineItemsTableUpdateCompanionBuilder = LineItemsCompanion Function({
  Value<String> id,
  Value<String> receiptId,
  Value<String> name,
  Value<double> qty,
  Value<double?> unitPrice,
  Value<double> amount,
  Value<int> rowid,
});

final class $$LineItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LineItemsTable, LineItem> {
  $$LineItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ReceiptsTable _receiptIdTable(_$AppDatabase db) =>
      db.receipts.createAlias('line_items__receipt_id__receipts__id');

  $$ReceiptsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<String>('receipt_id')!;

    final manager = $$ReceiptsTableTableManager(
      $_db,
      $_db.receipts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LineItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LineItemsTable> {
  $$LineItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  $$ReceiptsTableFilterComposer get receiptId {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LineItemsTable> {
  $$LineItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReceiptsTableOrderingComposer get receiptId {
    final $$ReceiptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableOrderingComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LineItemsTable> {
  $$LineItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$ReceiptsTableAnnotationComposer get receiptId {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LineItemsTable,
          LineItem,
          $$LineItemsTableFilterComposer,
          $$LineItemsTableOrderingComposer,
          $$LineItemsTableAnnotationComposer,
          $$LineItemsTableCreateCompanionBuilder,
          $$LineItemsTableUpdateCompanionBuilder,
          (LineItem, $$LineItemsTableReferences),
          LineItem,
          PrefetchHooks Function({bool receiptId})
        > {
  $$LineItemsTableTableManager(_$AppDatabase db, $LineItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LineItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LineItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LineItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> receiptId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<double?> unitPrice = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LineItemsCompanion(
                id: id,
                receiptId: receiptId,
                name: name,
                qty: qty,
                unitPrice: unitPrice,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String receiptId,
                required String name,
                Value<double> qty = const Value.absent(),
                Value<double?> unitPrice = const Value.absent(),
                required double amount,
                Value<int> rowid = const Value.absent(),
              }) => LineItemsCompanion.insert(
                id: id,
                receiptId: receiptId,
                name: name,
                qty: qty,
                unitPrice: unitPrice,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LineItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (receiptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.receiptId,
                        referencedTable: $$LineItemsTableReferences
                            ._receiptIdTable(db),
                        referencedColumn: $$LineItemsTableReferences
                            ._receiptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LineItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LineItemsTable,
      LineItem,
      $$LineItemsTableFilterComposer,
      $$LineItemsTableOrderingComposer,
      $$LineItemsTableAnnotationComposer,
      $$LineItemsTableCreateCompanionBuilder,
      $$LineItemsTableUpdateCompanionBuilder,
      (LineItem, $$LineItemsTableReferences),
      LineItem,
      PrefetchHooks Function({bool receiptId})
    >;
typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  required String id,
  required String scanId,
  required String title,
  Value<String> body,
  Value<bool> pinned,
  Value<int> rowid,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String> id,
  Value<String> scanId,
  Value<String> title,
  Value<String> body,
  Value<bool> pinned,
  Value<int> rowid,
});

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, Document> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('documents__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, $$DocumentsTableReferences),
          Document,
          PrefetchHooks Function({bool scanId})
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scanId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                scanId: scanId,
                title: title,
                body: body,
                pinned: pinned,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scanId,
                required String title,
                Value<String> body = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                scanId: scanId,
                title: title,
                body: body,
                pinned: pinned,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $$DocumentsTableReferences
                            ._scanIdTable(db),
                        referencedColumn: $$DocumentsTableReferences
                            ._scanIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, $$DocumentsTableReferences),
      Document,
      PrefetchHooks Function({bool scanId})
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required String id,
  required String name,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> rowid,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ScanTagsTable, List<ScanTag>> _scanTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scanTags,
    aliasName: 'tags__id__scan_tags__tag_id',
  );

  $$ScanTagsTableProcessedTableManager get scanTagsRefs {
    final manager = $$ScanTagsTableTableManager(
      $_db,
      $_db.scanTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scanTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> scanTagsRefs(
    Expression<bool> Function($$ScanTagsTableFilterComposer f) f,
  ) {
    final $$ScanTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScanTagsTableFilterComposer(
            $db: $db,
            $table: $db.scanTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> scanTagsRefs<T extends Object>(
    Expression<T> Function($$ScanTagsTableAnnotationComposer a) f,
  ) {
    final $$ScanTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scanTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScanTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.scanTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool scanTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => TagsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<int> rowid = const Value.absent(),
          }) => TagsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({scanTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (scanTagsRefs) db.scanTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scanTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, ScanTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._scanTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).scanTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool scanTagsRefs})
    >;
typedef $$ScanTagsTableCreateCompanionBuilder = ScanTagsCompanion Function({
  required String scanId,
  required String tagId,
  Value<int> rowid,
});
typedef $$ScanTagsTableUpdateCompanionBuilder = ScanTagsCompanion Function({
  Value<String> scanId,
  Value<String> tagId,
  Value<int> rowid,
});

final class $$ScanTagsTableReferences
    extends BaseReferences<_$AppDatabase, $ScanTagsTable, ScanTag> {
  $$ScanTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('scan_tags__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('scan_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScanTagsTableFilterComposer
    extends Composer<_$AppDatabase, $ScanTagsTable> {
  $$ScanTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScanTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanTagsTable> {
  $$ScanTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScanTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanTagsTable> {
  $$ScanTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScanTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanTagsTable,
          ScanTag,
          $$ScanTagsTableFilterComposer,
          $$ScanTagsTableOrderingComposer,
          $$ScanTagsTableAnnotationComposer,
          $$ScanTagsTableCreateCompanionBuilder,
          $$ScanTagsTableUpdateCompanionBuilder,
          (ScanTag, $$ScanTagsTableReferences),
          ScanTag,
          PrefetchHooks Function({bool scanId, bool tagId})
        > {
  $$ScanTagsTableTableManager(_$AppDatabase db, $ScanTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> scanId = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ScanTagsCompanion(scanId: scanId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String scanId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => ScanTagsCompanion.insert(
                scanId: scanId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScanTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scanId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $$ScanTagsTableReferences._scanIdTable(
                          db,
                        ),
                        referencedColumn: $$ScanTagsTableReferences
                            ._scanIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$ScanTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$ScanTagsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ScanTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanTagsTable,
      ScanTag,
      $$ScanTagsTableFilterComposer,
      $$ScanTagsTableOrderingComposer,
      $$ScanTagsTableAnnotationComposer,
      $$ScanTagsTableCreateCompanionBuilder,
      $$ScanTagsTableUpdateCompanionBuilder,
      (ScanTag, $$ScanTagsTableReferences),
      ScanTag,
      PrefetchHooks Function({bool scanId, bool tagId})
    >;
typedef $$TextLinesTableCreateCompanionBuilder = TextLinesCompanion Function({
  required String id,
  required String scanId,
  required int pageIndex,
  required int lineOrder,
  required String textContent,
  Value<String> boxJson,
  Value<double> confidence,
  Value<String> script,
  Value<bool> corrected,
  Value<int> rowid,
});
typedef $$TextLinesTableUpdateCompanionBuilder = TextLinesCompanion Function({
  Value<String> id,
  Value<String> scanId,
  Value<int> pageIndex,
  Value<int> lineOrder,
  Value<String> textContent,
  Value<String> boxJson,
  Value<double> confidence,
  Value<String> script,
  Value<bool> corrected,
  Value<int> rowid,
});

final class $$TextLinesTableReferences
    extends BaseReferences<_$AppDatabase, $TextLinesTable, TextLine> {
  $$TextLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('text_lines__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DetailsTable, List<Detail>> _detailsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.details,
    aliasName: 'text_lines__id__details__source_line_id',
  );

  $$DetailsTableProcessedTableManager get detailsRefs {
    final manager = $$DetailsTableTableManager(
      $_db,
      $_db.details,
    ).filter((f) => f.sourceLineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_detailsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranslationsTable, List<Translation>>
  _translationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.translations,
    aliasName: 'text_lines__id__translations__line_id',
  );

  $$TranslationsTableProcessedTableManager get translationsRefs {
    final manager = $$TranslationsTableTableManager(
      $_db,
      $_db.translations,
    ).filter((f) => f.lineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_translationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TextLinesTableFilterComposer
    extends Composer<_$AppDatabase, $TextLinesTable> {
  $$TextLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineOrder => $composableBuilder(
    column: $table.lineOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boxJson => $composableBuilder(
    column: $table.boxJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get corrected => $composableBuilder(
    column: $table.corrected,
    builder: (column) => ColumnFilters(column),
  );

  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> detailsRefs(
    Expression<bool> Function($$DetailsTableFilterComposer f) f,
  ) {
    final $$DetailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.details,
      getReferencedColumn: (t) => t.sourceLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DetailsTableFilterComposer(
            $db: $db,
            $table: $db.details,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> translationsRefs(
    Expression<bool> Function($$TranslationsTableFilterComposer f) f,
  ) {
    final $$TranslationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.translations,
      getReferencedColumn: (t) => t.lineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranslationsTableFilterComposer(
            $db: $db,
            $table: $db.translations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TextLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $TextLinesTable> {
  $$TextLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineOrder => $composableBuilder(
    column: $table.lineOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boxJson => $composableBuilder(
    column: $table.boxJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get corrected => $composableBuilder(
    column: $table.corrected,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TextLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TextLinesTable> {
  $$TextLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<int> get lineOrder =>
      $composableBuilder(column: $table.lineOrder, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get boxJson =>
      $composableBuilder(column: $table.boxJson, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get script =>
      $composableBuilder(column: $table.script, builder: (column) => column);

  GeneratedColumn<bool> get corrected =>
      $composableBuilder(column: $table.corrected, builder: (column) => column);

  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> detailsRefs<T extends Object>(
    Expression<T> Function($$DetailsTableAnnotationComposer a) f,
  ) {
    final $$DetailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.details,
      getReferencedColumn: (t) => t.sourceLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DetailsTableAnnotationComposer(
            $db: $db,
            $table: $db.details,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> translationsRefs<T extends Object>(
    Expression<T> Function($$TranslationsTableAnnotationComposer a) f,
  ) {
    final $$TranslationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.translations,
      getReferencedColumn: (t) => t.lineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranslationsTableAnnotationComposer(
            $db: $db,
            $table: $db.translations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TextLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TextLinesTable,
          TextLine,
          $$TextLinesTableFilterComposer,
          $$TextLinesTableOrderingComposer,
          $$TextLinesTableAnnotationComposer,
          $$TextLinesTableCreateCompanionBuilder,
          $$TextLinesTableUpdateCompanionBuilder,
          (TextLine, $$TextLinesTableReferences),
          TextLine,
          PrefetchHooks Function({
            bool scanId,
            bool detailsRefs,
            bool translationsRefs,
          })
        > {
  $$TextLinesTableTableManager(_$AppDatabase db, $TextLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scanId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<int> lineOrder = const Value.absent(),
                Value<String> textContent = const Value.absent(),
                Value<String> boxJson = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<bool> corrected = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextLinesCompanion(
                id: id,
                scanId: scanId,
                pageIndex: pageIndex,
                lineOrder: lineOrder,
                textContent: textContent,
                boxJson: boxJson,
                confidence: confidence,
                script: script,
                corrected: corrected,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scanId,
                required int pageIndex,
                required int lineOrder,
                required String textContent,
                Value<String> boxJson = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<bool> corrected = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextLinesCompanion.insert(
                id: id,
                scanId: scanId,
                pageIndex: pageIndex,
                lineOrder: lineOrder,
                textContent: textContent,
                boxJson: boxJson,
                confidence: confidence,
                script: script,
                corrected: corrected,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TextLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                scanId = false,
                detailsRefs = false,
                translationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (detailsRefs) db.details,
                    if (translationsRefs) db.translations,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (scanId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.scanId,
                            referencedTable: $$TextLinesTableReferences
                                ._scanIdTable(db),
                            referencedColumn: $$TextLinesTableReferences
                                ._scanIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (detailsRefs)
                        await $_getPrefetchedData<
                          TextLine,
                          $TextLinesTable,
                          Detail
                        >(
                          currentTable: table,
                          referencedTable: $$TextLinesTableReferences
                              ._detailsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TextLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).detailsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceLineId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (translationsRefs)
                        await $_getPrefetchedData<
                          TextLine,
                          $TextLinesTable,
                          Translation
                        >(
                          currentTable: table,
                          referencedTable: $$TextLinesTableReferences
                              ._translationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TextLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).translationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lineId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TextLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TextLinesTable,
      TextLine,
      $$TextLinesTableFilterComposer,
      $$TextLinesTableOrderingComposer,
      $$TextLinesTableAnnotationComposer,
      $$TextLinesTableCreateCompanionBuilder,
      $$TextLinesTableUpdateCompanionBuilder,
      (TextLine, $$TextLinesTableReferences),
      TextLine,
      PrefetchHooks Function({
        bool scanId,
        bool detailsRefs,
        bool translationsRefs,
      })
    >;
typedef $$DetailsTableCreateCompanionBuilder = DetailsCompanion Function({
  required String id,
  required String scanId,
  required String detailKey,
  required String value,
  Value<String?> sourceLineId,
  Value<int> rowid,
});
typedef $$DetailsTableUpdateCompanionBuilder = DetailsCompanion Function({
  Value<String> id,
  Value<String> scanId,
  Value<String> detailKey,
  Value<String> value,
  Value<String?> sourceLineId,
  Value<int> rowid,
});

final class $$DetailsTableReferences
    extends BaseReferences<_$AppDatabase, $DetailsTable, Detail> {
  $$DetailsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('details__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TextLinesTable _sourceLineIdTable(_$AppDatabase db) =>
      db.textLines.createAlias('details__source_line_id__text_lines__id');

  $$TextLinesTableProcessedTableManager? get sourceLineId {
    final $_column = $_itemColumn<String>('source_line_id');
    if ($_column == null) return null;
    final manager = $$TextLinesTableTableManager(
      $_db,
      $_db.textLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceLineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DetailsTableFilterComposer
    extends Composer<_$AppDatabase, $DetailsTable> {
  $$DetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailKey => $composableBuilder(
    column: $table.detailKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TextLinesTableFilterComposer get sourceLineId {
    final $$TextLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceLineId,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableFilterComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $DetailsTable> {
  $$DetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailKey => $composableBuilder(
    column: $table.detailKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TextLinesTableOrderingComposer get sourceLineId {
    final $$TextLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceLineId,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableOrderingComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DetailsTable> {
  $$DetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get detailKey =>
      $composableBuilder(column: $table.detailKey, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TextLinesTableAnnotationComposer get sourceLineId {
    final $$TextLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceLineId,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DetailsTable,
          Detail,
          $$DetailsTableFilterComposer,
          $$DetailsTableOrderingComposer,
          $$DetailsTableAnnotationComposer,
          $$DetailsTableCreateCompanionBuilder,
          $$DetailsTableUpdateCompanionBuilder,
          (Detail, $$DetailsTableReferences),
          Detail,
          PrefetchHooks Function({bool scanId, bool sourceLineId})
        > {
  $$DetailsTableTableManager(_$AppDatabase db, $DetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scanId = const Value.absent(),
                Value<String> detailKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String?> sourceLineId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DetailsCompanion(
                id: id,
                scanId: scanId,
                detailKey: detailKey,
                value: value,
                sourceLineId: sourceLineId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scanId,
                required String detailKey,
                required String value,
                Value<String?> sourceLineId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DetailsCompanion.insert(
                id: id,
                scanId: scanId,
                detailKey: detailKey,
                value: value,
                sourceLineId: sourceLineId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DetailsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scanId = false, sourceLineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $$DetailsTableReferences._scanIdTable(
                          db,
                        ),
                        referencedColumn: $$DetailsTableReferences
                            ._scanIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (sourceLineId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceLineId,
                        referencedTable: $$DetailsTableReferences
                            ._sourceLineIdTable(db),
                        referencedColumn: $$DetailsTableReferences
                            ._sourceLineIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DetailsTable,
      Detail,
      $$DetailsTableFilterComposer,
      $$DetailsTableOrderingComposer,
      $$DetailsTableAnnotationComposer,
      $$DetailsTableCreateCompanionBuilder,
      $$DetailsTableUpdateCompanionBuilder,
      (Detail, $$DetailsTableReferences),
      Detail,
      PrefetchHooks Function({bool scanId, bool sourceLineId})
    >;
typedef $$TranslationsTableCreateCompanionBuilder =
    TranslationsCompanion Function({
      required String id,
      required String scanId,
      Value<String?> lineId,
      required int lineOrder,
      Value<String> sourceText,
      required String englishText,
      Value<String> flagsJson,
      Value<bool> edited,
      Value<int> rowid,
    });
typedef $$TranslationsTableUpdateCompanionBuilder =
    TranslationsCompanion Function({
      Value<String> id,
      Value<String> scanId,
      Value<String?> lineId,
      Value<int> lineOrder,
      Value<String> sourceText,
      Value<String> englishText,
      Value<String> flagsJson,
      Value<bool> edited,
      Value<int> rowid,
    });

final class $$TranslationsTableReferences
    extends BaseReferences<_$AppDatabase, $TranslationsTable, Translation> {
  $$TranslationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScansTable _scanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('translations__scan_id__scans__id');

  $$ScansTableProcessedTableManager get scanId {
    final $_column = $_itemColumn<String>('scan_id')!;

    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TextLinesTable _lineIdTable(_$AppDatabase db) =>
      db.textLines.createAlias('translations__line_id__text_lines__id');

  $$TextLinesTableProcessedTableManager? get lineId {
    final $_column = $_itemColumn<String>('line_id');
    if ($_column == null) return null;
    final manager = $$TextLinesTableTableManager(
      $_db,
      $_db.textLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranslationsTableFilterComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineOrder => $composableBuilder(
    column: $table.lineOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flagsJson => $composableBuilder(
    column: $table.flagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );

  $$ScansTableFilterComposer get scanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TextLinesTableFilterComposer get lineId {
    final $$TextLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableFilterComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranslationsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineOrder => $composableBuilder(
    column: $table.lineOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flagsJson => $composableBuilder(
    column: $table.flagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScansTableOrderingComposer get scanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TextLinesTableOrderingComposer get lineId {
    final $$TextLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableOrderingComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranslationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lineOrder =>
      $composableBuilder(column: $table.lineOrder, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get englishText => $composableBuilder(
    column: $table.englishText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get flagsJson =>
      $composableBuilder(column: $table.flagsJson, builder: (column) => column);

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  $$ScansTableAnnotationComposer get scanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TextLinesTableAnnotationComposer get lineId {
    final $$TextLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lineId,
      referencedTable: $db.textLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TextLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.textLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranslationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranslationsTable,
          Translation,
          $$TranslationsTableFilterComposer,
          $$TranslationsTableOrderingComposer,
          $$TranslationsTableAnnotationComposer,
          $$TranslationsTableCreateCompanionBuilder,
          $$TranslationsTableUpdateCompanionBuilder,
          (Translation, $$TranslationsTableReferences),
          Translation,
          PrefetchHooks Function({bool scanId, bool lineId})
        > {
  $$TranslationsTableTableManager(_$AppDatabase db, $TranslationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scanId = const Value.absent(),
                Value<String?> lineId = const Value.absent(),
                Value<int> lineOrder = const Value.absent(),
                Value<String> sourceText = const Value.absent(),
                Value<String> englishText = const Value.absent(),
                Value<String> flagsJson = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranslationsCompanion(
                id: id,
                scanId: scanId,
                lineId: lineId,
                lineOrder: lineOrder,
                sourceText: sourceText,
                englishText: englishText,
                flagsJson: flagsJson,
                edited: edited,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scanId,
                Value<String?> lineId = const Value.absent(),
                required int lineOrder,
                Value<String> sourceText = const Value.absent(),
                required String englishText,
                Value<String> flagsJson = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranslationsCompanion.insert(
                id: id,
                scanId: scanId,
                lineId: lineId,
                lineOrder: lineOrder,
                sourceText: sourceText,
                englishText: englishText,
                flagsJson: flagsJson,
                edited: edited,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TranslationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scanId = false, lineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.scanId,
                        referencedTable: $$TranslationsTableReferences
                            ._scanIdTable(db),
                        referencedColumn: $$TranslationsTableReferences
                            ._scanIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (lineId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.lineId,
                        referencedTable: $$TranslationsTableReferences
                            ._lineIdTable(db),
                        referencedColumn: $$TranslationsTableReferences
                            ._lineIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranslationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranslationsTable,
      Translation,
      $$TranslationsTableFilterComposer,
      $$TranslationsTableOrderingComposer,
      $$TranslationsTableAnnotationComposer,
      $$TranslationsTableCreateCompanionBuilder,
      $$TranslationsTableUpdateCompanionBuilder,
      (Translation, $$TranslationsTableReferences),
      Translation,
      PrefetchHooks Function({bool scanId, bool lineId})
    >;
typedef $$NamesTableCreateCompanionBuilder = NamesCompanion Function({
  required String id,
  required String bangla,
  required String english,
  Value<String> category,
  Value<String> source,
  Value<bool> confirmed,
  Value<int> rowid,
});
typedef $$NamesTableUpdateCompanionBuilder = NamesCompanion Function({
  Value<String> id,
  Value<String> bangla,
  Value<String> english,
  Value<String> category,
  Value<String> source,
  Value<bool> confirmed,
  Value<int> rowid,
});

class $$NamesTableFilterComposer extends Composer<_$AppDatabase, $NamesTable> {
  $$NamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bangla => $composableBuilder(
    column: $table.bangla,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get english => $composableBuilder(
    column: $table.english,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NamesTableOrderingComposer
    extends Composer<_$AppDatabase, $NamesTable> {
  $$NamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bangla => $composableBuilder(
    column: $table.bangla,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get english => $composableBuilder(
    column: $table.english,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NamesTable> {
  $$NamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bangla =>
      $composableBuilder(column: $table.bangla, builder: (column) => column);

  GeneratedColumn<String> get english =>
      $composableBuilder(column: $table.english, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get confirmed =>
      $composableBuilder(column: $table.confirmed, builder: (column) => column);
}

class $$NamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NamesTable,
          Name,
          $$NamesTableFilterComposer,
          $$NamesTableOrderingComposer,
          $$NamesTableAnnotationComposer,
          $$NamesTableCreateCompanionBuilder,
          $$NamesTableUpdateCompanionBuilder,
          (Name, BaseReferences<_$AppDatabase, $NamesTable, Name>),
          Name,
          PrefetchHooks Function()
        > {
  $$NamesTableTableManager(_$AppDatabase db, $NamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bangla = const Value.absent(),
                Value<String> english = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> confirmed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NamesCompanion(
                id: id,
                bangla: bangla,
                english: english,
                category: category,
                source: source,
                confirmed: confirmed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bangla,
                required String english,
                Value<String> category = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> confirmed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NamesCompanion.insert(
                id: id,
                bangla: bangla,
                english: english,
                category: category,
                source: source,
                confirmed: confirmed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NamesTable,
      Name,
      $$NamesTableFilterComposer,
      $$NamesTableOrderingComposer,
      $$NamesTableAnnotationComposer,
      $$NamesTableCreateCompanionBuilder,
      $$NamesTableUpdateCompanionBuilder,
      (Name, BaseReferences<_$AppDatabase, $NamesTable, Name>),
      Name,
      PrefetchHooks Function()
    >;
typedef $$TermsTableCreateCompanionBuilder = TermsCompanion Function({
  required String id,
  required String bangla,
  Value<String> transliteration,
  required String english,
  Value<String> explanation,
  Value<String> chosenForm,
  Value<int> rowid,
});
typedef $$TermsTableUpdateCompanionBuilder = TermsCompanion Function({
  Value<String> id,
  Value<String> bangla,
  Value<String> transliteration,
  Value<String> english,
  Value<String> explanation,
  Value<String> chosenForm,
  Value<int> rowid,
});

class $$TermsTableFilterComposer extends Composer<_$AppDatabase, $TermsTable> {
  $$TermsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bangla => $composableBuilder(
    column: $table.bangla,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get english => $composableBuilder(
    column: $table.english,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chosenForm => $composableBuilder(
    column: $table.chosenForm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TermsTableOrderingComposer
    extends Composer<_$AppDatabase, $TermsTable> {
  $$TermsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bangla => $composableBuilder(
    column: $table.bangla,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get english => $composableBuilder(
    column: $table.english,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosenForm => $composableBuilder(
    column: $table.chosenForm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TermsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TermsTable> {
  $$TermsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bangla =>
      $composableBuilder(column: $table.bangla, builder: (column) => column);

  GeneratedColumn<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get english =>
      $composableBuilder(column: $table.english, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chosenForm => $composableBuilder(
    column: $table.chosenForm,
    builder: (column) => column,
  );
}

class $$TermsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TermsTable,
          Term,
          $$TermsTableFilterComposer,
          $$TermsTableOrderingComposer,
          $$TermsTableAnnotationComposer,
          $$TermsTableCreateCompanionBuilder,
          $$TermsTableUpdateCompanionBuilder,
          (Term, BaseReferences<_$AppDatabase, $TermsTable, Term>),
          Term,
          PrefetchHooks Function()
        > {
  $$TermsTableTableManager(_$AppDatabase db, $TermsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TermsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TermsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TermsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bangla = const Value.absent(),
                Value<String> transliteration = const Value.absent(),
                Value<String> english = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<String> chosenForm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TermsCompanion(
                id: id,
                bangla: bangla,
                transliteration: transliteration,
                english: english,
                explanation: explanation,
                chosenForm: chosenForm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bangla,
                Value<String> transliteration = const Value.absent(),
                required String english,
                Value<String> explanation = const Value.absent(),
                Value<String> chosenForm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TermsCompanion.insert(
                id: id,
                bangla: bangla,
                transliteration: transliteration,
                english: english,
                explanation: explanation,
                chosenForm: chosenForm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TermsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TermsTable,
      Term,
      $$TermsTableFilterComposer,
      $$TermsTableOrderingComposer,
      $$TermsTableAnnotationComposer,
      $$TermsTableCreateCompanionBuilder,
      $$TermsTableUpdateCompanionBuilder,
      (Term, BaseReferences<_$AppDatabase, $TermsTable, Term>),
      Term,
      PrefetchHooks Function()
    >;
typedef $$CorrectionsTableCreateCompanionBuilder =
    CorrectionsCompanion Function({
      required String id,
      required String wrongReading,
      required String rightReading,
      Value<int> count,
      Value<int> rowid,
    });
typedef $$CorrectionsTableUpdateCompanionBuilder =
    CorrectionsCompanion Function({
      Value<String> id,
      Value<String> wrongReading,
      Value<String> rightReading,
      Value<int> count,
      Value<int> rowid,
    });

class $$CorrectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CorrectionsTable> {
  $$CorrectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrongReading => $composableBuilder(
    column: $table.wrongReading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rightReading => $composableBuilder(
    column: $table.rightReading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CorrectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CorrectionsTable> {
  $$CorrectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrongReading => $composableBuilder(
    column: $table.wrongReading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rightReading => $composableBuilder(
    column: $table.rightReading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CorrectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CorrectionsTable> {
  $$CorrectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wrongReading => $composableBuilder(
    column: $table.wrongReading,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rightReading => $composableBuilder(
    column: $table.rightReading,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$CorrectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CorrectionsTable,
          Correction,
          $$CorrectionsTableFilterComposer,
          $$CorrectionsTableOrderingComposer,
          $$CorrectionsTableAnnotationComposer,
          $$CorrectionsTableCreateCompanionBuilder,
          $$CorrectionsTableUpdateCompanionBuilder,
          (
            Correction,
            BaseReferences<_$AppDatabase, $CorrectionsTable, Correction>,
          ),
          Correction,
          PrefetchHooks Function()
        > {
  $$CorrectionsTableTableManager(_$AppDatabase db, $CorrectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CorrectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CorrectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CorrectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> wrongReading = const Value.absent(),
                Value<String> rightReading = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrectionsCompanion(
                id: id,
                wrongReading: wrongReading,
                rightReading: rightReading,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String wrongReading,
                required String rightReading,
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CorrectionsCompanion.insert(
                id: id,
                wrongReading: wrongReading,
                rightReading: rightReading,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CorrectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CorrectionsTable,
      Correction,
      $$CorrectionsTableFilterComposer,
      $$CorrectionsTableOrderingComposer,
      $$CorrectionsTableAnnotationComposer,
      $$CorrectionsTableCreateCompanionBuilder,
      $$CorrectionsTableUpdateCompanionBuilder,
      (
        Correction,
        BaseReferences<_$AppDatabase, $CorrectionsTable, Correction>,
      ),
      Correction,
      PrefetchHooks Function()
    >;
typedef $$BundlesTableCreateCompanionBuilder = BundlesCompanion Function({
  required String id,
  required String title,
  Value<String> purpose,
  Value<DateTime?> dueDate,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BundlesTableUpdateCompanionBuilder = BundlesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> purpose,
  Value<DateTime?> dueDate,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$BundlesTableReferences
    extends BaseReferences<_$AppDatabase, $BundlesTable, Bundle> {
  $$BundlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BundleItemsTable, List<BundleItem>>
  _bundleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bundleItems,
    aliasName: 'bundles__id__bundle_items__bundle_id',
  );

  $$BundleItemsTableProcessedTableManager get bundleItemsRefs {
    final manager = $$BundleItemsTableTableManager(
      $_db,
      $_db.bundleItems,
    ).filter((f) => f.bundleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bundleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BundlesTableFilterComposer
    extends Composer<_$AppDatabase, $BundlesTable> {
  $$BundlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bundleItemsRefs(
    Expression<bool> Function($$BundleItemsTableFilterComposer f) f,
  ) {
    final $$BundleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.bundleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableFilterComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BundlesTableOrderingComposer
    extends Composer<_$AppDatabase, $BundlesTable> {
  $$BundlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BundlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BundlesTable> {
  $$BundlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> bundleItemsRefs<T extends Object>(
    Expression<T> Function($$BundleItemsTableAnnotationComposer a) f,
  ) {
    final $$BundleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.bundleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BundlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BundlesTable,
          Bundle,
          $$BundlesTableFilterComposer,
          $$BundlesTableOrderingComposer,
          $$BundlesTableAnnotationComposer,
          $$BundlesTableCreateCompanionBuilder,
          $$BundlesTableUpdateCompanionBuilder,
          (Bundle, $$BundlesTableReferences),
          Bundle,
          PrefetchHooks Function({bool bundleItemsRefs})
        > {
  $$BundlesTableTableManager(_$AppDatabase db, $BundlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BundlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BundlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BundlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BundlesCompanion(
                id: id,
                title: title,
                purpose: purpose,
                dueDate: dueDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> purpose = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BundlesCompanion.insert(
                id: id,
                title: title,
                purpose: purpose,
                dueDate: dueDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BundlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bundleItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (bundleItemsRefs) db.bundleItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (bundleItemsRefs)
                    await $_getPrefetchedData<
                      Bundle,
                      $BundlesTable,
                      BundleItem
                    >(
                      currentTable: table,
                      referencedTable: $$BundlesTableReferences
                          ._bundleItemsRefsTable(db),
                      managerFromTypedResult: (p0) => $$BundlesTableReferences(
                        db,
                        table,
                        p0,
                      ).bundleItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bundleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BundlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BundlesTable,
      Bundle,
      $$BundlesTableFilterComposer,
      $$BundlesTableOrderingComposer,
      $$BundlesTableAnnotationComposer,
      $$BundlesTableCreateCompanionBuilder,
      $$BundlesTableUpdateCompanionBuilder,
      (Bundle, $$BundlesTableReferences),
      Bundle,
      PrefetchHooks Function({bool bundleItemsRefs})
    >;
typedef $$BundleItemsTableCreateCompanionBuilder =
    BundleItemsCompanion Function({
      required String id,
      required String bundleId,
      required String title,
      required int itemOrder,
      Value<String> expectedKind,
      Value<String?> linkedScanId,
      Value<int> rowid,
    });
typedef $$BundleItemsTableUpdateCompanionBuilder =
    BundleItemsCompanion Function({
      Value<String> id,
      Value<String> bundleId,
      Value<String> title,
      Value<int> itemOrder,
      Value<String> expectedKind,
      Value<String?> linkedScanId,
      Value<int> rowid,
    });

final class $$BundleItemsTableReferences
    extends BaseReferences<_$AppDatabase, $BundleItemsTable, BundleItem> {
  $$BundleItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BundlesTable _bundleIdTable(_$AppDatabase db) =>
      db.bundles.createAlias('bundle_items__bundle_id__bundles__id');

  $$BundlesTableProcessedTableManager get bundleId {
    final $_column = $_itemColumn<String>('bundle_id')!;

    final manager = $$BundlesTableTableManager(
      $_db,
      $_db.bundles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bundleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ScansTable _linkedScanIdTable(_$AppDatabase db) =>
      db.scans.createAlias('bundle_items__linked_scan_id__scans__id');

  $$ScansTableProcessedTableManager? get linkedScanId {
    final $_column = $_itemColumn<String>('linked_scan_id');
    if ($_column == null) return null;
    final manager = $$ScansTableTableManager(
      $_db,
      $_db.scans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedScanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BundleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $BundleItemsTable> {
  $$BundleItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemOrder => $composableBuilder(
    column: $table.itemOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedKind => $composableBuilder(
    column: $table.expectedKind,
    builder: (column) => ColumnFilters(column),
  );

  $$BundlesTableFilterComposer get bundleId {
    final $$BundlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bundleId,
      referencedTable: $db.bundles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundlesTableFilterComposer(
            $db: $db,
            $table: $db.bundles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScansTableFilterComposer get linkedScanId {
    final $$ScansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableFilterComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BundleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $BundleItemsTable> {
  $$BundleItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemOrder => $composableBuilder(
    column: $table.itemOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedKind => $composableBuilder(
    column: $table.expectedKind,
    builder: (column) => ColumnOrderings(column),
  );

  $$BundlesTableOrderingComposer get bundleId {
    final $$BundlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bundleId,
      referencedTable: $db.bundles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundlesTableOrderingComposer(
            $db: $db,
            $table: $db.bundles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScansTableOrderingComposer get linkedScanId {
    final $$ScansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableOrderingComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BundleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BundleItemsTable> {
  $$BundleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get itemOrder =>
      $composableBuilder(column: $table.itemOrder, builder: (column) => column);

  GeneratedColumn<String> get expectedKind => $composableBuilder(
    column: $table.expectedKind,
    builder: (column) => column,
  );

  $$BundlesTableAnnotationComposer get bundleId {
    final $$BundlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bundleId,
      referencedTable: $db.bundles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundlesTableAnnotationComposer(
            $db: $db,
            $table: $db.bundles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ScansTableAnnotationComposer get linkedScanId {
    final $$ScansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedScanId,
      referencedTable: $db.scans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScansTableAnnotationComposer(
            $db: $db,
            $table: $db.scans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BundleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BundleItemsTable,
          BundleItem,
          $$BundleItemsTableFilterComposer,
          $$BundleItemsTableOrderingComposer,
          $$BundleItemsTableAnnotationComposer,
          $$BundleItemsTableCreateCompanionBuilder,
          $$BundleItemsTableUpdateCompanionBuilder,
          (BundleItem, $$BundleItemsTableReferences),
          BundleItem,
          PrefetchHooks Function({bool bundleId, bool linkedScanId})
        > {
  $$BundleItemsTableTableManager(_$AppDatabase db, $BundleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BundleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BundleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BundleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bundleId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> itemOrder = const Value.absent(),
                Value<String> expectedKind = const Value.absent(),
                Value<String?> linkedScanId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BundleItemsCompanion(
                id: id,
                bundleId: bundleId,
                title: title,
                itemOrder: itemOrder,
                expectedKind: expectedKind,
                linkedScanId: linkedScanId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bundleId,
                required String title,
                required int itemOrder,
                Value<String> expectedKind = const Value.absent(),
                Value<String?> linkedScanId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BundleItemsCompanion.insert(
                id: id,
                bundleId: bundleId,
                title: title,
                itemOrder: itemOrder,
                expectedKind: expectedKind,
                linkedScanId: linkedScanId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BundleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bundleId = false, linkedScanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bundleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bundleId,
                        referencedTable: $$BundleItemsTableReferences
                            ._bundleIdTable(db),
                        referencedColumn: $$BundleItemsTableReferences
                            ._bundleIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (linkedScanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.linkedScanId,
                        referencedTable: $$BundleItemsTableReferences
                            ._linkedScanIdTable(db),
                        referencedColumn: $$BundleItemsTableReferences
                            ._linkedScanIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BundleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BundleItemsTable,
      BundleItem,
      $$BundleItemsTableFilterComposer,
      $$BundleItemsTableOrderingComposer,
      $$BundleItemsTableAnnotationComposer,
      $$BundleItemsTableCreateCompanionBuilder,
      $$BundleItemsTableUpdateCompanionBuilder,
      (BundleItem, $$BundleItemsTableReferences),
      BundleItem,
      PrefetchHooks Function({bool bundleId, bool linkedScanId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScansTableTableManager get scans =>
      $$ScansTableTableManager(_db, _db.scans);
  $$ScanPagesTableTableManager get scanPages =>
      $$ScanPagesTableTableManager(_db, _db.scanPages);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db, _db.receipts);
  $$LineItemsTableTableManager get lineItems =>
      $$LineItemsTableTableManager(_db, _db.lineItems);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$ScanTagsTableTableManager get scanTags =>
      $$ScanTagsTableTableManager(_db, _db.scanTags);
  $$TextLinesTableTableManager get textLines =>
      $$TextLinesTableTableManager(_db, _db.textLines);
  $$DetailsTableTableManager get details =>
      $$DetailsTableTableManager(_db, _db.details);
  $$TranslationsTableTableManager get translations =>
      $$TranslationsTableTableManager(_db, _db.translations);
  $$NamesTableTableManager get names =>
      $$NamesTableTableManager(_db, _db.names);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db, _db.terms);
  $$CorrectionsTableTableManager get corrections =>
      $$CorrectionsTableTableManager(_db, _db.corrections);
  $$BundlesTableTableManager get bundles =>
      $$BundlesTableTableManager(_db, _db.bundles);
  $$BundleItemsTableTableManager get bundleItems =>
      $$BundleItemsTableTableManager(_db, _db.bundleItems);
}
