/// Standard error format according to SDD 9.7:
/// { "error": { "code": "VALIDATION_FAILED", "message": "...", "details": {...} } }
class AppError {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  const AppError({
    required this.code,
    required this.message,
    this.details,
  });

  factory AppError.fromJson(Map<String, dynamic> json) {
    final errorObj = json['error'] as Map<String, dynamic>? ?? json;
    return AppError(
      code: errorObj['code'] as String? ?? 'UNKNOWN_ERROR',
      message: errorObj['message'] as String? ?? 'Terjadi kesalahan sistem',
      details: errorObj['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error': {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      },
    };
  }

  @override
  String toString() => 'AppError(code: $code, message: $message, details: $details)';
}
