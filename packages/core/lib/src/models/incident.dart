enum HazardType {
  banjir,
  longsor,
  gempa,
  kebakaran,
  lainnya;

  static HazardType fromString(String str) {
    switch (str.toLowerCase()) {
      case 'banjir':
        return HazardType.banjir;
      case 'longsor':
        return HazardType.longsor;
      case 'gempa':
        return HazardType.gempa;
      case 'kebakaran':
        return HazardType.kebakaran;
      default:
        return HazardType.lainnya;
    }
  }
}

enum IncidentMode {
  nyata,
  latihan;

  static IncidentMode fromString(String str) {
    return str.toLowerCase() == 'latihan' ? IncidentMode.latihan : IncidentMode.nyata;
  }
}

enum IncidentStatus {
  aktif,
  selesai;

  static IncidentStatus fromString(String str) {
    return str.toLowerCase() == 'selesai' ? IncidentStatus.selesai : IncidentStatus.aktif;
  }
}

class Incident {
  final String id;
  final String rtId;
  final int shortId; // uint32 identifier for BLE packet
  final HazardType hazard;
  final IncidentMode mode;
  final List<String> scopeBlockIds;
  final String message;
  final String startedBy;
  final DateTime startedAt;
  final DateTime? endedAt;
  final IncidentStatus status;
  final Map<String, dynamic>? metrics;

  const Incident({
    required this.id,
    required this.rtId,
    required this.shortId,
    required this.hazard,
    required this.mode,
    this.scopeBlockIds = const [],
    required this.message,
    required this.startedBy,
    required this.startedAt,
    this.endedAt,
    this.status = IncidentStatus.aktif,
    this.metrics,
  });

  bool get isActive => status == IncidentStatus.aktif;
  bool get isDrill => mode == IncidentMode.latihan;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      rtId: json['rt_id'] as String,
      shortId: json['short_id'] as int,
      hazard: HazardType.fromString(json['hazard'] as String),
      mode: IncidentMode.fromString(json['mode'] as String),
      scopeBlockIds: (json['scope_block_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      message: json['message'] as String? ?? '',
      startedBy: json['started_by'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      status: IncidentStatus.fromString(json['status'] as String),
      metrics: json['metrics'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rt_id': rtId,
      'short_id': shortId,
      'hazard': hazard.name,
      'mode': mode.name,
      'scope_block_ids': scopeBlockIds,
      'message': message,
      'started_by': startedBy,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      'status': status.name,
      if (metrics != null) 'metrics': metrics,
    };
  }
}

class DrillComparisonMetric {
  final String incidentId;
  final HazardType hazard;
  final DateTime startedAt;
  final int t90;
  final int t100;
  final double vulnReached30;
  final double offlineDelivery;

  const DrillComparisonMetric({
    required this.incidentId,
    required this.hazard,
    required this.startedAt,
    required this.t90,
    required this.t100,
    required this.vulnReached30,
    required this.offlineDelivery,
  });

  factory DrillComparisonMetric.fromJson(Map<String, dynamic> json) {
    return DrillComparisonMetric(
      incidentId: json['incident_id'] as String,
      hazard: HazardType.fromString(json['hazard'] as String),
      startedAt: DateTime.parse(json['started_at'] as String),
      t90: (json['t90'] as num?)?.toInt() ?? 0,
      t100: (json['t100'] as num?)?.toInt() ?? 0,
      vulnReached30: (json['vuln_reached_30'] as num?)?.toDouble() ?? 0.0,
      offlineDelivery: (json['offline_delivery'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'incident_id': incidentId,
      'hazard': hazard.name,
      'started_at': startedAt.toIso8601String(),
      't90': t90,
      't100': t100,
      'vuln_reached_30': vulnReached30,
      'offline_delivery': offlineDelivery,
    };
  }
}

class DrillComparisonSummary {
  final int totalDrills;
  final double averageVulnReached30;
  final double averageOfflineDelivery;
  final String trend; // "improving", "needs_practice", "stable", "empty"
  final List<DrillComparisonMetric> drills;

  const DrillComparisonSummary({
    required this.totalDrills,
    required this.averageVulnReached30,
    required this.averageOfflineDelivery,
    required this.trend,
    required this.drills,
  });

  factory DrillComparisonSummary.fromJson(Map<String, dynamic> json) {
    return DrillComparisonSummary(
      totalDrills: (json['total_drills'] as num?)?.toInt() ?? 0,
      averageVulnReached30: (json['average_vuln_reached_30'] as num?)?.toDouble() ?? 0.0,
      averageOfflineDelivery: (json['average_offline_delivery'] as num?)?.toDouble() ?? 0.0,
      trend: json['trend'] as String? ?? 'empty',
      drills: (json['drills'] as List<dynamic>?)
              ?.map((e) => DrillComparisonMetric.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_drills': totalDrills,
      'average_vuln_reached_30': averageVulnReached30,
      'average_offline_delivery': averageOfflineDelivery,
      'trend': trend,
      'drills': drills.map((d) => d.toJson()).toList(),
    };
  }
}
