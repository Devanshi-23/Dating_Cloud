# Dating Cloud API Reference

> **Status: PROPOSED — NOT IMPLEMENTED.** There is no backend for this
> project yet. This document and [`openapi.yaml`](openapi.yaml) define the
> contract the Flutter `Api*Repository` classes are written against. When a
> backend is built, update both files from the real routes and tests.

- Machine-readable spec: [`openapi.yaml`](openapi.yaml) (validated with
  `npx @redocly/cli lint docs/api/openapi.yaml`)
- Errors: [`error_codes.md`](error_codes.md)
- Realtime: [`socket_events.md`](socket_events.md)

## Conventions

| Topic | Rule |
| --- | --- |
| Base URL | `{API_BASE_URL}` = `https://<host>/api/v1` |
| Auth | `Authorization: Bearer <accessToken>` unless marked **Public** |
| Format | JSON, UTF-8, timestamps ISO-8601 UTC |
| Pagination | `?cursor=&limit=` (limit 1–50, default 20). Response `data: { items, nextCursor }`; `nextCursor: null` = last page |
| Idempotency | `Idempotency-Key: <uuid-v4>` on marked endpoints. Replays within 24 h return the original response |
| Rate limits | `429 RATE_LIMITED` + `Retry-After` seconds |
| Blocks | Enforced server-side everywhere. Blocked members return `404 NOT_FOUND` |
| Location | Distances rounded to whole km; coordinates never returned |

**Success envelope**

```json
{ "success": true, "data": { "id": "usr_demo_001" }, "meta": { "requestId": "req_demo_001" } }
```

