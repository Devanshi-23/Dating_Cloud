# Dating App — Flutter API Guide

Hand this file to the **Flutter / mobile developer**.

Full detailed contract (same APIs): `admin/API.md`

---

## 1. Setup

### Base URL

```
{HOST}/api/v1
```

| Environment | Base URL |
|-------------|----------|
| **ngrok (device / emulator)** | `https://figure-cancel-snowiness.ngrok-free.dev/api/v1` |
| Local (same machine / iOS sim) | `http://127.0.0.1:5050/api/v1` |

| Service | URL |
|---------|-----|
| REST | `https://figure-cancel-snowiness.ngrok-free.dev/api/v1` |
| Images | `https://figure-cancel-snowiness.ngrok-free.dev/uploads/...` |
| Socket.IO | `wss://figure-cancel-snowiness.ngrok-free.dev/v1` (namespace `/v1`) |

> Free ngrok hostname **changes** when the tunnel restarts. Ask backend for current `APP_URL` in `backend/.env`.

### Required headers

| Header | When | Example |
|--------|------|---------|
| `Content-Type` | JSON body | `application/json` |
| `Authorization` | All protected APIs | `Bearer <accessToken>` |
| `Idempotency-Key` | Swipes + send message | UUID string |
| `ngrok-skip-browser-warning` | Optional (Postman / web) | `true` |

### How every response looks

**Success**
```json
{
  "success": true,
  "data": {},
  "meta": { "requestId": "req_xxx" }
}
```

