# Socket.IO Events

> **Status: PROPOSED — NOT IMPLEMENTED** on either side. The Flutter client
> has no socket code yet (Phase 5). REST remains the source of truth: every
> event below has a REST equivalent, so a client that misses events can
> catch up by refetching.

## Connection

| Item | Value |
| --- | --- |
| URL | `SOCKET_BASE_URL`, namespace `/v1` |
| Transport | WebSocket only (no long-polling fallback on mobile) |
| Auth | `auth: { token: "<accessToken>" }` in the handshake. The server verifies the JWT and rejects with `connect_error` `{ code: "UNAUTHENTICATED" }` |
| Token expiry | The server emits `session:expired` and disconnects. The client refreshes through REST and reconnects |
| Reconnect | Exponential backoff 1 s → 30 s with jitter. After reconnecting, refetch `GET /conversations` and open message lists |
| Background | Disconnect when the app is backgrounded. Push (FCM) covers that period |

## Rooms and authorisation

- On connect, the server joins the socket to `user:{userId}`. Clients **cannot**
  join rooms themselves. All events are sent to user rooms, and the server
  checks match membership and blocks before every emit.
- When a match ends (unmatch, block, suspension), the server stops emitting that
  conversation's events to both users at once.

## Server → client events

All payloads use the same schemas as the REST API (`docs/api/openapi.yaml`).

### `message:new`

Sent to both participants after `POST /conversations/{id}/messages` succeeds.

```json
{
  "message": {
    "id": "msg_01HZX", "conversationId": "cnv_01HZX", "senderId": "usr_001",
    "text": "Saturday afternoon?", "sentAt": "2026-01-15T12:05:00.000Z",
    "status": "SENT", "clientMessageId": "3f1c2a9e-1d2b-4c5e-9f00-123456789abc"
  }
}
```

The sender's client removes duplicates using `clientMessageId`.

### `message:read`

```json
{ "conversationId": "cnv_01HZX", "readerId": "usr_001", "upToMessageId": "msg_01HZX", "readAt": "2026-01-15T12:06:00.000Z" }
```

### `typing`

Short-lived and never stored. The server rate-limits it to 1 event per 3 s per conversation.

```json
{ "conversationId": "cnv_01HZX", "userId": "usr_001", "isTyping": true }
```

### `match:new`

Sent to the *other* member when someone else's swipe creates a match. The swiper already gets the match in the REST response.

```json
{ "match": { "id": "mat_01HZX", "otherUser": { "id": "usr_me", "displayName": "Alex Morgan", "age": 29, "interests": [], "photos": [], "isVerified": true }, "matchedAt": "2026-01-15T12:00:00.000Z", "conversationId": "cnv_01HZX" } }
```

### `match:removed`

Covers unmatch, block and moderation. Deliberately gives no reason, so block state doesn't leak.

```json
{ "matchId": "mat_01HZX", "conversationId": "cnv_01HZX" }
```

### `entitlement:updated`

Sent after a store webhook changes entitlement. The client refetches `GET /subscriptions/entitlement`.

```json
{ "tier": "PLUS", "isActive": true }
```

### `session:expired`

```json
{ "code": "UNAUTHENTICATED" }
```

## Client → server events

Every client event takes an acknowledgement callback `ack({ ok: true })` or
`ack({ ok: false, error: { code, message } })`, using the codes in `error_codes.md`.

| Event | Payload | Server checks | Ack errors |
| --- | --- | --- | --- |
| `typing` | `{ conversationId, isTyping }` | Active match, not blocked | `MATCH_REQUIRED`, `RATE_LIMITED` |
| `message:read` | `{ conversationId, upToMessageId }` | Participant | `NOT_FOUND` |

Sending messages over the socket is **not** supported. Use REST, which provides
idempotency, rate limiting and moderation hooks in one place.

## Security notes

- Never trust user IDs in client payloads. The server takes the user from the
  verified token.
- Payloads never include phone numbers, exact location or moderation state.
- Every event is checked for authorisation on emit, not only when joining a room.