**Error envelope**

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Please correct the highlighted fields.",
    "details": [{ "field": "displayName", "reason": "REQUIRED" }]
  },
  "meta": { "requestId": "req_demo_002" }
}
```

**Client status legend**: **Used** = called by the app today through an
`Api*Repository`. **Planned** = contract only; the matching client feature
arrives in a later phase (see [`../feature_matrix.md`](../feature_matrix.md)).

**Mock behaviour**: in `DATA_MODE=mock` the matching `Mock*Repository`
simulates each Used endpoint against the in-memory store described in
[`../mock_mode.md`](../mock_mode.md). The Mock column below says what it does.

---

## Auth

### `POST /auth/otp/request` — Used · Public

Send a 6-digit code by SMS. The response never reveals whether the number is
registered.

- **Module**: `auth` · `ApiAuthRepository.requestOtp`
- **Rate limit**: 3 per 10 min per phone; 20 per hour per IP
- **Request**

  | Field | Type | Rules |
  | --- | --- | --- |
  | `phoneNumber` | string | E.164, `^\+[1-9]\d{7,14}$`. The client strips spaces, dashes and brackets |

  ```json
  { "phoneNumber": "+919876543210" }
  ```

- **200**

  ```json
  {
    "success": true,
    "data": { "expiresInSeconds": 300, "resendAfterSeconds": 30 },
    "meta": { "requestId": "req_01" }
  }
  ```

- **Errors**: `400 VALIDATION_ERROR` (bad format), `429 RATE_LIMITED`,
  `500 SERVER_ERROR`
- **Client**: the app validates the number before sending, using the selected
  country code plus the national number (a leading `0` is dropped).
  `resendAfterSeconds` drives the "Resend code in Ns" countdown.
- **Mock**: any E.164 number succeeds (300 s expiry, 30 s resend); anything
  else fails with `VALIDATION_ERROR` on field `phoneNumber`.

### `POST /auth/otp/verify` — Used · Public

Exchange the code for tokens. Creates the account on first use
(`isNewUser: true`). Five wrong attempts invalidate the code.

- **Module**: `auth` · `ApiAuthRepository.verifyOtp` (stores tokens in the
  Keychain or Android keystore via `SecureTokenStore`)
- **Rate limit**: 5 attempts per code; 10 per 10 min per phone
- **Request**

  ```json
  { "phoneNumber": "+919876543210", "code": "123456" }
  ```

- **200**

  ```json
  {
    "success": true,
    "data": {
      "user": { "id": "usr_01HZX", "onboardingComplete": true },
      "isNewUser": false,
      "tokens": {
        "accessToken": "eyJhbGciOiJIUzI1NiJ9.demo.sig",
        "refreshToken": "rt_9f8e7d",
        "expiresIn": 900
      }
    },
    "meta": { "requestId": "req_02" }
  }
  ```

- **Errors**: `400 OTP_INVALID`, `400 OTP_EXPIRED`, `400 VALIDATION_ERROR`,
  `403 ACCOUNT_INELIGIBLE` (under 18 / banned), `429 RATE_LIMITED`
- **Client rule**: the app routes to onboarding when `isNewUser` is true or
  `user.onboardingComplete` is false; otherwise to Discover.
- **Mock**: `123456` signs in as `usr_me`, `000000` returns `OTP_EXPIRED`,
  any other code returns `OTP_INVALID`. Verifying without first requesting a code returns `OTP_EXPIRED`.
  `+919876543210` opens the onboarded demo account; any other number creates a
  fresh account with `onboardingComplete: false`.

### `POST /auth/token/refresh` — Used · Public

Rotate the refresh token. Refresh tokens are single-use; reusing a rotated
token revokes the whole token family.

- **Client**: called automatically by `AuthInterceptor` after any `401`, at
  most once per request. Concurrent 401s share one refresh (queued
  interceptor). If the refresh itself returns 401/403, tokens are cleared and the user is
  signed out.
- **Request** `{ "refreshToken": "rt_9f8e7d" }`
- **200** `data`: `{ "accessToken": "…", "refreshToken": "rt_new", "expiresIn": 900 }`
- **Errors**: `401 UNAUTHENTICATED`, `429 RATE_LIMITED`
- **Mock**: not applicable (mock sessions have no tokens).

### `POST /auth/logout` — Used

Revoke the refresh token.

- **Request** `{ "refreshToken": "rt_9f8e7d" }` · **200** `data: null`
- **Client**: local tokens are always cleared, even if this call fails.
- **Mock**: clears the in-memory session.

### Planned auth endpoints

| Endpoint | Purpose | Request | 2xx `data` | Errors |
| --- | --- | --- | --- | --- |
| `POST /auth/register` · Public | Email sign-up | `{ email, password(10–128), displayName, dateOfBirth, acceptedTermsVersion }` | `AuthResult` (201) | 400, 403 `ACCOUNT_INELIGIBLE`, 409, 429 |
| `POST /auth/login` · Public | Email sign-in | `{ email, password }` | `AuthResult` | 400, 401, 429 |
| `POST /auth/social/{apple\|google}` · Public | Social sign-in. Server verifies `idToken` with the provider | `{ idToken, nonce? }` | `AuthResult` | 400, 401, 403, 501 `FEATURE_NOT_CONFIGURED` |

---

## Profile

### `GET /profile/me` — Used

The signed-in member's profile and preferences. Also used to validate a
restored session on app start (`ApiAuthRepository.currentSession`).

- **Module**: `profile` · `ApiProfileRepository.getMyProfile`
- **200**

  ```json
  {
    "success": true,
    "data": {
      "id": "usr_me",
      "displayName": "Alex Morgan",
      "age": 29,
      "bio": "Product designer. Weekend trail runner.",
      "interests": ["Running", "Design"],
      "photos": [
        { "id": "pho_1", "url": "https://cdn.example.invalid/p/usr_me_0.jpg", "order": 0, "moderationStatus": "APPROVED" }
      ],
      "city": "Pune",
      "distanceKm": null,
      "isVerified": true,
      "phoneNumber": "+919876543210",
      "gender": "MAN",
      "preferences": { "minAge": 24, "maxAge": 36, "maxDistanceKm": 25, "showMe": "EVERYONE" },
      "verificationStatus": "VERIFIED",
      "onboardingComplete": true
    },
    "meta": { "requestId": "req_03" }
  }
  ```

  `onboardingComplete` is required: on app start, `currentSession` reads it to
  decide between onboarding and Discover. `gender` is private (never in
  `PublicProfile`) and `null` before onboarding.

- **Errors**: `401 UNAUTHENTICATED`, `500 SERVER_ERROR`
- **Client rule**: on `401` after a failed refresh the session is cleared;
  on `NETWORK_ERROR` the splash screen shows **retry**. The app never signs the user out just because it is offline.
- **Mock**: returns the `Alex Morgan` fixture.

### `POST /profile/onboarding` — Used

Creates the profile once, after the first sign-in, at the end of the 12-step
setup (name, birthday, gender, who to see, distance, looking for, lifestyle,
about you, interests, photos, bio/prompt, location). Photos are uploaded
first through the [media endpoints](#media--used-for-onboarding-photos) and
referenced by id; later changes use `/profile/photos`.

- **Module**: `onboarding` · `ApiOnboardingRepository.completeOnboarding`
- **Rate limit**: 10 per hour
- **Request**

  ```json
  {
    "displayName": "Sam",
    "dateOfBirth": "1998-02-14",
    "gender": "NON_BINARY",
    "showGender": true,
    "showMe": "WOMEN",
    "maxDistanceKm": 80,
    "relationshipGoal": "LONG_TERM",
    "interestIds": ["int_hiking", "int_coffee"],
    "photoMediaIds": ["med_01HZX", "med_01HZY"],
    "basics": { "drinking": "SOBER", "workout": "OFTEN" },
    "bio": "Coffee first, then adventures.",
    "prompt": { "promptId": "GREEN_FLAG", "answer": "Kindness to waiters." },
    "location": { "latitude": 18.52, "longitude": 73.86 },
    "acceptedTermsVersion": "2026-01"
  }
  ```

  | Field | Rules |
  | --- | --- |
  | `displayName` | 1–40 chars after trimming |
  | `dateOfBirth` | ISO date. Kept private; only the age is public. Under 18 gets `403 ACCOUNT_INELIGIBLE` |
  | `gender` | `WOMAN` · `MAN` · `NON_BINARY` |
  | `showGender` | Whether others see the gender on the profile |
  | `showMe` | `WOMEN` · `MEN` · `EVERYONE` |
  | `maxDistanceKm` | 1–500 (the app's slider offers 1–160, default 80) |
  | `relationshipGoal` | `LONG_TERM` · `LONG_TERM_OPEN_TO_SHORT` · `SHORT_TERM_OPEN_TO_LONG` · `SHORT_TERM_FUN` · `NEW_FRIENDS` · `STILL_FIGURING_OUT` |
  | `interestIds` | 1–10 unique ids from `GET /interests` |
  | `photoMediaIds` | 2–6 unique ids from `/media/complete` (own, purpose `PROFILE_PHOTO`, not rejected), in display order |
  | `basics` | Optional. Question id → option id; ids listed under `ProfileBasics` in `openapi.yaml`. Omitted when empty |
  | `bio` | Optional, ≤ 500 chars. Omitted when empty |
  | `prompt` | Optional. `promptId` from the 6 documented prompts, `answer` 1–150 chars |
  | `location` | Optional. Rounded by the app to 2 decimals (~1 km). Omitted when the member doesn't share a location |
  | `acceptedTermsVersion` | Must equal the current Terms version (`2026-01`) |

- **200** `data`: `MyProfile` with `onboardingComplete: true`, including
  `relationshipGoal`, `basics` and `prompt`
- **Errors**: `400 VALIDATION_ERROR` (field details: `LENGTH_1_40`,
  `COUNT_1_10`, `UNKNOWN_INTEREST`, `COUNT_2_6`, `UNKNOWN_MEDIA`,
  `RANGE_1_500`, `UNKNOWN_OPTION`, `MAX_500`, `INVALID`, `NOT_CURRENT`),
  `401 UNAUTHENTICATED`, `403 ACCOUNT_INELIGIBLE`, `409 CONFLICT` (already
  onboarded), `429 RATE_LIMITED`
- **Client rule**: the app checks age before submitting and shows a blocking
  "adults only" screen whose only action is **Sign out**. The server check is
  the authoritative one; a `403` shows the same screen. On `409` the app goes
  straight to Discover. Terms must be accepted on the location step before the
  location permission is requested; a denied permission offers **Continue
  without location** (and **Open Settings** when permanently denied).
- **Mock**: applies the same rules and errors, using the device clock for age.
  Photos stay on the device and are shown from `file://` paths. The location
  is simulated (a fixed demo point, labelled on screen); no permission prompt.

