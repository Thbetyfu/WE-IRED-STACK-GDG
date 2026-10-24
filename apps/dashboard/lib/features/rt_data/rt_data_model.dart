class CsvRowError {
  final int row;
  final String field;
  final String message;

  const CsvRowError({
    required this.row,
    required this.field,
    required this.message,
  });

  factory CsvRowError.fromJson(Map<String, dynamic> json) {
    return CsvRowError(
      row: json['row'] as int? ?? 0,
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? 'Kesalahan validasi data',
    );
  }

  Map<String, dynamic> toJson() => {
    'row': row,
    'field': field,
    'message': message,
  };
}

class CsvImportResult {
  final int totalRows;
  final int importedCount;
  final int failedCount;
  final List<CsvRowError> errors;

  const CsvImportResult({
    required this.totalRows,
    required this.importedCount,
    required this.failedCount,
    this.errors = const [],
  });

  bool get hasErrors => failedCount > 0 || errors.isNotEmpty;

  factory CsvImportResult.fromJson(Map<String, dynamic> json) {
    return CsvImportResult(
      totalRows: json['total_rows'] as int? ?? 0,
      importedCount: json['imported_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      errors: (json['errors'] as List<dynamic>? ?? [])
          .map((e) => CsvRowError.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'total_rows': totalRows,
    'imported_count': importedCount,
    'failed_count': failedCount,
    'errors': errors.map((e) => e.toJson()).toList(),
  };
}
