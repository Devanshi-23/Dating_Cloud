# Feature Matrix

Status key:

- **Mock Ready**: works end to end in `DATA_MODE=mock`.
- **API Ready**: `Api*Repository` is implemented and tested against the
  proposed contract with a fake HTTP adapter. It still needs a real backend
  (see *Backend*).
- **Backend Needed**: the client cannot be finished until the server
  exists or has the integration configured.
- **Planned**: a later phase. **Optional**: only if configured.

*Backend* is the server status. It is **Not built** for every row, because no
backend exists yet.

| # | Feature | Mock | API client | UI | Backend | Phase |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | App foundation, theme, routing, config, DI | Mock Ready | API Ready | Done | — | 1 ✅ |
| 2 | Auth: phone OTP, session restore, sign-out | Mock Ready (demo + new-account numbers, pre-filled in dev) | API Ready (token refresh, secure storage, OTP challenge) | Welcome, legal drafts, country code, resend countdown | Not built | 1 ✅ / 2 ✅ |
| 2b | Auth: email/password, Apple/Google | Planned | Planned | — | Not built | Deferred (open question 1) |
| 3 | Age gate & onboarding | Mock Ready (real photo picker, simulated location) | API Ready (`POST /profile/onboarding`, `GET /interests`, media upload) | 12-step flow (gender, distance, looking for, lifestyle, photos, bio/prompt, location) + under-18 block | Not built | 2 ✅ |
| 4 | Profile: view own / others, edit, preferences | Mock Ready (repository) | API Ready | Read-only "Me" tab | Not built | 3 |
| 5 | Media upload, photo reorder, verification | Onboarding upload Mock Ready; reorder/verification Planned | Onboarding upload API Ready (`/media/upload-url`, storage `PUT`, `/media/complete`); rest Planned | Onboarding photo grid | Backend Needed (S3 + moderation) | 2 / 3 |
| 6 | Discovery feed + filters | Mock Ready (bundled AI portraits) | API Ready (pagination without repeats, photo prefetch) | Swipe deck with stacked next card (filter sheet in Phase 4) | Not built | 1 ✅ / 4 |
| 7 | Like / pass / super-like / undo | Mock Ready (idempotent) | API Ready (Idempotency-Key reused on retry) | Drag gestures with LIKE/PASS stamps, buttons, fly-out and spring-back animations, reduced motion | Not built | 1 ✅ / 4 (gestures ✅) |
| 8 | Mutual matches, unmatch | Mock Ready | API Ready | Match dialog + list | Not built | 1 ✅ / 4 |
| 9 | Likes You (premium) | Planned | Planned | — | Not built | 4 |
| 10 | Search & filters | Planned (filters in repository contract) | API Ready (query params) | — | Not built | 4 |
| 11 | Chat: list, thread, send text | Mock Ready | API Ready (REST) | Basic | Not built | 1 ✅ / 5 |
| 11b | Realtime (Socket.IO), read receipts, typing, attachments | Planned | Planned | — | Backend Needed | 5 |
| 12 | Voice/video calls | Optional | Optional | — | Backend Needed (provider) | 8 |
| 13 | Push (FCM) + notification inbox | Planned | Planned | — | Backend Needed (Firebase project) | 5 |
| 14 | Safety: block, report, moderation | Planned | Planned | — | Not built | 6 |
| 15 | Subscriptions: products, entitlement | Mock Ready | API Ready | Basic premium section | Not built | 1 ✅ |
| 15b | In-app purchase + server verification | Mock Ready (**simulated**, flagged) | Backend Needed (returns `FEATURE_NOT_CONFIGURED`) | — | Backend Needed (store credentials) | 7 |
| 16 | Settings, privacy, account deletion | Planned | Planned | Sign-out only | Not built | 6 |
| 17 | Help / support, AI assistant | Planned / Optional | Planned | — | Not built | 6 / 8 |
| 18 | Analytics & feature flags | Flags in `AppConfig` | — | — | — | 9 |
| A | Admin / moderator dashboard | — | — | — | Not built (separate web app or API only) | 6 |
| D | Developer tools: latency, failures, empty states, reset | Mock Ready | n/a | Done | n/a | 1 ✅ |

## Mock fixtures available

| Fixture | Count | Notes |
| --- | --- | --- |
| Fictional adult profiles | 12 (+ current user) | `usr_001` to `usr_012`, ages 26–35, AI-generated portraits in `assets/mock/profiles/`, occupation on 10 of 12 |
| "Already liked you" | 4 | `usr_001`, `usr_003`, `usr_005`, `usr_008`: liking them creates a match |
| Seeded matches | 2 | Noor (3 messages), Theo (empty conversation) |
| Products | 3 | Plus monthly, Premium monthly, Premium yearly |
| Interests | 24 | 6 categories, ids like `int_hiking` |
| Sign-in numbers | — | `+919876543210` = onboarded demo account; any other valid number = new account |
| Notifications, reports, verification states | — | Added with Phases 5–6 |