### `GET /interests` — Used

- **Module**: `onboarding` · `ApiOnboardingRepository.getInterests`
- **200** `data`: `{ "items": [{ "id": "int_hiking", "label": "Hiking", "category": "Outdoors" }] }`
- **Errors**: `401 UNAUTHENTICATED`
- **Mock**: 24 interests in 6 categories (`MockFixtures.interests`).

### `PATCH /profile/me` — Used

Partial update. `age` comes from date of birth and cannot be edited.

- **Request** (at least one field)

  | Field | Rules |
  | --- | --- |
  | `displayName` | 1–40 chars |
  | `bio` | ≤ 500 chars |
  | `interests` | 1–10 strings |
  | `city` | ≤ 80 chars |
  | `occupation` | ≤ 80 chars; empty or `null` clears it |

  ```json
  { "bio": "Product designer. Weekend trail runner." }
  ```

- **200**: same shape as `GET /profile/me`
- **Errors**: `400 VALIDATION_ERROR`, `401`, `429` (30/hour)
- **Mock**: validates `displayName` length (`LENGTH_1_40`) and updates the
  in-memory profile.

### `GET /profiles/{userId}` — Used

Another member's public profile (`PublicProfile`: no phone, preferences or
moderation fields).

- **200** `data`:

  ```json
  {
    "id": "usr_001", "displayName": "Avery", "age": 29,
    "bio": "Board-game host, sunrise hiker.", "interests": ["Hiking", "Coffee"],
    "photos": [{ "id": "pho_001", "url": "https://cdn.example.invalid/p/usr_001_0.jpg", "order": 0 }],
    "city": "Pune", "distanceKm": 3, "isVerified": true,
    "relationshipGoal": "LONG_TERM",
    "basics": { "drinking": "SOBER" },
    "prompt": { "promptId": "GREEN_FLAG", "answer": "Kindness to waiters." }
  }
  ```

  `relationshipGoal`, `basics` and `prompt` are optional. The profile details
  sheet shows them and skips unknown ids.
