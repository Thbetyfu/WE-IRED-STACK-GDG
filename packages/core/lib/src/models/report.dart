class ReportStatus {
  static const int aman = 1;
  static const int titikKumpul = 2;
  static const int butuhBantuan = 3;

  static String label(int status) {
    switch (status) {
      case aman:
        return 'Aman di Rumah';
      case titikKumpul:
        return 'Sudah di Titik Kumpul';
      case butuhBantuan:
        return 'Butuh Bantuan';
      default:
        return 'Belum Melapor';
    }
  }
}

class ReportUrgency {
  static const int none = 0;
  static const int biasa = 1;
  static const int kritis = 2;

  static String label(int urgency) {
    switch (urgency) {
      case kritis:
        return 'Kritis (Darurat Medis / Jiwa Terancam)';
      case biasa:
        return 'Biasa / Mendesak';
      default:
        return 'Tidak Ada';
    }
  }
}

class ReportNeeds {
  static const int evakuasi = 1 << 0;
  static const int medis = 1 << 1;
  static const int logistik = 1 << 2; // makanan & air
  static const int tempatTinggal = 1 << 3;
  static const int lainnya = 1 << 4;

  static bool hasNeed(int needsMask, int need) => (needsMask & need) != 0;
}

class Report {
  final String id;
  final String incidentId;
  final String householdId;
  final int seq;
  final int status; // 1: aman, 2: titik kumpul, 3: butuh bantuan
  final int urgency; // 0, 1, 2
  final int needs; // bitmask
  final int memberMask; // bitmask 0–7
  final String? message;
  final double? lat;
  final double? lon;
  final int? battery; // 0–100
  final String channel; // app, outbox, relay_volunteer, mesh, beacon, beacon_checkin, whatsapp, proxy
  final String? reporterUserId;
  final String? beaconId;
  final DateTime deviceTime;
  final DateTime? receivedAt;
  final List<dynamic>? relayPath;

  const Report({
    required this.id,
    required this.incidentId,
    required this.householdId,
    required this.seq,
    required this.status,
    this.urgency = ReportUrgency.none,
    this.needs = 0,
    this.memberMask = 0,
    this.message,
    this.lat,
    this.lon,
    this.battery,
    required this.channel,
    this.reporterUserId,
    this.beaconId,
    required this.deviceTime,
    this.receivedAt,
    this.relayPath,
  });

  bool get isCritical => status == ReportStatus.butuhBantuan && urgency == ReportUrgency.kritis;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      householdId: json['household_id'] as String,
      seq: json['seq'] as int,
      status: json['status'] as int,
      urgency: json['urgency'] as int? ?? ReportUrgency.none,
      needs: json['needs'] as int? ?? 0,
      memberMask: json['member_mask'] as int? ?? 0,
      message: json['message'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      battery: json['battery'] as int?,
      channel: json['channel'] as String? ?? 'app',
      reporterUserId: json['reporter_user_id'] as String?,
      beaconId: json['beacon_id'] as String?,
      deviceTime: DateTime.parse(json['device_time'] as String),
      receivedAt: json['received_at'] != null ? DateTime.parse(json['received_at'] as String) : null,
      relayPath: json['relay_path'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'household_id': householdId,
      'seq': seq,
      'status': status,
      'urgency': urgency,
      'needs': needs,
      'member_mask': memberMask,
      if (message != null) 'message': message,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (battery != null) 'battery': battery,
      'channel': channel,
      if (reporterUserId != null) 'reporter_user_id': reporterUserId,
      if (beaconId != null) 'beacon_id': beaconId,
      'device_time': deviceTime.toIso8601String(),
      if (receivedAt != null) 'received_at': receivedAt!.toIso8601String(),
      if (relayPath != null) 'relay_path': relayPath,
    };
  }
}

class HouseholdState {
  final String incidentId;
  final String householdId;
  final String? reportId;
  final int status;
  final int urgency;
  final int needs;
  final int memberMask;
  final double priorityScore;
  final Map<String, dynamic>? scoreBreakdown;
  final bool reached;
  final int unconfirmedVulnerable;
  final DateTime updatedAt;

  const HouseholdState({
    required this.incidentId,
    required this.householdId,
    this.reportId,
    required this.status,
    this.urgency = 0,
    this.needs = 0,
    this.memberMask = 0,
    this.priorityScore = 0.0,
    this.scoreBreakdown,
    this.reached = false,
    this.unconfirmedVulnerable = 0,
    required this.updatedAt,
  });

  factory HouseholdState.fromJson(Map<String, dynamic> json) {
    return HouseholdState(
      incidentId: json['incident_id'] as String,
      householdId: json['household_id'] as String,
      reportId: json['report_id'] as String?,
      status: json['status'] as int,
      urgency: json['urgency'] as int? ?? 0,
      needs: json['needs'] as int? ?? 0,
      memberMask: json['member_mask'] as int? ?? 0,
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0.0,
      scoreBreakdown: json['score_breakdown'] as Map<String, dynamic>?,
      reached: json['reached'] as bool? ?? false,
      unconfirmedVulnerable: json['unconfirmed_vulnerable'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'incident_id': incidentId,
      'household_id': householdId,
      if (reportId != null) 'report_id': reportId,
      'status': status,
      'urgency': urgency,
      'needs': needs,
      'member_mask': memberMask,
      'priority_score': priorityScore,
      if (scoreBreakdown != null) 'score_breakdown': scoreBreakdown,
      'reached': reached,
      'unconfirmed_vulnerable': unconfirmedVulnerable,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
