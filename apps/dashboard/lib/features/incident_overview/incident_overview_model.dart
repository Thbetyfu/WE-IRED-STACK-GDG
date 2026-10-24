import 'package:core/core.dart';

class IncidentStatusSummary {
  final int totalHouseholds;
  final int aman;
  final int titikKumpul;
  final int butuhBantuan;
  final int kritis;
  final int belumMelapor;

  const IncidentStatusSummary({
    this.totalHouseholds = 0,
    this.aman = 0,
    this.titikKumpul = 0,
    this.butuhBantuan = 0,
    this.kritis = 0,
    this.belumMelapor = 0,
  });

  factory IncidentStatusSummary.fromJson(Map<String, dynamic> json) {
    return IncidentStatusSummary(
      totalHouseholds: json['total_households'] as int? ?? 0,
      aman: json['aman'] as int? ?? 0,
      titikKumpul: json['titik_kumpul'] as int? ?? 0,
      butuhBantuan: json['butuh_bantuan'] as int? ?? 0,
      kritis: json['kritis'] as int? ?? 0,
      belumMelapor: json['belum_melapor'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_households': totalHouseholds,
    'aman': aman,
    'titik_kumpul': titikKumpul,
    'butuh_bantuan': butuhBantuan,
    'kritis': kritis,
    'belum_melapor': belumMelapor,
  };
}

class DraftActivationResult {
  final String token;
  final int shortId;
  final HazardType hazard;
  final IncidentMode mode;
  final List<String> scopeBlockIds;
  final String message;
  final DateTime expiresAt;

  const DraftActivationResult({
    required this.token,
    required this.shortId,
    required this.hazard,
    required this.mode,
    required this.scopeBlockIds,
    required this.message,
    required this.expiresAt,
  });

  factory DraftActivationResult.fromJson(Map<String, dynamic> json) {
    return DraftActivationResult(
      token: json['token'] as String? ?? '',
      shortId: json['short_id'] as int? ?? 0,
      hazard: HazardType.fromString(json['hazard'] as String? ?? 'banjir'),
      mode: IncidentMode.fromString(json['mode'] as String? ?? 'nyata'),
      scopeBlockIds: (json['scope_block_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      message: json['message'] as String? ?? '',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class BmkgAlert {
  final String id;
  final String title;
  final String description;
  final String hazard;
  final String severity; // warning, advisory, critical
  final DateTime issuedAt;
  final bool isContractMock;

  const BmkgAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.hazard,
    this.severity = 'warning',
    required this.issuedAt,
    this.isContractMock = false,
  });

  factory BmkgAlert.fromJson(Map<String, dynamic> json) {
    return BmkgAlert(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      hazard: json['hazard'] as String? ?? 'cuaca',
      severity: json['severity'] as String? ?? 'warning',
      issuedAt: json['issued_at'] != null ? DateTime.tryParse(json['issued_at'] as String) ?? DateTime.now() : DateTime.now(),
      isContractMock: json['is_contract_mock'] as bool? ?? false,
    );
  }
}
