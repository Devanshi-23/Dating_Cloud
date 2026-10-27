const statusFor = {
  VALIDATION_ERROR: 400,
  UNAUTHENTICATED: 401,
  OTP_INVALID: 400,
  OTP_EXPIRED: 400,
  FORBIDDEN: 403,
  ACCOUNT_INELIGIBLE: 403,
  USER_BLOCKED: 403,
  MATCH_REQUIRED: 403,
  SUBSCRIPTION_REQUIRED: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  MEDIA_REJECTED: 422,
  RATE_LIMITED: 429,
  FEATURE_NOT_CONFIGURED: 501,
  SERVER_ERROR: 500,
};

export function requestId() {
  return `req_${crypto.randomUUID().replaceAll('-', '').slice(0, 12)}`;
}

export function ok(res, data, status = 200) {
  res.status(status).json({
    success: true,
    data: data ?? null,
    meta: { requestId: res.locals.requestId },
  });
}

export function fail(res, code, message, details) {
  res.status(statusFor[code] ?? 400).json({
    success: false,
    error: {
      code,
      message,
      ...(details?.length ? { details } : {}),
    },
    meta: { requestId: res.locals.requestId },
  });
}
