import '../models/user.dart';

class Session {
  final String userId;
  final String name;
  final String phone;
  final Role role;
  final String regionId;
  final String? householdId;
  final String accessToken;
  final String refreshToken;
  final String? householdKey; // 32-byte hex for BLE packet signing
  final DateTime expiresAt;

  const Session({
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    required this.regionId,
    this.householdId,
    required this.accessToken,
    required this.refreshToken,
    this.householdKey,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: Role.fromString(json['role'] as String),
      regionId: json['region_id'] as String,
      householdId: json['household_id'] as String?,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      householdKey: json['household_key'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'phone': phone,
      'role': role.toDbString(),
      'region_id': regionId,
      if (householdId != null) 'household_id': householdId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (householdKey != null) 'household_key': householdKey,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return Session(
      userId: userId,
      name: name,
      phone: phone,
      role: role,
      regionId: regionId,
      householdId: householdId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      householdKey: householdKey,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