**Error**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": [{ "field": "email", "reason": "REQUIRED" }]
  },
  "meta": { "requestId": "req_xxx" }
}
```

Always check `success`, then read `data` or `error`.

### Auth rules (must implement)

1. Login / OTP / register → save `accessToken` + `refreshToken` securely.
2. On every protected call → `Authorization: Bearer <accessToken>`.
3. On `401` / `UNAUTHENTICATED` → `POST /auth/token/refresh` with `refreshToken`, save both new tokens, **retry once**.
4. On logout → `POST /auth/logout` (this device) or `/auth/logout-all`.

### Pagination

| Query | Default | Notes |
|-------|---------|-------|
| `cursor` | — | From previous `nextCursor` |
| `limit` | `20` | Max `50` (messages default `50`) |

---

## 2. Typical app flows (how to use)

### A. First-time OTP user

1. `POST /auth/otp/request` → `{ "phoneNumber": "+919876543210" }` (E.164)
2. `POST /auth/otp/verify` → `{ "phoneNumber": "...", "code": "123456" }`  
   *(dev: fixed OTP `123456` — no real SMS yet)*
3. Save tokens
4. Upload 2–6 photos → `POST /media/upload` (`purpose=PROFILE_PHOTO`)
5. `POST /profile/onboarding` with `photoMediaIds`
6. `GET /discovery` → swipe
7. On match → conversations + Socket.IO

### B. Email register / login

1. `POST /auth/register` or `POST /auth/login`
2. Same onboarding / discovery as above if profile incomplete

### C. Returning user

1. Use stored `accessToken`
2. If expired → `POST /auth/token/refresh`
3. `GET /profile/me`, `GET /discovery`, `GET /matches`, `GET /conversations`

---

## 3. Image upload (IMPORTANT)

### Correct API

```
POST /api/v1/media/upload
```

**Content-Type:** `multipart/form-data`  
**Auth:** required  
**Rate limit:** 30 / hour

| Form field | Required | Values |
|------------|----------|--------|
| `file` | Yes | JPG / PNG / WebP, max **10 MB** |
| `purpose` | Yes | `PROFILE_PHOTO` \| `VERIFICATION_SELFIE` \| `CHAT_ATTACHMENT` |

**Flutter example**

```dart
final req = http.MultipartRequest(
  'POST',
  Uri.parse('$baseUrl/media/upload'),
);
req.headers['Authorization'] = 'Bearer $accessToken';
req.fields['purpose'] = 'PROFILE_PHOTO';
req.files.add(await http.MultipartFile.fromPath('file', imagePath));
final streamed = await req.send();
final body = await streamed.stream.bytesToString();
```

**Success `data` includes**
- `mediaId` (use this later)
- `url` (show image)

Then attach:

| Use case | Next API |
|----------|----------|
| Onboarding | `POST /profile/onboarding` → `photoMediaIds: ["med_..."]` |
| Add photo later | `POST /profile/photos` → `{ "mediaId": "med_..." }` |
| Verification | upload with `VERIFICATION_SELFIE` → `POST /profile/verification` |
| Chat image | upload with `CHAT_ATTACHMENT` → send message with `attachmentMediaId` |

### Do NOT use (removed — returns 404)

| Old API | Status |
|---------|--------|
| `POST /media/upload-url` | **Deleted** |
| `POST /media/complete` | **Deleted** |

There is **no** S3 / presigned URL flow anymore. Upload the file directly with multipart.

---

## 4. All APIs — what + how

Base path prefix: `/api/v1`

### Health

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| GET | `/health` | No | Connectivity check |

### Auth

| Method | Path | Auth | Body / notes |
|--------|------|------|--------------|
| POST | `/auth/otp/request` | No | `{ "phoneNumber": "+91..." }` |
| POST | `/auth/otp/verify` | No | `{ "phoneNumber", "code" }` → tokens |
| POST | `/auth/token/refresh` | No | `{ "refreshToken" }` → new tokens |
| POST | `/auth/logout` | Yes | `{ "refreshToken" }` |
| POST | `/auth/logout-all` | Yes | Log out every device |
| POST | `/auth/register` | No | email, password (10–128), displayName, dateOfBirth, acceptedTermsVersion |
| POST | `/auth/login` | No | `{ "email", "password" }` |
| POST | `/auth/social/:provider` | No | `apple` \| `google` — **not configured** (`FEATURE_NOT_CONFIGURED`) |

### Profile

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| GET | `/profile/me` | Yes | Own full profile |
| PATCH | `/profile/me` | Yes | Partial: displayName, bio, interests, city, occupation |
| POST | `/profile/onboarding` | Yes | **Once** after signup — needs 2–6 `photoMediaIds` |
| PUT | `/profile/preferences` | Yes | `{ minAge, maxAge, maxDistanceKm, showMe }` |
| PUT | `/profile/interests` | Yes | `{ "interestIds": ["int_..."] }` (1–10) |
| POST | `/profile/photos` | Yes | `{ "mediaId" }` after upload |
| PATCH | `/profile/photos/order` | Yes | `{ "photoIds": ["pho_..."] }` |
| DELETE | `/profile/photos/:photoId` | Yes | Remove photo |
| POST | `/profile/verification` | Yes | `{ "selfieMediaId" }` |
| GET | `/profiles/:userId` | Yes | Other member public profile |
| GET | `/interests` | Yes | Catalogue for chips / onboarding |

**Onboarding enums**

| Field | Values |
|-------|--------|
| `gender` | `WOMAN`, `MAN`, `NON_BINARY` |
| `showMe` | `WOMEN`, `MEN`, `EVERYONE` |
| `relationshipGoal` | `LONG_TERM`, `LONG_TERM_OPEN_TO_SHORT`, `SHORT_TERM_OPEN_TO_LONG`, `SHORT_TERM_FUN`, `NEW_FRIENDS`, `STILL_FIGURING_OUT` |

### Media

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| POST | `/media/upload` | Yes | Multipart `file` + `purpose` (see §3) |
| GET | `/media/:mediaId` | Yes | Metadata |

### Discovery / likes / matches

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| GET | `/discovery` | Yes | Swipe deck. Query: `minAge`, `maxAge`, `distanceKm` |
| POST | `/swipes` | Yes | Header `Idempotency-Key`. Body `{ "targetUserId", "action": "LIKE"|"PASS"|"SUPER_LIKE" }` |
| POST | `/swipes/undo` | Yes | Premium undo last swipe |
| GET | `/likes/received` | Yes | Who liked you (full list often premium) |
| GET | `/likes/sent` | Yes | Your outgoing likes |
| GET | `/matches` | Yes | Match list (paginated) |
| GET | `/matches/:matchId` | Yes | One match |
| POST | `/matches/:matchId/unmatch` | Yes | End match |

### Chat (REST)

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| GET | `/conversations` | Yes | Inbox list |
| GET | `/conversations/:id` | Yes | Conversation header |
| GET | `/conversations/:id/messages` | Yes | History (`cursor`, `limit`). Does **not** mark read |
| POST | `/conversations/:id/messages` | Yes | Send. Header `Idempotency-Key` **=** body `clientMessageId` (same UUID). Body: `text` and/or `attachmentMediaId` |
| POST | `/messages/:id/read` | Yes | Recipient marks read up to that message |
| POST | `/messages/:id/report` | Yes | `{ "reason", "details?", "alsoBlock?" }` |

**Report reasons:**  
`FAKE_PROFILE`, `INAPPROPRIATE_PHOTOS`, `HARASSMENT`, `SPAM_OR_SCAM`, `UNDERAGE`, `OFFLINE_BEHAVIOUR`, `OTHER`

### Safety

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| POST | `/users/:userId/block` | Yes | Block (idempotent) |
| DELETE | `/users/:userId/block` | Yes | Unblock |
| GET | `/blocks` | Yes | Block list |
| POST | `/reports` | Yes | Report user / photo |

### Devices & notifications

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| POST | `/devices` | Yes | After login: `{ platform: "IOS"|"ANDROID", pushToken, appVersion?, locale? }` |
| DELETE | `/devices/:deviceId` | Yes | On logout of this device |
| GET | `/notifications` | Yes | In-app inbox |
| POST | `/notifications/:id/read` | Yes | Mark one read |
| GET | `/notification-preferences` | Yes | Get toggles |
| PATCH | `/notification-preferences` | Yes | `{ newMatches, messages, likes, promotions }` |

### Subscriptions

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| GET | `/subscriptions/products` | Yes | Paywall UI catalogue |
| GET | `/subscriptions/entitlement` | Yes | Current tier — after login / purchase |
| POST | `/subscriptions/verify` | Yes | Store proof — **501 until configured** |
| POST | `/subscriptions/restore` | Yes | Restore — **501 until configured** |

### Support & account

| Method | Path | Auth | How to use |
|--------|------|------|------------|
| GET | `/support/faqs` | No | Help FAQs |
| POST | `/support/tickets` | Yes | `{ category, subject, message }` — 5/day |
| GET | `/support/tickets/:ticketId` | Yes | Own ticket |
| POST | `/account/deletion-request` | Yes | `{ "confirm": true, reason?, feedback? }` → **202** |
| GET | `/account/export-status` | Yes | Data export status |

**Ticket categories:** `ACCOUNT`, `BILLING`, `SAFETY`, `BUG`, `OTHER`

---

## 5. Socket.IO (realtime chat / matches)

| | |
|--|--|
| URL | Same host, namespace **`/v1`** |
| Transport | **WebSocket only** (`transports: ['websocket']`) |
| Auth | Handshake `auth: { token: "<accessToken>" }` |

**Client → server**

| Event | Payload |
|-------|---------|
| `typing` | `{ conversationId, isTyping }` |
| `message:read` | `{ conversationId, upToMessageId }` |

**Server → client**

| Event | Meaning |
|-------|---------|
| `message:new` | New chat message |
| `message:read` | Read receipt |
| `typing` | Other user typing |
| `match:new` | New match |
| `match:removed` | Unmatch |
| `entitlement:updated` | Subscription changed |
| `session:expired` | Refresh REST token, reconnect socket |

REST is still source of truth — refetch lists after reconnect if needed.

---

## 6. Common error codes

| Code | HTTP | What to do |
|------|------|------------|
| `VALIDATION_ERROR` | 400 | Fix fields in `error.details` |
| `OTP_INVALID` | 400 | Wrong code |
| `OTP_EXPIRED` | 400 | Request new OTP |
| `UNAUTHENTICATED` | 401 | Refresh token, retry once |
| `FORBIDDEN` | 403 | Not allowed |
| `ACCOUNT_INELIGIBLE` | 403 | Suspended / banned / deleted |
| `USER_BLOCKED` | 403 | Block relationship |
| `MATCH_REQUIRED` | 403 | Match / chat no longer valid |
| `SUBSCRIPTION_REQUIRED` | 403 | Show paywall |
| `NOT_FOUND` | 404 | Missing / hidden resource |
| `CONFLICT` | 409 | Duplicate / idempotency mismatch |
| `MEDIA_REJECTED` | 422 | Bad image type/size |
| `RATE_LIMITED` | 429 | Wait `Retry-After` |
| `SERVER_ERROR` | 500 | Retry later |
| `FEATURE_NOT_CONFIGURED` | 501 | Social / IAP / real SMS not wired |

---

## 7. Do NOT call from Flutter

| Path | Why |
|------|-----|
| `/api/v1/admin/*` | Admin panel only |
| `POST /auth/login/2fa` | Staff 2FA only |
| `POST /media/upload-url` | Removed — use `/media/upload` |
| `POST /media/complete` | Removed |

---

## 8. Flutter checklist

- [ ] Base URL = ngrok on real device, or `http://127.0.0.1:5050` on same-machine simulator
- [ ] Persist `accessToken` + `refreshToken` securely
- [ ] `Authorization: Bearer ...` on every protected call
- [ ] On 401 → refresh → retry once
- [ ] OTP: E.164 phone; dev code `123456`
- [ ] Upload via **`POST /media/upload`** (multipart) — **not** `upload-url`
- [ ] `Idempotency-Key` (UUID) on swipes + send message; `clientMessageId` = same UUID
- [ ] `POST /devices` after login for push
- [ ] Socket.IO namespace `/v1` with `auth.token`; handle `session:expired`
- [ ] Handle `RATE_LIMITED` and `FEATURE_NOT_CONFIGURED`
- [ ] Never call `/admin/*` or `/auth/login/2fa`

---

## 9. More detail

Request/response field rules and longer examples: **`admin/API.md`**

*Member APIs only. Generated for the Flutter app.*
