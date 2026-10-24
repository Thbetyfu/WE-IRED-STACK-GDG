import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:core/core.dart';

void main() {
  group('ApiClient and Interceptors Tests', () {
    late MemorySessionStorage sessionStorage;

    setUp(() {
      sessionStorage = MemorySessionStorage();
    });

    test('Injects Bearer token from session storage', () async {
      await sessionStorage.saveSession(
        Session(
          userId: 'u1',
          name: 'Nopal',
          phone: '+62812345678',
          role: Role.pengurus,
          regionId: 'reg-01',
          accessToken: 'initial-access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        ),
      );

      String? capturedAuthHeader;
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedAuthHeader = options.headers['Authorization'];
            handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
          },
        ),
      );

      final client = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
        customDio: mockDio,
      );

      await client.fetchSnapshot();
      expect(capturedAuthHeader, equals('Bearer initial-access-token'));
    });

    test('Parses SDD 9.7 standard error format into typed ApiException', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {
                    'error': {
                      'code': 'VALIDATION_FAILED',
                      'message': 'Nomor WhatsApp tidak valid',
                      'details': {'field': 'wa_phone'}
                    }
                  },
                ),
              ),
              true,
            );
          },
        ),
      );

      final client = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
        customDio: mockDio,
      );

      try {
        await client.requestOtp('invalid');
        fail('Expected DioException with ApiException');
      } on DioException catch (e) {
        expect(e.error, isA<ApiException>());
        final apiErr = e.error as ApiException;
        expect(apiErr.code, equals('VALIDATION_FAILED'));
        expect(apiErr.message, equals('Nomor WhatsApp tidak valid'));
        expect(apiErr.details?['field'], equals('wa_phone'));
      }
    });

    test('401 triggers token refresh and replays original request with rotated token', () async {
      await sessionStorage.saveSession(
        Session(
          userId: 'u1',
          name: 'Nopal',
          phone: '+62812345678',
          role: Role.pengurus,
          regionId: 'reg-01',
          accessToken: 'expired-token',
          refreshToken: 'valid-refresh-token',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );

      int requestCount = 0;
      final mockDio = Dio(BaseOptions(baseUrl: 'https://api.we-ired.id'));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == Endpoints.authRefresh) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'access_token': 'new-fresh-token',
                    'refresh_token': 'new-refresh-token',
                  },
                ),
              );
              return;
            }

            requestCount++;
            if (requestCount == 1) {
              // First attempt with expired token fails with 401
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(requestOptions: options, statusCode: 401),
                  type: DioExceptionType.badResponse,
                ),
                true,
              );
            } else {
              // Second attempt after refresh succeeds
              expect(options.headers['Authorization'], equals('Bearer new-fresh-token'));
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'status': 'success'},
                ),
              );
            }
          },
        ),
      );

      final client = ApiClient(
        baseUrl: 'https://api.we-ired.id',
        sessionStorage: sessionStorage,
        customDio: mockDio,
      );

      final result = await client.fetchSnapshot();
      expect(result['status'], equals('success'));
      expect(await sessionStorage.getAccessToken(), equals('new-fresh-token'));
      expect(await sessionStorage.getRefreshToken(), equals('new-refresh-token'));
    });
  });
}
