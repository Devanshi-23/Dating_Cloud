# Dating Cloud — Local Backend API

Working API for the Node server in `backend/`. Use this with Postman or the Flutter app in **API mode**.

Related: [error_codes.md](error_codes.md) · [socket_events.md](socket_events.md) · [openapi.yaml](openapi.yaml)

---

## Run the server

```bash
cd backend
cp .env.example .env   # once
npm install            # once
npm start              # http://0.0.0.0:3000
```

| Item | Value |
| --- | --- |
| Base URL (same PC / Postman) | `http://127.0.0.1:3000/api/v1` |
| Base URL (physical phone on Wi‑Fi) | `http://<your-pc-lan-ip>:3000/api/v1` |
| Socket.IO | `ws://<host>:3000/v1` |
| Flutter config | `config/api.local.json` → `DATA_MODE=api` |

Demo account (already onboarded — Alex Morgan):

| Field | Value |
| --- | --- |
| Phone | `+919876543210` (app UI: `9876543210`) |
| OTP | `123456` (`DEV_OTP_CODE` in `backend/.env`) |
| Seed chats | `cnv_seed_001` (Noor), `cnv_seed_002` (Theo) |

Any other valid E.164 number creates a **new** account that must complete onboarding.

Admin demo (from `.env.example`): `+919111111111` → role `ADMIN`.

---

## Conventions

| Topic | Rule |
| --- | --- |
| Auth | `Authorization: Bearer <accessToken>` unless marked **Public** |
| Body | JSON (`Content-Type: application/json`) |
| Timestamps | ISO-8601 UTC |
| Pagination | `?cursor=&limit=` (limit 1–50, default 20). Response: `{ items, nextCursor }` |
| Idempotency | Optional header `Idempotency-Key` on swipe / send-message (24h replay) |

**Success**

```json
{ "success": true, "data": { }, "meta": { "requestId": "req_…" } }
```

**Error**

```json
{
  "success": false,
  "error": { "code": "VALIDATION_ERROR", "message": "…", "details": [] },
  "meta": { "requestId": "req_…" }
}
```

---

## Quick Postman flow (demo user)

1. **GET** `/health` — Public  
2. **POST** `/auth/otp/request` — body `{ "phoneNumber": "+919876543210" }`  
3. **POST** `/auth/otp/verify` — body `{ "phoneNumber": "+919876543210", "code": "123456" }`  
   Copy `data.tokens.accessToken`.  
4. Set header `Authorization: Bearer <accessToken>` on later calls.  
5. Try: **GET** `/profile/me` → **GET** `/discovery` → **GET** `/matches` → **GET** `/conversations` → **GET** `/conversations/cnv_seed_001/messages`

### Did my message reach the other user?

1. **POST** `/conversations/cnv_seed_001/messages` with `{ "text": "hello" }` → expect `201` and `"status":"SENT"`.  
2. **GET** `/conversations/cnv_seed_001/messages` — message must appear (saved for both participants).  
3. Other user marks read: **POST** `/messages/<messageId>/read` → status becomes `READ`.  
4. If the other client is on Socket.IO, they also get `message:new` live.

New messages always start as `SENT`. `DELIVERED` appears only in seed data; live code sets `READ` via the read endpoint / socket `message:read`.

---

## Auth

### `GET /health` — Public

```json
{ "success": true, "data": { "status": "ok" } }
```

### `POST /auth/otp/request` — Public

```json
{ "phoneNumber": "+919876543210" }
```

- Phone: E.164 (`^\+[1-9]\d{7,14}$`)  
- No SMS in local mode; fixed OTP from `.env`  
- Resend cooldown: `OTP_RESEND_SECONDS` (default 30)

**200**

```json
{ "data": { "expiresInSeconds": 300, "resendAfterSeconds": 30 } }
```

### `POST /auth/otp/verify` — Public

```json
{ "phoneNumber": "+919876543210", "code": "123456" }
```

**200**

```json
{
  "data": {
    "isNewUser": false,
    "user": { "id": "usr_me", "onboardingComplete": true },
    "tokens": { "accessToken": "…", "refreshToken": "…" }
  }
}
```

### `POST /auth/token/refresh` — Public

```json
{ "refreshToken": "…" }
```

Returns a new `accessToken` + `refreshToken` pair.

### `POST /auth/logout` — Auth

```json
{ "refreshToken": "…" }
```

### Also available

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/register` | Email/password style register (extended) |
| POST | `/auth/login` | Email/password login (extended) |
| POST | `/auth/social/:provider` | Stub social login (extended) |

---

## Profile & onboarding

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/interests` | Yes | Catalog for onboarding chips |
| POST | `/profile/onboarding` | Yes | Complete new-user profile |
| GET | `/profile/me` | Yes | Own profile + preferences |
| PATCH | `/profile/me` | Yes | `displayName`, `bio`, `interests` |
| PUT | `/profile/preferences` | Yes | `minAge`, `maxAge`, `maxDistanceKm`, `showMe` |
| GET | `/profiles/:userId` | Yes | Public card (not self / not blocked) |
| PUT | `/profile/interests` | Yes | Replace interest list |
| POST | `/profile/photos` | Yes | Attach ready media |
| PATCH | `/profile/photos/order` | Yes | Reorder |
| DELETE | `/profile/photos/:photoId` | Yes | Remove photo |
| POST | `/profile/verification` | Yes | Selfie verification stub |

### `GET /profile/me` (demo shape)

```json
{
  "data": {
    "id": "usr_me",
    "displayName": "Alex Morgan",
    "age": 29,
    "bio": "…",
    "interests": ["Running", "Design", "Chai", "Live music"],
    "photos": [{ "id": "pho_usr_me_0", "url": "mock://avatar/usr_me", "order": 0 }],
    "city": "Pune",
    "onboardingComplete": true,
    "preferences": {
      "minAge": 24,
      "maxAge": 36,
      "maxDistanceKm": 25,
      "showMe": "EVERYONE"
    }
  }
}
```