- **Errors**: `401`, `404 NOT_FOUND` (also when blocked either way)
- **Mock**: looks up the fixture; unknown ID returns `NOT_FOUND`.

### `PUT /profile/preferences` — Used

- **Request / 200 `data`**:
  `{ "minAge": 24, "maxAge": 36, "maxDistanceKm": 25, "showMe": "EVERYONE" }`
  (`minAge` ≥ 18, `minAge` ≤ `maxAge`, distance 1–500, `showMe` is one of
  `WOMEN|MEN|EVERYONE`)
- **Errors**: `400 VALIDATION_ERROR`, `401`
- **Mock**: rejects `minAge < 18` or `minAge > maxAge`.

### Planned profile endpoints

| Endpoint | Purpose | Request | 2xx `data` | Errors / notes |
| --- | --- | --- | --- | --- |
| `PUT /profile/interests` | Replace interests | `{ interestIds: ["int_hiking"] }` (1–10) | `MyProfile` | 400, 401 |
| `POST /profile/photos` | Attach uploaded media (max 6) | `{ mediaId }` | `MyProfile` (201) | 409 when full, 422 `MEDIA_REJECTED` |
| `PATCH /profile/photos/order` | Reorder | `{ photoIds: ["pho_2","pho_1"] }` | `MyProfile` | 400 |
| `DELETE /profile/photos/{photoId}` | Remove (at least 1 must remain) | — | `MyProfile` | 404, 409 |
| `POST /profile/verification` | Selfie verification | `{ selfieMediaId }` | `{ status: "PENDING", submittedAt }` (202) | 429 (3/day) |

