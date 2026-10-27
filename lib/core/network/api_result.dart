import '../errors/failure.dart';
import 'json.dart';

/// Parses the standard `{success, data, error, meta}` envelope described in
/// `docs/api/api_reference.md`.
abstract final class ApiEnvelope {
  static Object? unwrapData(Object? body) {
    if (body == null || body == '') return null;
    final json = asJson(body, 'envelope');
    if (json['success'] == true) return json['data'];
    throw toFailure(body);
  }

  static Failure toFailure(Object? body, {int? statusCode}) {
    if (body is Map && body['error'] is Map) {
      final error = asJson(body['error'], 'error');
      final meta = body['meta'] is Map ? asJson(body['meta'], 'meta') : null;
      final code = ErrorCode.fromWire(error['code'] as String?);
      return Failure(
        code == ErrorCode.unknown && statusCode != null
            ? codeForStatus(statusCode)
            : code,
        message: error['message'] as String?,
        statusCode: statusCode,
        requestId: meta?['requestId'] as String?,
        details: [
          for (final detail in (error['details'] as List?) ?? const [])
            if (detail is Map)
              FieldError(
                field: '${detail['field'] ?? ''}',
                reason: '${detail['reason'] ?? ''}',
              ),
        ],
      );
    }
    return Failure(
      statusCode == null ? ErrorCode.serverError : codeForStatus(statusCode),
      statusCode: statusCode,
    );
  }

  static ErrorCode codeForStatus(int status) => switch (status) {
    400 || 422 => ErrorCode.validationError,
    401 => ErrorCode.unauthenticated,
    403 => ErrorCode.forbidden,
    404 => ErrorCode.notFound,
    409 => ErrorCode.conflict,
    429 => ErrorCode.rateLimited,
    501 => ErrorCode.featureNotConfigured,
    >= 500 => ErrorCode.serverError,
    _ => ErrorCode.unknown,
  };
}
