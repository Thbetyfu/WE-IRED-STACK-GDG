import 'dart:convert';
import 'package:drift/drift.dart';
import '../models/household.dart';
import '../models/report.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  SessionTable,
  HouseholdSnapshotTable,
  OutboxTable,
  RelayPacketsTable,
  AnnouncementsTable,
  BeaconsKnownTable,
  ContentCacheTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  // --- Transactional Outbox Methods (SDD 8.1, FR-SYNC-01) ---

  /// Enqueues a report and updates local household snapshot in a single atomic transaction.
  Future<void> enqueueReportTransactional({
    required Report report,
    Household? householdUpdate,
  }) {
    return transaction(() async {
      // 1. If household snapshot is provided, update snapshot
      if (householdUpdate != null) {
        await into(householdSnapshotTable).insertOnConflictUpdate(
          HouseholdSnapshotTableCompanion.insert(
            id: householdUpdate.id,
            rtId: householdUpdate.rtId,
            blockId: Value(householdUpdate.blockId),
            number: householdUpdate.number,
            address: householdUpdate.address,
            lat: Value(householdUpdate.lat),
            lon: Value(householdUpdate.lon),
            headName: householdUpdate.headName,
            waPhone: householdUpdate.waPhone,
            hasDevice: Value(householdUpdate.hasDevice),
            isSynthetic: Value(householdUpdate.isSynthetic),
            jsonData: jsonEncode(householdUpdate.toJson()),
            updatedAt: DateTime.now(),
          ),
        );
      }

      // 2. Insert into outbox table
      await into(outboxTable).insertOnConflictUpdate(
        OutboxTableCompanion.insert(
          id: report.id,
          kind: 'report',
          payload: jsonEncode(report.toJson()),
          createdAt: DateTime.now(),
          attempts: const Value(0),
          nextAttemptAt: DateTime.now(),
          status: const Value('pending'),
        ),
      );
    });
  }

  /// Fetches pending outbox items ready for transmission (up to batch size).
  Future<List<OutboxTableData>> fetchPendingOutboxItems({int limit = 50}) {
    final now = DateTime.now();
    return (select(outboxTable)
          ..where((t) => t.status.equals('pending') & t.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])
          ..limit(limit))
        .get();
  }

  /// Marks an outbox item as successfully transmitted.
  Future<void> markOutboxItemCompleted(String id) {
    return (delete(outboxTable)..where((t) => t.id.equals(id))).go();
  }

  /// Reschedules an outbox item with exponential backoff on failure.
  Future<void> rescheduleOutboxItem({
    required String id,
    required DateTime nextAttemptAt,
    required int currentAttempts,
  }) {
    return (update(outboxTable)..where((t) => t.id.equals(id))).write(
      OutboxTableCompanion(
        attempts: Value(currentAttempts + 1),
        nextAttemptAt: Value(nextAttemptAt),
        status: const Value('pending'),
      ),
    );
  }

  // --- Snapshot Methods ---
  Future<void> saveHouseholdSnapshot(Household household) {
    return into(householdSnapshotTable).insertOnConflictUpdate(
      HouseholdSnapshotTableCompanion.insert(
        id: household.id,
        rtId: household.rtId,
        blockId: Value(household.blockId),
        number: household.number,
        address: household.address,
        lat: Value(household.lat),
        lon: Value(household.lon),
        headName: household.headName,
        waPhone: household.waPhone,
        hasDevice: Value(household.hasDevice),
        isSynthetic: Value(household.isSynthetic),
        jsonData: jsonEncode(household.toJson()),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<Household?> getHouseholdSnapshot(String id) async {
    final row = await (select(householdSnapshotTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return Household.fromJson(jsonDecode(row.jsonData) as Map<String, dynamic>);
  }
}