## Media — used for onboarding photos

Uploads go straight to S3-compatible storage. The API server never proxies file bytes.
Steps 1–3 are used by `ApiOnboardingRepository.uploadPhoto` as soon as a photo
is picked (image_picker, downscaled to ≤ 1600 px, JPEG quality 85).

1. `POST /media/upload-url` sends `{ purpose: PROFILE_PHOTO|VERIFICATION_SELFIE|CHAT_ATTACHMENT, contentType: image/jpeg|png|heic|webp, sizeBytes ≤ 10 MiB }`
   and gets back `201 { mediaId, uploadUrl, method: "PUT", headers, expiresAt }`.
2. The client `PUT`s the bytes to `uploadUrl` with the returned headers, using
   a separate HTTP client that never sends the API `Authorization` header.
   A storage error is shown on the photo tile with **Retry**.
3. `POST /media/complete` sends `{ mediaId }`. The server checks magic bytes and size, strips EXIF location, queues moderation, and returns
   `{ id, status: PENDING_REVIEW, contentType, url }`. Errors: `422 MEDIA_REJECTED`; a `status` of `REJECTED` is treated the same.
4. `GET /media/{mediaId}` (planned) returns metadata plus a signed read URL valid for 1 hour. Only the owner, or a match for chat attachments, can read it.

Rate limit: 30 upload URLs per hour.

---

## Discovery & swipes

### `GET /discovery` — Used

Ranked candidates. The server excludes: self, anyone already swiped or matched,
blocked in either direction, suspended, and anyone outside *both* members'
preferences.

- **Query**: `cursor`, `limit` (default 10 from the app), `minAge` (18–99),
  `maxAge` (18–99), `distanceKm` (1–500)
- **Example**: `GET /discovery?minAge=18&maxAge=60&distanceKm=50&limit=10`
- **200**

  ```json
  {
    "success": true,
    "data": {
      "items": [
        {
          "id": "usr_001", "displayName": "Avery", "age": 29,
          "bio": "Board-game host, sunrise hiker.", "interests": ["Hiking", "Coffee", "Board games"],
          "photos": [{ "id": "pho_001", "url": "https://cdn.example.invalid/p/usr_001_0.jpg", "order": 0 }],
          "city": "Pune", "occupation": "Game designer", "distanceKm": 3, "isVerified": true
        }
      ],
      "nextCursor": "eyJvIjoxMH0"
    },
    "meta": { "requestId": "req_04" }
  }
  ```

- **Errors**: `400 VALIDATION_ERROR` (e.g. `maxAge < minAge`), `401`, `500`
- **Client**: when 3 or fewer cards remain, `DiscoveryViewModel` fetches the
  next page in the background, drops any profile already shown, and prefetches
  the photos of the next 5 cards. Optional fields (`bio`, `city`,
  `occupation`, `distanceKm`, `photos`) may be empty or missing; the card hides
  those rows and falls back to initials when there is no photo or it fails to
  load.
- **Mock**: filters fixtures by age and distance, excludes swiped and matched
  members, and uses offset cursors (`"10"`). `forceEmpty` returns `items: []`.

### `POST /swipes` — Used · Idempotent

Record like / pass / super-like. If the target already liked the caller, the
server creates the match and conversation **in the same transaction**, so
concurrent mutual likes produce exactly one match.

- **Headers**: `Idempotency-Key: <uuid-v4>`. The app generates one per profile
  and action, and reuses it if the user retries after a failure.
- **Client**: the card leaves the deck as soon as the user swipes, and the
  request runs in the background. Only one request per profile can be in
  flight. On `409` the card stays gone, because the server already has a
  response to that member. On any other error the card returns to the top of
  the deck with a message, so a swipe is never silently lost. A match comes
  only from this response (`isMatch` / `match`); the app then refreshes the
  Matches and Chats lists.
