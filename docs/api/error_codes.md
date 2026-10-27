# Error Codes

Every error response uses this envelope:

```json
{
  "success": false,
  "error": { "code": "CONFLICT", "message": "You already responded to this profile.", "details": [] },
  "meta": { "requestId": "req_01HZF" }
}
```

- `message` must be safe to show users. Never include stack traces, SQL or
  Mongo errors, internal IDs of other members, or secrets.
- `details` lists field-level problems: `{ "field": "displayName", "reason": "REQUIRED" }`.
- `requestId` is logged server-side for support. The client keeps it on `Failure.requestId`.

In Flutter, `ApiEnvelope.toFailure` turns every error into
`Failure(ErrorCode, message, details, requestId, statusCode)`
(`lib/core/errors/failure.dart`). Mock repositories throw the same `Failure`
type, so UI code handles both modes the same way.

| Code | HTTP | Meaning | Client behaviour |
| --- | --- | --- | --- |
| `VALIDATION_ERROR` | 400 / 422 | Input failed validation. `details` names the fields | Show inline field errors |
| `UNAUTHENTICATED` | 401 | Missing, expired or revoked token | Interceptor refreshes once and retries; if refresh fails → clear tokens → sign-in |
| `FORBIDDEN` | 403 | Authenticated but not allowed (e.g. no admin role) | Show message; no retry |
| `NOT_FOUND` | 404 | Doesn't exist **or not visible to the caller** (including blocks) | Show "not available", drop it from local lists |
| `CONFLICT` | 409 | Duplicate action, state conflict, or reused `Idempotency-Key` with a different body | Treat as done, then refresh |
| `RATE_LIMITED` | 429 | Too many requests. `Retry-After` header gives seconds | Show message; retry after the delay |
| `OTP_INVALID` | 400 | Wrong code | Inline error on the code field |
| `OTP_EXPIRED` | 400 | Code expired, used up, or never requested | Ask the user to request a new code |
| `ACCOUNT_INELIGIBLE` | 403 | Under 18, banned, or unsupported region | Blocking screen; no retry |
| `USER_BLOCKED` | 403 | Only returned when acting on the block itself (e.g. messaging someone *you* blocked) | Offer to unblock |
| `MATCH_REQUIRED` | 403 | Chat action without an active match (e.g. after an unmatch) | Close the conversation |
| `SUBSCRIPTION_REQUIRED` | 403 | Premium feature or free quota used up. `details` may say which quota | Show the paywall |
| `MEDIA_REJECTED` | 422 | Upload failed type/size checks or moderation. `details[0].reason` gives the cause | Ask for a different photo |
| `NETWORK_ERROR` | — | **Client-only.** Timeout, no connectivity, TLS failure | "You are offline" + retry. Never replaced with mock data |
| `SERVER_ERROR` | 5xx | Unexpected server failure, or a malformed response the client could not parse | Generic error + retry |
| `FEATURE_NOT_CONFIGURED` | 501 | Integration not configured (server), or not built yet (client) | "Not available yet"; no retry |

Codes the client does not recognise map to `UNKNOWN` and fall back to the HTTP
status: 400/422 becomes validation, 401 unauthenticated, 403 forbidden, 404 not found,
409 conflict, 429 rate limited, 501 not configured, and any other 5xx a server error.

## Common `details.reason` values

| Reason | Used with |
| --- | --- |
| `REQUIRED`, `INVALID_FORMAT`, `OUT_OF_RANGE`, `LENGTH_1_40`, `LENGTH_1_1000` | `VALIDATION_ERROR` |
| `DAILY_LIKES_EXHAUSTED`, `DAILY_SUPER_LIKES_EXHAUSTED`, `COUNT_<n>` | `SUBSCRIPTION_REQUIRED` |
| `NO_FACE_DETECTED`, `EXPLICIT_CONTENT`, `UNSUPPORTED_TYPE`, `TOO_LARGE` | `MEDIA_REJECTED` |
