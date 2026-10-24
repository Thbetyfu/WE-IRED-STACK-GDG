library core;

// Models (SDD 5.2)
export 'src/models/models.dart';

// Auth & Secure Storage (SDD 5.3)
export 'src/auth/session.dart';
export 'src/auth/secure_storage.dart';

// API Client & Interceptors (SDD 9, FR-AUTH-05)
export 'src/api/endpoints.dart';
export 'src/api/auth_interceptor.dart';
export 'src/api/error_interceptor.dart';
export 'src/api/api_client.dart';

// WebSocket Client (SDD 9.6)
export 'src/websocket/ws_event.dart';
export 'src/websocket/websocket_client.dart';

// Drift Database (SDD 5.3)
export 'src/db/tables.dart';
export 'src/db/database.dart';

// Transactional Outbox & Endpoint Detection (FR-SYNC-01..04, N-04, SDD 8.1)
export 'src/outbox/outbox.dart';
