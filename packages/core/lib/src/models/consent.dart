enum ConsentMethod {
  aplikasi,
  kertas,
  lisanDisaksikan;

  static ConsentMethod fromString(String str) {
    switch (str.toLowerCase()) {
      case 'aplikasi':
        return ConsentMethod.aplikasi;
      case 'kertas':
        return ConsentMethod.kertas;
      case 'lisan_disaksikan':
        return ConsentMethod.lisanDisaksikan;
      default:
        return ConsentMethod.aplikasi;
    }
  }

  String toDbString() {
    switch (this) {
      case ConsentMethod.aplikasi:
        return 'aplikasi';
      case ConsentMethod.kertas:
        return 'kertas';
      case ConsentMethod.lisanDisaksikan:
        return 'lisan_disaksikan';
    }
  }
}

class Consent {
  final String id;
  final String householdId;
  final String givenBy;
  final ConsentMethod method;
  final String textVersion;
  final DateTime givenAt;
  final DateTime? revokedAt;

  const Consent({
    required this.id,
    required this.householdId,
    required this.givenBy,
    required this.method,
    required this.textVersion,
    required this.givenAt,
    this.revokedAt,
  });

  bool get isValid => revokedAt == null;

  factory Consent.fromJson(Map<String, dynamic> json) {
    return Consent(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      givenBy: json['given_by'] as String,
      method: ConsentMethod.fromString(json['method'] as String),
      textVersion: json['text_version'] as String,
      givenAt: DateTime.parse(json['given_at'] as String),
      revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'given_by': givenBy,
      'method': method.toDbString(),
      'text_version': textVersion,
      'given_at': givenAt.toIso8601String(),
      if (revokedAt != null) 'revoked_at': revokedAt!.toIso8601String(),
    };
  }
}
