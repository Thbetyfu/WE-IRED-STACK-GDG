// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionTableTable extends SessionTable
    with TableInfo<$SessionTableTable, SessionTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accessTokenMeta =
      const VerificationMeta('accessToken');
  @override
  late final GeneratedColumn<String> accessToken = GeneratedColumn<String>(
      'access_token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _refreshTokenMeta =
      const VerificationMeta('refreshToken');
  @override
  late final GeneratedColumn<String> refreshToken = GeneratedColumn<String>(
      'refresh_token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _regionIdMeta =
      const VerificationMeta('regionId');
  @override
  late final GeneratedColumn<String> regionId = GeneratedColumn<String>(
      'region_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _householdIdMeta =
      const VerificationMeta('householdId');
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
      'household_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accessToken,
        refreshToken,
        role,
        regionId,
        householdId,
        userId,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_table';
  @override
  VerificationContext validateIntegrity(Insertable<SessionTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('access_token')) {
      context.handle(
          _accessTokenMeta,
          accessToken.isAcceptableOrUnknown(
              data['access_token']!, _accessTokenMeta));
    } else if (isInserting) {
      context.missing(_accessTokenMeta);
    }
    if (data.containsKey('refresh_token')) {
      context.handle(
          _refreshTokenMeta,
          refreshToken.isAcceptableOrUnknown(
              data['refresh_token']!, _refreshTokenMeta));
    } else if (isInserting) {
      context.missing(_refreshTokenMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('region_id')) {
      context.handle(_regionIdMeta,
          regionId.isAcceptableOrUnknown(data['region_id']!, _regionIdMeta));
    } else if (isInserting) {
      context.missing(_regionIdMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
          _householdIdMeta,
          householdId.isAcceptableOrUnknown(
              data['household_id']!, _householdIdMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      accessToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}access_token'])!,
      refreshToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}refresh_token'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      regionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}region_id'])!,
      householdId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}household_id']),
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SessionTableTable createAlias(String alias) {
    return $SessionTableTable(attachedDatabase, alias);
  }
}

class SessionTableData extends DataClass
    implements Insertable<SessionTableData> {
  final String id;
  final String accessToken;
  final String refreshToken;
  final String role;
  final String regionId;
  final String? householdId;
  final String userId;
  final DateTime updatedAt;
  const SessionTableData(
      {required this.id,
      required this.accessToken,
      required this.refreshToken,
      required this.role,
      required this.regionId,
      this.householdId,
      required this.userId,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['access_token'] = Variable<String>(accessToken);
    map['refresh_token'] = Variable<String>(refreshToken);
    map['role'] = Variable<String>(role);
    map['region_id'] = Variable<String>(regionId);
    if (!nullToAbsent || householdId != null) {
      map['household_id'] = Variable<String>(householdId);
    }
    map['user_id'] = Variable<String>(userId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionTableCompanion toCompanion(bool nullToAbsent) {
    return SessionTableCompanion(
      id: Value(id),
      accessToken: Value(accessToken),
      refreshToken: Value(refreshToken),
      role: Value(role),
      regionId: Value(regionId),
      householdId: householdId == null && nullToAbsent
          ? const Value.absent()
          : Value(householdId),
      userId: Value(userId),
      updatedAt: Value(updatedAt),
    );
  }

  factory SessionTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionTableData(
      id: serializer.fromJson<String>(json['id']),
      accessToken: serializer.fromJson<String>(json['accessToken']),
      refreshToken: serializer.fromJson<String>(json['refreshToken']),
      role: serializer.fromJson<String>(json['role']),
      regionId: serializer.fromJson<String>(json['regionId']),
      householdId: serializer.fromJson<String?>(json['householdId']),
      userId: serializer.fromJson<String>(json['userId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accessToken': serializer.toJson<String>(accessToken),
      'refreshToken': serializer.toJson<String>(refreshToken),
      'role': serializer.toJson<String>(role),
      'regionId': serializer.toJson<String>(regionId),
      'householdId': serializer.toJson<String?>(householdId),
      'userId': serializer.toJson<String>(userId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SessionTableData copyWith(
          {String? id,
          String? accessToken,
          String? refreshToken,
          String? role,
          String? regionId,
          Value<String?> householdId = const Value.absent(),
          String? userId,
          DateTime? updatedAt}) =>
      SessionTableData(
        id: id ?? this.id,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        role: role ?? this.role,
        regionId: regionId ?? this.regionId,
        householdId: householdId.present ? householdId.value : this.householdId,
        userId: userId ?? this.userId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SessionTableData copyWithCompanion(SessionTableCompanion data) {
    return SessionTableData(
      id: data.id.present ? data.id.value : this.id,
      accessToken:
          data.accessToken.present ? data.accessToken.value : this.accessToken,
      refreshToken: data.refreshToken.present
          ? data.refreshToken.value
          : this.refreshToken,
      role: data.role.present ? data.role.value : this.role,
      regionId: data.regionId.present ? data.regionId.value : this.regionId,
      householdId:
          data.householdId.present ? data.householdId.value : this.householdId,
      userId: data.userId.present ? data.userId.value : this.userId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionTableData(')
          ..write('id: $id, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('role: $role, ')
          ..write('regionId: $regionId, ')
          ..write('householdId: $householdId, ')
          ..write('userId: $userId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accessToken, refreshToken, role, regionId,
      householdId, userId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionTableData &&
          other.id == this.id &&
          other.accessToken == this.accessToken &&
          other.refreshToken == this.refreshToken &&
          other.role == this.role &&
          other.regionId == this.regionId &&
          other.householdId == this.householdId &&
          other.userId == this.userId &&
          other.updatedAt == this.updatedAt);
}

class SessionTableCompanion extends UpdateCompanion<SessionTableData> {
  final Value<String> id;
  final Value<String> accessToken;
  final Value<String> refreshToken;
  final Value<String> role;
  final Value<String> regionId;
  final Value<String?> householdId;
  final Value<String> userId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionTableCompanion({
    this.id = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.role = const Value.absent(),
    this.regionId = const Value.absent(),
    this.householdId = const Value.absent(),
    this.userId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionTableCompanion.insert({
    required String id,
    required String accessToken,
    required String refreshToken,
    required String role,
    required String regionId,
    this.householdId = const Value.absent(),
    required String userId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        accessToken = Value(accessToken),
        refreshToken = Value(refreshToken),
        role = Value(role),
        regionId = Value(regionId),
        userId = Value(userId),
        updatedAt = Value(updatedAt);
  static Insertable<SessionTableData> custom({
    Expression<String>? id,
    Expression<String>? accessToken,
    Expression<String>? refreshToken,
    Expression<String>? role,
    Expression<String>? regionId,
    Expression<String>? householdId,
    Expression<String>? userId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (role != null) 'role': role,
      if (regionId != null) 'region_id': regionId,
      if (householdId != null) 'household_id': householdId,
      if (userId != null) 'user_id': userId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? accessToken,
      Value<String>? refreshToken,
      Value<String>? role,
      Value<String>? regionId,
      Value<String?>? householdId,
      Value<String>? userId,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SessionTableCompanion(
      id: id ?? this.id,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      role: role ?? this.role,
      regionId: regionId ?? this.regionId,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
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
    if (accessToken.present) {
      map['access_token'] = Variable<String>(accessToken.value);
    }
    if (refreshToken.present) {
      map['refresh_token'] = Variable<String>(refreshToken.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (regionId.present) {
      map['region_id'] = Variable<String>(regionId.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
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
    return (StringBuffer('SessionTableCompanion(')
          ..write('id: $id, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('role: $role, ')
          ..write('regionId: $regionId, ')
          ..write('householdId: $householdId, ')
          ..write('userId: $userId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HouseholdSnapshotTableTable extends HouseholdSnapshotTable
    with TableInfo<$HouseholdSnapshotTableTable, HouseholdSnapshotTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdSnapshotTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rtIdMeta = const VerificationMeta('rtId');
  @override
  late final GeneratedColumn<String> rtId = GeneratedColumn<String>(
      'rt_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _blockIdMeta =
      const VerificationMeta('blockId');
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
      'block_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
      'number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
      'lon', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _headNameMeta =
      const VerificationMeta('headName');
  @override
  late final GeneratedColumn<String> headName = GeneratedColumn<String>(
      'head_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _waPhoneMeta =
      const VerificationMeta('waPhone');
  @override
  late final GeneratedColumn<String> waPhone = GeneratedColumn<String>(
      'wa_phone', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hasDeviceMeta =
      const VerificationMeta('hasDevice');
  @override
  late final GeneratedColumn<bool> hasDevice = GeneratedColumn<bool>(
      'has_device', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("has_device" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isSyntheticMeta =
      const VerificationMeta('isSynthetic');
  @override
  late final GeneratedColumn<bool> isSynthetic = GeneratedColumn<bool>(
      'is_synthetic', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_synthetic" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _jsonDataMeta =
      const VerificationMeta('jsonData');
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
      'json_data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        rtId,
        blockId,
        number,
        address,
        lat,
        lon,
        headName,
        waPhone,
        hasDevice,
        isSynthetic,
        jsonData,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'household_snapshot_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<HouseholdSnapshotTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rt_id')) {
      context.handle(
          _rtIdMeta, rtId.isAcceptableOrUnknown(data['rt_id']!, _rtIdMeta));
    } else if (isInserting) {
      context.missing(_rtIdMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(_blockIdMeta,
          blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta));
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lon')) {
      context.handle(
          _lonMeta, lon.isAcceptableOrUnknown(data['lon']!, _lonMeta));
    }
    if (data.containsKey('head_name')) {
      context.handle(_headNameMeta,
          headName.isAcceptableOrUnknown(data['head_name']!, _headNameMeta));
    } else if (isInserting) {
      context.missing(_headNameMeta);
    }
    if (data.containsKey('wa_phone')) {
      context.handle(_waPhoneMeta,
          waPhone.isAcceptableOrUnknown(data['wa_phone']!, _waPhoneMeta));
    } else if (isInserting) {
      context.missing(_waPhoneMeta);
    }
    if (data.containsKey('has_device')) {
      context.handle(_hasDeviceMeta,
          hasDevice.isAcceptableOrUnknown(data['has_device']!, _hasDeviceMeta));
    }
    if (data.containsKey('is_synthetic')) {
      context.handle(
          _isSyntheticMeta,
          isSynthetic.isAcceptableOrUnknown(
              data['is_synthetic']!, _isSyntheticMeta));
    }
    if (data.containsKey('json_data')) {
      context.handle(_jsonDataMeta,
          jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta));
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HouseholdSnapshotTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HouseholdSnapshotTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      rtId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rt_id'])!,
      blockId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}block_id']),
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}number'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address'])!,
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lon']),
      headName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}head_name'])!,
      waPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wa_phone'])!,
      hasDevice: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}has_device'])!,
      isSynthetic: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synthetic'])!,
      jsonData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json_data'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $HouseholdSnapshotTableTable createAlias(String alias) {
    return $HouseholdSnapshotTableTable(attachedDatabase, alias);
  }
}

class HouseholdSnapshotTableData extends DataClass
    implements Insertable<HouseholdSnapshotTableData> {
  final String id;
  final String rtId;
  final String? blockId;
  final String number;
  final String address;
  final double? lat;
  final double? lon;
  final String headName;
  final String waPhone;
  final bool hasDevice;
  final bool isSynthetic;
  final String jsonData;
  final DateTime updatedAt;
  const HouseholdSnapshotTableData(
      {required this.id,
      required this.rtId,
      this.blockId,
      required this.number,
      required this.address,
      this.lat,
      this.lon,
      required this.headName,
      required this.waPhone,
      required this.hasDevice,
      required this.isSynthetic,
      required this.jsonData,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['rt_id'] = Variable<String>(rtId);
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    map['number'] = Variable<String>(number);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    map['head_name'] = Variable<String>(headName);
    map['wa_phone'] = Variable<String>(waPhone);
    map['has_device'] = Variable<bool>(hasDevice);
    map['is_synthetic'] = Variable<bool>(isSynthetic);
    map['json_data'] = Variable<String>(jsonData);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HouseholdSnapshotTableCompanion toCompanion(bool nullToAbsent) {
    return HouseholdSnapshotTableCompanion(
      id: Value(id),
      rtId: Value(rtId),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      number: Value(number),
      address: Value(address),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      headName: Value(headName),
      waPhone: Value(waPhone),
      hasDevice: Value(hasDevice),
      isSynthetic: Value(isSynthetic),
      jsonData: Value(jsonData),
      updatedAt: Value(updatedAt),
    );
  }

  factory HouseholdSnapshotTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HouseholdSnapshotTableData(
      id: serializer.fromJson<String>(json['id']),
      rtId: serializer.fromJson<String>(json['rtId']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      number: serializer.fromJson<String>(json['number']),
      address: serializer.fromJson<String>(json['address']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      headName: serializer.fromJson<String>(json['headName']),
      waPhone: serializer.fromJson<String>(json['waPhone']),
      hasDevice: serializer.fromJson<bool>(json['hasDevice']),
      isSynthetic: serializer.fromJson<bool>(json['isSynthetic']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'rtId': serializer.toJson<String>(rtId),
      'blockId': serializer.toJson<String?>(blockId),
      'number': serializer.toJson<String>(number),
      'address': serializer.toJson<String>(address),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'headName': serializer.toJson<String>(headName),
      'waPhone': serializer.toJson<String>(waPhone),
      'hasDevice': serializer.toJson<bool>(hasDevice),
      'isSynthetic': serializer.toJson<bool>(isSynthetic),
      'jsonData': serializer.toJson<String>(jsonData),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HouseholdSnapshotTableData copyWith(
          {String? id,
          String? rtId,
          Value<String?> blockId = const Value.absent(),
          String? number,
          String? address,
          Value<double?> lat = const Value.absent(),
          Value<double?> lon = const Value.absent(),
          String? headName,
          String? waPhone,
          bool? hasDevice,
          bool? isSynthetic,
          String? jsonData,
          DateTime? updatedAt}) =>
      HouseholdSnapshotTableData(
        id: id ?? this.id,
        rtId: rtId ?? this.rtId,
        blockId: blockId.present ? blockId.value : this.blockId,
        number: number ?? this.number,
        address: address ?? this.address,
        lat: lat.present ? lat.value : this.lat,
        lon: lon.present ? lon.value : this.lon,
        headName: headName ?? this.headName,
        waPhone: waPhone ?? this.waPhone,
        hasDevice: hasDevice ?? this.hasDevice,
        isSynthetic: isSynthetic ?? this.isSynthetic,
        jsonData: jsonData ?? this.jsonData,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  HouseholdSnapshotTableData copyWithCompanion(
      HouseholdSnapshotTableCompanion data) {
    return HouseholdSnapshotTableData(
      id: data.id.present ? data.id.value : this.id,
      rtId: data.rtId.present ? data.rtId.value : this.rtId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      number: data.number.present ? data.number.value : this.number,
      address: data.address.present ? data.address.value : this.address,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      headName: data.headName.present ? data.headName.value : this.headName,
      waPhone: data.waPhone.present ? data.waPhone.value : this.waPhone,
      hasDevice: data.hasDevice.present ? data.hasDevice.value : this.hasDevice,
      isSynthetic:
          data.isSynthetic.present ? data.isSynthetic.value : this.isSynthetic,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdSnapshotTableData(')
          ..write('id: $id, ')
          ..write('rtId: $rtId, ')
          ..write('blockId: $blockId, ')
          ..write('number: $number, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('headName: $headName, ')
          ..write('waPhone: $waPhone, ')
          ..write('hasDevice: $hasDevice, ')
          ..write('isSynthetic: $isSynthetic, ')
          ..write('jsonData: $jsonData, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, rtId, blockId, number, address, lat, lon,
      headName, waPhone, hasDevice, isSynthetic, jsonData, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HouseholdSnapshotTableData &&
          other.id == this.id &&
          other.rtId == this.rtId &&
          other.blockId == this.blockId &&
          other.number == this.number &&
          other.address == this.address &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.headName == this.headName &&
          other.waPhone == this.waPhone &&
          other.hasDevice == this.hasDevice &&
          other.isSynthetic == this.isSynthetic &&
          other.jsonData == this.jsonData &&
          other.updatedAt == this.updatedAt);
}

class HouseholdSnapshotTableCompanion
    extends UpdateCompanion<HouseholdSnapshotTableData> {
  final Value<String> id;
  final Value<String> rtId;
  final Value<String?> blockId;
  final Value<String> number;
  final Value<String> address;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<String> headName;
  final Value<String> waPhone;
  final Value<bool> hasDevice;
  final Value<bool> isSynthetic;
  final Value<String> jsonData;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HouseholdSnapshotTableCompanion({
    this.id = const Value.absent(),
    this.rtId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.number = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.headName = const Value.absent(),
    this.waPhone = const Value.absent(),
    this.hasDevice = const Value.absent(),
    this.isSynthetic = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdSnapshotTableCompanion.insert({
    required String id,
    required String rtId,
    this.blockId = const Value.absent(),
    required String number,
    required String address,
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    required String headName,
    required String waPhone,
    this.hasDevice = const Value.absent(),
    this.isSynthetic = const Value.absent(),
    required String jsonData,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        rtId = Value(rtId),
        number = Value(number),
        address = Value(address),
        headName = Value(headName),
        waPhone = Value(waPhone),
        jsonData = Value(jsonData),
        updatedAt = Value(updatedAt);
  static Insertable<HouseholdSnapshotTableData> custom({
    Expression<String>? id,
    Expression<String>? rtId,
    Expression<String>? blockId,
    Expression<String>? number,
    Expression<String>? address,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<String>? headName,
    Expression<String>? waPhone,
    Expression<bool>? hasDevice,
    Expression<bool>? isSynthetic,
    Expression<String>? jsonData,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rtId != null) 'rt_id': rtId,
      if (blockId != null) 'block_id': blockId,
      if (number != null) 'number': number,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (headName != null) 'head_name': headName,
      if (waPhone != null) 'wa_phone': waPhone,
      if (hasDevice != null) 'has_device': hasDevice,
      if (isSynthetic != null) 'is_synthetic': isSynthetic,
      if (jsonData != null) 'json_data': jsonData,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdSnapshotTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? rtId,
      Value<String?>? blockId,
      Value<String>? number,
      Value<String>? address,
      Value<double?>? lat,
      Value<double?>? lon,
      Value<String>? headName,
      Value<String>? waPhone,
      Value<bool>? hasDevice,
      Value<bool>? isSynthetic,
      Value<String>? jsonData,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return HouseholdSnapshotTableCompanion(
      id: id ?? this.id,
      rtId: rtId ?? this.rtId,
      blockId: blockId ?? this.blockId,
      number: number ?? this.number,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      headName: headName ?? this.headName,
      waPhone: waPhone ?? this.waPhone,
      hasDevice: hasDevice ?? this.hasDevice,
      isSynthetic: isSynthetic ?? this.isSynthetic,
      jsonData: jsonData ?? this.jsonData,
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
    if (rtId.present) {
      map['rt_id'] = Variable<String>(rtId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (headName.present) {
      map['head_name'] = Variable<String>(headName.value);
    }
    if (waPhone.present) {
      map['wa_phone'] = Variable<String>(waPhone.value);
    }
    if (hasDevice.present) {
      map['has_device'] = Variable<bool>(hasDevice.value);
    }
    if (isSynthetic.present) {
      map['is_synthetic'] = Variable<bool>(isSynthetic.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
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
    return (StringBuffer('HouseholdSnapshotTableCompanion(')
          ..write('id: $id, ')
          ..write('rtId: $rtId, ')
          ..write('blockId: $blockId, ')
          ..write('number: $number, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('headName: $headName, ')
          ..write('waPhone: $waPhone, ')
          ..write('hasDevice: $hasDevice, ')
          ..write('isSynthetic: $isSynthetic, ')
          ..write('jsonData: $jsonData, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTableTable extends OutboxTable
    with TableInfo<$OutboxTableTable, OutboxTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, kind, payload, createdAt, attempts, nextAttemptAt, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_table';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $OutboxTableTable createAlias(String alias) {
    return $OutboxTableTable(attachedDatabase, alias);
  }
}

class OutboxTableData extends DataClass implements Insertable<OutboxTableData> {
  final String id;
  final String kind;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime nextAttemptAt;
  final String status;
  const OutboxTableData(
      {required this.id,
      required this.kind,
      required this.payload,
      required this.createdAt,
      required this.attempts,
      required this.nextAttemptAt,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  OutboxTableCompanion toCompanion(bool nullToAbsent) {
    return OutboxTableCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      status: Value(status),
    );
  }

  factory OutboxTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxTableData(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'status': serializer.toJson<String>(status),
    };
  }

  OutboxTableData copyWith(
          {String? id,
          String? kind,
          String? payload,
          DateTime? createdAt,
          int? attempts,
          DateTime? nextAttemptAt,
          String? status}) =>
      OutboxTableData(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        status: status ?? this.status,
      );
  OutboxTableData copyWithCompanion(OutboxTableCompanion data) {
    return OutboxTableData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxTableData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, kind, payload, createdAt, attempts, nextAttemptAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxTableData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.status == this.status);
}

class OutboxTableCompanion extends UpdateCompanion<OutboxTableData> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<DateTime> nextAttemptAt;
  final Value<String> status;
  final Value<int> rowid;
  const OutboxTableCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxTableCompanion.insert({
    required String id,
    required String kind,
    required String payload,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    required DateTime nextAttemptAt,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        payload = Value(payload),
        createdAt = Value(createdAt),
        nextAttemptAt = Value(nextAttemptAt);
  static Insertable<OutboxTableData> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<int>? attempts,
      Value<DateTime>? nextAttemptAt,
      Value<String>? status,
      Value<int>? rowid}) {
    return OutboxTableCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxTableCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RelayPacketsTableTable extends RelayPacketsTable
    with TableInfo<$RelayPacketsTableTable, RelayPacketsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RelayPacketsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _packetBytesMeta =
      const VerificationMeta('packetBytes');
  @override
  late final GeneratedColumn<Uint8List> packetBytes =
      GeneratedColumn<Uint8List>('packet_bytes', aliasedName, false,
          type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _receivedFromMeta =
      const VerificationMeta('receivedFrom');
  @override
  late final GeneratedColumn<String> receivedFrom = GeneratedColumn<String>(
      'received_from', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _ackedMeta = const VerificationMeta('acked');
  @override
  late final GeneratedColumn<bool> acked = GeneratedColumn<bool>(
      'acked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("acked" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [key, packetBytes, receivedFrom, receivedAt, acked];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'relay_packets_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<RelayPacketsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('packet_bytes')) {
      context.handle(
          _packetBytesMeta,
          packetBytes.isAcceptableOrUnknown(
              data['packet_bytes']!, _packetBytesMeta));
    } else if (isInserting) {
      context.missing(_packetBytesMeta);
    }
    if (data.containsKey('received_from')) {
      context.handle(
          _receivedFromMeta,
          receivedFrom.isAcceptableOrUnknown(
              data['received_from']!, _receivedFromMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('acked')) {
      context.handle(
          _ackedMeta, acked.isAcceptableOrUnknown(data['acked']!, _ackedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RelayPacketsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RelayPacketsTableData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      packetBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}packet_bytes'])!,
      receivedFrom: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}received_from']),
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      acked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}acked'])!,
    );
  }

  @override
  $RelayPacketsTableTable createAlias(String alias) {
    return $RelayPacketsTableTable(attachedDatabase, alias);
  }
}

class RelayPacketsTableData extends DataClass
    implements Insertable<RelayPacketsTableData> {
  final String key;
  final Uint8List packetBytes;
  final String? receivedFrom;
  final DateTime receivedAt;
  final bool acked;
  const RelayPacketsTableData(
      {required this.key,
      required this.packetBytes,
      this.receivedFrom,
      required this.receivedAt,
      required this.acked});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['packet_bytes'] = Variable<Uint8List>(packetBytes);
    if (!nullToAbsent || receivedFrom != null) {
      map['received_from'] = Variable<String>(receivedFrom);
    }
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['acked'] = Variable<bool>(acked);
    return map;
  }

  RelayPacketsTableCompanion toCompanion(bool nullToAbsent) {
    return RelayPacketsTableCompanion(
      key: Value(key),
      packetBytes: Value(packetBytes),
      receivedFrom: receivedFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedFrom),
      receivedAt: Value(receivedAt),
      acked: Value(acked),
    );
  }

  factory RelayPacketsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RelayPacketsTableData(
      key: serializer.fromJson<String>(json['key']),
      packetBytes: serializer.fromJson<Uint8List>(json['packetBytes']),
      receivedFrom: serializer.fromJson<String?>(json['receivedFrom']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      acked: serializer.fromJson<bool>(json['acked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'packetBytes': serializer.toJson<Uint8List>(packetBytes),
      'receivedFrom': serializer.toJson<String?>(receivedFrom),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'acked': serializer.toJson<bool>(acked),
    };
  }

  RelayPacketsTableData copyWith(
          {String? key,
          Uint8List? packetBytes,
          Value<String?> receivedFrom = const Value.absent(),
          DateTime? receivedAt,
          bool? acked}) =>
      RelayPacketsTableData(
        key: key ?? this.key,
        packetBytes: packetBytes ?? this.packetBytes,
        receivedFrom:
            receivedFrom.present ? receivedFrom.value : this.receivedFrom,
        receivedAt: receivedAt ?? this.receivedAt,
        acked: acked ?? this.acked,
      );
  RelayPacketsTableData copyWithCompanion(RelayPacketsTableCompanion data) {
    return RelayPacketsTableData(
      key: data.key.present ? data.key.value : this.key,
      packetBytes:
          data.packetBytes.present ? data.packetBytes.value : this.packetBytes,
      receivedFrom: data.receivedFrom.present
          ? data.receivedFrom.value
          : this.receivedFrom,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      acked: data.acked.present ? data.acked.value : this.acked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RelayPacketsTableData(')
          ..write('key: $key, ')
          ..write('packetBytes: $packetBytes, ')
          ..write('receivedFrom: $receivedFrom, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('acked: $acked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, $driftBlobEquality.hash(packetBytes),
      receivedFrom, receivedAt, acked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RelayPacketsTableData &&
          other.key == this.key &&
          $driftBlobEquality.equals(other.packetBytes, this.packetBytes) &&
          other.receivedFrom == this.receivedFrom &&
          other.receivedAt == this.receivedAt &&
          other.acked == this.acked);
}

class RelayPacketsTableCompanion
    extends UpdateCompanion<RelayPacketsTableData> {
  final Value<String> key;
  final Value<Uint8List> packetBytes;
  final Value<String?> receivedFrom;
  final Value<DateTime> receivedAt;
  final Value<bool> acked;
  final Value<int> rowid;
  const RelayPacketsTableCompanion({
    this.key = const Value.absent(),
    this.packetBytes = const Value.absent(),
    this.receivedFrom = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.acked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RelayPacketsTableCompanion.insert({
    required String key,
    required Uint8List packetBytes,
    this.receivedFrom = const Value.absent(),
    required DateTime receivedAt,
    this.acked = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        packetBytes = Value(packetBytes),
        receivedAt = Value(receivedAt);
  static Insertable<RelayPacketsTableData> custom({
    Expression<String>? key,
    Expression<Uint8List>? packetBytes,
    Expression<String>? receivedFrom,
    Expression<DateTime>? receivedAt,
    Expression<bool>? acked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (packetBytes != null) 'packet_bytes': packetBytes,
      if (receivedFrom != null) 'received_from': receivedFrom,
      if (receivedAt != null) 'received_at': receivedAt,
      if (acked != null) 'acked': acked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RelayPacketsTableCompanion copyWith(
      {Value<String>? key,
      Value<Uint8List>? packetBytes,
      Value<String?>? receivedFrom,
      Value<DateTime>? receivedAt,
      Value<bool>? acked,
      Value<int>? rowid}) {
    return RelayPacketsTableCompanion(
      key: key ?? this.key,
      packetBytes: packetBytes ?? this.packetBytes,
      receivedFrom: receivedFrom ?? this.receivedFrom,
      receivedAt: receivedAt ?? this.receivedAt,
      acked: acked ?? this.acked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (packetBytes.present) {
      map['packet_bytes'] = Variable<Uint8List>(packetBytes.value);
    }
    if (receivedFrom.present) {
      map['received_from'] = Variable<String>(receivedFrom.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (acked.present) {
      map['acked'] = Variable<bool>(acked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RelayPacketsTableCompanion(')
          ..write('key: $key, ')
          ..write('packetBytes: $packetBytes, ')
          ..write('receivedFrom: $receivedFrom, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('acked: $acked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnouncementsTableTable extends AnnouncementsTable
    with TableInfo<$AnnouncementsTableTable, AnnouncementsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnouncementsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shortIdMeta =
      const VerificationMeta('shortId');
  @override
  late final GeneratedColumn<int> shortId = GeneratedColumn<int>(
      'short_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _textContentMeta =
      const VerificationMeta('textContent');
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
      'text_content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _signatureMeta =
      const VerificationMeta('signature');
  @override
  late final GeneratedColumn<Uint8List> signature = GeneratedColumn<Uint8List>(
      'signature', aliasedName, true,
      type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _verifiedMeta =
      const VerificationMeta('verified');
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
      'verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("verified" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns =>
      [id, shortId, level, textContent, expiresAt, signature, verified];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'announcements_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<AnnouncementsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('short_id')) {
      context.handle(_shortIdMeta,
          shortId.isAcceptableOrUnknown(data['short_id']!, _shortIdMeta));
    } else if (isInserting) {
      context.missing(_shortIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
          _textContentMeta,
          textContent.isAcceptableOrUnknown(
              data['text_content']!, _textContentMeta));
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(_signatureMeta,
          signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta));
    }
    if (data.containsKey('verified')) {
      context.handle(_verifiedMeta,
          verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnouncementsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnouncementsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shortId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}short_id'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level'])!,
      textContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text_content'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      signature: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}signature']),
      verified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}verified'])!,
    );
  }

  @override
  $AnnouncementsTableTable createAlias(String alias) {
    return $AnnouncementsTableTable(attachedDatabase, alias);
  }
}

class AnnouncementsTableData extends DataClass
    implements Insertable<AnnouncementsTableData> {
  final String id;
  final int shortId;
  final String level;
  final String textContent;
  final DateTime expiresAt;
  final Uint8List? signature;
  final bool verified;
  const AnnouncementsTableData(
      {required this.id,
      required this.shortId,
      required this.level,
      required this.textContent,
      required this.expiresAt,
      this.signature,
      required this.verified});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['short_id'] = Variable<int>(shortId);
    map['level'] = Variable<String>(level);
    map['text_content'] = Variable<String>(textContent);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || signature != null) {
      map['signature'] = Variable<Uint8List>(signature);
    }
    map['verified'] = Variable<bool>(verified);
    return map;
  }

  AnnouncementsTableCompanion toCompanion(bool nullToAbsent) {
    return AnnouncementsTableCompanion(
      id: Value(id),
      shortId: Value(shortId),
      level: Value(level),
      textContent: Value(textContent),
      expiresAt: Value(expiresAt),
      signature: signature == null && nullToAbsent
          ? const Value.absent()
          : Value(signature),
      verified: Value(verified),
    );
  }

  factory AnnouncementsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnouncementsTableData(
      id: serializer.fromJson<String>(json['id']),
      shortId: serializer.fromJson<int>(json['shortId']),
      level: serializer.fromJson<String>(json['level']),
      textContent: serializer.fromJson<String>(json['textContent']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      signature: serializer.fromJson<Uint8List?>(json['signature']),
      verified: serializer.fromJson<bool>(json['verified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shortId': serializer.toJson<int>(shortId),
      'level': serializer.toJson<String>(level),
      'textContent': serializer.toJson<String>(textContent),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'signature': serializer.toJson<Uint8List?>(signature),
      'verified': serializer.toJson<bool>(verified),
    };
  }

  AnnouncementsTableData copyWith(
          {String? id,
          int? shortId,
          String? level,
          String? textContent,
          DateTime? expiresAt,
          Value<Uint8List?> signature = const Value.absent(),
          bool? verified}) =>
      AnnouncementsTableData(
        id: id ?? this.id,
        shortId: shortId ?? this.shortId,
        level: level ?? this.level,
        textContent: textContent ?? this.textContent,
        expiresAt: expiresAt ?? this.expiresAt,
        signature: signature.present ? signature.value : this.signature,
        verified: verified ?? this.verified,
      );
  AnnouncementsTableData copyWithCompanion(AnnouncementsTableCompanion data) {
    return AnnouncementsTableData(
      id: data.id.present ? data.id.value : this.id,
      shortId: data.shortId.present ? data.shortId.value : this.shortId,
      level: data.level.present ? data.level.value : this.level,
      textContent:
          data.textContent.present ? data.textContent.value : this.textContent,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      signature: data.signature.present ? data.signature.value : this.signature,
      verified: data.verified.present ? data.verified.value : this.verified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementsTableData(')
          ..write('id: $id, ')
          ..write('shortId: $shortId, ')
          ..write('level: $level, ')
          ..write('textContent: $textContent, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('signature: $signature, ')
          ..write('verified: $verified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shortId, level, textContent, expiresAt,
      $driftBlobEquality.hash(signature), verified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnouncementsTableData &&
          other.id == this.id &&
          other.shortId == this.shortId &&
          other.level == this.level &&
          other.textContent == this.textContent &&
          other.expiresAt == this.expiresAt &&
          $driftBlobEquality.equals(other.signature, this.signature) &&
          other.verified == this.verified);
}

class AnnouncementsTableCompanion
    extends UpdateCompanion<AnnouncementsTableData> {
  final Value<String> id;
  final Value<int> shortId;
  final Value<String> level;
  final Value<String> textContent;
  final Value<DateTime> expiresAt;
  final Value<Uint8List?> signature;
  final Value<bool> verified;
  final Value<int> rowid;
  const AnnouncementsTableCompanion({
    this.id = const Value.absent(),
    this.shortId = const Value.absent(),
    this.level = const Value.absent(),
    this.textContent = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.signature = const Value.absent(),
    this.verified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnouncementsTableCompanion.insert({
    required String id,
    required int shortId,
    required String level,
    required String textContent,
    required DateTime expiresAt,
    this.signature = const Value.absent(),
    this.verified = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shortId = Value(shortId),
        level = Value(level),
        textContent = Value(textContent),
        expiresAt = Value(expiresAt);
  static Insertable<AnnouncementsTableData> custom({
    Expression<String>? id,
    Expression<int>? shortId,
    Expression<String>? level,
    Expression<String>? textContent,
    Expression<DateTime>? expiresAt,
    Expression<Uint8List>? signature,
    Expression<bool>? verified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shortId != null) 'short_id': shortId,
      if (level != null) 'level': level,
      if (textContent != null) 'text_content': textContent,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (signature != null) 'signature': signature,
      if (verified != null) 'verified': verified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnouncementsTableCompanion copyWith(
      {Value<String>? id,
      Value<int>? shortId,
      Value<String>? level,
      Value<String>? textContent,
      Value<DateTime>? expiresAt,
      Value<Uint8List?>? signature,
      Value<bool>? verified,
      Value<int>? rowid}) {
    return AnnouncementsTableCompanion(
      id: id ?? this.id,
      shortId: shortId ?? this.shortId,
      level: level ?? this.level,
      textContent: textContent ?? this.textContent,
      expiresAt: expiresAt ?? this.expiresAt,
      signature: signature ?? this.signature,
      verified: verified ?? this.verified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shortId.present) {
      map['short_id'] = Variable<int>(shortId.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (signature.present) {
      map['signature'] = Variable<Uint8List>(signature.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementsTableCompanion(')
          ..write('id: $id, ')
          ..write('shortId: $shortId, ')
          ..write('level: $level, ')
          ..write('textContent: $textContent, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('signature: $signature, ')
          ..write('verified: $verified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BeaconsKnownTableTable extends BeaconsKnownTable
    with TableInfo<$BeaconsKnownTableTable, BeaconsKnownTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeaconsKnownTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _assemblyPointIdMeta =
      const VerificationMeta('assemblyPointId');
  @override
  late final GeneratedColumn<String> assemblyPointId = GeneratedColumn<String>(
      'assembly_point_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, assemblyPointId, name, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beacons_known_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<BeaconsKnownTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('assembly_point_id')) {
      context.handle(
          _assemblyPointIdMeta,
          assemblyPointId.isAcceptableOrUnknown(
              data['assembly_point_id']!, _assemblyPointIdMeta));
    } else if (isInserting) {
      context.missing(_assemblyPointIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BeaconsKnownTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BeaconsKnownTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      assemblyPointId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}assembly_point_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at'])!,
    );
  }

  @override
  $BeaconsKnownTableTable createAlias(String alias) {
    return $BeaconsKnownTableTable(attachedDatabase, alias);
  }
}

class BeaconsKnownTableData extends DataClass
    implements Insertable<BeaconsKnownTableData> {
  final String id;
  final String assemblyPointId;
  final String name;
  final DateTime lastSeenAt;
  const BeaconsKnownTableData(
      {required this.id,
      required this.assemblyPointId,
      required this.name,
      required this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['assembly_point_id'] = Variable<String>(assemblyPointId);
    map['name'] = Variable<String>(name);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  BeaconsKnownTableCompanion toCompanion(bool nullToAbsent) {
    return BeaconsKnownTableCompanion(
      id: Value(id),
      assemblyPointId: Value(assemblyPointId),
      name: Value(name),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory BeaconsKnownTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BeaconsKnownTableData(
      id: serializer.fromJson<String>(json['id']),
      assemblyPointId: serializer.fromJson<String>(json['assemblyPointId']),
      name: serializer.fromJson<String>(json['name']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assemblyPointId': serializer.toJson<String>(assemblyPointId),
      'name': serializer.toJson<String>(name),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  BeaconsKnownTableData copyWith(
          {String? id,
          String? assemblyPointId,
          String? name,
          DateTime? lastSeenAt}) =>
      BeaconsKnownTableData(
        id: id ?? this.id,
        assemblyPointId: assemblyPointId ?? this.assemblyPointId,
        name: name ?? this.name,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
  BeaconsKnownTableData copyWithCompanion(BeaconsKnownTableCompanion data) {
    return BeaconsKnownTableData(
      id: data.id.present ? data.id.value : this.id,
      assemblyPointId: data.assemblyPointId.present
          ? data.assemblyPointId.value
          : this.assemblyPointId,
      name: data.name.present ? data.name.value : this.name,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BeaconsKnownTableData(')
          ..write('id: $id, ')
          ..write('assemblyPointId: $assemblyPointId, ')
          ..write('name: $name, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, assemblyPointId, name, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BeaconsKnownTableData &&
          other.id == this.id &&
          other.assemblyPointId == this.assemblyPointId &&
          other.name == this.name &&
          other.lastSeenAt == this.lastSeenAt);
}

class BeaconsKnownTableCompanion
    extends UpdateCompanion<BeaconsKnownTableData> {
  final Value<String> id;
  final Value<String> assemblyPointId;
  final Value<String> name;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const BeaconsKnownTableCompanion({
    this.id = const Value.absent(),
    this.assemblyPointId = const Value.absent(),
    this.name = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BeaconsKnownTableCompanion.insert({
    required String id,
    required String assemblyPointId,
    required String name,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        assemblyPointId = Value(assemblyPointId),
        name = Value(name),
        lastSeenAt = Value(lastSeenAt);
  static Insertable<BeaconsKnownTableData> custom({
    Expression<String>? id,
    Expression<String>? assemblyPointId,
    Expression<String>? name,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assemblyPointId != null) 'assembly_point_id': assemblyPointId,
      if (name != null) 'name': name,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BeaconsKnownTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? assemblyPointId,
      Value<String>? name,
      Value<DateTime>? lastSeenAt,
      Value<int>? rowid}) {
    return BeaconsKnownTableCompanion(
      id: id ?? this.id,
      assemblyPointId: assemblyPointId ?? this.assemblyPointId,
      name: name ?? this.name,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assemblyPointId.present) {
      map['assembly_point_id'] = Variable<String>(assemblyPointId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeaconsKnownTableCompanion(')
          ..write('id: $id, ')
          ..write('assemblyPointId: $assemblyPointId, ')
          ..write('name: $name, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentCacheTableTable extends ContentCacheTable
    with TableInfo<$ContentCacheTableTable, ContentCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentJsonMeta =
      const VerificationMeta('contentJson');
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
      'content_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, contentJson, version, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_cache_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ContentCacheTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
          _contentJsonMeta,
          contentJson.isAcceptableOrUnknown(
              data['content_json']!, _contentJsonMeta));
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ContentCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentCacheTableData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      contentJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_json'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $ContentCacheTableTable createAlias(String alias) {
    return $ContentCacheTableTable(attachedDatabase, alias);
  }
}

class ContentCacheTableData extends DataClass
    implements Insertable<ContentCacheTableData> {
  final String key;
  final String contentJson;
  final int version;
  final DateTime cachedAt;
  const ContentCacheTableData(
      {required this.key,
      required this.contentJson,
      required this.version,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['content_json'] = Variable<String>(contentJson);
    map['version'] = Variable<int>(version);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ContentCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ContentCacheTableCompanion(
      key: Value(key),
      contentJson: Value(contentJson),
      version: Value(version),
      cachedAt: Value(cachedAt),
    );
  }

  factory ContentCacheTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentCacheTableData(
      key: serializer.fromJson<String>(json['key']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      version: serializer.fromJson<int>(json['version']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'contentJson': serializer.toJson<String>(contentJson),
      'version': serializer.toJson<int>(version),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  ContentCacheTableData copyWith(
          {String? key,
          String? contentJson,
          int? version,
          DateTime? cachedAt}) =>
      ContentCacheTableData(
        key: key ?? this.key,
        contentJson: contentJson ?? this.contentJson,
        version: version ?? this.version,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  ContentCacheTableData copyWithCompanion(ContentCacheTableCompanion data) {
    return ContentCacheTableData(
      key: data.key.present ? data.key.value : this.key,
      contentJson:
          data.contentJson.present ? data.contentJson.value : this.contentJson,
      version: data.version.present ? data.version.value : this.version,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentCacheTableData(')
          ..write('key: $key, ')
          ..write('contentJson: $contentJson, ')
          ..write('version: $version, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, contentJson, version, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentCacheTableData &&
          other.key == this.key &&
          other.contentJson == this.contentJson &&
          other.version == this.version &&
          other.cachedAt == this.cachedAt);
}

class ContentCacheTableCompanion
    extends UpdateCompanion<ContentCacheTableData> {
  final Value<String> key;
  final Value<String> contentJson;
  final Value<int> version;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ContentCacheTableCompanion({
    this.key = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.version = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentCacheTableCompanion.insert({
    required String key,
    required String contentJson,
    required int version,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        contentJson = Value(contentJson),
        version = Value(version),
        cachedAt = Value(cachedAt);
  static Insertable<ContentCacheTableData> custom({
    Expression<String>? key,
    Expression<String>? contentJson,
    Expression<int>? version,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (contentJson != null) 'content_json': contentJson,
      if (version != null) 'version': version,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentCacheTableCompanion copyWith(
      {Value<String>? key,
      Value<String>? contentJson,
      Value<int>? version,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return ContentCacheTableCompanion(
      key: key ?? this.key,
      contentJson: contentJson ?? this.contentJson,
      version: version ?? this.version,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentCacheTableCompanion(')
          ..write('key: $key, ')
          ..write('contentJson: $contentJson, ')
          ..write('version: $version, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionTableTable sessionTable = $SessionTableTable(this);
  late final $HouseholdSnapshotTableTable householdSnapshotTable =
      $HouseholdSnapshotTableTable(this);
  late final $OutboxTableTable outboxTable = $OutboxTableTable(this);
  late final $RelayPacketsTableTable relayPacketsTable =
      $RelayPacketsTableTable(this);
  late final $AnnouncementsTableTable announcementsTable =
      $AnnouncementsTableTable(this);
  late final $BeaconsKnownTableTable beaconsKnownTable =
      $BeaconsKnownTableTable(this);
  late final $ContentCacheTableTable contentCacheTable =
      $ContentCacheTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sessionTable,
        householdSnapshotTable,
        outboxTable,
        relayPacketsTable,
        announcementsTable,
        beaconsKnownTable,
        contentCacheTable
      ];
}

typedef $$SessionTableTableCreateCompanionBuilder = SessionTableCompanion
    Function({
  required String id,
  required String accessToken,
  required String refreshToken,
  required String role,
  required String regionId,
  Value<String?> householdId,
  required String userId,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SessionTableTableUpdateCompanionBuilder = SessionTableCompanion
    Function({
  Value<String> id,
  Value<String> accessToken,
  Value<String> refreshToken,
  Value<String> role,
  Value<String> regionId,
  Value<String?> householdId,
  Value<String> userId,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SessionTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionTableTable> {
  $$SessionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get regionId => $composableBuilder(
      column: $table.regionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SessionTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionTableTable> {
  $$SessionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get regionId => $composableBuilder(
      column: $table.regionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionTableTable> {
  $$SessionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => column);

  GeneratedColumn<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get regionId =>
      $composableBuilder(column: $table.regionId, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SessionTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionTableTable,
    SessionTableData,
    $$SessionTableTableFilterComposer,
    $$SessionTableTableOrderingComposer,
    $$SessionTableTableAnnotationComposer,
    $$SessionTableTableCreateCompanionBuilder,
    $$SessionTableTableUpdateCompanionBuilder,
    (
      SessionTableData,
      BaseReferences<_$AppDatabase, $SessionTableTable, SessionTableData>
    ),
    SessionTableData,
    PrefetchHooks Function()> {
  $$SessionTableTableTableManager(_$AppDatabase db, $SessionTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> accessToken = const Value.absent(),
            Value<String> refreshToken = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> regionId = const Value.absent(),
            Value<String?> householdId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionTableCompanion(
            id: id,
            accessToken: accessToken,
            refreshToken: refreshToken,
            role: role,
            regionId: regionId,
            householdId: householdId,
            userId: userId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String accessToken,
            required String refreshToken,
            required String role,
            required String regionId,
            Value<String?> householdId = const Value.absent(),
            required String userId,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionTableCompanion.insert(
            id: id,
            accessToken: accessToken,
            refreshToken: refreshToken,
            role: role,
            regionId: regionId,
            householdId: householdId,
            userId: userId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SessionTableTable, SessionTableData>(table),
                    BaseReferences<_$AppDatabase, $SessionTableTable,
                        SessionTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionTableTable,
    SessionTableData,
    $$SessionTableTableFilterComposer,
    $$SessionTableTableOrderingComposer,
    $$SessionTableTableAnnotationComposer,
    $$SessionTableTableCreateCompanionBuilder,
    $$SessionTableTableUpdateCompanionBuilder,
    (
      SessionTableData,
      BaseReferences<_$AppDatabase, $SessionTableTable, SessionTableData>
    ),
    SessionTableData,
    PrefetchHooks Function()>;
typedef $$HouseholdSnapshotTableTableCreateCompanionBuilder
    = HouseholdSnapshotTableCompanion Function({
  required String id,
  required String rtId,
  Value<String?> blockId,
  required String number,
  required String address,
  Value<double?> lat,
  Value<double?> lon,
  required String headName,
  required String waPhone,
  Value<bool> hasDevice,
  Value<bool> isSynthetic,
  required String jsonData,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$HouseholdSnapshotTableTableUpdateCompanionBuilder
    = HouseholdSnapshotTableCompanion Function({
  Value<String> id,
  Value<String> rtId,
  Value<String?> blockId,
  Value<String> number,
  Value<String> address,
  Value<double?> lat,
  Value<double?> lon,
  Value<String> headName,
  Value<String> waPhone,
  Value<bool> hasDevice,
  Value<bool> isSynthetic,
  Value<String> jsonData,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$HouseholdSnapshotTableTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdSnapshotTableTable> {
  $$HouseholdSnapshotTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rtId => $composableBuilder(
      column: $table.rtId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blockId => $composableBuilder(
      column: $table.blockId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lon => $composableBuilder(
      column: $table.lon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headName => $composableBuilder(
      column: $table.headName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get waPhone => $composableBuilder(
      column: $table.waPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasDevice => $composableBuilder(
      column: $table.hasDevice, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynthetic => $composableBuilder(
      column: $table.isSynthetic, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$HouseholdSnapshotTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdSnapshotTableTable> {
  $$HouseholdSnapshotTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rtId => $composableBuilder(
      column: $table.rtId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blockId => $composableBuilder(
      column: $table.blockId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lon => $composableBuilder(
      column: $table.lon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headName => $composableBuilder(
      column: $table.headName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get waPhone => $composableBuilder(
      column: $table.waPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasDevice => $composableBuilder(
      column: $table.hasDevice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynthetic => $composableBuilder(
      column: $table.isSynthetic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jsonData => $composableBuilder(
      column: $table.jsonData, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$HouseholdSnapshotTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdSnapshotTableTable> {
  $$HouseholdSnapshotTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rtId =>
      $composableBuilder(column: $table.rtId, builder: (column) => column);

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<String> get headName =>
      $composableBuilder(column: $table.headName, builder: (column) => column);

  GeneratedColumn<String> get waPhone =>
      $composableBuilder(column: $table.waPhone, builder: (column) => column);

  GeneratedColumn<bool> get hasDevice =>
      $composableBuilder(column: $table.hasDevice, builder: (column) => column);

  GeneratedColumn<bool> get isSynthetic => $composableBuilder(
      column: $table.isSynthetic, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HouseholdSnapshotTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HouseholdSnapshotTableTable,
    HouseholdSnapshotTableData,
    $$HouseholdSnapshotTableTableFilterComposer,
    $$HouseholdSnapshotTableTableOrderingComposer,
    $$HouseholdSnapshotTableTableAnnotationComposer,
    $$HouseholdSnapshotTableTableCreateCompanionBuilder,
    $$HouseholdSnapshotTableTableUpdateCompanionBuilder,
    (
      HouseholdSnapshotTableData,
      BaseReferences<_$AppDatabase, $HouseholdSnapshotTableTable,
          HouseholdSnapshotTableData>
    ),
    HouseholdSnapshotTableData,
    PrefetchHooks Function()> {
  $$HouseholdSnapshotTableTableTableManager(
      _$AppDatabase db, $HouseholdSnapshotTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdSnapshotTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdSnapshotTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdSnapshotTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> rtId = const Value.absent(),
            Value<String?> blockId = const Value.absent(),
            Value<String> number = const Value.absent(),
            Value<String> address = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lon = const Value.absent(),
            Value<String> headName = const Value.absent(),
            Value<String> waPhone = const Value.absent(),
            Value<bool> hasDevice = const Value.absent(),
            Value<bool> isSynthetic = const Value.absent(),
            Value<String> jsonData = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HouseholdSnapshotTableCompanion(
            id: id,
            rtId: rtId,
            blockId: blockId,
            number: number,
            address: address,
            lat: lat,
            lon: lon,
            headName: headName,
            waPhone: waPhone,
            hasDevice: hasDevice,
            isSynthetic: isSynthetic,
            jsonData: jsonData,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String rtId,
            Value<String?> blockId = const Value.absent(),
            required String number,
            required String address,
            Value<double?> lat = const Value.absent(),
            Value<double?> lon = const Value.absent(),
            required String headName,
            required String waPhone,
            Value<bool> hasDevice = const Value.absent(),
            Value<bool> isSynthetic = const Value.absent(),
            required String jsonData,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HouseholdSnapshotTableCompanion.insert(
            id: id,
            rtId: rtId,
            blockId: blockId,
            number: number,
            address: address,
            lat: lat,
            lon: lon,
            headName: headName,
            waPhone: waPhone,
            hasDevice: hasDevice,
            isSynthetic: isSynthetic,
            jsonData: jsonData,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$HouseholdSnapshotTableTable,
                        HouseholdSnapshotTableData>(table),
                    BaseReferences<_$AppDatabase, $HouseholdSnapshotTableTable,
                        HouseholdSnapshotTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HouseholdSnapshotTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $HouseholdSnapshotTableTable,
        HouseholdSnapshotTableData,
        $$HouseholdSnapshotTableTableFilterComposer,
        $$HouseholdSnapshotTableTableOrderingComposer,
        $$HouseholdSnapshotTableTableAnnotationComposer,
        $$HouseholdSnapshotTableTableCreateCompanionBuilder,
        $$HouseholdSnapshotTableTableUpdateCompanionBuilder,
        (
          HouseholdSnapshotTableData,
          BaseReferences<_$AppDatabase, $HouseholdSnapshotTableTable,
              HouseholdSnapshotTableData>
        ),
        HouseholdSnapshotTableData,
        PrefetchHooks Function()>;
typedef $$OutboxTableTableCreateCompanionBuilder = OutboxTableCompanion
    Function({
  required String id,
  required String kind,
  required String payload,
  required DateTime createdAt,
  Value<int> attempts,
  required DateTime nextAttemptAt,
  Value<String> status,
  Value<int> rowid,
});
typedef $$OutboxTableTableUpdateCompanionBuilder = OutboxTableCompanion
    Function({
  Value<String> id,
  Value<String> kind,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<DateTime> nextAttemptAt,
  Value<String> status,
  Value<int> rowid,
});

class $$OutboxTableTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTableTable> {
  $$OutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$OutboxTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTableTable,
    OutboxTableData,
    $$OutboxTableTableFilterComposer,
    $$OutboxTableTableOrderingComposer,
    $$OutboxTableTableAnnotationComposer,
    $$OutboxTableTableCreateCompanionBuilder,
    $$OutboxTableTableUpdateCompanionBuilder,
    (
      OutboxTableData,
      BaseReferences<_$AppDatabase, $OutboxTableTable, OutboxTableData>
    ),
    OutboxTableData,
    PrefetchHooks Function()> {
  $$OutboxTableTableTableManager(_$AppDatabase db, $OutboxTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime> nextAttemptAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxTableCompanion(
            id: id,
            kind: kind,
            payload: payload,
            createdAt: createdAt,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String kind,
            required String payload,
            required DateTime createdAt,
            Value<int> attempts = const Value.absent(),
            required DateTime nextAttemptAt,
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxTableCompanion.insert(
            id: id,
            kind: kind,
            payload: payload,
            createdAt: createdAt,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxTableTable, OutboxTableData>(table),
                    BaseReferences<_$AppDatabase, $OutboxTableTable,
                        OutboxTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTableTable,
    OutboxTableData,
    $$OutboxTableTableFilterComposer,
    $$OutboxTableTableOrderingComposer,
    $$OutboxTableTableAnnotationComposer,
    $$OutboxTableTableCreateCompanionBuilder,
    $$OutboxTableTableUpdateCompanionBuilder,
    (
      OutboxTableData,
      BaseReferences<_$AppDatabase, $OutboxTableTable, OutboxTableData>
    ),
    OutboxTableData,
    PrefetchHooks Function()>;
typedef $$RelayPacketsTableTableCreateCompanionBuilder
    = RelayPacketsTableCompanion Function({
  required String key,
  required Uint8List packetBytes,
  Value<String?> receivedFrom,
  required DateTime receivedAt,
  Value<bool> acked,
  Value<int> rowid,
});
typedef $$RelayPacketsTableTableUpdateCompanionBuilder
    = RelayPacketsTableCompanion Function({
  Value<String> key,
  Value<Uint8List> packetBytes,
  Value<String?> receivedFrom,
  Value<DateTime> receivedAt,
  Value<bool> acked,
  Value<int> rowid,
});

class $$RelayPacketsTableTableFilterComposer
    extends Composer<_$AppDatabase, $RelayPacketsTableTable> {
  $$RelayPacketsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get packetBytes => $composableBuilder(
      column: $table.packetBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receivedFrom => $composableBuilder(
      column: $table.receivedFrom, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get acked => $composableBuilder(
      column: $table.acked, builder: (column) => ColumnFilters(column));
}

class $$RelayPacketsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RelayPacketsTableTable> {
  $$RelayPacketsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get packetBytes => $composableBuilder(
      column: $table.packetBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receivedFrom => $composableBuilder(
      column: $table.receivedFrom,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get acked => $composableBuilder(
      column: $table.acked, builder: (column) => ColumnOrderings(column));
}

class $$RelayPacketsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RelayPacketsTableTable> {
  $$RelayPacketsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<Uint8List> get packetBytes => $composableBuilder(
      column: $table.packetBytes, builder: (column) => column);

  GeneratedColumn<String> get receivedFrom => $composableBuilder(
      column: $table.receivedFrom, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<bool> get acked =>
      $composableBuilder(column: $table.acked, builder: (column) => column);
}

class $$RelayPacketsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RelayPacketsTableTable,
    RelayPacketsTableData,
    $$RelayPacketsTableTableFilterComposer,
    $$RelayPacketsTableTableOrderingComposer,
    $$RelayPacketsTableTableAnnotationComposer,
    $$RelayPacketsTableTableCreateCompanionBuilder,
    $$RelayPacketsTableTableUpdateCompanionBuilder,
    (
      RelayPacketsTableData,
      BaseReferences<_$AppDatabase, $RelayPacketsTableTable,
          RelayPacketsTableData>
    ),
    RelayPacketsTableData,
    PrefetchHooks Function()> {
  $$RelayPacketsTableTableTableManager(
      _$AppDatabase db, $RelayPacketsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RelayPacketsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RelayPacketsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RelayPacketsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<Uint8List> packetBytes = const Value.absent(),
            Value<String?> receivedFrom = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<bool> acked = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RelayPacketsTableCompanion(
            key: key,
            packetBytes: packetBytes,
            receivedFrom: receivedFrom,
            receivedAt: receivedAt,
            acked: acked,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required Uint8List packetBytes,
            Value<String?> receivedFrom = const Value.absent(),
            required DateTime receivedAt,
            Value<bool> acked = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RelayPacketsTableCompanion.insert(
            key: key,
            packetBytes: packetBytes,
            receivedFrom: receivedFrom,
            receivedAt: receivedAt,
            acked: acked,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RelayPacketsTableTable, RelayPacketsTableData>(
                        table),
                    BaseReferences<_$AppDatabase, $RelayPacketsTableTable,
                        RelayPacketsTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RelayPacketsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RelayPacketsTableTable,
    RelayPacketsTableData,
    $$RelayPacketsTableTableFilterComposer,
    $$RelayPacketsTableTableOrderingComposer,
    $$RelayPacketsTableTableAnnotationComposer,
    $$RelayPacketsTableTableCreateCompanionBuilder,
    $$RelayPacketsTableTableUpdateCompanionBuilder,
    (
      RelayPacketsTableData,
      BaseReferences<_$AppDatabase, $RelayPacketsTableTable,
          RelayPacketsTableData>
    ),
    RelayPacketsTableData,
    PrefetchHooks Function()>;
typedef $$AnnouncementsTableTableCreateCompanionBuilder
    = AnnouncementsTableCompanion Function({
  required String id,
  required int shortId,
  required String level,
  required String textContent,
  required DateTime expiresAt,
  Value<Uint8List?> signature,
  Value<bool> verified,
  Value<int> rowid,
});
typedef $$AnnouncementsTableTableUpdateCompanionBuilder
    = AnnouncementsTableCompanion Function({
  Value<String> id,
  Value<int> shortId,
  Value<String> level,
  Value<String> textContent,
  Value<DateTime> expiresAt,
  Value<Uint8List?> signature,
  Value<bool> verified,
  Value<int> rowid,
});

class $$AnnouncementsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AnnouncementsTableTable> {
  $$AnnouncementsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shortId => $composableBuilder(
      column: $table.shortId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get textContent => $composableBuilder(
      column: $table.textContent, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get signature => $composableBuilder(
      column: $table.signature, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get verified => $composableBuilder(
      column: $table.verified, builder: (column) => ColumnFilters(column));
}

class $$AnnouncementsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnouncementsTableTable> {
  $$AnnouncementsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shortId => $composableBuilder(
      column: $table.shortId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get textContent => $composableBuilder(
      column: $table.textContent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get signature => $composableBuilder(
      column: $table.signature, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get verified => $composableBuilder(
      column: $table.verified, builder: (column) => ColumnOrderings(column));
}

class $$AnnouncementsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnouncementsTableTable> {
  $$AnnouncementsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get shortId =>
      $composableBuilder(column: $table.shortId, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
      column: $table.textContent, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);
}

class $$AnnouncementsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnouncementsTableTable,
    AnnouncementsTableData,
    $$AnnouncementsTableTableFilterComposer,
    $$AnnouncementsTableTableOrderingComposer,
    $$AnnouncementsTableTableAnnotationComposer,
    $$AnnouncementsTableTableCreateCompanionBuilder,
    $$AnnouncementsTableTableUpdateCompanionBuilder,
    (
      AnnouncementsTableData,
      BaseReferences<_$AppDatabase, $AnnouncementsTableTable,
          AnnouncementsTableData>
    ),
    AnnouncementsTableData,
    PrefetchHooks Function()> {
  $$AnnouncementsTableTableTableManager(
      _$AppDatabase db, $AnnouncementsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnouncementsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnouncementsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnouncementsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> shortId = const Value.absent(),
            Value<String> level = const Value.absent(),
            Value<String> textContent = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<Uint8List?> signature = const Value.absent(),
            Value<bool> verified = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsTableCompanion(
            id: id,
            shortId: shortId,
            level: level,
            textContent: textContent,
            expiresAt: expiresAt,
            signature: signature,
            verified: verified,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int shortId,
            required String level,
            required String textContent,
            required DateTime expiresAt,
            Value<Uint8List?> signature = const Value.absent(),
            Value<bool> verified = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsTableCompanion.insert(
            id: id,
            shortId: shortId,
            level: level,
            textContent: textContent,
            expiresAt: expiresAt,
            signature: signature,
            verified: verified,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AnnouncementsTableTable,
                        AnnouncementsTableData>(table),
                    BaseReferences<_$AppDatabase, $AnnouncementsTableTable,
                        AnnouncementsTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnnouncementsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnouncementsTableTable,
    AnnouncementsTableData,
    $$AnnouncementsTableTableFilterComposer,
    $$AnnouncementsTableTableOrderingComposer,
    $$AnnouncementsTableTableAnnotationComposer,
    $$AnnouncementsTableTableCreateCompanionBuilder,
    $$AnnouncementsTableTableUpdateCompanionBuilder,
    (
      AnnouncementsTableData,
      BaseReferences<_$AppDatabase, $AnnouncementsTableTable,
          AnnouncementsTableData>
    ),
    AnnouncementsTableData,
    PrefetchHooks Function()>;
typedef $$BeaconsKnownTableTableCreateCompanionBuilder
    = BeaconsKnownTableCompanion Function({
  required String id,
  required String assemblyPointId,
  required String name,
  required DateTime lastSeenAt,
  Value<int> rowid,
});
typedef $$BeaconsKnownTableTableUpdateCompanionBuilder
    = BeaconsKnownTableCompanion Function({
  Value<String> id,
  Value<String> assemblyPointId,
  Value<String> name,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});

class $$BeaconsKnownTableTableFilterComposer
    extends Composer<_$AppDatabase, $BeaconsKnownTableTable> {
  $$BeaconsKnownTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assemblyPointId => $composableBuilder(
      column: $table.assemblyPointId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));
}

class $$BeaconsKnownTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BeaconsKnownTableTable> {
  $$BeaconsKnownTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assemblyPointId => $composableBuilder(
      column: $table.assemblyPointId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $$BeaconsKnownTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeaconsKnownTableTable> {
  $$BeaconsKnownTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assemblyPointId => $composableBuilder(
      column: $table.assemblyPointId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);
}

class $$BeaconsKnownTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BeaconsKnownTableTable,
    BeaconsKnownTableData,
    $$BeaconsKnownTableTableFilterComposer,
    $$BeaconsKnownTableTableOrderingComposer,
    $$BeaconsKnownTableTableAnnotationComposer,
    $$BeaconsKnownTableTableCreateCompanionBuilder,
    $$BeaconsKnownTableTableUpdateCompanionBuilder,
    (
      BeaconsKnownTableData,
      BaseReferences<_$AppDatabase, $BeaconsKnownTableTable,
          BeaconsKnownTableData>
    ),
    BeaconsKnownTableData,
    PrefetchHooks Function()> {
  $$BeaconsKnownTableTableTableManager(
      _$AppDatabase db, $BeaconsKnownTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BeaconsKnownTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BeaconsKnownTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BeaconsKnownTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> assemblyPointId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BeaconsKnownTableCompanion(
            id: id,
            assemblyPointId: assemblyPointId,
            name: name,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String assemblyPointId,
            required String name,
            required DateTime lastSeenAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BeaconsKnownTableCompanion.insert(
            id: id,
            assemblyPointId: assemblyPointId,
            name: name,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$BeaconsKnownTableTable, BeaconsKnownTableData>(
                        table),
                    BaseReferences<_$AppDatabase, $BeaconsKnownTableTable,
                        BeaconsKnownTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BeaconsKnownTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BeaconsKnownTableTable,
    BeaconsKnownTableData,
    $$BeaconsKnownTableTableFilterComposer,
    $$BeaconsKnownTableTableOrderingComposer,
    $$BeaconsKnownTableTableAnnotationComposer,
    $$BeaconsKnownTableTableCreateCompanionBuilder,
    $$BeaconsKnownTableTableUpdateCompanionBuilder,
    (
      BeaconsKnownTableData,
      BaseReferences<_$AppDatabase, $BeaconsKnownTableTable,
          BeaconsKnownTableData>
    ),
    BeaconsKnownTableData,
    PrefetchHooks Function()>;
typedef $$ContentCacheTableTableCreateCompanionBuilder
    = ContentCacheTableCompanion Function({
  required String key,
  required String contentJson,
  required int version,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$ContentCacheTableTableUpdateCompanionBuilder
    = ContentCacheTableCompanion Function({
  Value<String> key,
  Value<String> contentJson,
  Value<int> version,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$ContentCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $ContentCacheTableTable> {
  $$ContentCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentJson => $composableBuilder(
      column: $table.contentJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$ContentCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentCacheTableTable> {
  $$ContentCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentJson => $composableBuilder(
      column: $table.contentJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$ContentCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentCacheTableTable> {
  $$ContentCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
      column: $table.contentJson, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ContentCacheTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentCacheTableTable,
    ContentCacheTableData,
    $$ContentCacheTableTableFilterComposer,
    $$ContentCacheTableTableOrderingComposer,
    $$ContentCacheTableTableAnnotationComposer,
    $$ContentCacheTableTableCreateCompanionBuilder,
    $$ContentCacheTableTableUpdateCompanionBuilder,
    (
      ContentCacheTableData,
      BaseReferences<_$AppDatabase, $ContentCacheTableTable,
          ContentCacheTableData>
    ),
    ContentCacheTableData,
    PrefetchHooks Function()> {
  $$ContentCacheTableTableTableManager(
      _$AppDatabase db, $ContentCacheTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentCacheTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> contentJson = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentCacheTableCompanion(
            key: key,
            contentJson: contentJson,
            version: version,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String contentJson,
            required int version,
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentCacheTableCompanion.insert(
            key: key,
            contentJson: contentJson,
            version: version,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ContentCacheTableTable, ContentCacheTableData>(
                        table),
                    BaseReferences<_$AppDatabase, $ContentCacheTableTable,
                        ContentCacheTableData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentCacheTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentCacheTableTable,
    ContentCacheTableData,
    $$ContentCacheTableTableFilterComposer,
    $$ContentCacheTableTableOrderingComposer,
    $$ContentCacheTableTableAnnotationComposer,
    $$ContentCacheTableTableCreateCompanionBuilder,
    $$ContentCacheTableTableUpdateCompanionBuilder,
    (
      ContentCacheTableData,
      BaseReferences<_$AppDatabase, $ContentCacheTableTable,
          ContentCacheTableData>
    ),
    ContentCacheTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db, _db.sessionTable);
  $$HouseholdSnapshotTableTableTableManager get householdSnapshotTable =>
      $$HouseholdSnapshotTableTableTableManager(
          _db, _db.householdSnapshotTable);
  $$OutboxTableTableTableManager get outboxTable =>
      $$OutboxTableTableTableManager(_db, _db.outboxTable);
  $$RelayPacketsTableTableTableManager get relayPacketsTable =>
      $$RelayPacketsTableTableTableManager(_db, _db.relayPacketsTable);
  $$AnnouncementsTableTableTableManager get announcementsTable =>
      $$AnnouncementsTableTableTableManager(_db, _db.announcementsTable);
  $$BeaconsKnownTableTableTableManager get beaconsKnownTable =>
      $$BeaconsKnownTableTableTableManager(_db, _db.beaconsKnownTable);
  $$ContentCacheTableTableTableManager get contentCacheTable =>
      $$ContentCacheTableTableTableManager(_db, _db.contentCacheTable);
}
