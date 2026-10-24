class Volunteer {
  final String userId;
  final String rtId;
  final String name;
  final String phone;
  final List<String> skills;
  final bool available;
  final double? lastLat;
  final double? lastLon;
  final DateTime? lastLocAt;
  final List<String> assignedBlocks;
  final DateTime createdAt;

  const Volunteer({
    required this.userId,
    required this.rtId,
    this.name = '',
    this.phone = '',
    this.skills = const [],
    this.available = true,
    this.lastLat,
    this.lastLon,
    this.lastLocAt,
    this.assignedBlocks = const [],
    required this.createdAt,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    return Volunteer(
      userId: json['user_id'] as String? ?? '',
      rtId: json['rt_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      skills: (json['skills'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      available: json['available'] as bool? ?? true,
      lastLat: (json['last_lat'] as num?)?.toDouble(),
      lastLon: (json['last_lon'] as num?)?.toDouble(),
      lastLocAt: json['last_loc_at'] != null ? DateTime.tryParse(json['last_loc_at'] as String) : null,
      assignedBlocks: (json['assigned_blocks'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'rt_id': rtId,
      'name': name,
      'phone': phone,
      'skills': skills,
      'available': available,
      if (lastLat != null) 'last_lat': lastLat,
      if (lastLon != null) 'last_lon': lastLon,
      if (lastLocAt != null) 'last_loc_at': lastLocAt?.toIso8601String(),
      'assigned_blocks': assignedBlocks,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Volunteer copyWith({
    String? userId,
    String? rtId,
    String? name,
    String? phone,
    List<String>? skills,
    bool? available,
    double? lastLat,
    double? lastLon,
    DateTime? lastLocAt,
    List<String>? assignedBlocks,
    DateTime? createdAt,
  }) {
    return Volunteer(
      userId: userId ?? this.userId,
      rtId: rtId ?? this.rtId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      skills: skills ?? this.skills,
      available: available ?? this.available,
      lastLat: lastLat ?? this.lastLat,
      lastLon: lastLon ?? this.lastLon,
      lastLocAt: lastLocAt ?? this.lastLocAt,
      assignedBlocks: assignedBlocks ?? this.assignedBlocks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
