import 'dart:async';
import 'dart:convert';
import '../api/api_client.dart';
import '../models/report.dart';
import 'endpoint_detector.dart';
import 'outbox_store.dart';
import 'retry_policy.dart';

class OutboxWorker {
  final OutboxStore database;
  final ApiClient apiClient;
  final EndpointDetector endpointDetector;
  final Duration pollInterval;
  final int batchSize;

  Timer? _timer;
  bool _isProcessing = false;
  bool _running = false;

  OutboxWorker({
    required this.database,
    required this.apiClient,
    required this.endpointDetector,
    this.pollInterval = const Duration(seconds: 2),
    this.batchSize = 50, // FR-SYNC-02: batch <= 50
  });

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;

    // Start background endpoint detection every 3 seconds
    endpointDetector.start();

    // Trigger immediate outbox process attempt
    processPendingOutbox();

    _timer = Timer.periodic(pollInterval, (_) {
      processPendingOutbox();
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    endpointDetector.stop();
  }

  Future<void> processPendingOutbox() async {
    if (_isProcessing || !_running) return;

    // Verify active connection exists (Cloud or Posko)
    if (!endpointDetector.currentEndpoint.isHealthy) {
      return;
    }

    _isProcessing = true;
    try {
      final items = await database.fetchPendingOutboxItems(limit: batchSize);
      if (items.isEmpty) return;

      final reports = <Report>[];
      final itemMap = <String, OutboxItem>{};

      for (final item in items) {
        if (item.kind == 'report') {
          try {
            final json = jsonDecode(item.payload) as Map<String, dynamic>;
            final r = Report.fromJson(json);
            reports.add(r);
            itemMap[r.id] = item;
          } catch (_) {
            // Malformed local report payload, complete and remove to prevent poison pill
            await database.markOutboxItemCompleted(item.id);
          }
        }
      }

      if (reports.isEmpty) return;

      try {
        final response = await apiClient.syncReports(reports);
        final results = response['results'] as List<dynamic>? ?? [];

        if (results.isNotEmpty) {
          for (final res in results) {
            if (res is Map<String, dynamic>) {
              final id = res['id'] as String?;
              final status = res['status'] as String?;

              if (id != null && itemMap.containsKey(id)) {
                final item = itemMap[id]!;
                if (status == 'accepted' || status == 'duplicate') {
                  await database.markOutboxItemCompleted(id);
                } else {
                  final nextAttempt = RetryPolicy.nextAttemptDateTime(item.attempts);
                  await database.rescheduleOutboxItem(
                    id: id,
                    nextAttemptAt: nextAttempt,
                    currentAttempts: item.attempts,
                  );
                }
              }
            }
          }
        } else {
          // If response does not have per-item result array, mark all accepted
          for (final r in reports) {
            await database.markOutboxItemCompleted(r.id);
          }
        }
      } catch (_) {
        // Transmission failure: reschedule entire batch with exponential backoff (FR-SYNC-03)
        for (final item in items) {
          final nextAttempt = RetryPolicy.nextAttemptDateTime(item.attempts);
          await database.rescheduleOutboxItem(
            id: item.id,
            nextAttemptAt: nextAttempt,
            currentAttempts: item.attempts,
          );
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
}
