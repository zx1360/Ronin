// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class GalleryAssets extends Table
    with TableInfo<GalleryAssets, GalleryAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryAssets(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(GalleryAssets.$convertercreatedAt);
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(GalleryAssets.$converterupdatedAt);
  late final GeneratedColumnWithTypeConverter<DateTime, int> capturedAt =
      GeneratedColumn<int>(
        'captured_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(GalleryAssets.$convertercapturedAt);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _previewPathMeta = const VerificationMeta(
    'previewPath',
  );
  late final GeneratedColumn<String> previewPath = GeneratedColumn<String>(
    'preview_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncCountMeta = const VerificationMeta(
    'syncCount',
  );
  late final GeneratedColumn<int> syncCount = GeneratedColumn<int>(
    'sync_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'REFERENCES gallery_assets(id)ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED',
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _editParamsMeta = const VerificationMeta(
    'editParams',
  );
  late final GeneratedColumn<String> editParams = GeneratedColumn<String>(
    'edit_params',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    capturedAt,
    filePath,
    thumbPath,
    previewPath,
    hash,
    sizeBytes,
    mimeType,
    isDeleted,
    syncCount,
    groupId,
    message,
    editParams,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    }
    if (data.containsKey('preview_path')) {
      context.handle(
        _previewPathMeta,
        previewPath.isAcceptableOrUnknown(
          data['preview_path']!,
          _previewPathMeta,
        ),
      );
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    } else if (isInserting) {
      context.missing(_isDeletedMeta);
    }
    if (data.containsKey('sync_count')) {
      context.handle(
        _syncCountMeta,
        syncCount.isAcceptableOrUnknown(data['sync_count']!, _syncCountMeta),
      );
    } else if (isInserting) {
      context.missing(_syncCountMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    if (data.containsKey('edit_params')) {
      context.handle(
        _editParamsMeta,
        editParams.isAcceptableOrUnknown(data['edit_params']!, _editParamsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GalleryAssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryAssetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: GalleryAssets.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: GalleryAssets.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      capturedAt: GalleryAssets.$convertercapturedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}captured_at'],
        )!,
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      ),
      previewPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_path'],
      ),
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      syncCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_count'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
      editParams: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edit_params'],
      ),
    );
  }

  @override
  GalleryAssets createAlias(String alias) {
    return GalleryAssets(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = const EpochMicros();
  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  static TypeConverter<DateTime, int> $convertercapturedAt =
      const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class GalleryAssetRow extends DataClass implements Insertable<GalleryAssetRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime capturedAt;
  final String filePath;
  final String? thumbPath;
  final String? previewPath;
  final String hash;
  final int sizeBytes;
  final String? mimeType;
  final bool isDeleted;
  final int syncCount;
  final String? groupId;
  final String? message;
  final String? editParams;
  const GalleryAssetRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.capturedAt,
    required this.filePath,
    this.thumbPath,
    this.previewPath,
    required this.hash,
    required this.sizeBytes,
    this.mimeType,
    required this.isDeleted,
    required this.syncCount,
    this.groupId,
    this.message,
    this.editParams,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['created_at'] = Variable<int>(
        GalleryAssets.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        GalleryAssets.$converterupdatedAt.toSql(updatedAt),
      );
    }
    {
      map['captured_at'] = Variable<int>(
        GalleryAssets.$convertercapturedAt.toSql(capturedAt),
      );
    }
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || thumbPath != null) {
      map['thumb_path'] = Variable<String>(thumbPath);
    }
    if (!nullToAbsent || previewPath != null) {
      map['preview_path'] = Variable<String>(previewPath);
    }
    map['hash'] = Variable<String>(hash);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_count'] = Variable<int>(syncCount);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    if (!nullToAbsent || editParams != null) {
      map['edit_params'] = Variable<String>(editParams);
    }
    return map;
  }

  GalleryAssetsCompanion toCompanion(bool nullToAbsent) {
    return GalleryAssetsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      capturedAt: Value(capturedAt),
      filePath: Value(filePath),
      thumbPath: thumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbPath),
      previewPath: previewPath == null && nullToAbsent
          ? const Value.absent()
          : Value(previewPath),
      hash: Value(hash),
      sizeBytes: Value(sizeBytes),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      isDeleted: Value(isDeleted),
      syncCount: Value(syncCount),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
      editParams: editParams == null && nullToAbsent
          ? const Value.absent()
          : Value(editParams),
    );
  }

  factory GalleryAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryAssetRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      capturedAt: serializer.fromJson<DateTime>(json['captured_at']),
      filePath: serializer.fromJson<String>(json['file_path']),
      thumbPath: serializer.fromJson<String?>(json['thumb_path']),
      previewPath: serializer.fromJson<String?>(json['preview_path']),
      hash: serializer.fromJson<String>(json['hash']),
      sizeBytes: serializer.fromJson<int>(json['size_bytes']),
      mimeType: serializer.fromJson<String?>(json['mime_type']),
      isDeleted: serializer.fromJson<bool>(json['is_deleted']),
      syncCount: serializer.fromJson<int>(json['sync_count']),
      groupId: serializer.fromJson<String?>(json['group_id']),
      message: serializer.fromJson<String?>(json['message']),
      editParams: serializer.fromJson<String?>(json['edit_params']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'captured_at': serializer.toJson<DateTime>(capturedAt),
      'file_path': serializer.toJson<String>(filePath),
      'thumb_path': serializer.toJson<String?>(thumbPath),
      'preview_path': serializer.toJson<String?>(previewPath),
      'hash': serializer.toJson<String>(hash),
      'size_bytes': serializer.toJson<int>(sizeBytes),
      'mime_type': serializer.toJson<String?>(mimeType),
      'is_deleted': serializer.toJson<bool>(isDeleted),
      'sync_count': serializer.toJson<int>(syncCount),
      'group_id': serializer.toJson<String?>(groupId),
      'message': serializer.toJson<String?>(message),
      'edit_params': serializer.toJson<String?>(editParams),
    };
  }

  GalleryAssetRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? capturedAt,
    String? filePath,
    Value<String?> thumbPath = const Value.absent(),
    Value<String?> previewPath = const Value.absent(),
    String? hash,
    int? sizeBytes,
    Value<String?> mimeType = const Value.absent(),
    bool? isDeleted,
    int? syncCount,
    Value<String?> groupId = const Value.absent(),
    Value<String?> message = const Value.absent(),
    Value<String?> editParams = const Value.absent(),
  }) => GalleryAssetRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    capturedAt: capturedAt ?? this.capturedAt,
    filePath: filePath ?? this.filePath,
    thumbPath: thumbPath.present ? thumbPath.value : this.thumbPath,
    previewPath: previewPath.present ? previewPath.value : this.previewPath,
    hash: hash ?? this.hash,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    isDeleted: isDeleted ?? this.isDeleted,
    syncCount: syncCount ?? this.syncCount,
    groupId: groupId.present ? groupId.value : this.groupId,
    message: message.present ? message.value : this.message,
    editParams: editParams.present ? editParams.value : this.editParams,
  );
  GalleryAssetRow copyWithCompanion(GalleryAssetsCompanion data) {
    return GalleryAssetRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
      previewPath: data.previewPath.present
          ? data.previewPath.value
          : this.previewPath,
      hash: data.hash.present ? data.hash.value : this.hash,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncCount: data.syncCount.present ? data.syncCount.value : this.syncCount,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      message: data.message.present ? data.message.value : this.message,
      editParams: data.editParams.present
          ? data.editParams.value
          : this.editParams,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryAssetRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('filePath: $filePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('previewPath: $previewPath, ')
          ..write('hash: $hash, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncCount: $syncCount, ')
          ..write('groupId: $groupId, ')
          ..write('message: $message, ')
          ..write('editParams: $editParams')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    capturedAt,
    filePath,
    thumbPath,
    previewPath,
    hash,
    sizeBytes,
    mimeType,
    isDeleted,
    syncCount,
    groupId,
    message,
    editParams,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryAssetRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.capturedAt == this.capturedAt &&
          other.filePath == this.filePath &&
          other.thumbPath == this.thumbPath &&
          other.previewPath == this.previewPath &&
          other.hash == this.hash &&
          other.sizeBytes == this.sizeBytes &&
          other.mimeType == this.mimeType &&
          other.isDeleted == this.isDeleted &&
          other.syncCount == this.syncCount &&
          other.groupId == this.groupId &&
          other.message == this.message &&
          other.editParams == this.editParams);
}

