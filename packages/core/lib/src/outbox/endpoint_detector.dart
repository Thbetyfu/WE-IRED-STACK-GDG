import 'dart:async';
import 'package:dio/dio.dart';
import '../api/endpoints.dart';

enum EndpointType {
  cloud,
  posko,
  none,
}

class EndpointInfo {
  final EndpointType type;
  final String? url;
  final int latencyMs;
  final bool isHealthy;
  final DateTime checkedAt;

  const EndpointInfo({
    required this.type,
    this.url,
    this.latencyMs = 0,
    required this.isHealthy,
    required this.checkedAt,
  });

  static EndpointInfo disconnected() {
    return EndpointInfo(
      type: EndpointType.none,
      isHealthy: false,
      checkedAt: DateTime.now(),
    );
  }

  @override
  String toString() => 'EndpointInfo(type: $type, url: $url, latency: ${latencyMs}ms, healthy: $isHealthy)';
}

/// Implements SDD 8.1 and FR-SYNC-04:
/// Checks /healthz sequentially every 3 seconds to detect Cloud or Posko Local availability.
class EndpointDetector {
  final String cloudUrl;
  String? poskoUrl;
  final Duration checkInterval;
  final Duration healthTimeout;
  final void Function(String newBaseUrl)? onEndpointChanged;

  final Dio _dio;
  Timer? _timer;
  bool _isChecking = false;

  EndpointInfo _currentEndpoint = EndpointInfo.disconnected();
  final _controller = StreamController<EndpointInfo>.broadcast();

  EndpointDetector({
    required this.cloudUrl,
    this.poskoUrl,
    this.checkInterval = const Duration(seconds: 3),
    this.healthTimeout = const Duration(seconds: 3),
    this.onEndpointChanged,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: healthTimeout,
                receiveTimeout: healthTimeout,
              ),
            );

  Stream<EndpointInfo> get onEndpointUpdated => _controller.stream;
  EndpointInfo get currentEndpoint => _currentEndpoint;

  void setPoskoUrl(String? url) {
    poskoUrl = url;
  }

  void start() {
    stop();
    // Run initial probe immediately
    checkEndpoints();
    _timer = Timer.periodic(checkInterval, (_) => checkEndpoints());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<EndpointInfo> checkEndpoints() async {
    if (_isChecking) return _currentEndpoint;
    _isChecking = true;

    try {
      // 1. Probe Cloud first (SDD 8.1)
      final cloudInfo = await _probeUrl(cloudUrl, EndpointType.cloud);
      if (cloudInfo.isHealthy) {
        _updateActiveEndpoint(cloudInfo);
        return cloudInfo;
      }

      // 2. If Cloud unreachable, probe Posko Local if configured
      if (poskoUrl != null && poskoUrl!.isNotEmpty) {
        final poskoInfo = await _probeUrl(poskoUrl!, EndpointType.posko);
        if (poskoInfo.isHealthy) {
          _updateActiveEndpoint(poskoInfo);
          return poskoInfo;
        }
      }

      // 3. Neither endpoint reachable -> offline
      final disconnectedInfo = EndpointInfo.disconnected();
      _updateActiveEndpoint(disconnectedInfo);
      return disconnectedInfo;
    } finally {
      _isChecking = false;
    }
  }

  Future<EndpointInfo> _probeUrl(String targetBaseUrl, EndpointType type) async {
    final cleanUrl = targetBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final healthzUrl = '$cleanUrl${Endpoints.healthz}';
    final sw = Stopwatch()..start();

    try {
      final response = await _dio.get(
        healthzUrl,
        options: Options(
          sendTimeout: healthTimeout,
          receiveTimeout: healthTimeout,
        ),
      );
      sw.stop();

      final isHealthy = response.statusCode == 200;
      return EndpointInfo(
        type: type,
        url: cleanUrl,
        latencyMs: sw.elapsedMilliseconds,
        isHealthy: isHealthy,
        checkedAt: DateTime.now(),
      );
    } catch (_) {
      return EndpointInfo(
        type: type,
        url: cleanUrl,
        latencyMs: sw.elapsedMilliseconds,
        isHealthy: false,
        checkedAt: DateTime.now(),
      );
    }
  }

  void _updateActiveEndpoint(EndpointInfo newInfo) {
    final changed = _currentEndpoint.type != newInfo.type || _currentEndpoint.url != newInfo.url;
    _currentEndpoint = newInfo;

    if (changed) {
      if (newInfo.url != null && newInfo.isHealthy) {
        onEndpointChanged?.call(newInfo.url!);
      }
      if (!_controller.isClosed) {
        _controller.add(newInfo);
      }
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
