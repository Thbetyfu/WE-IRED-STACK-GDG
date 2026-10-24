enum RegionType { kelurahan, rw, rt }

class Region {
  final String id;
  final RegionType type;
  final String? parentId;
  final String name;
  final String? code;
  final double? centroidLat;
  final double? centroidLon;
  final bool aiEnabled;

  const Region({
    required this.id,
    required this.type,
    this.parentId,
    required this.name,
    this.code,
    this.centroidLat,
    this.centroidLon,
    this.aiEnabled = false,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      type: RegionType.values.byName(json['type'] as String),
      parentId: json['parent_id'] as String?,
      name: json['name'] as String,
      code: json['code'] as String?,
      centroidLat: (json['centroid_lat'] as num?)?.toDouble(),
      centroidLon: (json['centroid_lon'] as num?)?.toDouble(),
      aiEnabled: json['ai_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      if (parentId != null) 'parent_id': parentId,
      'name': name,
      if (code != null) 'code': code,
      if (centroidLat != null) 'centroid_lat': centroidLat,
      if (centroidLon != null) 'centroid_lon': centroidLon,
      'ai_enabled': aiEnabled,
    };
  }
}