class GalleryAssetsCompanion extends UpdateCompanion<GalleryAssetRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> capturedAt;
  final Value<String> filePath;
  final Value<String?> thumbPath;
  final Value<String?> previewPath;
  final Value<String> hash;
  final Value<int> sizeBytes;
  final Value<String?> mimeType;
  final Value<bool> isDeleted;
  final Value<int> syncCount;
  final Value<String?> groupId;
  final Value<String?> message;
  final Value<String?> editParams;
  final Value<int> rowid;
  const GalleryAssetsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.filePath = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.previewPath = const Value.absent(),
    this.hash = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncCount = const Value.absent(),
    this.groupId = const Value.absent(),
    this.message = const Value.absent(),
    this.editParams = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryAssetsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime capturedAt,
    required String filePath,
    this.thumbPath = const Value.absent(),
    this.previewPath = const Value.absent(),
    required String hash,
    required int sizeBytes,
    this.mimeType = const Value.absent(),
    required bool isDeleted,
    required int syncCount,
    this.groupId = const Value.absent(),
    this.message = const Value.absent(),
    this.editParams = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       capturedAt = Value(capturedAt),
       filePath = Value(filePath),
       hash = Value(hash),
       sizeBytes = Value(sizeBytes),
       isDeleted = Value(isDeleted),
       syncCount = Value(syncCount);
  static Insertable<GalleryAssetRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? capturedAt,
    Expression<String>? filePath,
    Expression<String>? thumbPath,
    Expression<String>? previewPath,
    Expression<String>? hash,
    Expression<int>? sizeBytes,
    Expression<String>? mimeType,
    Expression<bool>? isDeleted,
    Expression<int>? syncCount,
    Expression<String>? groupId,
    Expression<String>? message,
    Expression<String>? editParams,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (filePath != null) 'file_path': filePath,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (previewPath != null) 'preview_path': previewPath,
      if (hash != null) 'hash': hash,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mimeType != null) 'mime_type': mimeType,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncCount != null) 'sync_count': syncCount,
      if (groupId != null) 'group_id': groupId,
      if (message != null) 'message': message,
      if (editParams != null) 'edit_params': editParams,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryAssetsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? capturedAt,
    Value<String>? filePath,
    Value<String?>? thumbPath,
    Value<String?>? previewPath,
    Value<String>? hash,
    Value<int>? sizeBytes,
    Value<String?>? mimeType,
    Value<bool>? isDeleted,
    Value<int>? syncCount,
    Value<String?>? groupId,
    Value<String?>? message,
    Value<String?>? editParams,
    Value<int>? rowid,
  }) {
    return GalleryAssetsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      filePath: filePath ?? this.filePath,
      thumbPath: thumbPath ?? this.thumbPath,
      previewPath: previewPath ?? this.previewPath,
      hash: hash ?? this.hash,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      isDeleted: isDeleted ?? this.isDeleted,
      syncCount: syncCount ?? this.syncCount,
      groupId: groupId ?? this.groupId,
      message: message ?? this.message,
      editParams: editParams ?? this.editParams,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        GalleryAssets.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        GalleryAssets.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(
        GalleryAssets.$convertercapturedAt.toSql(capturedAt.value),
      );
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (previewPath.present) {
      map['preview_path'] = Variable<String>(previewPath.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncCount.present) {
      map['sync_count'] = Variable<int>(syncCount.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (editParams.present) {
      map['edit_params'] = Variable<String>(editParams.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryAssetsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('filePath: $filePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('previewPath: $previewPath, ')
          ..write('hash: $hash, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncCount: $syncCount, ')
          ..write('groupId: $groupId, ')
          ..write('message: $message, ')
          ..write('editParams: $editParams, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class GalleryTags extends Table with TableInfo<GalleryTags, GalleryTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryTags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(GalleryTags.$convertercreatedAt);
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(GalleryTags.$converterupdatedAt);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'REFERENCES gallery_tags(id)ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED',
  );
  static const VerificationMeta _fullPathMeta = const VerificationMeta(
    'fullPath',
  );
  late final GeneratedColumn<String> fullPath = GeneratedColumn<String>(
    'full_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _mediaCountMeta = const VerificationMeta(
    'mediaCount',
  );
  late final GeneratedColumn<int> mediaCount = GeneratedColumn<int>(
    'media_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    name,
    parentId,
    fullPath,
    isFavorite,
    mediaCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryTagRow> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('full_path')) {
      context.handle(
        _fullPathMeta,
        fullPath.isAcceptableOrUnknown(data['full_path']!, _fullPathMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    } else if (isInserting) {
      context.missing(_isFavoriteMeta);
    }
    if (data.containsKey('media_count')) {
      context.handle(
        _mediaCountMeta,
        mediaCount.isAcceptableOrUnknown(data['media_count']!, _mediaCountMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GalleryTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryTagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: GalleryTags.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: GalleryTags.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      fullPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_path'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      mediaCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_count'],
      )!,
    );
  }

  @override
  GalleryTags createAlias(String alias) {
    return GalleryTags(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = const EpochMicros();
  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class GalleryTagRow extends DataClass implements Insertable<GalleryTagRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String name;
  final String? parentId;
  final String? fullPath;
  final bool isFavorite;
  final int mediaCount;
  const GalleryTagRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    this.parentId,
    this.fullPath,
    required this.isFavorite,
    required this.mediaCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['created_at'] = Variable<int>(
        GalleryTags.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        GalleryTags.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || fullPath != null) {
      map['full_path'] = Variable<String>(fullPath);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['media_count'] = Variable<int>(mediaCount);
    return map;
  }

  GalleryTagsCompanion toCompanion(bool nullToAbsent) {
    return GalleryTagsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      fullPath: fullPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fullPath),
      isFavorite: Value(isFavorite),
      mediaCount: Value(mediaCount),
    );
  }

  factory GalleryTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryTagRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      fullPath: serializer.fromJson<String?>(json['full_path']),
      isFavorite: serializer.fromJson<bool>(json['is_favorite']),
      mediaCount: serializer.fromJson<int>(json['media_count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'name': serializer.toJson<String>(name),
      'parent_id': serializer.toJson<String?>(parentId),
      'full_path': serializer.toJson<String?>(fullPath),
      'is_favorite': serializer.toJson<bool>(isFavorite),
      'media_count': serializer.toJson<int>(mediaCount),
    };
  }

  GalleryTagRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    Value<String?> parentId = const Value.absent(),
    Value<String?> fullPath = const Value.absent(),
    bool? isFavorite,
    int? mediaCount,
  }) => GalleryTagRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    fullPath: fullPath.present ? fullPath.value : this.fullPath,
    isFavorite: isFavorite ?? this.isFavorite,
    mediaCount: mediaCount ?? this.mediaCount,
  );
  GalleryTagRow copyWithCompanion(GalleryTagsCompanion data) {
    return GalleryTagRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      fullPath: data.fullPath.present ? data.fullPath.value : this.fullPath,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      mediaCount: data.mediaCount.present
          ? data.mediaCount.value
          : this.mediaCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryTagRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('fullPath: $fullPath, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('mediaCount: $mediaCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    name,
    parentId,
    fullPath,
    isFavorite,
    mediaCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryTagRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.fullPath == this.fullPath &&
          other.isFavorite == this.isFavorite &&
          other.mediaCount == this.mediaCount);
}

class GalleryTagsCompanion extends UpdateCompanion<GalleryTagRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<String?> fullPath;
  final Value<bool> isFavorite;
  final Value<int> mediaCount;
  final Value<int> rowid;
  const GalleryTagsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.fullPath = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.mediaCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryTagsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String name,
    this.parentId = const Value.absent(),
    this.fullPath = const Value.absent(),
    required bool isFavorite,
    required int mediaCount,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name),
       isFavorite = Value(isFavorite),
       mediaCount = Value(mediaCount);
  static Insertable<GalleryTagRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<String>? fullPath,
    Expression<bool>? isFavorite,
    Expression<int>? mediaCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (fullPath != null) 'full_path': fullPath,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (mediaCount != null) 'media_count': mediaCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryTagsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? name,
    Value<String?>? parentId,
    Value<String?>? fullPath,
    Value<bool>? isFavorite,
    Value<int>? mediaCount,
    Value<int>? rowid,
  }) {
    return GalleryTagsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      fullPath: fullPath ?? this.fullPath,
      isFavorite: isFavorite ?? this.isFavorite,
      mediaCount: mediaCount ?? this.mediaCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        GalleryTags.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        GalleryTags.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (fullPath.present) {
      map['full_path'] = Variable<String>(fullPath.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (mediaCount.present) {
      map['media_count'] = Variable<int>(mediaCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryTagsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('fullPath: $fullPath, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('mediaCount: $mediaCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class GalleryLinks extends Table with TableInfo<GalleryLinks, GalleryLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryLinks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES gallery_assets(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES gallery_tags(id)ON DELETE CASCADE',
  );
  @override
  List<GeneratedColumn> get $columns => [mediaId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {mediaId, tagId};
  @override
  GalleryLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryLink(
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  GalleryLinks createAlias(String alias) {
    return GalleryLinks(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(media_id, tag_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class GalleryLink extends DataClass implements Insertable<GalleryLink> {
  final String mediaId;
  final String tagId;
  const GalleryLink({required this.mediaId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<String>(mediaId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  GalleryLinksCompanion toCompanion(bool nullToAbsent) {
    return GalleryLinksCompanion(mediaId: Value(mediaId), tagId: Value(tagId));
  }

  factory GalleryLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryLink(
      mediaId: serializer.fromJson<String>(json['media_id']),
      tagId: serializer.fromJson<String>(json['tag_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'media_id': serializer.toJson<String>(mediaId),
      'tag_id': serializer.toJson<String>(tagId),
    };
  }

  GalleryLink copyWith({String? mediaId, String? tagId}) =>
      GalleryLink(mediaId: mediaId ?? this.mediaId, tagId: tagId ?? this.tagId);
  GalleryLink copyWithCompanion(GalleryLinksCompanion data) {
    return GalleryLink(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryLink(')
          ..write('mediaId: $mediaId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryLink &&
          other.mediaId == this.mediaId &&
          other.tagId == this.tagId);
}

class GalleryLinksCompanion extends UpdateCompanion<GalleryLink> {
  final Value<String> mediaId;
  final Value<String> tagId;
  final Value<int> rowid;
  const GalleryLinksCompanion({
    this.mediaId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryLinksCompanion.insert({
    required String mediaId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : mediaId = Value(mediaId),
       tagId = Value(tagId);
  static Insertable<GalleryLink> custom({
    Expression<String>? mediaId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryLinksCompanion copyWith({
    Value<String>? mediaId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return GalleryLinksCompanion(
      mediaId: mediaId ?? this.mediaId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
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
    return (StringBuffer('GalleryLinksCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class GalleryOperations extends Table
    with TableInfo<GalleryOperations, GalleryOperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryOperations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT FALSE',
    defaultValue: const CustomExpression('FALSE'),
  );
  @override
  List<GeneratedColumn> get $columns => [seq, kind, body, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  GalleryOperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryOperationRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  GalleryOperations createAlias(String alias) {
    return GalleryOperations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class GalleryOperationRow extends DataClass
    implements Insertable<GalleryOperationRow> {
  final int seq;
  final String kind;
  final String body;
  final bool synced;
  const GalleryOperationRow({
    required this.seq,
    required this.kind,
    required this.body,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['kind'] = Variable<String>(kind);
    map['body'] = Variable<String>(body);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  GalleryOperationsCompanion toCompanion(bool nullToAbsent) {
    return GalleryOperationsCompanion(
      seq: Value(seq),
      kind: Value(kind),
      body: Value(body),
      synced: Value(synced),
    );
  }

  factory GalleryOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryOperationRow(
      seq: serializer.fromJson<int>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String>(json['body']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String>(body),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  GalleryOperationRow copyWith({
    int? seq,
    String? kind,
    String? body,
    bool? synced,
  }) => GalleryOperationRow(
    seq: seq ?? this.seq,
    kind: kind ?? this.kind,
    body: body ?? this.body,
    synced: synced ?? this.synced,
  );
  GalleryOperationRow copyWithCompanion(GalleryOperationsCompanion data) {
    return GalleryOperationRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryOperationRow(')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, kind, body, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryOperationRow &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.synced == this.synced);
}

class GalleryOperationsCompanion extends UpdateCompanion<GalleryOperationRow> {
  final Value<int> seq;
  final Value<String> kind;
  final Value<String> body;
  final Value<bool> synced;
  const GalleryOperationsCompanion({
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.synced = const Value.absent(),
  });
  GalleryOperationsCompanion.insert({
    this.seq = const Value.absent(),
    required String kind,
    required String body,
    this.synced = const Value.absent(),
  }) : kind = Value(kind),
       body = Value(body);
  static Insertable<GalleryOperationRow> custom({
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (synced != null) 'synced': synced,
    });
  }

  GalleryOperationsCompanion copyWith({
    Value<int>? seq,
    Value<String>? kind,
    Value<String>? body,
    Value<bool>? synced,
  }) {
    return GalleryOperationsCompanion(
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryOperationsCompanion(')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class GalleryLibrary extends Table
    with TableInfo<GalleryLibrary, GalleryBinding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryLibrary(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (slot = 1)',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [slot, id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_library';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryBinding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  GalleryBinding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryBinding(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  GalleryLibrary createAlias(String alias) {
    return GalleryLibrary(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class GalleryBinding extends DataClass implements Insertable<GalleryBinding> {
  final int slot;
  final String id;
  const GalleryBinding({required this.slot, required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<int>(slot);
    map['id'] = Variable<String>(id);
    return map;
  }

  GalleryLibraryCompanion toCompanion(bool nullToAbsent) {
    return GalleryLibraryCompanion(slot: Value(slot), id: Value(id));
  }

  factory GalleryBinding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryBinding(
      slot: serializer.fromJson<int>(json['slot']),
      id: serializer.fromJson<String>(json['id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<int>(slot),
      'id': serializer.toJson<String>(id),
    };
  }

  GalleryBinding copyWith({int? slot, String? id}) =>
      GalleryBinding(slot: slot ?? this.slot, id: id ?? this.id);
  GalleryBinding copyWithCompanion(GalleryLibraryCompanion data) {
    return GalleryBinding(
      slot: data.slot.present ? data.slot.value : this.slot,
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryBinding(')
          ..write('slot: $slot, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, id);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryBinding &&
          other.slot == this.slot &&
          other.id == this.id);
}

class GalleryLibraryCompanion extends UpdateCompanion<GalleryBinding> {
  final Value<int> slot;
  final Value<String> id;
  const GalleryLibraryCompanion({
    this.slot = const Value.absent(),
    this.id = const Value.absent(),
  });
  GalleryLibraryCompanion.insert({
    this.slot = const Value.absent(),
    required String id,
  }) : id = Value(id);
  static Insertable<GalleryBinding> custom({
    Expression<int>? slot,
    Expression<String>? id,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (id != null) 'id': id,
    });
  }

  GalleryLibraryCompanion copyWith({Value<int>? slot, Value<String>? id}) {
    return GalleryLibraryCompanion(slot: slot ?? this.slot, id: id ?? this.id);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryLibraryCompanion(')
          ..write('slot: $slot, ')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }
}

class GalleryPositions extends Table
    with TableInfo<GalleryPositions, GalleryPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryPositions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL PRIMARY KEY REFERENCES gallery_library(slot)ON DELETE CASCADE',
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [slot, currentIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryPosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  GalleryPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryPosition(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
    );
  }

  @override
  GalleryPositions createAlias(String alias) {
    return GalleryPositions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class GalleryPosition extends DataClass implements Insertable<GalleryPosition> {
  final int slot;
  final int currentIndex;
  const GalleryPosition({required this.slot, required this.currentIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<int>(slot);
    map['current_index'] = Variable<int>(currentIndex);
    return map;
  }

  GalleryPositionsCompanion toCompanion(bool nullToAbsent) {
    return GalleryPositionsCompanion(
      slot: Value(slot),
      currentIndex: Value(currentIndex),
    );
  }

  factory GalleryPosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryPosition(
      slot: serializer.fromJson<int>(json['slot']),
      currentIndex: serializer.fromJson<int>(json['current_index']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<int>(slot),
      'current_index': serializer.toJson<int>(currentIndex),
    };
  }

  GalleryPosition copyWith({int? slot, int? currentIndex}) => GalleryPosition(
    slot: slot ?? this.slot,
    currentIndex: currentIndex ?? this.currentIndex,
  );
  GalleryPosition copyWithCompanion(GalleryPositionsCompanion data) {
    return GalleryPosition(
      slot: data.slot.present ? data.slot.value : this.slot,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryPosition(')
          ..write('slot: $slot, ')
          ..write('currentIndex: $currentIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, currentIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryPosition &&
          other.slot == this.slot &&
          other.currentIndex == this.currentIndex);
}

class GalleryPositionsCompanion extends UpdateCompanion<GalleryPosition> {
  final Value<int> slot;
  final Value<int> currentIndex;
  const GalleryPositionsCompanion({
    this.slot = const Value.absent(),
    this.currentIndex = const Value.absent(),
  });
  GalleryPositionsCompanion.insert({
    this.slot = const Value.absent(),
    this.currentIndex = const Value.absent(),
  });
  static Insertable<GalleryPosition> custom({
    Expression<int>? slot,
    Expression<int>? currentIndex,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (currentIndex != null) 'current_index': currentIndex,
    });
  }

  GalleryPositionsCompanion copyWith({
    Value<int>? slot,
    Value<int>? currentIndex,
  }) {
    return GalleryPositionsCompanion(
      slot: slot ?? this.slot,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryPositionsCompanion(')
          ..write('slot: $slot, ')
          ..write('currentIndex: $currentIndex')
          ..write(')'))
        .toString();
  }
}

class ComicCatalog extends Table with TableInfo<ComicCatalog, ComicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ComicCatalog(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _coverImageMeta = const VerificationMeta(
    'coverImage',
  );
  late final GeneratedColumn<String> coverImage = GeneratedColumn<String>(
    'cover_image',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta(
    'chapterCount',
  );
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _imageCountMeta = const VerificationMeta(
    'imageCount',
  );
  late final GeneratedColumn<int> imageCount = GeneratedColumn<int>(
    'image_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _isPublicMeta = const VerificationMeta(
    'isPublic',
  );
  late final GeneratedColumn<bool> isPublic = GeneratedColumn<bool>(
    'is_public',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _readedMeta = const VerificationMeta('readed');
  late final GeneratedColumn<bool> readed = GeneratedColumn<bool>(
    'readed',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    coverImage,
    chapterCount,
    imageCount,
    isPublic,
    readed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comic_catalog';
  @override
  VerificationContext validateIntegrity(
    Insertable<ComicRow> instance, {
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
    if (data.containsKey('cover_image')) {
      context.handle(
        _coverImageMeta,
        coverImage.isAcceptableOrUnknown(data['cover_image']!, _coverImageMeta),
      );
    } else if (isInserting) {
      context.missing(_coverImageMeta);
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(
          data['chapter_count']!,
          _chapterCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterCountMeta);
    }
    if (data.containsKey('image_count')) {
      context.handle(
        _imageCountMeta,
        imageCount.isAcceptableOrUnknown(data['image_count']!, _imageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_imageCountMeta);
    }
    if (data.containsKey('is_public')) {
      context.handle(
        _isPublicMeta,
        isPublic.isAcceptableOrUnknown(data['is_public']!, _isPublicMeta),
      );
    }
    if (data.containsKey('readed')) {
      context.handle(
        _readedMeta,
        readed.isAcceptableOrUnknown(data['readed']!, _readedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ComicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ComicRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      coverImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image'],
      )!,
      chapterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_count'],
      )!,
      imageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_count'],
      )!,
      isPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_public'],
      ),
      readed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}readed'],
      ),
    );
  }

  @override
  ComicCatalog createAlias(String alias) {
    return ComicCatalog(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ComicRow extends DataClass implements Insertable<ComicRow> {
  final String id;
  final String name;
  final String coverImage;
  final int chapterCount;
  final int imageCount;
  final bool? isPublic;
  final bool? readed;
  const ComicRow({
    required this.id,
    required this.name,
    required this.coverImage,
    required this.chapterCount,
    required this.imageCount,
    this.isPublic,
    this.readed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['cover_image'] = Variable<String>(coverImage);
    map['chapter_count'] = Variable<int>(chapterCount);
    map['image_count'] = Variable<int>(imageCount);
    if (!nullToAbsent || isPublic != null) {
      map['is_public'] = Variable<bool>(isPublic);
    }
    if (!nullToAbsent || readed != null) {
      map['readed'] = Variable<bool>(readed);
    }
    return map;
  }

  ComicCatalogCompanion toCompanion(bool nullToAbsent) {
    return ComicCatalogCompanion(
      id: Value(id),
      name: Value(name),
      coverImage: Value(coverImage),
      chapterCount: Value(chapterCount),
      imageCount: Value(imageCount),
      isPublic: isPublic == null && nullToAbsent
          ? const Value.absent()
          : Value(isPublic),
      readed: readed == null && nullToAbsent
          ? const Value.absent()
          : Value(readed),
    );
  }

  factory ComicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ComicRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      coverImage: serializer.fromJson<String>(json['cover_image']),
      chapterCount: serializer.fromJson<int>(json['chapter_count']),
      imageCount: serializer.fromJson<int>(json['image_count']),
      isPublic: serializer.fromJson<bool?>(json['is_public']),
      readed: serializer.fromJson<bool?>(json['readed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cover_image': serializer.toJson<String>(coverImage),
      'chapter_count': serializer.toJson<int>(chapterCount),
      'image_count': serializer.toJson<int>(imageCount),
      'is_public': serializer.toJson<bool?>(isPublic),
      'readed': serializer.toJson<bool?>(readed),
    };
  }

  ComicRow copyWith({
    String? id,
    String? name,
    String? coverImage,
    int? chapterCount,
    int? imageCount,
    Value<bool?> isPublic = const Value.absent(),
    Value<bool?> readed = const Value.absent(),
  }) => ComicRow(
    id: id ?? this.id,
    name: name ?? this.name,
    coverImage: coverImage ?? this.coverImage,
    chapterCount: chapterCount ?? this.chapterCount,
    imageCount: imageCount ?? this.imageCount,
    isPublic: isPublic.present ? isPublic.value : this.isPublic,
    readed: readed.present ? readed.value : this.readed,
  );
  ComicRow copyWithCompanion(ComicCatalogCompanion data) {
    return ComicRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      coverImage: data.coverImage.present
          ? data.coverImage.value
          : this.coverImage,
      chapterCount: data.chapterCount.present
          ? data.chapterCount.value
          : this.chapterCount,
      imageCount: data.imageCount.present
          ? data.imageCount.value
          : this.imageCount,
      isPublic: data.isPublic.present ? data.isPublic.value : this.isPublic,
      readed: data.readed.present ? data.readed.value : this.readed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ComicRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverImage: $coverImage, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('imageCount: $imageCount, ')
          ..write('isPublic: $isPublic, ')
          ..write('readed: $readed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    coverImage,
    chapterCount,
    imageCount,
    isPublic,
    readed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComicRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.coverImage == this.coverImage &&
          other.chapterCount == this.chapterCount &&
          other.imageCount == this.imageCount &&
          other.isPublic == this.isPublic &&
          other.readed == this.readed);
}

class ComicCatalogCompanion extends UpdateCompanion<ComicRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> coverImage;
  final Value<int> chapterCount;
  final Value<int> imageCount;
  final Value<bool?> isPublic;
  final Value<bool?> readed;
  final Value<int> rowid;
  const ComicCatalogCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.imageCount = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.readed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ComicCatalogCompanion.insert({
    required String id,
    required String name,
    required String coverImage,
    required int chapterCount,
    required int imageCount,
    this.isPublic = const Value.absent(),
    this.readed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       coverImage = Value(coverImage),
       chapterCount = Value(chapterCount),
       imageCount = Value(imageCount);
  static Insertable<ComicRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? coverImage,
    Expression<int>? chapterCount,
    Expression<int>? imageCount,
    Expression<bool>? isPublic,
    Expression<bool>? readed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (coverImage != null) 'cover_image': coverImage,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (imageCount != null) 'image_count': imageCount,
      if (isPublic != null) 'is_public': isPublic,
      if (readed != null) 'readed': readed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ComicCatalogCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? coverImage,
    Value<int>? chapterCount,
    Value<int>? imageCount,
    Value<bool?>? isPublic,
    Value<bool?>? readed,
    Value<int>? rowid,
  }) {
    return ComicCatalogCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      coverImage: coverImage ?? this.coverImage,
      chapterCount: chapterCount ?? this.chapterCount,
      imageCount: imageCount ?? this.imageCount,
      isPublic: isPublic ?? this.isPublic,
      readed: readed ?? this.readed,
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
    if (coverImage.present) {
      map['cover_image'] = Variable<String>(coverImage.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    if (imageCount.present) {
      map['image_count'] = Variable<int>(imageCount.value);
    }
    if (isPublic.present) {
      map['is_public'] = Variable<bool>(isPublic.value);
    }
    if (readed.present) {
      map['readed'] = Variable<bool>(readed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComicCatalogCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverImage: $coverImage, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('imageCount: $imageCount, ')
          ..write('isPublic: $isPublic, ')
          ..write('readed: $readed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ComicChapters extends Table
    with TableInfo<ComicChapters, ComicChapterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ComicChapters(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES comic_catalog(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dirNameMeta = const VerificationMeta(
    'dirName',
  );
  late final GeneratedColumn<String> dirName = GeneratedColumn<String>(
    'dir_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
    'images',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    comicId,
    chapterIndex,
    dirName,
    images,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comic_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<ComicChapterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('dir_name')) {
      context.handle(
        _dirNameMeta,
        dirName.isAcceptableOrUnknown(data['dir_name']!, _dirNameMeta),
      );
    } else if (isInserting) {
      context.missing(_dirNameMeta);
    }
    if (data.containsKey('images')) {
      context.handle(
        _imagesMeta,
        images.isAcceptableOrUnknown(data['images']!, _imagesMeta),
      );
    } else if (isInserting) {
      context.missing(_imagesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ComicChapterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ComicChapterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      dirName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dir_name'],
      )!,
      images: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}images'],
      )!,
    );
  }

  @override
  ComicChapters createAlias(String alias) {
    return ComicChapters(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ComicChapterRow extends DataClass implements Insertable<ComicChapterRow> {
  final String id;
  final String comicId;
  final int chapterIndex;
  final String dirName;
  final String images;
  const ComicChapterRow({
    required this.id,
    required this.comicId,
    required this.chapterIndex,
    required this.dirName,
    required this.images,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['comic_id'] = Variable<String>(comicId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['dir_name'] = Variable<String>(dirName);
    map['images'] = Variable<String>(images);
    return map;
  }

  ComicChaptersCompanion toCompanion(bool nullToAbsent) {
    return ComicChaptersCompanion(
      id: Value(id),
      comicId: Value(comicId),
      chapterIndex: Value(chapterIndex),
      dirName: Value(dirName),
      images: Value(images),
    );
  }

  factory ComicChapterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ComicChapterRow(
      id: serializer.fromJson<String>(json['id']),
      comicId: serializer.fromJson<String>(json['comic_id']),
      chapterIndex: serializer.fromJson<int>(json['chapter_index']),
      dirName: serializer.fromJson<String>(json['dir_name']),
      images: serializer.fromJson<String>(json['images']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'comic_id': serializer.toJson<String>(comicId),
      'chapter_index': serializer.toJson<int>(chapterIndex),
      'dir_name': serializer.toJson<String>(dirName),
      'images': serializer.toJson<String>(images),
    };
  }

  ComicChapterRow copyWith({
    String? id,
    String? comicId,
    int? chapterIndex,
    String? dirName,
    String? images,
  }) => ComicChapterRow(
    id: id ?? this.id,
    comicId: comicId ?? this.comicId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    dirName: dirName ?? this.dirName,
    images: images ?? this.images,
  );
  ComicChapterRow copyWithCompanion(ComicChaptersCompanion data) {
    return ComicChapterRow(
      id: data.id.present ? data.id.value : this.id,
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      dirName: data.dirName.present ? data.dirName.value : this.dirName,
      images: data.images.present ? data.images.value : this.images,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ComicChapterRow(')
          ..write('id: $id, ')
          ..write('comicId: $comicId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('dirName: $dirName, ')
          ..write('images: $images')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, comicId, chapterIndex, dirName, images);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComicChapterRow &&
          other.id == this.id &&
          other.comicId == this.comicId &&
          other.chapterIndex == this.chapterIndex &&
          other.dirName == this.dirName &&
          other.images == this.images);
}

class ComicChaptersCompanion extends UpdateCompanion<ComicChapterRow> {
  final Value<String> id;
  final Value<String> comicId;
  final Value<int> chapterIndex;
  final Value<String> dirName;
  final Value<String> images;
  final Value<int> rowid;
  const ComicChaptersCompanion({
    this.id = const Value.absent(),
    this.comicId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.dirName = const Value.absent(),
    this.images = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ComicChaptersCompanion.insert({
    required String id,
    required String comicId,
    required int chapterIndex,
    required String dirName,
    required String images,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       comicId = Value(comicId),
       chapterIndex = Value(chapterIndex),
       dirName = Value(dirName),
       images = Value(images);
  static Insertable<ComicChapterRow> custom({
    Expression<String>? id,
    Expression<String>? comicId,
    Expression<int>? chapterIndex,
    Expression<String>? dirName,
    Expression<String>? images,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (comicId != null) 'comic_id': comicId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (dirName != null) 'dir_name': dirName,
      if (images != null) 'images': images,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ComicChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? comicId,
    Value<int>? chapterIndex,
    Value<String>? dirName,
    Value<String>? images,
    Value<int>? rowid,
  }) {
    return ComicChaptersCompanion(
      id: id ?? this.id,
      comicId: comicId ?? this.comicId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      dirName: dirName ?? this.dirName,
      images: images ?? this.images,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (dirName.present) {
      map['dir_name'] = Variable<String>(dirName.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComicChaptersCompanion(')
          ..write('id: $id, ')
          ..write('comicId: $comicId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('dirName: $dirName, ')
          ..write('images: $images, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ComicProgress extends Table
    with TableInfo<ComicProgress, ComicProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ComicProgress(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _flipReadingMeta = const VerificationMeta(
    'flipReading',
  );
  late final GeneratedColumn<bool> flipReading = GeneratedColumn<bool>(
    'flip_reading',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [comicId, chapterIndex, flipReading];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comic_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ComicProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('flip_reading')) {
      context.handle(
        _flipReadingMeta,
        flipReading.isAcceptableOrUnknown(
          data['flip_reading']!,
          _flipReadingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_flipReadingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {comicId};
  @override
  ComicProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ComicProgressRow(
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      flipReading: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flip_reading'],
      )!,
    );
  }

  @override
  ComicProgress createAlias(String alias) {
    return ComicProgress(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ComicProgressRow extends DataClass
    implements Insertable<ComicProgressRow> {
  final String comicId;
  final int chapterIndex;
  final bool flipReading;
  const ComicProgressRow({
    required this.comicId,
    required this.chapterIndex,
    required this.flipReading,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['comic_id'] = Variable<String>(comicId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['flip_reading'] = Variable<bool>(flipReading);
    return map;
  }

  ComicProgressCompanion toCompanion(bool nullToAbsent) {
    return ComicProgressCompanion(
      comicId: Value(comicId),
      chapterIndex: Value(chapterIndex),
      flipReading: Value(flipReading),
    );
  }

  factory ComicProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ComicProgressRow(
      comicId: serializer.fromJson<String>(json['comic_id']),
      chapterIndex: serializer.fromJson<int>(json['chapter_index']),
      flipReading: serializer.fromJson<bool>(json['flip_reading']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'comic_id': serializer.toJson<String>(comicId),
      'chapter_index': serializer.toJson<int>(chapterIndex),
      'flip_reading': serializer.toJson<bool>(flipReading),
    };
  }

  ComicProgressRow copyWith({
    String? comicId,
    int? chapterIndex,
    bool? flipReading,
  }) => ComicProgressRow(
    comicId: comicId ?? this.comicId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    flipReading: flipReading ?? this.flipReading,
  );
  ComicProgressRow copyWithCompanion(ComicProgressCompanion data) {
    return ComicProgressRow(
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      flipReading: data.flipReading.present
          ? data.flipReading.value
          : this.flipReading,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ComicProgressRow(')
          ..write('comicId: $comicId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('flipReading: $flipReading')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(comicId, chapterIndex, flipReading);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComicProgressRow &&
          other.comicId == this.comicId &&
          other.chapterIndex == this.chapterIndex &&
          other.flipReading == this.flipReading);
}

class ComicProgressCompanion extends UpdateCompanion<ComicProgressRow> {
  final Value<String> comicId;
  final Value<int> chapterIndex;
  final Value<bool> flipReading;
  final Value<int> rowid;
  const ComicProgressCompanion({
    this.comicId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.flipReading = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ComicProgressCompanion.insert({
    required String comicId,
    required int chapterIndex,
    required bool flipReading,
    this.rowid = const Value.absent(),
  }) : comicId = Value(comicId),
       chapterIndex = Value(chapterIndex),
       flipReading = Value(flipReading);
  static Insertable<ComicProgressRow> custom({
    Expression<String>? comicId,
    Expression<int>? chapterIndex,
    Expression<bool>? flipReading,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (comicId != null) 'comic_id': comicId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (flipReading != null) 'flip_reading': flipReading,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ComicProgressCompanion copyWith({
    Value<String>? comicId,
    Value<int>? chapterIndex,
    Value<bool>? flipReading,
    Value<int>? rowid,
  }) {
    return ComicProgressCompanion(
      comicId: comicId ?? this.comicId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      flipReading: flipReading ?? this.flipReading,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (flipReading.present) {
      map['flip_reading'] = Variable<bool>(flipReading.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComicProgressCompanion(')
          ..write('comicId: $comicId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('flipReading: $flipReading, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ComicDownloads extends Table
    with TableInfo<ComicDownloads, ComicDownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ComicDownloads(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _comicIdMeta = const VerificationMeta(
    'comicId',
  );
  late final GeneratedColumn<String> comicId = GeneratedColumn<String>(
    'comic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _taskMeta = const VerificationMeta('task');
  late final GeneratedColumn<String> task = GeneratedColumn<String>(
    'task',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [comicId, createdAtMs, task];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comic_downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ComicDownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('comic_id')) {
      context.handle(
        _comicIdMeta,
        comicId.isAcceptableOrUnknown(data['comic_id']!, _comicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_comicIdMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('task')) {
      context.handle(
        _taskMeta,
        task.isAcceptableOrUnknown(data['task']!, _taskMeta),
      );
    } else if (isInserting) {
      context.missing(_taskMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {comicId};
  @override
  ComicDownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ComicDownloadRow(
      comicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comic_id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      task: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task'],
      )!,
    );
  }

  @override
  ComicDownloads createAlias(String alias) {
    return ComicDownloads(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ComicDownloadRow extends DataClass
    implements Insertable<ComicDownloadRow> {
  final String comicId;
  final int createdAtMs;
  final String task;
  const ComicDownloadRow({
    required this.comicId,
    required this.createdAtMs,
    required this.task,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['comic_id'] = Variable<String>(comicId);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['task'] = Variable<String>(task);
    return map;
  }

  ComicDownloadsCompanion toCompanion(bool nullToAbsent) {
    return ComicDownloadsCompanion(
      comicId: Value(comicId),
      createdAtMs: Value(createdAtMs),
      task: Value(task),
    );
  }

  factory ComicDownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ComicDownloadRow(
      comicId: serializer.fromJson<String>(json['comic_id']),
      createdAtMs: serializer.fromJson<int>(json['created_at_ms']),
      task: serializer.fromJson<String>(json['task']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'comic_id': serializer.toJson<String>(comicId),
      'created_at_ms': serializer.toJson<int>(createdAtMs),
      'task': serializer.toJson<String>(task),
    };
  }

  ComicDownloadRow copyWith({
    String? comicId,
    int? createdAtMs,
    String? task,
  }) => ComicDownloadRow(
    comicId: comicId ?? this.comicId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    task: task ?? this.task,
  );
  ComicDownloadRow copyWithCompanion(ComicDownloadsCompanion data) {
    return ComicDownloadRow(
      comicId: data.comicId.present ? data.comicId.value : this.comicId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      task: data.task.present ? data.task.value : this.task,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ComicDownloadRow(')
          ..write('comicId: $comicId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('task: $task')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(comicId, createdAtMs, task);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComicDownloadRow &&
          other.comicId == this.comicId &&
          other.createdAtMs == this.createdAtMs &&
          other.task == this.task);
}

class ComicDownloadsCompanion extends UpdateCompanion<ComicDownloadRow> {
  final Value<String> comicId;
  final Value<int> createdAtMs;
  final Value<String> task;
  final Value<int> rowid;
  const ComicDownloadsCompanion({
    this.comicId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.task = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ComicDownloadsCompanion.insert({
    required String comicId,
    required int createdAtMs,
    required String task,
    this.rowid = const Value.absent(),
  }) : comicId = Value(comicId),
       createdAtMs = Value(createdAtMs),
       task = Value(task);
  static Insertable<ComicDownloadRow> custom({
    Expression<String>? comicId,
    Expression<int>? createdAtMs,
    Expression<String>? task,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (comicId != null) 'comic_id': comicId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (task != null) 'task': task,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ComicDownloadsCompanion copyWith({
    Value<String>? comicId,
    Value<int>? createdAtMs,
    Value<String>? task,
    Value<int>? rowid,
  }) {
    return ComicDownloadsCompanion(
      comicId: comicId ?? this.comicId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      task: task ?? this.task,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (comicId.present) {
      map['comic_id'] = Variable<String>(comicId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (task.present) {
      map['task'] = Variable<String>(task.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComicDownloadsCompanion(')
          ..write('comicId: $comicId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('task: $task, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ChatConversations extends Table
    with TableInfo<ChatConversations, ChatConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChatConversations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(ChatConversations.$convertercreatedAt);
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(ChatConversations.$converterupdatedAt);
  static const VerificationMeta _messagesMeta = const VerificationMeta(
    'messages',
  );
  late final GeneratedColumn<String> messages = GeneratedColumn<String>(
    'messages',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    messages,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatConversationRow> instance, {
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
    if (data.containsKey('messages')) {
      context.handle(
        _messagesMeta,
        messages.isAcceptableOrUnknown(data['messages']!, _messagesMeta),
      );
    } else if (isInserting) {
      context.missing(_messagesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: ChatConversations.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: ChatConversations.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      messages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messages'],
      )!,
    );
  }

  @override
  ChatConversations createAlias(String alias) {
    return ChatConversations(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = const EpochMicros();
  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class ChatConversationRow extends DataClass
    implements Insertable<ChatConversationRow> {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String messages;
  const ChatConversationRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['created_at'] = Variable<int>(
        ChatConversations.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        ChatConversations.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['messages'] = Variable<String>(messages);
    return map;
  }

  ChatConversationsCompanion toCompanion(bool nullToAbsent) {
    return ChatConversationsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      messages: Value(messages),
    );
  }

  factory ChatConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatConversationRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      messages: serializer.fromJson<String>(json['messages']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'messages': serializer.toJson<String>(messages),
    };
  }

  ChatConversationRow copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? messages,
  }) => ChatConversationRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );
  ChatConversationRow copyWithCompanion(ChatConversationsCompanion data) {
    return ChatConversationRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      messages: data.messages.present ? data.messages.value : this.messages,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messages: $messages')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, createdAt, updatedAt, messages);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatConversationRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.messages == this.messages);
}

class ChatConversationsCompanion extends UpdateCompanion<ChatConversationRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> messages;
  final Value<int> rowid;
  const ChatConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.messages = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatConversationsCompanion.insert({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String messages,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       messages = Value(messages);
  static Insertable<ChatConversationRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? messages,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (messages != null) 'messages': messages,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? messages,
    Value<int>? rowid,
  }) {
    return ChatConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
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
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        ChatConversations.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        ChatConversations.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (messages.present) {
      map['messages'] = Variable<String>(messages.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messages: $messages, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ReviewPresets extends Table
    with TableInfo<ReviewPresets, ReviewPresetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ReviewPresets(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _toneMeta = const VerificationMeta('tone');
  late final GeneratedColumn<String> tone = GeneratedColumn<String>(
    'tone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, role, tone];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewPresetRow> instance, {
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
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('tone')) {
      context.handle(
        _toneMeta,
        tone.isAcceptableOrUnknown(data['tone']!, _toneMeta),
      );
    } else if (isInserting) {
      context.missing(_toneMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewPresetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewPresetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      tone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tone'],
      )!,
    );
  }

  @override
  ReviewPresets createAlias(String alias) {
    return ReviewPresets(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ReviewPresetRow extends DataClass implements Insertable<ReviewPresetRow> {
  final String id;
  final String name;
  final String role;
  final String tone;
  const ReviewPresetRow({
    required this.id,
    required this.name,
    required this.role,
    required this.tone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['role'] = Variable<String>(role);
    map['tone'] = Variable<String>(tone);
    return map;
  }

  ReviewPresetsCompanion toCompanion(bool nullToAbsent) {
    return ReviewPresetsCompanion(
      id: Value(id),
      name: Value(name),
      role: Value(role),
      tone: Value(tone),
    );
  }

  factory ReviewPresetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewPresetRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      role: serializer.fromJson<String>(json['role']),
      tone: serializer.fromJson<String>(json['tone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'role': serializer.toJson<String>(role),
      'tone': serializer.toJson<String>(tone),
    };
  }

  ReviewPresetRow copyWith({
    String? id,
    String? name,
    String? role,
    String? tone,
  }) => ReviewPresetRow(
    id: id ?? this.id,
    name: name ?? this.name,
    role: role ?? this.role,
    tone: tone ?? this.tone,
  );
  ReviewPresetRow copyWithCompanion(ReviewPresetsCompanion data) {
    return ReviewPresetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      role: data.role.present ? data.role.value : this.role,
      tone: data.tone.present ? data.tone.value : this.tone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewPresetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('tone: $tone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, role, tone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewPresetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.role == this.role &&
          other.tone == this.tone);
}

class ReviewPresetsCompanion extends UpdateCompanion<ReviewPresetRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> role;
  final Value<String> tone;
  final Value<int> rowid;
  const ReviewPresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.role = const Value.absent(),
    this.tone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewPresetsCompanion.insert({
    required String id,
    required String name,
    required String role,
    required String tone,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       role = Value(role),
       tone = Value(tone);
  static Insertable<ReviewPresetRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? role,
    Expression<String>? tone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (tone != null) 'tone': tone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewPresetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? role,
    Value<String>? tone,
    Value<int>? rowid,
  }) {
    return ReviewPresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      tone: tone ?? this.tone,
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
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (tone.present) {
      map['tone'] = Variable<String>(tone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewPresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('tone: $tone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ReviewHistory extends Table
    with TableInfo<ReviewHistory, ReviewHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ReviewHistory(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _presetNameMeta = const VerificationMeta(
    'presetName',
  );
  late final GeneratedColumn<String> presetName = GeneratedColumn<String>(
    'preset_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _spanMeta = const VerificationMeta('span');
  late final GeneratedColumn<String> span = GeneratedColumn<String>(
    'span',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(ReviewHistory.$convertercreatedAt);
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statsMeta = const VerificationMeta('stats');
  late final GeneratedColumn<String> stats = GeneratedColumn<String>(
    'stats',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    presetName,
    span,
    createdAt,
    content,
    stats,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('preset_name')) {
      context.handle(
        _presetNameMeta,
        presetName.isAcceptableOrUnknown(data['preset_name']!, _presetNameMeta),
      );
    } else if (isInserting) {
      context.missing(_presetNameMeta);
    }
    if (data.containsKey('span')) {
      context.handle(
        _spanMeta,
        span.isAcceptableOrUnknown(data['span']!, _spanMeta),
      );
    } else if (isInserting) {
      context.missing(_spanMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('stats')) {
      context.handle(
        _statsMeta,
        stats.isAcceptableOrUnknown(data['stats']!, _statsMeta),
      );
    } else if (isInserting) {
      context.missing(_statsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      presetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_name'],
      )!,
      span: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}span'],
      )!,
      createdAt: ReviewHistory.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      stats: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stats'],
      )!,
    );
  }

  @override
  ReviewHistory createAlias(String alias) {
    return ReviewHistory(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class ReviewHistoryRow extends DataClass
    implements Insertable<ReviewHistoryRow> {
  final String id;
  final String presetName;
  final String span;
  final DateTime createdAt;
  final String content;
  final String stats;
  const ReviewHistoryRow({
    required this.id,
    required this.presetName,
    required this.span,
    required this.createdAt,
    required this.content,
    required this.stats,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['preset_name'] = Variable<String>(presetName);
    map['span'] = Variable<String>(span);
    {
      map['created_at'] = Variable<int>(
        ReviewHistory.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['content'] = Variable<String>(content);
    map['stats'] = Variable<String>(stats);
    return map;
  }

  ReviewHistoryCompanion toCompanion(bool nullToAbsent) {
    return ReviewHistoryCompanion(
      id: Value(id),
      presetName: Value(presetName),
      span: Value(span),
      createdAt: Value(createdAt),
      content: Value(content),
      stats: Value(stats),
    );
  }

  factory ReviewHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      presetName: serializer.fromJson<String>(json['preset_name']),
      span: serializer.fromJson<String>(json['span']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
      content: serializer.fromJson<String>(json['content']),
      stats: serializer.fromJson<String>(json['stats']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'preset_name': serializer.toJson<String>(presetName),
      'span': serializer.toJson<String>(span),
      'created_at': serializer.toJson<DateTime>(createdAt),
      'content': serializer.toJson<String>(content),
      'stats': serializer.toJson<String>(stats),
    };
  }

  ReviewHistoryRow copyWith({
    String? id,
    String? presetName,
    String? span,
    DateTime? createdAt,
    String? content,
    String? stats,
  }) => ReviewHistoryRow(
    id: id ?? this.id,
    presetName: presetName ?? this.presetName,
    span: span ?? this.span,
    createdAt: createdAt ?? this.createdAt,
    content: content ?? this.content,
    stats: stats ?? this.stats,
  );
  ReviewHistoryRow copyWithCompanion(ReviewHistoryCompanion data) {
    return ReviewHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      presetName: data.presetName.present
          ? data.presetName.value
          : this.presetName,
      span: data.span.present ? data.span.value : this.span,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      content: data.content.present ? data.content.value : this.content,
      stats: data.stats.present ? data.stats.value : this.stats,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewHistoryRow(')
          ..write('id: $id, ')
          ..write('presetName: $presetName, ')
          ..write('span: $span, ')
          ..write('createdAt: $createdAt, ')
          ..write('content: $content, ')
          ..write('stats: $stats')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, presetName, span, createdAt, content, stats);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewHistoryRow &&
          other.id == this.id &&
          other.presetName == this.presetName &&
          other.span == this.span &&
          other.createdAt == this.createdAt &&
          other.content == this.content &&
          other.stats == this.stats);
}

class ReviewHistoryCompanion extends UpdateCompanion<ReviewHistoryRow> {
  final Value<String> id;
  final Value<String> presetName;
  final Value<String> span;
  final Value<DateTime> createdAt;
  final Value<String> content;
  final Value<String> stats;
  final Value<int> rowid;
  const ReviewHistoryCompanion({
    this.id = const Value.absent(),
    this.presetName = const Value.absent(),
    this.span = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.content = const Value.absent(),
    this.stats = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewHistoryCompanion.insert({
    required String id,
    required String presetName,
    required String span,
    required DateTime createdAt,
    required String content,
    required String stats,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       presetName = Value(presetName),
       span = Value(span),
       createdAt = Value(createdAt),
       content = Value(content),
       stats = Value(stats);
  static Insertable<ReviewHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? presetName,
    Expression<String>? span,
    Expression<int>? createdAt,
    Expression<String>? content,
    Expression<String>? stats,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (presetName != null) 'preset_name': presetName,
      if (span != null) 'span': span,
      if (createdAt != null) 'created_at': createdAt,
      if (content != null) 'content': content,
      if (stats != null) 'stats': stats,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? presetName,
    Value<String>? span,
    Value<DateTime>? createdAt,
    Value<String>? content,
    Value<String>? stats,
    Value<int>? rowid,
  }) {
    return ReviewHistoryCompanion(
      id: id ?? this.id,
      presetName: presetName ?? this.presetName,
      span: span ?? this.span,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      stats: stats ?? this.stats,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (presetName.present) {
      map['preset_name'] = Variable<String>(presetName.value);
    }
    if (span.present) {
      map['span'] = Variable<String>(span.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        ReviewHistory.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (stats.present) {
      map['stats'] = Variable<String>(stats.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewHistoryCompanion(')
          ..write('id: $id, ')
          ..write('presetName: $presetName, ')
          ..write('span: $span, ')
          ..write('createdAt: $createdAt, ')
          ..write('content: $content, ')
          ..write('stats: $stats, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class BookletStyles extends Table with TableInfo<BookletStyles, BookletStyle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BookletStyles(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _tasksMeta = const VerificationMeta('tasks');
  late final GeneratedColumn<String> tasks = GeneratedColumn<String>(
    'tasks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(BookletStyles.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, startDate, tasks, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'booklet_styles';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookletStyle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('tasks')) {
      context.handle(
        _tasksMeta,
        tasks.isAcceptableOrUnknown(data['tasks']!, _tasksMeta),
      );
    } else if (isInserting) {
      context.missing(_tasksMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookletStyle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookletStyle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      tasks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tasks'],
      )!,
      updatedAt: BookletStyles.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  BookletStyles createAlias(String alias) {
    return BookletStyles(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class BookletStyle extends DataClass implements Insertable<BookletStyle> {
  final String id;
  final String startDate;
  final String tasks;
  final DateTime updatedAt;
  const BookletStyle({
    required this.id,
    required this.startDate,
    required this.tasks,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['start_date'] = Variable<String>(startDate);
    map['tasks'] = Variable<String>(tasks);
    {
      map['updated_at'] = Variable<int>(
        BookletStyles.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  BookletStylesCompanion toCompanion(bool nullToAbsent) {
    return BookletStylesCompanion(
      id: Value(id),
      startDate: Value(startDate),
      tasks: Value(tasks),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookletStyle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookletStyle(
      id: serializer.fromJson<String>(json['id']),
      startDate: serializer.fromJson<String>(json['start_date']),
      tasks: serializer.fromJson<String>(json['tasks']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'start_date': serializer.toJson<String>(startDate),
      'tasks': serializer.toJson<String>(tasks),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookletStyle copyWith({
    String? id,
    String? startDate,
    String? tasks,
    DateTime? updatedAt,
  }) => BookletStyle(
    id: id ?? this.id,
    startDate: startDate ?? this.startDate,
    tasks: tasks ?? this.tasks,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookletStyle copyWithCompanion(BookletStylesCompanion data) {
    return BookletStyle(
      id: data.id.present ? data.id.value : this.id,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      tasks: data.tasks.present ? data.tasks.value : this.tasks,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookletStyle(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('tasks: $tasks, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startDate, tasks, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookletStyle &&
          other.id == this.id &&
          other.startDate == this.startDate &&
          other.tasks == this.tasks &&
          other.updatedAt == this.updatedAt);
}

class BookletStylesCompanion extends UpdateCompanion<BookletStyle> {
  final Value<String> id;
  final Value<String> startDate;
  final Value<String> tasks;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookletStylesCompanion({
    this.id = const Value.absent(),
    this.startDate = const Value.absent(),
    this.tasks = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookletStylesCompanion.insert({
    required String id,
    required String startDate,
    required String tasks,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startDate = Value(startDate),
       tasks = Value(tasks),
       updatedAt = Value(updatedAt);
  static Insertable<BookletStyle> custom({
    Expression<String>? id,
    Expression<String>? startDate,
    Expression<String>? tasks,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startDate != null) 'start_date': startDate,
      if (tasks != null) 'tasks': tasks,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookletStylesCompanion copyWith({
    Value<String>? id,
    Value<String>? startDate,
    Value<String>? tasks,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookletStylesCompanion(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      tasks: tasks ?? this.tasks,
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
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (tasks.present) {
      map['tasks'] = Variable<String>(tasks.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        BookletStyles.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookletStylesCompanion(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('tasks: $tasks, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class BookletRecords extends Table
    with TableInfo<BookletRecords, BookletRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  BookletRecords(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _styleIdMeta = const VerificationMeta(
    'styleId',
  );
  late final GeneratedColumn<String> styleId = GeneratedColumn<String>(
    'style_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES booklet_styles(id)DEFERRABLE INITIALLY DEFERRED',
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _taskCompletionMeta = const VerificationMeta(
    'taskCompletion',
  );
  late final GeneratedColumn<String> taskCompletion = GeneratedColumn<String>(
    'task_completion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(BookletRecords.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    styleId,
    date,
    message,
    taskCompletion,
    mood,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'booklet_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookletRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('style_id')) {
      context.handle(
        _styleIdMeta,
        styleId.isAcceptableOrUnknown(data['style_id']!, _styleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_styleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('task_completion')) {
      context.handle(
        _taskCompletionMeta,
        taskCompletion.isAcceptableOrUnknown(
          data['task_completion']!,
          _taskCompletionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taskCompletionMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {styleId, date},
  ];
  @override
  BookletRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookletRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      styleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      taskCompletion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_completion'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      ),
      updatedAt: BookletRecords.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  BookletRecords createAlias(String alias) {
    return BookletRecords(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  @override
  List<String> get customConstraints => const ['UNIQUE(style_id, date)'];
  @override
  bool get dontWriteConstraints => true;
}

class BookletRecord extends DataClass implements Insertable<BookletRecord> {
  final String id;
  final String styleId;
  final String date;
  final String message;
  final String taskCompletion;
  final String? mood;
  final DateTime updatedAt;
  const BookletRecord({
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
    this.mood,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['style_id'] = Variable<String>(styleId);
    map['date'] = Variable<String>(date);
    map['message'] = Variable<String>(message);
    map['task_completion'] = Variable<String>(taskCompletion);
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    {
      map['updated_at'] = Variable<int>(
        BookletRecords.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  BookletRecordsCompanion toCompanion(bool nullToAbsent) {
    return BookletRecordsCompanion(
      id: Value(id),
      styleId: Value(styleId),
      date: Value(date),
      message: Value(message),
      taskCompletion: Value(taskCompletion),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookletRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookletRecord(
      id: serializer.fromJson<String>(json['id']),
      styleId: serializer.fromJson<String>(json['style_id']),
      date: serializer.fromJson<String>(json['date']),
      message: serializer.fromJson<String>(json['message']),
      taskCompletion: serializer.fromJson<String>(json['task_completion']),
      mood: serializer.fromJson<String?>(json['mood']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'style_id': serializer.toJson<String>(styleId),
      'date': serializer.toJson<String>(date),
      'message': serializer.toJson<String>(message),
      'task_completion': serializer.toJson<String>(taskCompletion),
      'mood': serializer.toJson<String?>(mood),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookletRecord copyWith({
    String? id,
    String? styleId,
    String? date,
    String? message,
    String? taskCompletion,
    Value<String?> mood = const Value.absent(),
    DateTime? updatedAt,
  }) => BookletRecord(
    id: id ?? this.id,
    styleId: styleId ?? this.styleId,
    date: date ?? this.date,
    message: message ?? this.message,
    taskCompletion: taskCompletion ?? this.taskCompletion,
    mood: mood.present ? mood.value : this.mood,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookletRecord copyWithCompanion(BookletRecordsCompanion data) {
    return BookletRecord(
      id: data.id.present ? data.id.value : this.id,
      styleId: data.styleId.present ? data.styleId.value : this.styleId,
      date: data.date.present ? data.date.value : this.date,
      message: data.message.present ? data.message.value : this.message,
      taskCompletion: data.taskCompletion.present
          ? data.taskCompletion.value
          : this.taskCompletion,
      mood: data.mood.present ? data.mood.value : this.mood,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookletRecord(')
          ..write('id: $id, ')
          ..write('styleId: $styleId, ')
          ..write('date: $date, ')
          ..write('message: $message, ')
          ..write('taskCompletion: $taskCompletion, ')
          ..write('mood: $mood, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, styleId, date, message, taskCompletion, mood, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookletRecord &&
          other.id == this.id &&
          other.styleId == this.styleId &&
          other.date == this.date &&
          other.message == this.message &&
          other.taskCompletion == this.taskCompletion &&
          other.mood == this.mood &&
          other.updatedAt == this.updatedAt);
}

class BookletRecordsCompanion extends UpdateCompanion<BookletRecord> {
  final Value<String> id;
  final Value<String> styleId;
  final Value<String> date;
  final Value<String> message;
  final Value<String> taskCompletion;
  final Value<String?> mood;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookletRecordsCompanion({
    this.id = const Value.absent(),
    this.styleId = const Value.absent(),
    this.date = const Value.absent(),
    this.message = const Value.absent(),
    this.taskCompletion = const Value.absent(),
    this.mood = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookletRecordsCompanion.insert({
    required String id,
    required String styleId,
    required String date,
    required String message,
    required String taskCompletion,
    this.mood = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       styleId = Value(styleId),
       date = Value(date),
       message = Value(message),
       taskCompletion = Value(taskCompletion),
       updatedAt = Value(updatedAt);
  static Insertable<BookletRecord> custom({
    Expression<String>? id,
    Expression<String>? styleId,
    Expression<String>? date,
    Expression<String>? message,
    Expression<String>? taskCompletion,
    Expression<String>? mood,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (styleId != null) 'style_id': styleId,
      if (date != null) 'date': date,
      if (message != null) 'message': message,
      if (taskCompletion != null) 'task_completion': taskCompletion,
      if (mood != null) 'mood': mood,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookletRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? styleId,
    Value<String>? date,
    Value<String>? message,
    Value<String>? taskCompletion,
    Value<String?>? mood,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookletRecordsCompanion(
      id: id ?? this.id,
      styleId: styleId ?? this.styleId,
      date: date ?? this.date,
      message: message ?? this.message,
      taskCompletion: taskCompletion ?? this.taskCompletion,
      mood: mood ?? this.mood,
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
    if (styleId.present) {
      map['style_id'] = Variable<String>(styleId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (taskCompletion.present) {
      map['task_completion'] = Variable<String>(taskCompletion.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        BookletRecords.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookletRecordsCompanion(')
          ..write('id: $id, ')
          ..write('styleId: $styleId, ')
          ..write('date: $date, ')
          ..write('message: $message, ')
          ..write('taskCompletion: $taskCompletion, ')
          ..write('mood: $mood, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EssayEntries extends Table with TableInfo<EssayEntries, EssayEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EssayEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> date =
      GeneratedColumn<int>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(EssayEntries.$converterdate);
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _imgsMeta = const VerificationMeta('imgs');
  late final GeneratedColumn<String> imgs = GeneratedColumn<String>(
    'imgs',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messagesMeta = const VerificationMeta(
    'messages',
  );
  late final GeneratedColumn<String> messages = GeneratedColumn<String>(
    'messages',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  late final GeneratedColumnWithTypeConverter<DateTime?, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: '',
      ).withConverter<DateTime?>(EssayEntries.$convertercreatedAtn);
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(EssayEntries.$converterupdatedAt);
  late final GeneratedColumnWithTypeConverter<DateTime, int> labelsUpdatedAt =
      GeneratedColumn<int>(
        'labels_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(EssayEntries.$converterlabelsUpdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    wordCount,
    title,
    content,
    imgs,
    messages,
    mood,
    createdAt,
    updatedAt,
    labelsUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'essay_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EssayEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wordCountMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('imgs')) {
      context.handle(
        _imgsMeta,
        imgs.isAcceptableOrUnknown(data['imgs']!, _imgsMeta),
      );
    } else if (isInserting) {
      context.missing(_imgsMeta);
    }
    if (data.containsKey('messages')) {
      context.handle(
        _messagesMeta,
        messages.isAcceptableOrUnknown(data['messages']!, _messagesMeta),
      );
    } else if (isInserting) {
      context.missing(_messagesMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EssayEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EssayEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: EssayEntries.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}date'],
        )!,
      ),
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      imgs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imgs'],
      )!,
      messages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messages'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      ),
      createdAt: EssayEntries.$convertercreatedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        ),
      ),
      updatedAt: EssayEntries.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      labelsUpdatedAt: EssayEntries.$converterlabelsUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}labels_updated_at'],
        )!,
      ),
    );
  }

  @override
  EssayEntries createAlias(String alias) {
    return EssayEntries(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterdate = const EpochMicros();
  static TypeConverter<DateTime, int> $convertercreatedAt = const EpochMicros();
  static TypeConverter<DateTime?, int?> $convertercreatedAtn =
      NullAwareTypeConverter.wrap($convertercreatedAt);
  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  static TypeConverter<DateTime, int> $converterlabelsUpdatedAt =
      const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class EssayEntry extends DataClass implements Insertable<EssayEntry> {
  final String id;
  final DateTime date;
  final int wordCount;
  final String title;
  final String content;
  final String imgs;
  final String messages;
  final String? mood;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime labelsUpdatedAt;
  const EssayEntry({
    required this.id,
    required this.date,
    required this.wordCount,
    required this.title,
    required this.content,
    required this.imgs,
    required this.messages,
    this.mood,
    this.createdAt,
    required this.updatedAt,
    required this.labelsUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['date'] = Variable<int>(EssayEntries.$converterdate.toSql(date));
    }
    map['word_count'] = Variable<int>(wordCount);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['imgs'] = Variable<String>(imgs);
    map['messages'] = Variable<String>(messages);
    if (!nullToAbsent || mood != null) {
      map['mood'] = Variable<String>(mood);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(
        EssayEntries.$convertercreatedAtn.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        EssayEntries.$converterupdatedAt.toSql(updatedAt),
      );
    }
    {
      map['labels_updated_at'] = Variable<int>(
        EssayEntries.$converterlabelsUpdatedAt.toSql(labelsUpdatedAt),
      );
    }
    return map;
  }

  EssayEntriesCompanion toCompanion(bool nullToAbsent) {
    return EssayEntriesCompanion(
      id: Value(id),
      date: Value(date),
      wordCount: Value(wordCount),
      title: Value(title),
      content: Value(content),
      imgs: Value(imgs),
      messages: Value(messages),
      mood: mood == null && nullToAbsent ? const Value.absent() : Value(mood),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      labelsUpdatedAt: Value(labelsUpdatedAt),
    );
  }

  factory EssayEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EssayEntry(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      wordCount: serializer.fromJson<int>(json['word_count']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      imgs: serializer.fromJson<String>(json['imgs']),
      messages: serializer.fromJson<String>(json['messages']),
      mood: serializer.fromJson<String?>(json['mood']),
      createdAt: serializer.fromJson<DateTime?>(json['created_at']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
      labelsUpdatedAt: serializer.fromJson<DateTime>(json['labels_updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<DateTime>(date),
      'word_count': serializer.toJson<int>(wordCount),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'imgs': serializer.toJson<String>(imgs),
      'messages': serializer.toJson<String>(messages),
      'mood': serializer.toJson<String?>(mood),
      'created_at': serializer.toJson<DateTime?>(createdAt),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
      'labels_updated_at': serializer.toJson<DateTime>(labelsUpdatedAt),
    };
  }

  EssayEntry copyWith({
    String? id,
    DateTime? date,
    int? wordCount,
    String? title,
    String? content,
    String? imgs,
    String? messages,
    Value<String?> mood = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    DateTime? labelsUpdatedAt,
  }) => EssayEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    wordCount: wordCount ?? this.wordCount,
    title: title ?? this.title,
    content: content ?? this.content,
    imgs: imgs ?? this.imgs,
    messages: messages ?? this.messages,
    mood: mood.present ? mood.value : this.mood,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    labelsUpdatedAt: labelsUpdatedAt ?? this.labelsUpdatedAt,
  );
  EssayEntry copyWithCompanion(EssayEntriesCompanion data) {
    return EssayEntry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      imgs: data.imgs.present ? data.imgs.value : this.imgs,
      messages: data.messages.present ? data.messages.value : this.messages,
      mood: data.mood.present ? data.mood.value : this.mood,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      labelsUpdatedAt: data.labelsUpdatedAt.present
          ? data.labelsUpdatedAt.value
          : this.labelsUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EssayEntry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('wordCount: $wordCount, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('imgs: $imgs, ')
          ..write('messages: $messages, ')
          ..write('mood: $mood, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('labelsUpdatedAt: $labelsUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    wordCount,
    title,
    content,
    imgs,
    messages,
    mood,
    createdAt,
    updatedAt,
    labelsUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EssayEntry &&
          other.id == this.id &&
          other.date == this.date &&
          other.wordCount == this.wordCount &&
          other.title == this.title &&
          other.content == this.content &&
          other.imgs == this.imgs &&
          other.messages == this.messages &&
          other.mood == this.mood &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.labelsUpdatedAt == this.labelsUpdatedAt);
}

class EssayEntriesCompanion extends UpdateCompanion<EssayEntry> {
  final Value<String> id;
  final Value<DateTime> date;
  final Value<int> wordCount;
  final Value<String> title;
  final Value<String> content;
  final Value<String> imgs;
  final Value<String> messages;
  final Value<String?> mood;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> labelsUpdatedAt;
  final Value<int> rowid;
  const EssayEntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.imgs = const Value.absent(),
    this.messages = const Value.absent(),
    this.mood = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.labelsUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EssayEntriesCompanion.insert({
    required String id,
    required DateTime date,
    required int wordCount,
    required String title,
    required String content,
    required String imgs,
    required String messages,
    this.mood = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    required DateTime labelsUpdatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       wordCount = Value(wordCount),
       title = Value(title),
       content = Value(content),
       imgs = Value(imgs),
       messages = Value(messages),
       updatedAt = Value(updatedAt),
       labelsUpdatedAt = Value(labelsUpdatedAt);
  static Insertable<EssayEntry> custom({
    Expression<String>? id,
    Expression<int>? date,
    Expression<int>? wordCount,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? imgs,
    Expression<String>? messages,
    Expression<String>? mood,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? labelsUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (wordCount != null) 'word_count': wordCount,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (imgs != null) 'imgs': imgs,
      if (messages != null) 'messages': messages,
      if (mood != null) 'mood': mood,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (labelsUpdatedAt != null) 'labels_updated_at': labelsUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EssayEntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? date,
    Value<int>? wordCount,
    Value<String>? title,
    Value<String>? content,
    Value<String>? imgs,
    Value<String>? messages,
    Value<String?>? mood,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? labelsUpdatedAt,
    Value<int>? rowid,
  }) {
    return EssayEntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      wordCount: wordCount ?? this.wordCount,
      title: title ?? this.title,
      content: content ?? this.content,
      imgs: imgs ?? this.imgs,
      messages: messages ?? this.messages,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      labelsUpdatedAt: labelsUpdatedAt ?? this.labelsUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(
        EssayEntries.$converterdate.toSql(date.value),
      );
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (imgs.present) {
      map['imgs'] = Variable<String>(imgs.value);
    }
    if (messages.present) {
      map['messages'] = Variable<String>(messages.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        EssayEntries.$convertercreatedAtn.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        EssayEntries.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (labelsUpdatedAt.present) {
      map['labels_updated_at'] = Variable<int>(
        EssayEntries.$converterlabelsUpdatedAt.toSql(labelsUpdatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EssayEntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('wordCount: $wordCount, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('imgs: $imgs, ')
          ..write('messages: $messages, ')
          ..write('mood: $mood, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('labelsUpdatedAt: $labelsUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EssayLabels extends Table with TableInfo<EssayLabels, EssayLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EssayLabels(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'REFERENCES essay_labels(id)DEFERRABLE INITIALLY DEFERRED',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(EssayLabels.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, name, parentId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'essay_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EssayLabel> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EssayLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EssayLabel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      updatedAt: EssayLabels.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  EssayLabels createAlias(String alias) {
    return EssayLabels(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class EssayLabel extends DataClass implements Insertable<EssayLabel> {
  final String id;
  final String name;
  final String? parentId;
  final DateTime updatedAt;
  const EssayLabel({
    required this.id,
    required this.name,
    this.parentId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    {
      map['updated_at'] = Variable<int>(
        EssayLabels.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  EssayLabelsCompanion toCompanion(bool nullToAbsent) {
    return EssayLabelsCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      updatedAt: Value(updatedAt),
    );
  }

  factory EssayLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EssayLabel(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parent_id': serializer.toJson<String?>(parentId),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EssayLabel copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
    DateTime? updatedAt,
  }) => EssayLabel(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EssayLabel copyWithCompanion(EssayLabelsCompanion data) {
    return EssayLabel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EssayLabel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EssayLabel &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.updatedAt == this.updatedAt);
}

class EssayLabelsCompanion extends UpdateCompanion<EssayLabel> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EssayLabelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EssayLabelsCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<EssayLabel> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EssayLabelsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EssayLabelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        EssayLabels.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EssayLabelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EssayLinks extends Table with TableInfo<EssayLinks, EssayLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EssayLinks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _essayIdMeta = const VerificationMeta(
    'essayId',
  );
  late final GeneratedColumn<String> essayId = GeneratedColumn<String>(
    'essay_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES essay_entries(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  late final GeneratedColumn<String> labelId = GeneratedColumn<String>(
    'label_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES essay_labels(id)DEFERRABLE INITIALLY DEFERRED',
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [essayId, labelId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'essay_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<EssayLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('essay_id')) {
      context.handle(
        _essayIdMeta,
        essayId.isAcceptableOrUnknown(data['essay_id']!, _essayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_essayIdMeta);
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_labelIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {essayId, position};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {labelId, essayId},
  ];
  @override
  EssayLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EssayLink(
      essayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}essay_id'],
      )!,
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  EssayLinks createAlias(String alias) {
    return EssayLinks(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(essay_id, position)',
    'UNIQUE(label_id, essay_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class EssayLink extends DataClass implements Insertable<EssayLink> {
  final String essayId;
  final String labelId;
  final int position;
  const EssayLink({
    required this.essayId,
    required this.labelId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['essay_id'] = Variable<String>(essayId);
    map['label_id'] = Variable<String>(labelId);
    map['position'] = Variable<int>(position);
    return map;
  }

  EssayLinksCompanion toCompanion(bool nullToAbsent) {
    return EssayLinksCompanion(
      essayId: Value(essayId),
      labelId: Value(labelId),
      position: Value(position),
    );
  }

  factory EssayLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EssayLink(
      essayId: serializer.fromJson<String>(json['essay_id']),
      labelId: serializer.fromJson<String>(json['label_id']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'essay_id': serializer.toJson<String>(essayId),
      'label_id': serializer.toJson<String>(labelId),
      'position': serializer.toJson<int>(position),
    };
  }

  EssayLink copyWith({String? essayId, String? labelId, int? position}) =>
      EssayLink(
        essayId: essayId ?? this.essayId,
        labelId: labelId ?? this.labelId,
        position: position ?? this.position,
      );
  EssayLink copyWithCompanion(EssayLinksCompanion data) {
    return EssayLink(
      essayId: data.essayId.present ? data.essayId.value : this.essayId,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EssayLink(')
          ..write('essayId: $essayId, ')
          ..write('labelId: $labelId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(essayId, labelId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EssayLink &&
          other.essayId == this.essayId &&
          other.labelId == this.labelId &&
          other.position == this.position);
}

class EssayLinksCompanion extends UpdateCompanion<EssayLink> {
  final Value<String> essayId;
  final Value<String> labelId;
  final Value<int> position;
  final Value<int> rowid;
  const EssayLinksCompanion({
    this.essayId = const Value.absent(),
    this.labelId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EssayLinksCompanion.insert({
    required String essayId,
    required String labelId,
    required int position,
    this.rowid = const Value.absent(),
  }) : essayId = Value(essayId),
       labelId = Value(labelId),
       position = Value(position);
  static Insertable<EssayLink> custom({
    Expression<String>? essayId,
    Expression<String>? labelId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (essayId != null) 'essay_id': essayId,
      if (labelId != null) 'label_id': labelId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EssayLinksCompanion copyWith({
    Value<String>? essayId,
    Value<String>? labelId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return EssayLinksCompanion(
      essayId: essayId ?? this.essayId,
      labelId: labelId ?? this.labelId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (essayId.present) {
      map['essay_id'] = Variable<String>(essayId.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<String>(labelId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EssayLinksCompanion(')
          ..write('essayId: $essayId, ')
          ..write('labelId: $labelId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class EssayDrafts extends Table with TableInfo<EssayDrafts, EssayDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  EssayDrafts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> editedAt =
      GeneratedColumn<int>(
        'edited_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(EssayDrafts.$convertereditedAt);
  static const VerificationMeta _essayMeta = const VerificationMeta('essay');
  late final GeneratedColumn<String> essay = GeneratedColumn<String>(
    'essay',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _originalMeta = const VerificationMeta(
    'original',
  );
  late final GeneratedColumn<String> original = GeneratedColumn<String>(
    'original',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [id, editedAt, essay, original];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'essay_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EssayDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('essay')) {
      context.handle(
        _essayMeta,
        essay.isAcceptableOrUnknown(data['essay']!, _essayMeta),
      );
    } else if (isInserting) {
      context.missing(_essayMeta);
    }
    if (data.containsKey('original')) {
      context.handle(
        _originalMeta,
        original.isAcceptableOrUnknown(data['original']!, _originalMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EssayDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EssayDraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      editedAt: EssayDrafts.$convertereditedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}edited_at'],
        )!,
      ),
      essay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}essay'],
      )!,
      original: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original'],
      ),
    );
  }

  @override
  EssayDrafts createAlias(String alias) {
    return EssayDrafts(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertereditedAt = const EpochMicros();
  @override
  bool get dontWriteConstraints => true;
}

class EssayDraftRow extends DataClass implements Insertable<EssayDraftRow> {
  final String id;
  final DateTime editedAt;
  final String essay;
  final String? original;
  const EssayDraftRow({
    required this.id,
    required this.editedAt,
    required this.essay,
    this.original,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['edited_at'] = Variable<int>(
        EssayDrafts.$convertereditedAt.toSql(editedAt),
      );
    }
    map['essay'] = Variable<String>(essay);
    if (!nullToAbsent || original != null) {
      map['original'] = Variable<String>(original);
    }
    return map;
  }

  EssayDraftsCompanion toCompanion(bool nullToAbsent) {
    return EssayDraftsCompanion(
      id: Value(id),
      editedAt: Value(editedAt),
      essay: Value(essay),
      original: original == null && nullToAbsent
          ? const Value.absent()
          : Value(original),
    );
  }

  factory EssayDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EssayDraftRow(
      id: serializer.fromJson<String>(json['id']),
      editedAt: serializer.fromJson<DateTime>(json['edited_at']),
      essay: serializer.fromJson<String>(json['essay']),
      original: serializer.fromJson<String?>(json['original']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'edited_at': serializer.toJson<DateTime>(editedAt),
      'essay': serializer.toJson<String>(essay),
      'original': serializer.toJson<String?>(original),
    };
  }

  EssayDraftRow copyWith({
    String? id,
    DateTime? editedAt,
    String? essay,
    Value<String?> original = const Value.absent(),
  }) => EssayDraftRow(
    id: id ?? this.id,
    editedAt: editedAt ?? this.editedAt,
    essay: essay ?? this.essay,
    original: original.present ? original.value : this.original,
  );
  EssayDraftRow copyWithCompanion(EssayDraftsCompanion data) {
    return EssayDraftRow(
      id: data.id.present ? data.id.value : this.id,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      essay: data.essay.present ? data.essay.value : this.essay,
      original: data.original.present ? data.original.value : this.original,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EssayDraftRow(')
          ..write('id: $id, ')
          ..write('editedAt: $editedAt, ')
          ..write('essay: $essay, ')
          ..write('original: $original')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, editedAt, essay, original);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EssayDraftRow &&
          other.id == this.id &&
          other.editedAt == this.editedAt &&
          other.essay == this.essay &&
          other.original == this.original);
}

class EssayDraftsCompanion extends UpdateCompanion<EssayDraftRow> {
  final Value<String> id;
  final Value<DateTime> editedAt;
  final Value<String> essay;
  final Value<String?> original;
  final Value<int> rowid;
  const EssayDraftsCompanion({
    this.id = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.essay = const Value.absent(),
    this.original = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EssayDraftsCompanion.insert({
    required String id,
    required DateTime editedAt,
    required String essay,
    this.original = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       editedAt = Value(editedAt),
       essay = Value(essay);
  static Insertable<EssayDraftRow> custom({
    Expression<String>? id,
    Expression<int>? editedAt,
    Expression<String>? essay,
    Expression<String>? original,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (editedAt != null) 'edited_at': editedAt,
      if (essay != null) 'essay': essay,
      if (original != null) 'original': original,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EssayDraftsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? editedAt,
    Value<String>? essay,
    Value<String?>? original,
    Value<int>? rowid,
  }) {
    return EssayDraftsCompanion(
      id: id ?? this.id,
      editedAt: editedAt ?? this.editedAt,
      essay: essay ?? this.essay,
      original: original ?? this.original,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<int>(
        EssayDrafts.$convertereditedAt.toSql(editedAt.value),
      );
    }
    if (essay.present) {
      map['essay'] = Variable<String>(essay.value);
    }
    if (original.present) {
      map['original'] = Variable<String>(original.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EssayDraftsCompanion(')
          ..write('id: $id, ')
          ..write('editedAt: $editedAt, ')
          ..write('essay: $essay, ')
          ..write('original: $original, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncCursors extends Table with TableInfo<SyncCursors, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncCursors(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (revision >= 0)',
  );
  @override
  List<GeneratedColumn> get $columns => [address, module, revision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {address, module};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  SyncCursors createAlias(String alias) {
    return SyncCursors(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(address, module)'];
  @override
  bool get dontWriteConstraints => true;
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String address;
  final String module;
  final int revision;
  const SyncCursor({
    required this.address,
    required this.module,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address'] = Variable<String>(address);
    map['module'] = Variable<String>(module);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      address: Value(address),
      module: Value(module),
      revision: Value(revision),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      address: serializer.fromJson<String>(json['address']),
      module: serializer.fromJson<String>(json['module']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'address': serializer.toJson<String>(address),
      'module': serializer.toJson<String>(module),
      'revision': serializer.toJson<int>(revision),
    };
  }

  SyncCursor copyWith({String? address, String? module, int? revision}) =>
      SyncCursor(
        address: address ?? this.address,
        module: module ?? this.module,
        revision: revision ?? this.revision,
      );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      address: data.address.present ? data.address.value : this.address,
      module: data.module.present ? data.module.value : this.module,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('address: $address, ')
          ..write('module: $module, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(address, module, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.address == this.address &&
          other.module == this.module &&
          other.revision == this.revision);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> address;
  final Value<String> module;
  final Value<int> revision;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.address = const Value.absent(),
    this.module = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String address,
    required String module,
    required int revision,
    this.rowid = const Value.absent(),
  }) : address = Value(address),
       module = Value(module),
       revision = Value(revision);
  static Insertable<SyncCursor> custom({
    Expression<String>? address,
    Expression<String>? module,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (address != null) 'address': address,
      if (module != null) 'module': module,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? address,
    Value<String>? module,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      address: address ?? this.address,
      module: module ?? this.module,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('address: $address, ')
          ..write('module: $module, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncDeletions extends Table with TableInfo<SyncDeletions, SyncDeletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncDeletions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      ).withConverter<DateTime>(SyncDeletions.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [module, collection, id, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_deletions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncDeletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleMeta);
    }
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {module, collection, id};
  @override
  SyncDeletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncDeletion(
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      )!,
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: SyncDeletions.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  SyncDeletions createAlias(String alias) {
    return SyncDeletions(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMicros();
  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(module, collection, id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SyncDeletion extends DataClass implements Insertable<SyncDeletion> {
  final String module;
  final String collection;
  final String id;
  final DateTime updatedAt;
  const SyncDeletion({
    required this.module,
    required this.collection,
    required this.id,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['module'] = Variable<String>(module);
    map['collection'] = Variable<String>(collection);
    map['id'] = Variable<String>(id);
    {
      map['updated_at'] = Variable<int>(
        SyncDeletions.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  SyncDeletionsCompanion toCompanion(bool nullToAbsent) {
    return SyncDeletionsCompanion(
      module: Value(module),
      collection: Value(collection),
      id: Value(id),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncDeletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncDeletion(
      module: serializer.fromJson<String>(json['module']),
      collection: serializer.fromJson<String>(json['collection']),
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'module': serializer.toJson<String>(module),
      'collection': serializer.toJson<String>(collection),
      'id': serializer.toJson<String>(id),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncDeletion copyWith({
    String? module,
    String? collection,
    String? id,
    DateTime? updatedAt,
  }) => SyncDeletion(
    module: module ?? this.module,
    collection: collection ?? this.collection,
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncDeletion copyWithCompanion(SyncDeletionsCompanion data) {
    return SyncDeletion(
      module: data.module.present ? data.module.value : this.module,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncDeletion(')
          ..write('module: $module, ')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(module, collection, id, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncDeletion &&
          other.module == this.module &&
          other.collection == this.collection &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt);
}

class SyncDeletionsCompanion extends UpdateCompanion<SyncDeletion> {
  final Value<String> module;
  final Value<String> collection;
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncDeletionsCompanion({
    this.module = const Value.absent(),
    this.collection = const Value.absent(),
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncDeletionsCompanion.insert({
    required String module,
    required String collection,
    required String id,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : module = Value(module),
       collection = Value(collection),
       id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<SyncDeletion> custom({
    Expression<String>? module,
    Expression<String>? collection,
    Expression<String>? id,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (module != null) 'module': module,
      if (collection != null) 'collection': collection,
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncDeletionsCompanion copyWith({
    Value<String>? module,
    Value<String>? collection,
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncDeletionsCompanion(
      module: module ?? this.module,
      collection: collection ?? this.collection,
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        SyncDeletions.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncDeletionsCompanion(')
          ..write('module: $module, ')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final GalleryAssets galleryAssets = GalleryAssets(this);
  late final GalleryTags galleryTags = GalleryTags(this);
  late final GalleryLinks galleryLinks = GalleryLinks(this);
  late final GalleryOperations galleryOperations = GalleryOperations(this);
  late final GalleryLibrary galleryLibrary = GalleryLibrary(this);
  late final GalleryPositions galleryPositions = GalleryPositions(this);
  late final Index galleryAssetsOrder = Index(
    'gallery_assets_order',
    'CREATE INDEX gallery_assets_order ON gallery_assets (group_id, captured_at, id)',
  );
  late final Index galleryTagsParent = Index(
    'gallery_tags_parent',
    'CREATE INDEX gallery_tags_parent ON gallery_tags (parent_id)',
  );
  late final Index galleryLinksTag = Index(
    'gallery_links_tag',
    'CREATE INDEX gallery_links_tag ON gallery_links (tag_id)',
  );
  late final ComicCatalog comicCatalog = ComicCatalog(this);
  late final ComicChapters comicChapters = ComicChapters(this);
  late final ComicProgress comicProgress = ComicProgress(this);
  late final ComicDownloads comicDownloads = ComicDownloads(this);
  late final Index comicChapterOrder = Index(
    'comic_chapter_order',
    'CREATE INDEX comic_chapter_order ON comic_chapters (comic_id, chapter_index)',
  );
  late final ChatConversations chatConversations = ChatConversations(this);
  late final ReviewPresets reviewPresets = ReviewPresets(this);
  late final ReviewHistory reviewHistory = ReviewHistory(this);
  late final BookletStyles bookletStyles = BookletStyles(this);
  late final BookletRecords bookletRecords = BookletRecords(this);
  late final Index bookletRecordsDate = Index(
    'booklet_records_date',
    'CREATE INDEX booklet_records_date ON booklet_records (date)',
  );
  late final EssayEntries essayEntries = EssayEntries(this);
  late final EssayLabels essayLabels = EssayLabels(this);
  late final EssayLinks essayLinks = EssayLinks(this);
  late final EssayDrafts essayDrafts = EssayDrafts(this);
  late final Index essayEntriesDate = Index(
    'essay_entries_date',
    'CREATE INDEX essay_entries_date ON essay_entries (date, id)',
  );
  late final SyncCursors syncCursors = SyncCursors(this);
  late final SyncDeletions syncDeletions = SyncDeletions(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    galleryAssets,
    galleryTags,
    galleryLinks,
    galleryOperations,
    galleryLibrary,
    galleryPositions,
    galleryAssetsOrder,
    galleryTagsParent,
    galleryLinksTag,
    comicCatalog,
    comicChapters,
    comicProgress,
    comicDownloads,
    comicChapterOrder,
    chatConversations,
    reviewPresets,
    reviewHistory,
    bookletStyles,
    bookletRecords,
    bookletRecordsDate,
    essayEntries,
    essayLabels,
    essayLinks,
    essayDrafts,
    essayEntriesDate,
    syncCursors,
    syncDeletions,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'gallery_assets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('gallery_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'gallery_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('gallery_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'gallery_library',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('gallery_positions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'comic_catalog',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('comic_chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'essay_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('essay_links', kind: UpdateKind.delete)],
    ),
  ]);
}
