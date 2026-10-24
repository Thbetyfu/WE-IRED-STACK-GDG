import 'package:dio/dio.dart';
import '../auth/secure_storage.dart';
import '../auth/session.dart';
import '../models/report.dart';
import 'auth_interceptor.dart';
import 'endpoints.dart';
import 'error_interceptor.dart';

class ApiClient {
  final Dio dio;
  final SessionStorage sessionStorage;
  final void Function()? onSessionExpired;

  ApiClient({
    required String baseUrl,
    required this.sessionStorage,
    this.onSessionExpired,
    Dio? customDio,
  }) : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    dio.interceptors.insert(
      0,
      AuthInterceptor(
        dio: dio,
        sessionStorage: sessionStorage,
        onSessionExpired: onSessionExpired,
      ),
    );
    dio.interceptors.add(ErrorInterceptor());
  }

  void setBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
  }

  String get baseUrl => dio.options.baseUrl;

  // Generic HTTP methods
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.get<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  // Health check for endpoint detection (SDD 8.1, FR-SYNC-04)
  Future<Map<String, dynamic>> checkHealth({Duration timeout = const Duration(seconds: 3)}) async {
    final response = await dio.get(
      Endpoints.healthz,
      options: Options(
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  // Auth Endpoints (SDD 9.1)
  Future<void> requestOtp(String phone) async {
    await dio.post(
      Endpoints.authOtpRequest,
      data: {'phone': phone},
    );
  }

  Future<Session> verifyOtp(String phone, String code) async {
    final response = await dio.post(
      Endpoints.authOtpVerify,
      data: {'phone': phone, 'code': code},
    );
    final session = Session.fromJson(response.data as Map<String, dynamic>);
    await sessionStorage.saveSession(session);
    return session;
  }

  Future<Session> loginWithPassword(String email, String password) async {
    final response = await dio.post(
      Endpoints.authLogin,
      data: {'email': email, 'password': password},
    );
    final session = Session.fromJson(response.data as Map<String, dynamic>);
    await sessionStorage.saveSession(session);
    return session;
  }

  Future<Session> activateHousehold({
    required String inviteCode,
    required String phone,
    required String otp,
  }) async {
    final response = await dio.post(
      Endpoints.authActivate,
      data: {
        'invite_code': inviteCode,
        'phone': phone,
        'otp': otp,
      },
    );
    final session = Session.fromJson(response.data as Map<String, dynamic>);
    await sessionStorage.saveSession(session);
    return session;
  }

  Future<void> logout() async {
    try {
      await dio.post(Endpoints.authLogout);
    } finally {
      await sessionStorage.clearSession();
    }
  }

  // Sync Endpoints (SDD 9.4, FR-SYNC-02)
  Future<Map<String, dynamic>> syncReports(List<Report> reports) async {
    final response = await dio.post(
      Endpoints.syncReports,
      data: {
        'reports': reports.map((r) => r.toJson()).toList(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> syncRelayPackets(List<Map<String, dynamic>> packets) async {
    final response = await dio.post(
      Endpoints.syncRelayPackets,
      data: {
        'packets': packets,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> fetchSnapshot({String scope = 'household'}) async {
    final response = await dio.get(
      Endpoints.syncSnapshot,
      queryParameters: {'scope': scope},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
