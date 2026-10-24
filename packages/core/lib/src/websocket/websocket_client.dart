import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth/secure_storage.dart';
import 'ws_event.dart';

enum WsConnectionState {
  connecting,
  connected,
  disconnected,
}

class WebSocketClient {
  final String baseWsUrl; // e.g. ws://api.we-ired.id or ws://192.168.4.1:8080
  final SessionStorage sessionStorage;

  String? _incidentId;
  int? _lastEventId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;

  final _eventController = StreamController<WsEvent>.broadcast();
  final _stateController = StreamController<WsConnectionState>.broadcast();

  WsConnectionState _state = WsConnectionState.disconnected;

  WebSocketClient({
    required this.baseWsUrl,
    required this.sessionStorage,
  });

  Stream<WsEvent> get events => _eventController.stream;
  Stream<WsConnectionState> get stateChanges => _stateController.stream;
  WsConnectionState get state => _state;
  int? get lastEventId => _lastEventId;

  void connect(String incidentId, {int? resumeFromEventId}) {
    _incidentId = incidentId;
    if (resumeFromEventId != null) {
      _lastEventId = resumeFromEventId;
    }
    _disposed = false;
    _establishConnection();
  }

  void _setState(WsConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  Future<void> _establishConnection() async {
    if (_disposed || _incidentId == null) return;
    _setState(WsConnectionState.connecting);

    try {
      final token = await sessionStorage.getAccessToken();

      var uriStr = '$baseWsUrl/ws?incident=$_incidentId';
      if (_lastEventId != null && _lastEventId! > 0) {
        uriStr += '&last_event_id=$_lastEventId';
      }
      if (token != null && token.isNotEmpty) {
        uriStr += '&token=$token';
      }

      final uri = Uri.parse(uriStr);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _setState(WsConnectionState.connected);
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _onMessageReceived(dynamic message) {
    try {
      final text = message is String ? message : utf8.decode(message as List<int>);
      final json = jsonDecode(text) as Map<String, dynamic>;
      final event = WsEvent.fromJson(json);

      if (event.eventId > 0) {
        _lastEventId = event.eventId;
      }

      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    } catch (_) {
      // Ignore malformed frames
    }
  }

  void _handleDisconnect() {
    _setState(WsConnectionState.disconnected);
    _cleanupChannel();

    if (!_disposed) {
      _reconnectTimer?.cancel();
      // Auto-reconnect with 2 second backoff, carrying forward _lastEventId
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (!_disposed) {
          _establishConnection();
        }
      });
    }
  }

  void _cleanupChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _cleanupChannel();
    _setState(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _stateController.close();
  }
}
