import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  group('OutboxWorker Tests (FR-SYNC-01..04, NFR-REL-01)', () {
    late MemoryOutboxStore outboxStore;
    late MemorySessionStorage sessionStorage;

    setUp(() {
      outboxStore = MemoryOutboxStore();
      sessionStorage = MemorySessionStorage();
    });

    Report createSampleReport(String id, int seq) {
      return Report(
        id: id,
        incidentId: 'inc-01',
        householdId: 'hh-01',
        seq: seq,
        status: ReportStatus.aman,
        channel: 'outbox',
        deviceTime: DateTime.now(),
      );
    }

    test('Offline condition: Does not send reports when endpoint is unhealthy', () async {
      // Enqueue report
      final report = createSampleReport('rep-offline-1', 1);
      outboxStore.enqueue(
        OutboxItem(
          id: report.id,
          kind: 'report',
          payload: jsonEncode(report.toJson()),
          createdAt: DateTime.now(),
          nextAttemptAt: DateTime.now(),
        ),
      );

      final detector = EndpointDetector(
        cloudUrl: 'https://api.we-ired.id',
        dio: Dio()..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
            },
          ),
        ),
      );
      await detector.checkEndpoints();
      expect(detector.currentEndpoint.isHealthy, isFalse);

      final apiClient = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
      );

      final worker = OutboxWorker(
        database: outboxStore,
        apiClient: apiClient,
        endpointDetector: detector,
      );

      // Trigger processing while offline
      await worker.processPendingOutbox();

      // Report must still remain intact in outbox (NFR-REL-01: no lost reports)
      expect(outboxStore.count, equals(1));
      expect(outboxStore.getItem('rep-offline-1'), isNotNull);
    });

    test('Network recovery & Success: Transmits batch and completes items', () async {
      final report = createSampleReport('rep-success-1', 1);
      outboxStore.enqueue(
        OutboxItem(
          id: report.id,
          kind: 'report',
          payload: jsonEncode(report.toJson()),
          createdAt: DateTime.now(),
          nextAttemptAt: DateTime.now(),
        ),
      );

      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == Endpoints.healthz) {
              handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'status': 'ok'}));
            } else if (options.path == Endpoints.syncReports) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'results': [
                      {'id': 'rep-success-1', 'status': 'accepted'}
                    ]
                  },
                ),
              );
            }
          },
        ),
      );

      final detector = EndpointDetector(cloudUrl: 'https://api.we-ired.id', dio: mockDio);
      await detector.checkEndpoints();
      expect(detector.currentEndpoint.isHealthy, isTrue);

      final apiClient = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
        customDio: mockDio,
      );

      final worker = OutboxWorker(
        database: outboxStore,
        apiClient: apiClient,
        endpointDetector: detector,
      );

      await worker.processPendingOutbox();

      // Successfully transmitted report is marked completed and removed from outbox
      expect(outboxStore.count, equals(0));
    });

    test('Server failure: Does NOT delete failed items; reschedules with exponential backoff', () async {
      final report = createSampleReport('rep-fail-1', 1);
      outboxStore.enqueue(
        OutboxItem(
          id: report.id,
          kind: 'report',
          payload: jsonEncode(report.toJson()),
          createdAt: DateTime.now(),
          attempts: 0,
          nextAttemptAt: DateTime.now(),
        ),
      );

      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == Endpoints.healthz) {
              handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'status': 'ok'}));
            } else if (options.path == Endpoints.syncReports) {
              // Server returns internal error (500)
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(requestOptions: options, statusCode: 500),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          },
        ),
      );

      final detector = EndpointDetector(cloudUrl: 'https://api.we-ired.id', dio: mockDio);
      await detector.checkEndpoints();

      final apiClient = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
        customDio: mockDio,
      );

      final worker = OutboxWorker(
        database: outboxStore,
        apiClient: apiClient,
        endpointDetector: detector,
      );

      await worker.processPendingOutbox();

      // Item must NOT be deleted
      expect(outboxStore.count, equals(1));
      final item = outboxStore.getItem('rep-fail-1');
      expect(item, isNotNull);
      expect(item!.attempts, equals(1));
      expect(item.nextAttemptAt.isAfter(DateTime.now()), isTrue);
    });

    test('Duplicate status handling: Safely completes item without server duplication', () async {
      final report = createSampleReport('rep-dup-1', 1);
      outboxStore.enqueue(
        OutboxItem(
          id: report.id,
          kind: 'report',
          payload: jsonEncode(report.toJson()),
          createdAt: DateTime.now(),
          nextAttemptAt: DateTime.now(),
        ),
      );

      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == Endpoints.healthz) {
              handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'status': 'ok'}));
            } else if (options.path == Endpoints.syncReports) {
              // Server reports report was already recorded (idempotent duplicate)
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'results': [
                      {'id': 'rep-dup-1', 'status': 'duplicate'}
                    ]
                  },
                ),
              );
            }
          },
        ),
      );

      final detector = EndpointDetector(cloudUrl: 'https://api.we-ired.id', dio: mockDio);
      await detector.checkEndpoints();

      final apiClient = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
        customDio: mockDio,
      );

      final worker = OutboxWorker(
        database: outboxStore,
        apiClient: apiClient,
        endpointDetector: detector,
      );

      await worker.processPendingOutbox();

      // Duplicate report acknowledged by server is safely purged from local queue
      expect(outboxStore.count, equals(0));
    });
  });
}
