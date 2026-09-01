/// An error the user should see, already turned into a readable sentence.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Pulls a human-readable message out of a FastAPI error body.
///
/// FastAPI answers with `{"detail": "..."}` for raised HTTPExceptions and
/// `{"detail": [{"loc": [...], "msg": "..."}]}` for validation failures.
String parseErrorMessage(dynamic body, {String fallback = 'Something went wrong'}) {
  if (body is Map && body['detail'] != null) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
  }
  return fallback;
}
