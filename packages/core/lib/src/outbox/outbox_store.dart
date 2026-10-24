class OutboxItem {
  final String id;
  final String kind; // report | proxy_report | consent
  final String payload; // serialized JSON
  final DateTime createdAt;
  final int attempts;
  final DateTime nextAttemptAt;
  final String status; // pending | in_progress | completed | failed

  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    required this.nextAttemptAt,
    this.status = 'pending',
  });

  OutboxItem copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    String? status,
  }) {
    return OutboxItem(
      id: id,
      kind: kind,
      payload: payload,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
    );
  }
}

/// Abstract contract for transactional outbox persistence (SDD 8.1, FR-SYNC-01)
abstract class OutboxStore {
  Future<List<OutboxItem>> fetchPendingOutboxItems({int limit = 50});
  Future<void> markOutboxItemCompleted(String id);
  Future<void> rescheduleOutboxItem({
    required String id,
    required DateTime nextAttemptAt,
    required int currentAttempts,
  });
}

/// In-memory implementation of OutboxStore for unit testing
class MemoryOutboxStore implements OutboxStore {
  final Map<String, OutboxItem> _items = {};

  void enqueue(OutboxItem item) {
    _items[item.id] = item;
  }

  OutboxItem? getItem(String id) => _items[id];

  int get count => _items.length;

  @override
  Future<List<OutboxItem>> fetchPendingOutboxItems({int limit = 50}) async {
    final now = DateTime.now();
    final pending = _items.values
        .where((i) => i.status == 'pending' && !i.nextAttemptAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return pending.take(limit).toList();
  }

  @override
  Future<void> markOutboxItemCompleted(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> rescheduleOutboxItem({
    required String id,
    required DateTime nextAttemptAt,
    required int currentAttempts,
  }) async {
    final item = _items[id];
    if (item != null) {
      _items[id] = item.copyWith(
        attempts: currentAttempts + 1,
        nextAttemptAt: nextAttemptAt,
        status: 'pending',
      );
    }
  }
}
