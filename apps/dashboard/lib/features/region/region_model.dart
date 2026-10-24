class AccessibleRT {
  final String id;
  final String name;
  final String type;
  final String? parentId;

  const AccessibleRT({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  factory AccessibleRT.fromJson(Map<String, dynamic> json) {
    return AccessibleRT(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'rt',
      parentId: json['parent_id'] as String?,
    );
  }
}

class RegionAggregateModel {
  final String regionId;
  final String regionName;
  final int totalRTs;
  final int activeIncidents;
  final Map<String, int> householdsByStatus;
  final int vulnerableUnreached;

  const RegionAggregateModel({
    required this.regionId,
    required this.regionName,
    required this.totalRTs,
    required this.activeIncidents,
    required this.householdsByStatus,
    required this.vulnerableUnreached,
  });

  factory RegionAggregateModel.fromJson(Map<String, dynamic> json) {
    final statusMapRaw = json['households_by_status'] as Map<String, dynamic>? ?? {};
    final statusMap = <String, int>{};
    statusMapRaw.forEach((k, v) {
      statusMap[k] = (v as num?)?.toInt() ?? 0;
    });

    return RegionAggregateModel(
      regionId: json['region_id'] as String? ?? '',
      regionName: json['region_name'] as String? ?? '',
      totalRTs: (json['total_rts'] as num?)?.toInt() ?? 0,
      activeIncidents: (json['active_incidents'] as num?)?.toInt() ?? 0,
      householdsByStatus: statusMap,
      vulnerableUnreached: (json['vulnerable_unreached'] as num?)?.toInt() ?? 0,
    );
  }
}

class RTDetailSummary {
  final String rtId;
  final String name;
  final bool hasActiveIncident;
  final String incidentTitle;
  final int totalHouseholds;
  final int safeCount;
  final int needHelpCount;
  final int criticalCount;
  final int unreportedCount;
  final int vulnerableUnreached;

  const RTDetailSummary({
    required this.rtId,
    required this.name,
    required this.hasActiveIncident,
    required this.incidentTitle,
    required this.totalHouseholds,
    required this.safeCount,
    required this.needHelpCount,
    required this.criticalCount,
    required this.unreportedCount,
    required this.vulnerableUnreached,
  });
}
