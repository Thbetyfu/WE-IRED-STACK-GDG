import 'package:drift/drift.dart';

// SDD 5.3: Drift Tables for Local Application Database

class SessionTable extends Table {
  TextColumn get id => text()(); // primary key e.g. 'active_session'
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  TextColumn get role => text()();
  TextColumn get regionId => text()();
  TextColumn get householdId => text().nullable()();
  TextColumn get userId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class HouseholdSnapshotTable extends Table {
  TextColumn get id => text()(); // household_id
  TextColumn get rtId => text()();
  TextColumn get blockId => text().nullable()();
  TextColumn get number => text()();
  TextColumn get address => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  TextColumn get headName => text()();
  TextColumn get waPhone => text()();
  BoolColumn get hasDevice => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynthetic => boolean().withDefault(const Constant(false))();
  TextColumn get jsonData => text()(); // full household json with members & consents
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxTable extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get kind => text()(); // report | proxy_report | consent | etc
  TextColumn get payload => text()(); // serialized JSON payload
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending | in_progress | completed | failed

  @override
  Set<Column> get primaryKey => {id};
}

class RelayPacketsTable extends Table {
  TextColumn get key => text()(); // household_short_id:incident_short_id:seq
  BlobColumn get packetBytes => blob()();
  TextColumn get receivedFrom => text().nullable()(); // peer node short id
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get acked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {key};
}

class AnnouncementsTable extends Table {
  TextColumn get id => text()();
  IntColumn get shortId => integer()();
  TextColumn get level => text()(); // info | penting | darurat
  TextColumn get textContent => text()();
  DateTimeColumn get expiresAt => dateTime()();
  BlobColumn get signature => blob().nullable()();
  BoolColumn get verified => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class BeaconsKnownTable extends Table {
  TextColumn get id => text()(); // device_id
  TextColumn get assemblyPointId => text()();
  TextColumn get name => text()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ContentCacheTable extends Table {
  TextColumn get key => text()(); // module_id or topic
  TextColumn get contentJson => text()();
  IntColumn get version => integer()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
