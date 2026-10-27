/// Error codes shared by the API contract (`docs/api/error_codes.md`) and
/// the mock repositories.
enum ErrorCode {
  validationError('VALIDATION_ERROR'),
  unauthenticated('UNAUTHENTICATED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),
  rateLimited('RATE_LIMITED'),
  otpInvalid('OTP_INVALID'),
  otpExpired('OTP_EXPIRED'),
  accountIneligible('ACCOUNT_INELIGIBLE'),
  userBlocked('USER_BLOCKED'),
  matchRequired('MATCH_REQUIRED'),
  subscriptionRequired('SUBSCRIPTION_REQUIRED'),
  mediaRejected('MEDIA_REJECTED'),
  networkError('NETWORK_ERROR'),
  serverError('SERVER_ERROR'),
  featureNotConfigured('FEATURE_NOT_CONFIGURED'),
  unknown('UNKNOWN');

  const ErrorCode(this.wire);

  final String wire;

  static ErrorCode fromWire(String? value) => ErrorCode.values.firstWhere(
    (code) => code.wire == value,
    orElse: () => ErrorCode.unknown,
  );
}

class FieldError {
  const FieldError({required this.field, required this.reason});

  final String field;
  final String reason;
}

/// The single error type repositories throw. Widgets and ViewModels never see
/// transport exceptions (Dio, sockets, JSON).
class Failure implements Exception {
  const Failure(
    this.code, {
    this._message,
    this.details = const [],
    this.requestId,
    this.statusCode,
  });

  factory Failure.featureNotConfigured(String feature) => Failure(
    ErrorCode.featureNotConfigured,
    message: '$feature is not available yet.',
  );

  final ErrorCode code;
  final String? _message;
  final List<FieldError> details;
  final String? requestId;
  final int? statusCode;

  String get message => _message ?? _defaultMessage(code);

  bool get isRetryable => switch (code) {
    ErrorCode.networkError ||
    ErrorCode.serverError ||
    ErrorCode.rateLimited ||
    ErrorCode.unknown => true,
    _ => false,
  };

  static String _defaultMessage(ErrorCode code) => switch (code) {
    ErrorCode.validationError => 'Please correct the highlighted fields.',
    ErrorCode.unauthenticated => 'Your session has expired. Please sign in.',
    ErrorCode.forbidden => 'You do not have access to this.',
    ErrorCode.notFound => 'We could not find what you were looking for.',
    ErrorCode.conflict => 'This action was already completed.',
    ErrorCode.rateLimited => 'Too many attempts. Please wait and try again.',
    ErrorCode.otpInvalid => 'That code is incorrect.',
    ErrorCode.otpExpired => 'That code has expired. Request a new one.',
    ErrorCode.accountIneligible => 'This account is not eligible.',
    ErrorCode.userBlocked => 'This member is no longer available.',
    ErrorCode.matchRequired => 'You need to match before doing this.',
    ErrorCode.subscriptionRequired => 'This needs a premium plan.',
    ErrorCode.mediaRejected => 'This photo could not be accepted.',
    ErrorCode.networkError =>
      'You appear to be offline. Check your connection.',
    ErrorCode.serverError => 'Something went wrong on our side.',
    ErrorCode.featureNotConfigured => 'This feature is not available yet.',
    ErrorCode.unknown => 'Something went wrong.',
  };

  @override
  String toString() =>
      'Failure(${code.wire}${statusCode == null ? '' : ', $statusCode'}: $message)';
}
