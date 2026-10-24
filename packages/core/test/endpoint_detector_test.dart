import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  group('EndpointDetector Tests (SDD 8.1, FR-SYNC-04)', () {
    test('Prioritizes Cloud when both Cloud and Posko are healthy', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'status': 'ok'},
              ),
            );
          },
        ),
      );

      String? activeUrl;
      final detector = EndpointDetector(
        cloudUrl: 'https://api.we-ired.id',
        poskoUrl: 'http://192.168.4.1:8080',
        dio: mockDio,
        onEndpointChanged: (newUrl) {
          activeUrl = newUrl;
        },
      );

      final result = await detector.checkEndpoints();
      expect(result.type, equals(EndpointType.cloud));
      expect(result.url, equals('https://api.we-ired.id'));
      expect(result.isHealthy, isTrue);
      expect(activeUrl, equals('https://api.we-ired.id'));
    });

    test('Falls back to Posko when Cloud is unreachable', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'api.we-ired.id') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                  error: 'Connection timed out',
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'status': 'ok', 'mode': 'posko'},
                ),
              );
            }
          },
        ),
      );

      String? activeUrl;
      final detector = EndpointDetector(
        cloudUrl: 'https://api.we-ired.id',
        poskoUrl: 'http://192.168.4.1:8080',
        dio: mockDio,
        onEndpointChanged: (newUrl) {
          activeUrl = newUrl;
        },
      );

      final result = await detector.checkEndpoints();
      expect(result.type, equals(EndpointType.posko));
      expect(result.url, equals('http://192.168.4.1:8080'));
      expect(result.isHealthy, isTrue);
      expect(activeUrl, equals('http://192.168.4.1:8080'));
    });

    test('Reports disconnected when neither Cloud nor Posko responds', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'Network unreachable',
              ),
            );
          },
        ),
      );

      final detector = EndpointDetector(
        cloudUrl: 'https://api.we-ired.id',
        poskoUrl: 'http://192.168.4.1:8080',
        dio: mockDio,
      );

      final result = await detector.checkEndpoints();
      expect(result.type, equals(EndpointType.none));
      expect(result.isHealthy, isFalse);
    });
  });
}
