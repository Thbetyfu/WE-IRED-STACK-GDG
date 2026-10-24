class RecapModel {
  final String id;
  final String incidentId;
  final RecapDataModel? data;
  final String notes;
  final String narrative;
  final bool aiAssisted;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? pdfUrl;
  final String? csvUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecapModel({
    required this.id,
    required this.incidentId,
    this.data,
    this.notes = '',
    this.narrative = '',
    this.aiAssisted = false,
    this.approvedBy,
    this.approvedAt,
    this.pdfUrl,
    this.csvUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => approvedBy != null && approvedBy!.isNotEmpty;

  factory RecapModel.fromJson(Map<String, dynamic> json) {
    return RecapModel(
      id: json['id'] as String? ?? '',
      incidentId: json['incident_id'] as String? ?? '',
      data: json['data'] != null ? RecapDataModel.fromJson(json['data'] as Map<String, dynamic>) : null,
      notes: json['notes'] as String? ?? '',
      narrative: json['narrative'] as String? ?? '',
      aiAssisted: json['ai_assisted'] as bool? ?? false,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'] as String) : null,
      pdfUrl: json['pdf_url'] as String?,
      csvUrl: json['csv_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_id': incidentId,
    'data': data?.toJson(),
    'notes': notes,
    'narrative': narrative,
    'ai_assisted': aiAssisted,
    'approved_by': approvedBy,
    'approved_at': approvedAt?.toIso8601String(),
    'pdf_url': pdfUrl,
    'csv_url': csvUrl,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  RecapModel copyWith({
    String? id,
    String? incidentId,
    RecapDataModel? data,
    String? notes,
    String? narrative,
    bool? aiAssisted,
    String? approvedBy,
    DateTime? approvedAt,
    String? pdfUrl,
    String? csvUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecapModel(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      data: data ?? this.data,
      notes: notes ?? this.notes,
      narrative: narrative ?? this.narrative,
      aiAssisted: aiAssisted ?? this.aiAssisted,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      csvUrl: csvUrl ?? this.csvUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RecapDataModel {
  final RegionInfoModel region;
  final IncidentInfoModel incident;
  final HouseholdSummaryModel householdSummary;
  final VulnerableSummaryModel vulnerableSummary;
  final NeedsSummaryModel needsSummary;
  final List<FollowUpHouseholdModel> followUpHouseholds;
  final TaskSummaryModel taskSummary;
  final MetricSummaryModel metrics;
  final List<TimelineEventModel> timeline;

  const RecapDataModel({
    required this.region,
    required this.incident,
    required this.householdSummary,
    required this.vulnerableSummary,
    required this.needsSummary,
    this.followUpHouseholds = const [],
    required this.taskSummary,
    required this.metrics,
    this.timeline = const [],
  });

  factory RecapDataModel.fromJson(Map<String, dynamic> json) {
    return RecapDataModel(
      region: RegionInfoModel.fromJson(json['region'] as Map<String, dynamic>? ?? {}),
      incident: IncidentInfoModel.fromJson(json['incident'] as Map<String, dynamic>? ?? {}),
      householdSummary: HouseholdSummaryModel.fromJson(json['household_summary'] as Map<String, dynamic>? ?? {}),
      vulnerableSummary: VulnerableSummaryModel.fromJson(json['vulnerable_summary'] as Map<String, dynamic>? ?? {}),
      needsSummary: NeedsSummaryModel.fromJson(json['needs_summary'] as Map<String, dynamic>? ?? {}),
      followUpHouseholds: (json['follow_up_households'] as List<dynamic>? ?? [])
          .map((e) => FollowUpHouseholdModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      taskSummary: TaskSummaryModel.fromJson(json['task_summary'] as Map<String, dynamic>? ?? {}),
      metrics: MetricSummaryModel.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map((e) => TimelineEventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'region': region.toJson(),
    'incident': incident.toJson(),
    'household_summary': householdSummary.toJson(),
    'vulnerable_summary': vulnerableSummary.toJson(),
    'needs_summary': needsSummary.toJson(),
    'follow_up_households': followUpHouseholds.map((e) => e.toJson()).toList(),
    'task_summary': taskSummary.toJson(),
    'metrics': metrics.toJson(),
    'timeline': timeline.map((e) => e.toJson()).toList(),
  };
}

class RegionInfoModel {
  final String rtId;
  final String rtName;
  final String rwName;
  final String kelurahanName;
  final String kecamatanName;

  const RegionInfoModel({
    this.rtId = '',
    this.rtName = '',
    this.rwName = '',
    this.kelurahanName = '',
    this.kecamatanName = '',
  });

  factory RegionInfoModel.fromJson(Map<String, dynamic> json) {
    return RegionInfoModel(
      rtId: json['rt_id'] as String? ?? '',
      rtName: json['rt_name'] as String? ?? '',
      rwName: json['rw_name'] as String? ?? '',
      kelurahanName: json['kelurahan_name'] as String? ?? '',
      kecamatanName: json['kecamatan_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'rt_id': rtId,
    'rt_name': rtName,
    'rw_name': rwName,
    'kelurahan_name': kelurahanName,
    'kecamatan_name': kecamatanName,
  };
}

class IncidentInfoModel {
  final String id;
  final String hazard;
  final String mode;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String duration;

  const IncidentInfoModel({
    this.id = '',
    this.hazard = '',
    this.mode = '',
    this.status = '',
    required this.startedAt,
    this.endedAt,
    this.duration = '',
  });

  factory IncidentInfoModel.fromJson(Map<String, dynamic> json) {
    return IncidentInfoModel(
      id: json['id'] as String? ?? '',
      hazard: json['hazard'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'] as String) ?? DateTime.now() : DateTime.now(),
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'] as String) : null,
      duration: json['duration'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'hazard': hazard,
    'mode': mode,
    'status': status,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'duration': duration,
  };
}

class HouseholdSummaryModel {
  final int total;
  final int aman;
  final int titikKumpul;
  final int butuhBantuan;
  final int belumMelapor;

  const HouseholdSummaryModel({
    this.total = 0,
    this.aman = 0,
    this.titikKumpul = 0,
    this.butuhBantuan = 0,
    this.belumMelapor = 0,
  });

  factory HouseholdSummaryModel.fromJson(Map<String, dynamic> json) {
    return HouseholdSummaryModel(
      total: json['total'] as int? ?? 0,
      aman: json['aman'] as int? ?? 0,
      titikKumpul: json['titik_kumpul'] as int? ?? 0,
      butuhBantuan: json['butuh_bantuan'] as int? ?? 0,
      belumMelapor: json['belum_melapor'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'aman': aman,
    'titik_kumpul': titikKumpul,
    'butuh_bantuan': butuhBantuan,
    'belum_melapor': belumMelapor,
  };
}

class VulnerableSummaryModel {
  final int totalVulnerable;
  final int reachedCount;
  final double percentage;

  const VulnerableSummaryModel({
    this.totalVulnerable = 0,
    this.reachedCount = 0,
    this.percentage = 0.0,
  });

  factory VulnerableSummaryModel.fromJson(Map<String, dynamic> json) {
    return VulnerableSummaryModel(
      totalVulnerable: json['total_vulnerable'] as int? ?? 0,
      reachedCount: json['reached_count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_vulnerable': totalVulnerable,
    'reached_count': reachedCount,
    'percentage': percentage,
  };
}

class NeedsSummaryModel {
  final int evakuasi;
  final int medis;
  final int makananAir;
  final int tempatTinggal;
  final int lainnya;

  const NeedsSummaryModel({
    this.evakuasi = 0,
    this.medis = 0,
    this.makananAir = 0,
    this.tempatTinggal = 0,
    this.lainnya = 0,
  });

  factory NeedsSummaryModel.fromJson(Map<String, dynamic> json) {
    return NeedsSummaryModel(
      evakuasi: json['evakuasi'] as int? ?? 0,
      medis: json['medis'] as int? ?? 0,
      makananAir: json['makanan_air'] as int? ?? 0,
      tempatTinggal: json['tempat_tinggal'] as int? ?? 0,
      lainnya: json['lainnya'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'evakuasi': evakuasi,
    'medis': medis,
    'makanan_air': makananAir,
    'tempat_tinggal': tempatTinggal,
    'lainnya': lainnya,
  };
}

class FollowUpHouseholdModel {
  final String householdId;
  final String number;
  final String headName;
  final String address;
  final String status;
  final String urgency;
  final List<String> needs;
  final double? lat;
  final double? lon;

  const FollowUpHouseholdModel({
    required this.householdId,
    required this.number,
    required this.headName,
    required this.address,
    required this.status,
    required this.urgency,
    this.needs = const [],
    this.lat,
    this.lon,
  });

  factory FollowUpHouseholdModel.fromJson(Map<String, dynamic> json) {
    return FollowUpHouseholdModel(
      householdId: json['household_id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      headName: json['head_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      status: json['status'] as String? ?? '',
      urgency: json['urgency'] as String? ?? '',
      needs: (json['needs'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'household_id': householdId,
    'number': number,
    'head_name': headName,
    'address': address,
    'status': status,
    'urgency': urgency,
    'needs': needs,
    'lat': lat,
    'lon': lon,
  };
}

class TaskSummaryModel {
  final int total;
  final int completed;
  final int inProgress;
  final int accepted;
  final int rejected;
  final int timedOut;

  const TaskSummaryModel({
    this.total = 0,
    this.completed = 0,
    this.inProgress = 0,
    this.accepted = 0,
    this.rejected = 0,
    this.timedOut = 0,
  });

  factory TaskSummaryModel.fromJson(Map<String, dynamic> json) {
    return TaskSummaryModel(
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      inProgress: json['in_progress'] as int? ?? 0,
      accepted: json['accepted'] as int? ?? 0,
      rejected: json['rejected'] as int? ?? 0,
      timedOut: json['timed_out'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'completed': completed,
    'in_progress': inProgress,
    'accepted': accepted,
    'rejected': rejected,
    'timed_out': timedOut,
  };
}

class MetricSummaryModel {
  final String t90;
  final String t100;
  final double vulnReached30;
  final double offlineDelivery;
  final String tRecap;
  final Map<String, int> byChannel;

  const MetricSummaryModel({
    this.t90 = 'N/A',
    this.t100 = 'N/A',
    this.vulnReached30 = 0.0,
    this.offlineDelivery = 0.0,
    this.tRecap = 'Tersedia',
    this.byChannel = const {},
  });

  factory MetricSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawByChannel = json['by_channel'] as Map<String, dynamic>? ?? {};
    final convertedChannel = rawByChannel.map((k, v) => MapEntry(k, (v as num).toInt()));

    return MetricSummaryModel(
      t90: json['t90']?.toString() ?? 'N/A',
      t100: json['t100']?.toString() ?? 'N/A',
      vulnReached30: (json['vuln_reached_30'] as num?)?.toDouble() ?? 0.0,
      offlineDelivery: (json['offline_delivery'] as num?)?.toDouble() ?? 0.0,
      tRecap: json['t_recap']?.toString() ?? 'Tersedia',
      byChannel: convertedChannel,
    );
  }

  Map<String, dynamic> toJson() => {
    't90': t90,
    't100': t100,
    'vuln_reached_30': vulnReached30,
    'offline_delivery': offlineDelivery,
    't_recap': tRecap,
    'by_channel': byChannel,
  };
}

class TimelineEventModel {
  final DateTime time;
  final String title;
  final String description;

  const TimelineEventModel({
    required this.time,
    required this.title,
    required this.description,
  });

  factory TimelineEventModel.fromJson(Map<String, dynamic> json) {
    return TimelineEventModel(
      time: json['time'] != null ? DateTime.tryParse(json['time'] as String) ?? DateTime.now() : DateTime.now(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'title': title,
    'description': description,
  };
}
