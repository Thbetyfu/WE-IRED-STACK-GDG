class PoskoStatusModel {
  final String mode; // "cloud" | "posko"
  final String poskoId;
  final int cursor;
  final int conflictsCount;
  final int pendingConflicts;
  final String status;
  final DateTime? lastSyncAt;

  const PoskoStatusModel({
    required this.mode,
    required this.poskoId,
    required this.cursor,
    required this.conflictsCount,
    required this.pendingConflicts,
    required this.status,
    this.lastSyncAt,
  });

  factory PoskoStatusModel.fromJson(Map<String, dynamic> json) {
    return PoskoStatusModel(
      mode: json['mode'] as String? ?? 'posko',
      poskoId: json['posko_id'] as String? ?? 'posko-lokal-01',
      cursor: (json['cursor'] as num?)?.toInt() ?? 0,
      conflictsCount: (json['conflicts_count'] as num?)?.toInt() ?? 0,
      pendingConflicts: (json['pending_conflicts'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'operational',
      lastSyncAt: json['last_sync_at'] != null ? DateTime.tryParse(json['last_sync_at'].toString()) : null,
    );
  }
}

class SyncConflictModel {
  final String id;
  final String regionId;
  final String poskoId;
  final String entity;
  final String entityId;
  final Map<String, dynamic> cloudVersion;
  final Map<String, dynamic> poskoVersion;
  final String status; // unresolved, resolved, ignored
  final DateTime createdAt;

  const SyncConflictModel({
    required this.id,
    required this.regionId,
    required this.poskoId,
    required this.entity,
    required this.entityId,
    required this.cloudVersion,
    required this.poskoVersion,
    required this.status,
    required this.createdAt,
  });

  factory SyncConflictModel.fromJson(Map<String, dynamic> json) {
    return SyncConflictModel(
      id: json['id'] as String? ?? '',
      regionId: json['region_id'] as String? ?? '',
      poskoId: json['posko_id'] as String? ?? '',
      entity: json['entity'] as String? ?? 'household',
      entityId: json['entity_id'] as String? ?? '',
      cloudVersion: (json['cloud_version'] as Map<String, dynamic>?) ?? {},
      poskoVersion: (json['posko_version'] as Map<String, dynamic>?) ?? {},
      status: json['status'] as String? ?? 'unresolved',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PoskoQRConfigModel {
  final String poskoId;
  final String rtId;
  final String endpointUrl;
  final bool ssl;
  final String certFingerprint;
  final DateTime generatedAt;

  const PoskoQRConfigModel({
    required this.poskoId,
    required this.rtId,
    required this.endpointUrl,
    required this.ssl,
    required this.certFingerprint,
    required this.generatedAt,
  });

  factory PoskoQRConfigModel.fromJson(Map<String, dynamic> json) {
    return PoskoQRConfigModel(
      poskoId: json['posko_id'] as String? ?? 'posko-lokal-01',
      rtId: json['rt_id'] as String? ?? 'rt-01',
      endpointUrl: json['endpoint_url'] as String? ?? 'https://192.168.4.1:8080/api/v1',
      ssl: json['ssl'] as bool? ?? true,
      certFingerprint: json['cert_fingerprint'] as String? ?? 'E3:B0:C4:42:98:FC:1C:14:9A:FB:F4:C8:99:6F:B9:24:27:AE:41:E4:64:9B:93:4C:A4:95:99:1B:78:52:B8:55',
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SnapshotImportResult {
  final String status;
  final String rtId;
  final int householdsCount;
  final int volunteersCount;
  final int lastCursor;

  const SnapshotImportResult({
    required this.status,
    required this.rtId,
    required this.householdsCount,
    required this.volunteersCount,
    required this.lastCursor,
  });

  factory SnapshotImportResult.fromJson(Map<String, dynamic> json) {
    return SnapshotImportResult(
      status: json['status'] as String? ?? 'imported',
      rtId: json['rt_id'] as String? ?? '',
      householdsCount: (json['households'] as num?)?.toInt() ?? 0,
      volunteersCount: (json['volunteers'] as num?)?.toInt() ?? 0,
      lastCursor: (json['last_cursor'] as num?)?.toInt() ?? 0,
    );
  }
}
