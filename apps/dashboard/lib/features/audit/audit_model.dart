class AuditLogItem {
  final String id;
  final String regionId;
  final String userId;
  final String action;
  final String entity;
  final String entityId;
  final Map<String, dynamic> details;
  final String ipAddress;
  final String userAgent;
  final DateTime createdAt;

  const AuditLogItem({
    required this.id,
    required this.regionId,
    required this.userId,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.details,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id'] as String? ?? '',
      regionId: json['region_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? 'system',
      action: json['action'] as String? ?? '',
      entity: json['entity'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      ipAddress: json['ip_address'] as String? ?? '127.0.0.1',
      userAgent: json['user_agent'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
