class Endpoints {
  static const String prefix = '/api/v1';

  // Auth
  static const String authOtpRequest = '$prefix/auth/otp/request';
  static const String authOtpVerify = '$prefix/auth/otp/verify';
  static const String authLogin = '$prefix/auth/login';
  static const String authActivate = '$prefix/auth/activate';
  static const String authRefresh = '$prefix/auth/refresh';
  static const String authLogout = '$prefix/auth/logout';

  // Sync
  static const String healthz = '/healthz';
  static const String syncReports = '$prefix/sync/reports';
  static const String syncRelayPackets = '$prefix/sync/relay-packets';
  static const String syncSnapshot = '$prefix/sync/snapshot';
  static const String syncAcks = '$prefix/sync/acks';

  // Incidents & Reports
  static String incident(String id) => '$prefix/incidents/$id';
  static String incidentSummary(String id) => '$prefix/incidents/$id/summary';
  static String incidentMetrics(String id) => '$prefix/incidents/$id/metrics';
  static String incidentReports(String id) => '$prefix/incidents/$id/reports';
  static String incidentTasks(String id) => '$prefix/incidents/$id/tasks';

  // WebSocket
  static String ws(String incidentId, [String? lastEventId]) {
    var url = '/ws?incident=$incidentId';
    if (lastEventId != null && lastEventId.isNotEmpty) {
      url += '&last_event_id=$lastEventId';
    }
    return url;
  }
}
