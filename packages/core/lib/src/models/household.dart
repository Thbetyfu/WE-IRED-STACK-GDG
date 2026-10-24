class Household {
  final String id;
  final String rtId;
  final String? blockId;
  final String number;
  final String address;
  final double? lat;
  final double? lon;
  final String headName;
  final String waPhone;
  final bool hasDevice;
  final String? shortId;
  final String? inviteCode;
  final bool isSynthetic;

  const Household({
    required this.id,
    required this.rtId,
    this.blockId,
    required this.number,
    required this.address,
    this.lat,
    this.lon,
    required this.headName,
    required this.waPhone,
    this.hasDevice = true,
    this.shortId,
    this.inviteCode,
    this.isSynthetic = false,
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      rtId: json['rt_id'] as String,
      blockId: json['block_id'] as String?,
      number: json['number'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      headName: json['head_name'] as String,
      waPhone: json['wa_phone'] as String,
      hasDevice: json['has_device'] as bool? ?? true,
      shortId: json['short_id'] as String?,
      inviteCode: json['invite_code'] as String?,
      isSynthetic: json['is_synthetic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rt_id': rtId,
      if (blockId != null) 'block_id': blockId,
      'number': number,
      'address': address,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      'head_name': headName,
      'wa_phone': waPhone,
      'has_device': hasDevice,
      if (shortId != null) 'short_id': shortId,
      if (inviteCode != null) 'invite_code': inviteCode,
      'is_synthetic': isSynthetic,
    };
  }
}