- **Rate limit**: 120/min. Free tier quota: 50 likes + 1 super-like per 24 h,
  then `403 SUBSCRIPTION_REQUIRED` with
  `details: [{ field: "quota", reason: "DAILY_LIKES_EXHAUSTED" }]`
- **Request**

  ```json
  { "targetUserId": "usr_001", "action": "LIKE" }
  ```

  `action` is one of `LIKE | PASS | SUPER_LIKE`.

- **200 — no match**

  ```json
  { "success": true, "data": { "swipeId": "swp_01", "isMatch": false, "match": null }, "meta": { "requestId": "req_05" } }
  ```

- **200 — mutual match**

  ```json
  {
    "success": true,
    "data": {
      "swipeId": "swp_02",
      "isMatch": true,
      "match": {
        "id": "mat_01HZX",
        "otherUser": { "id": "usr_001", "displayName": "Avery", "age": 29, "interests": [], "photos": [], "isVerified": true },
        "matchedAt": "2026-01-15T12:00:00.000Z",
        "conversationId": "cnv_01HZX"
      }
    },
    "meta": { "requestId": "req_06" }
  }
  ```

- **Errors**: `400`, `401`, `403 SUBSCRIPTION_REQUIRED`, `404` (unknown or
  blocked target), `409 CONFLICT` (already swiped this member, or idempotency key reused
  with a different body), `429`
- **Mock**: deterministic. Liking `usr_001`, `usr_003`, `usr_005` or `usr_008`
  creates a match because they "already liked you". Replaying the same key returns the
  original result; a new key on the same target returns `CONFLICT`.

### `POST /swipes/undo` — Used

Undo the most recent swipe that did not create a match.

- **200** `data`: `{ "restoredProfile": { …PublicProfile } }`
- **Errors**: `401`, `403 SUBSCRIPTION_REQUIRED` (free tier), `404` (nothing
  to undo), `409` (last swipe created a match; unmatch instead)
- **Mock**: same rules. No subscription check.

### Planned likes endpoints

| Endpoint | Purpose | 200 `data` | Notes |
| --- | --- | --- | --- |
| `GET /likes/received?cursor=&limit=` | People who liked you, not yet swiped | `{ items: [{ user, action: LIKE\|SUPER_LIKE, likedAt }], nextCursor }` | Free tier gets `403 SUBSCRIPTION_REQUIRED` with `details[0].reason = "COUNT_12"` so the paywall can show the count |
| `GET /likes/sent?cursor=&limit=` | Your pending likes | same | — |

---

## Matches

### `GET /matches` — Used

Active matches, newest first. Paginated.

- **200** `data`: `{ "items": [Match], "nextCursor": null }`, with `Match` shaped as in the swipe example above
- **Errors**: `401`
- **Mock**: 2 seeded matches (`usr_011` Noor, `usr_012` Theo) plus any created
  by swiping.

### `POST /matches/{matchId}/unmatch` — Used

End a match. The conversation closes for both members, and the other member gets no notification.

- **200** `data: null` · **Errors**: `401`, `404`
- **Mock**: removes the match, its conversation and its messages.

### `GET /matches/{matchId}` — Planned

Returns one `Match` to participants only. Anyone else gets `404`.

---

## Chat

### `GET /conversations` — Used

Ordered by most recent activity (last message, else match time).

- **200** `data`:

  ```json
  {
    "items": [
      {
        "id": "cnv_seed_001",
        "matchId": "mat_seed_001",
        "otherUser": { "id": "usr_011", "displayName": "Noor", "age": 27, "interests": [], "photos": [], "isVerified": true },
        "lastMessage": {
          "id": "msg_seed_003", "conversationId": "cnv_seed_001", "senderId": "usr_011",
          "text": "Not yet. Saturday afternoon?", "sentAt": "2026-01-14T16:00:00.000Z",
          "status": "DELIVERED", "clientMessageId": null
        },
        "unreadCount": 1
      }
    ],
    "nextCursor": null
  }
  ```

- **Errors**: `401`

### `GET /conversations/{conversationId}` — Used

One conversation, for participants only. This endpoint was **added** to the original list so the
chat screen can load its header on its own (for example, when opened from a push notification).

