class ScoreBreakdownModel {
  final double u; // Status & Urgensi (maks 40)
  final double v; // Kerentanan (maks 24)
  final double w; // Lama Menunggu (maks 20)
  final double n; // Kebutuhan (maks 10)
  final double d; // Jarak (maks 6)
  final double total;

  const ScoreBreakdownModel({
    this.u = 0,
    this.v = 0,
    this.w = 0,
    this.n = 0,
    this.d = 0,
    this.total = 0,
  });

  factory ScoreBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdownModel(
      u: (json['u'] as num?)?.toDouble() ?? 0,
      v: (json['v'] as num?)?.toDouble() ?? 0,
      w: (json['w'] as num?)?.toDouble() ?? 0,
      n: (json['n'] as num?)?.toDouble() ?? 0,
      d: (json['d'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'u': u,
    'v': v,
    'w': w,
    'n': n,
    'd': d,
    'total': total,
  };
}

class ReportHistoryItem {
  final DateTime time;
  final String status;
  final String urgency;
  final String channel;
  final String notes;

  const ReportHistoryItem({
    required this.time,
    required this.status,
    required this.urgency,
    required this.channel,
    this.notes = '',
  });

  factory ReportHistoryItem.fromJson(Map<String, dynamic> json) {
    return ReportHistoryItem(
      time: json['time'] != null ? DateTime.tryParse(json['time'] as String) ?? DateTime.now() : DateTime.now(),
      status: json['status'] as String? ?? 'aman',
      urgency: json['urgency'] as String? ?? 'biasa',
      channel: json['channel'] as String? ?? 'aplikasi',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'status': status,
    'urgency': urgency,
    'channel': channel,
    'notes': notes,
  };
}

class TriageItem {
  final String householdId;
  final String number;
  final String headName;
  final String address;
  final String blockId;
  final double? lat;
  final double? lon;
  final String status; // kritis, butuh_bantuan, belum_melapor, titik_kumpul, aman
  final String urgency; // kritis, biasa
  final String channel; // aplikasi, whatsapp, relay, relawan, belum
  final double priorityScore;
  final ScoreBreakdownModel scoreBreakdown;
  final int vulnerableCount;
  final List<String> vulnerableCategories;
  final List<ReportHistoryItem> reportHistory;

  const TriageItem({
    required this.householdId,
    required this.number,
    required this.headName,
    required this.address,
    required this.blockId,
    this.lat,
    this.lon,
    required this.status,
    required this.urgency,
    required this.channel,
    required this.priorityScore,
    required this.scoreBreakdown,
    this.vulnerableCount = 0,
    this.vulnerableCategories = const [],
    this.reportHistory = const [],
  });

  factory TriageItem.fromJson(Map<String, dynamic> json) {
    // Handle state object if present
    final state = json['state'] as Map<String, dynamic>?;

    String resolvedStatus = 'belum_melapor';
    if (json['status'] != null) {
      if (json['status'] is int) {
        final s = json['status'] as int;
        resolvedStatus = s == 1 ? 'kritis' : (s == 2 ? 'butuh_bantuan' : (s == 3 ? 'aman' : 'belum_melapor'));
      } else {
        resolvedStatus = json['status'].toString();
      }
    } else if (state != null && state['status'] != null) {
      final s = state['status'];
      if (s is int) {
        resolvedStatus = s == 1 ? 'kritis' : (s == 2 ? 'butuh_bantuan' : (s == 3 ? 'aman' : 'belum_melapor'));
      } else {
        resolvedStatus = s.toString();
      }
    }

    String resolvedUrgency = 'biasa';
    if (json['urgency'] != null) {
      resolvedUrgency = json['urgency'].toString();
    } else if (state != null && state['urgency'] != null) {
      final u = state['urgency'];
      resolvedUrgency = (u == 1 || u == 'kritis') ? 'kritis' : 'biasa';
    }

    Map<String, dynamic>? breakdownJson = json['score_breakdown'] as Map<String, dynamic>?;
    if (breakdownJson == null && state != null && state['score_breakdown'] is Map<String, dynamic>) {
      breakdownJson = state['score_breakdown'] as Map<String, dynamic>;
    }

    return TriageItem(
      householdId: json['household_id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      headName: json['head_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      blockId: json['block_id'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      status: resolvedStatus,
      urgency: resolvedUrgency,
      channel: json['channel'] as String? ?? (state != null ? 'aplikasi' : 'belum'),
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? (state != null ? ((state['priority_score'] as num?)?.toDouble() ?? 0) : 0),
      scoreBreakdown: ScoreBreakdownModel.fromJson(breakdownJson ?? {}),
      vulnerableCount: json['vulnerable_count'] as int? ?? 0,
      vulnerableCategories: (json['vulnerable_categories'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      reportHistory: (json['report_history'] as List<dynamic>? ?? [])
          .map((e) => ReportHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
