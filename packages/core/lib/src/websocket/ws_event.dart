class WsEvent {
  final int eventId;
  final String event;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const WsEvent({
    required this.eventId,
    required this.event,
    required this.payload,
    required this.timestamp,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      eventId: json['event_id'] as int? ?? 0,
      event: json['event'] as String? ?? 'unknown',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'event': event,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'WsEvent(id: $eventId, event: $event, payload: $payload)';
}