- **200** `data`: a `Conversation` · **Errors**: `401`, `404`

### `GET /conversations/{conversationId}/messages` — Used

Oldest-first within a page. `nextCursor` loads **older** messages.

- **Query**: `cursor`, `limit` (default and max 50)
- **200** `data`: `{ "items": [Message], "nextCursor": "msg_cursor_or_null" }`
- **Errors**: `401`, `403 MATCH_REQUIRED` (unmatched), `404`

### `POST /conversations/{conversationId}/messages` — Used · Idempotent

- **Headers**: `Idempotency-Key` = the same value as `clientMessageId`
- **Rate limit**: 30/min per conversation, 300/hour per user
- **Request**

  ```json
  { "text": "Hi Avery!", "clientMessageId": "3f1c2a9e-1d2b-4c5e-9f00-123456789abc" }
  ```

  `text` is trimmed and must be 1–1000 chars.

- **201** `data`:

  ```json
  {
    "id": "msg_01HZX", "conversationId": "cnv_01HZX", "senderId": "usr_me",
    "text": "Hi Avery!", "sentAt": "2026-01-15T12:05:00.000Z",
    "status": "SENT", "clientMessageId": "3f1c2a9e-1d2b-4c5e-9f00-123456789abc"
  }
  ```

- **Side effect**: emits `message:new` over Socket.IO to both participants
  (see [`socket_events.md`](socket_events.md)) and sends a push to the recipient.
- **Errors**: `400 VALIDATION_ERROR` (`text` / `LENGTH_1_1000`), `401`,
  `403 MATCH_REQUIRED`, `404`, `429`
- **Mock**: appends the message to the in-memory store. A replayed `clientMessageId` returns the
  existing message.

### Planned chat endpoints

| Endpoint | Purpose | Request | Notes |
| --- | --- | --- | --- |
| `POST /messages/{messageId}/read` | Mark this and earlier messages read | — | Emits `message:read` |
| `POST /messages/{messageId}/report` | Report a received message | `{ reason, details?, alsoBlock=true }` | 201 `{ id, status: OPEN, createdAt }`; 20/day |

---

## Safety (planned)

| Endpoint | Purpose | Request | 2xx `data` | Notes |
| --- | --- | --- | --- | --- |
| `POST /users/{userId}/block` | Block (also unmatches) | — | `null` | Idempotent |
| `DELETE /users/{userId}/block` | Unblock | — | `null` | Does not restore the match |
| `GET /blocks?cursor=&limit=` | Your blocks | — | `{ items: [{ user: { id, displayName }, blockedAt }], nextCursor }` | — |
| `POST /reports` | Report a member or photo | `{ targetType: USER\|PHOTO, targetId, reason, details?, alsoBlock=true }` | `{ id, status: "OPEN", createdAt }` (201) | 20/day |

`reason` is one of `FAKE_PROFILE`, `INAPPROPRIATE_PHOTOS`, `HARASSMENT`,
`SPAM_OR_SCAM`, `UNDERAGE`, `OFFLINE_BEHAVIOUR`, `OTHER`.

## Notifications (planned)

| Endpoint | Purpose | Request | 2xx `data` |
| --- | --- | --- | --- |
| `POST /devices` | Upsert FCM token | `{ platform: IOS\|ANDROID, pushToken, appVersion?, locale? }` | `{ id, platform, lastSeenAt }` |
| `DELETE /devices/{deviceId}` | Stop pushes (on sign-out) | — | `null` |
| `GET /notifications?cursor=&limit=` | Inbox | — | `{ items: [{ id, type, title, body, data, createdAt, readAt }], nextCursor }` |
| `POST /notifications/{id}/read` | Mark read | — | `null` |
| `GET /notification-preferences` | Read prefs | — | `{ newMatches, messages, likes, promotions }` |
| `PATCH /notification-preferences` | Update prefs (partial) | `{ promotions: false }` | prefs |

