enum Role {
  operator,
  adminWilayah,
  pengurus,
  relawan,
  kepalaKeluarga;

  static Role fromString(String str) {
    switch (str.toLowerCase()) {
      case 'operator':
        return Role.operator;
      case 'admin_wilayah':
        return Role.adminWilayah;
      case 'pengurus':
        return Role.pengurus;
      case 'relawan':
        return Role.relawan;
      case 'kepala_keluarga':
        return Role.kepalaKeluarga;
      default:
        throw ArgumentError('Unknown role: $str');
    }
  }

  String toDbString() {
    switch (this) {
      case Role.operator:
        return 'operator';
      case Role.adminWilayah:
        return 'admin_wilayah';
      case Role.pengurus:
        return 'pengurus';
      case Role.relawan:
        return 'relawan';
      case Role.kepalaKeluarga:
        return 'kepala_keluarga';
    }
  }
}

class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final DateTime createdAt;
  final String? role;
  final String? regionId;
  final String? householdId;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    DateTime? createdAt,
    this.role,
    this.regionId,
    this.householdId,
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      role: json['role'] as String?,
      regionId: json['region_id'] as String?,
      householdId: json['household_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      'created_at': createdAt.toIso8601String(),
      if (role != null) 'role': role,
      if (regionId != null) 'region_id': regionId,
      if (householdId != null) 'household_id': householdId,
    };
  }
}

class Membership {
  final String userId;
  final String regionId;
  final Role role;
  final String? householdId;

  const Membership({
    required this.userId,
    required this.regionId,
    required this.role,
    this.householdId,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      userId: json['user_id'] as String,
      regionId: json['region_id'] as String,
      role: Role.fromString(json['role'] as String),
      householdId: json['household_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'region_id': regionId,
      'role': role.toDbString(),
      if (householdId != null) 'household_id': householdId,
    };
  }
}
