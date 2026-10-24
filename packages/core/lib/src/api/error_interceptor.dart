import 'package:dio/dio.dart';
import '../models/app_error.dart';

class ApiException implements Exception {
  final int statusCode;
  final AppError appError;
  final RequestOptions requestOptions;

  const ApiException({
    required this.statusCode,
    required this.appError,
    required this.requestOptions,
  });

  String get code => appError.code;
  String get message => appError.message;
  Map<String, dynamic>? get details => appError.details;

  @override
  String toString() => 'ApiException(status: $statusCode, code: $code, message: $message)';
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.data != null && err.response?.data is Map) {
      try {
        final data = Map<String, dynamic>.from(err.response!.data as Map);
        final appError = AppError.fromJson(data);
        final apiException = ApiException(
          statusCode: err.response?.statusCode ?? 500,
          appError: appError,
          requestOptions: err.requestOptions,
        );
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: err.type,
            error: apiException,
            message: apiException.message,
          ),
        );
        return;
      } catch (_) {
        // Fallback to default error handling
      }
    }
    super.onError(err, handler);
  }
}