`type` is one of `NEW_MATCH`, `NEW_MESSAGE`, `NEW_LIKE`, `VERIFICATION_RESULT`, `SYSTEM`.
Push payloads never include message text or exact location.

---

## Subscriptions

### `GET /subscriptions/products` — Used

- **200** `data` (wrapped in `items`, not paginated):

  ```json
  {
    "items": [
      { "id": "dc_plus_monthly", "tier": "PLUS", "title": "Plus", "description": "Unlimited likes and undo.", "priceLabel": "₹499", "period": "MONTHLY" }
    ]
  }
  ```

  `priceLabel` is for display only. The store purchase sheet shows the authoritative price.

### `GET /subscriptions/entitlement` — Used

The **only** source of truth for premium features. The client never works out entitlement itself.

- **200** `data`:
  `{ "tier": "PLUS", "isActive": true, "expiresAt": "2026-02-15T12:00:00.000Z", "willRenew": true, "platform": "ANDROID" }`
- Inactive (`isActive: false`) is treated as the free tier.

### `POST /subscriptions/verify` — Planned · Idempotent (per store transaction)

- **Request**: `{ "platform": "ANDROID", "productId": "dc_plus_monthly", "transactionProof": "<Play purchase token or App Store JWS>" }`
- **200** `data`: `Entitlement`
- **Errors**: `400`, `401`, `409` (transaction already linked to another
  account), `429` (20/h), `501 FEATURE_NOT_CONFIGURED`
- **Server**: verifies with Apple or Google, then keeps entitlement current through store
  server notifications (renewals, refunds, revocations).
- **Client today**: `ApiSubscriptionRepository.purchase` throws
  `FEATURE_NOT_CONFIGURED` because store billing is not integrated yet (Phase 7).
  **Mock**: `purchase` grants an entitlement flagged `isSimulated: true` that never reaches any server.

### `POST /subscriptions/restore` — Planned

`{ platform, transactionProofs: [...] }` returns an `Entitlement`. Rate limit: 10/h.

---

## Support & account (planned)

| Endpoint | Purpose | Request | 2xx `data` |
| --- | --- | --- | --- |
| `GET /support/faqs` · Public | FAQs | — | `{ items: [{ id, category, question, answer }] }` |
| `POST /support/tickets` | Open ticket (5/day) | `{ category: ACCOUNT\|BILLING\|SAFETY\|BUG\|OTHER, subject(3–120), message(10–5000) }` | `Ticket` (201) |
| `GET /support/tickets/{ticketId}` | Your ticket | — | `{ id, category, subject, status, createdAt, messages[] }` |
| `POST /account/deletion-request` | Schedule deletion | `{ confirm: true, reason?, feedback? }` | `{ status: "SCHEDULED", scheduledFor, activeStoreSubscription }` (202) |
| `GET /account/export-status` | Data export status | — | `{ status: NONE\|PREPARING\|READY\|EXPIRED, downloadUrl?, expiresAt? }` |

Deletion hides the profile immediately and erases data after a 14-day grace
period (signing in cancels it). If `activeStoreSubscription` is true, the app must
tell the member to cancel in the App Store or Play Store.

## Admin (planned · role-protected)

Requires role `MODERATOR` or `ADMIN` in the access-token claims, **verified
server-side against the database**. Members get `403 FORBIDDEN`. Every write
creates an audit log entry.

| Endpoint | Role | Purpose |
| --- | --- | --- |
| `GET /admin/reports?status=&cursor=&limit=` | MODERATOR | Moderation queue |
| `PATCH /admin/reports/{reportId}` | MODERATOR | `{ status: IN_REVIEW\|ACTIONED\|DISMISSED, resolutionNote?, assignToMe? }` |
| `GET /admin/users?q=&status=&cursor=&limit=` | MODERATOR | Search members |
| `PATCH /admin/users/{userId}/status` | MODERATOR (BANNED needs ADMIN) | `{ status: ACTIVE\|WARNED\|SUSPENDED\|BANNED, reason, until? }` |
| `GET /admin/audit-logs?actorId=&targetId=&cursor=&limit=` | ADMIN | Audit trail |
