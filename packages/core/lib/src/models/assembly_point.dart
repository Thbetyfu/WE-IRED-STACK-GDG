class Block {
  final String id;
  final String rtId;
  final String name;
  final Map<String, dynamic>? polygonGeojson;

  const Block({
    required this.id,
    required this.rtId,
    required this.name,
    this.polygonGeojson,
  });

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      id: json['id'] as String,
      rtId: json['rt_id'] as String,
      name: json['name'] as String,
      polygonGeojson: json['polygon_geojson'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rt_id': rtId,
      'name': name,
      if (polygonGeojson != null) 'polygon_geojson': polygonGeojson,
    };
  }
}

class AssemblyPoint {
  final String id;
  final String rtId;
  final String name;
  final double lat;
  final double lon;
  final int capacity;
  final Map<String, dynamic> facilities; // wheelchair, toilet, electricity, water
  final String? contact;

  const AssemblyPoint({
    required this.id,
    required this.rtId,
    required this.name,
    required this.lat,
    required this.lon,
    required this.capacity,
    this.facilities = const {},
    this.contact,
  });

  factory AssemblyPoint.fromJson(Map<String, dynamic> json) {
    return AssemblyPoint(
      id: json['id'] as String,
      rtId: json['rt_id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      capacity: json['capacity'] as int? ?? 0,
      facilities: (json['facilities'] as Map<String, dynamic>?) ?? {},
      contact: json['contact'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rt_id': rtId,
      'name': name,
      'lat': lat,
      'lon': lon,
      'capacity': capacity,
      'facilities': facilities,
      if (contact != null) 'contact': contact,
    };
  }
}
