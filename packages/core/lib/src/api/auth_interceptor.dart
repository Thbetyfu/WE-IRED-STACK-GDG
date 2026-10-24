import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/secure_storage.dart';
import 'endpoints.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final SessionStorage sessionStorage;
  final void Function()? onSessionExpired;

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.dio,
    required this.sessionStorage,
    this.onSessionExpired,
  });

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip injecting auth token for public auth endpoints
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/otp') ||
        options.path.contains('/auth/activate') ||
        options.path.contains('/healthz')) {
      return handler.next(options);
    }

    final token = await sessionStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains(Endpoints.authRefresh)) {
      try {
        final newToken = await _refreshToken();
        if (newToken != null) {
          // Retry original request with updated token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';

          final response = await dio.fetch(options);
          return handler.resolve(response);
        }
      } catch (refreshErr) {
        await sessionStorage.clearSession();
        onSessionExpired?.call();
        return handler.reject(err);
      }
    }
    super.onError(err, handler);
  }

  Future<String?> _refreshToken() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final currentRefreshToken = await sessionStorage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        throw StateError('No refresh token available');
      }

      // Use a clean Dio instance to avoid interceptor recursion
      final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
      final response = await refreshDio.post(
        Endpoints.authRefresh,
        data: {'refresh_token': currentRefreshToken},
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String;
        final newRefreshToken = data['refresh_token'] as String;
        final expiresAt = DateTime.now().add(const Duration(minutes: 15));

        await sessionStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
        );

        _refreshCompleter?.complete(newAccessToken);
        return newAccessToken;
      } else {
        throw StateError('Refresh token rejected');
      }
    } catch (e) {
      _refreshCompleter?.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}
