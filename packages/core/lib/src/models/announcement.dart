enum AnnouncementLevel {
  info,
  penting,
  darurat;

  static AnnouncementLevel fromString(String str) {
    switch (str.toLowerCase()) {
      case 'darurat':
        return AnnouncementLevel.darurat;
      case 'penting':
        return AnnouncementLevel.penting;
      default:
        return AnnouncementLevel.info;
    }
  }
}

class Announcement {
  final String id;
  final List<String> regionIds;
  final String? incidentId;
  final int shortId; // uint32
  final AnnouncementLevel level;
  final String text; // max 160 chars
  final DateTime expiresAt;
  final String? signature; // base64 Ed25519 signature
  final List<String> channels; // push, whatsapp, relay

  const Announcement({
    required this.id,
    this.regionIds = const [],
    this.incidentId,
    required this.shortId,
    required this.level,
    required this.text,
    required this.expiresAt,
    this.signature,
    this.channels = const ['push', 'relay'],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      regionIds: (json['region_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      incidentId: json['incident_id'] as String?,
      shortId: json['short_id'] as int,
      level: AnnouncementLevel.fromString(json['level'] as String),
      text: json['text'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      signature: json['signature'] as String?,
      channels: (json['channels'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'region_ids': regionIds,
      if (incidentId != null) 'incident_id': incidentId,
      'short_id': shortId,
      'level': level.name,
      'text': text,
      'expires_at': expiresAt.toIso8601String(),
      if (signature != null) 'signature': signature,
      'channels': channels,
    };
  }
}