---

## Media

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | `/media/upload-url` | Yes | Get upload target (`purpose`, `contentType`, `sizeBytes`) |
| PUT | `/media/raw/:mediaId` | No* | Raw bytes (max 10MB) |
| POST | `/media/complete` | Yes | Mark upload ready |
| GET | `/media/files/:mediaId` | No | Serve bytes when `READY` |
| GET | `/media/:mediaId` | Yes | Metadata for own media |

\*Upload URL is issued to the authenticated owner; put uses the returned URL / id.

---

## Discovery, swipes, matches

### `GET /discovery` — Auth

Query (optional): `minAge`, `maxAge`, `distanceKm`, `cursor`, `limit`.

Returns swipeable profiles (seeded candidates), excluding self / already swiped / matched / blocked.

### `POST /swipes` — Auth · Idempotent

```json
{ "targetUserId": "usr_001", "action": "LIKE" }
```

`action`: `LIKE` | `PASS` | `SUPER_LIKE`

If the target is in the seeded `likedMe` set and action is not `PASS`, response includes a new `match` + conversation.

### `POST /swipes/undo` — Auth · Premium

Requires active entitlement; undoes last swipe.

### Matches

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/matches` | List matches |
| GET | `/matches/:matchId` | Single match |
| POST | `/matches/:matchId/unmatch` | Removes match + conversation |

### Likes

| Method | Path |
| --- | --- |
| GET | `/likes/received` |
| GET | `/likes/sent` |

---

## Chat

Seeded for demo user:

| Conversation | Other user |
| --- | --- |
| `cnv_seed_001` | Noor (`usr_011`) |
| `cnv_seed_002` | Theo (`usr_012`) |

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/conversations` | Inbox (`lastMessage`, `unreadCount`) |
| GET | `/conversations/:id` | One thread summary |
| GET | `/conversations/:id/messages` | Message history |
| POST | `/conversations/:id/messages` | Send text / attachment · **201** |
| POST | `/messages/:messageId/read` | Mark read up to that message |
| POST | `/messages/:messageId/report` | Report a message |

### `POST /conversations/:id/messages`

```json
{ "text": "Saturday afternoon?", "clientMessageId": "optional-uuid" }
```

**201**

```json
{
  "data": {
    "id": "msg_…",
    "conversationId": "cnv_seed_001",
    "senderId": "usr_me",
    "text": "Saturday afternoon?",
    "sentAt": "2026-11-02T16:12:09.346Z",
    "status": "SENT",
    "clientMessageId": null,
    "attachment": null
  }
}
```

Also emits Socket.IO `message:new` to both user rooms and creates an in-memory notification for the other user.

---

## Safety, devices, notifications

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/users/:userId/block` | Block |
| DELETE | `/users/:userId/block` | Unblock |
| GET | `/blocks` | Block list |
| POST | `/reports` | Report user / content |
| POST | `/devices` | Register push device stub |
| DELETE | `/devices/:deviceId` | Remove device |
| GET | `/notifications` | In-app notifications |
| POST | `/notifications/:id/read` | Mark one read |
| GET | `/notification-preferences` | Prefs |
| PATCH | `/notification-preferences` | Update prefs |

---

## Subscriptions & support

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/subscriptions/products` | Store product list |
| GET | `/subscriptions/entitlement` | Current tier |
| POST | `/subscriptions/verify` | Verify purchase stub |
| POST | `/subscriptions/restore` | Restore stub |
| GET | `/support/faqs` | Public FAQs |
| POST | `/support/tickets` | Create ticket |
| GET | `/support/tickets/:ticketId` | Ticket detail |
| POST | `/account/deletion-request` | Request deletion |
| GET | `/account/export-status` | Data export stub |

---

## Admin (staff JWT)

Sign in with a phone listed in `STAFF_ROLES` (e.g. `+919111111111:ADMIN`). Members get `403 FORBIDDEN`.

| Method | Path | Min role |
| --- | --- | --- |
| GET | `/admin/reports` | MODERATOR |
| PATCH | `/admin/reports/:reportId` | MODERATOR |
| GET | `/admin/users` | MODERATOR |
| PATCH | `/admin/users/:userId/status` | MODERATOR (`BANNED` needs ADMIN) |
| GET | `/admin/audit-logs` | ADMIN |

---

## Socket.IO (realtime)

| Item | Value |
| --- | --- |
| URL | `{SOCKET_BASE_URL}` namespace `/v1` |
| Transport | WebSocket |
| Auth | Handshake `auth: { token: "<accessToken>" }` |

Server → client events used by this backend:

| Event | When |
| --- | --- |
| `message:new` | After REST send message |
| `message:read` | After read (REST or socket) |
| `typing` | Peer typing |
| `match:new` | Mutual like creates match |
| `match:removed` | Unmatch / undo that removed a match |
| `session:expired` | Access JWT expired |

Client → server: `typing`, `message:read` (with ack callback).

---

## Flutter API mode

`config/api.local.json` (git-ignored; copy from `config/api.example.json`):

```json
{
  "APP_ENV": "development",
  "DATA_MODE": "api",
  "API_BASE_URL": "http://<pc-lan-ip>:3000/api/v1",
  "SOCKET_BASE_URL": "http://<pc-lan-ip>:3000"
}
```

```bash
flutter run --dart-define-from-file=config/api.local.json
```

Phone and PC must be on the same Wi‑Fi. Android debug builds allow cleartext HTTP to the LAN IP.
