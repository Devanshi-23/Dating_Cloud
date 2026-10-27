# Implementation Plan

Each phase ships as a reviewable change and is only done when it meets the
spec's definition of done:

- Works in mock mode.
- Runs the same UI and ViewModels in API mode.
- Docs (OpenAPI + reference) are updated in the same change.
- Tests are added.
- `dart format`, `flutter analyze` and `flutter test` all pass.

## Phase 0 — Audit and specification ✅

- Audited the repo: fresh template, no backend (see `architecture.md`).
- Wrote `architecture.md`, `feature_matrix.md`, `mock_mode.md`,
  `environment_setup.md` and this plan.
- Wrote `docs/api/openapi.yaml` (58 operations, valid per Redocly), plus
  `api_reference.md`, `error_codes.md` and `socket_events.md`. All are labelled **proposed**.

## Phase 1 — Foundation and mock infrastructure ✅

- Packages: `flutter_riverpod` 3.4, `go_router` 18, `dio` 5.11,
  `flutter_secure_storage` 11, `uuid` 4.
- `AppConfig` with validation (production refuses mock unless the override is set; hybrid
  mode requires an explicit feature list; URL checks).
- `ApiClient` (envelope parsing, error mapping, timeouts, idempotency
  header), `AuthInterceptor` (Bearer, single queued refresh on 401) and
  `SecureTokenStore`.
- Contracts plus mock and API repositories for auth, profile, discovery, swipes,
  matches, chat and subscriptions, chosen per feature in `core/di`.
- `MockBackend`: deterministic fixtures, latency, failure injection, empty
  mode, reset, shared state between features.
- Theme, router with auth guard, tab shell, shared loading/empty/error/offline
  views.
- Foundation screens that prove the journey: splash, sign-in, discover, match dialog,
  matches, chats, conversation, me (with simulated premium) and developer tools.
- 52 tests: config guard, route guard, mock journey, scenarios, API mapping,
  token refresh, idempotency, mock/API parity, widget states, full UI flow.

**Review checkpoint.** The spec says to stop here until the foundation is reviewed.

## Phase 2 — Auth and onboarding ✅

- Welcome screen with Terms/Privacy links. The legal pages hold **draft**
  placeholder text and the version is `2026-01`.
- Sign-in has a country-code picker, client-side number validation, and a
  resend countdown driven by `resendAfterSeconds`.
- In mock mode with developer tools visible, the phone (`+91 9876543210`) and code
  (`123456`) are pre-filled (`mockAuthDefaultsProvider`). Nothing is pre-filled in
  API mode or production.
- Mock accounts: the demo number opens the onboarded demo account. Any other
  number creates a fresh account that goes through onboarding.
- Onboarding (`features/onboarding`) has twelve steps: name, birthday,
  gender (+ show on profile), who to see, distance, looking for, lifestyle,
  about you, interests, photos (2–6, uploaded as picked), bio/prompt, and
  location with Terms acceptance. Lifestyle, about you and bio/prompt can be
  skipped. It submits `POST /profile/onboarding` with the photo media ids.
- Device services: `image_picker` (gallery, downscaled) and `geolocator`
  (approximate, rounded to ~1 km). Mock mode keeps the real picker but
  simulates location. Platform usage strings are in `Info.plist`; Android
  asks for coarse location only.
- Age gate: checked on the client, then enforced by the server
  (`403 ACCOUNT_INELIGIBLE`). Under 18 shows a blocking screen whose only
  action is sign out.
- Router: signed out allows welcome and sign-in only, `needsOnboarding` allows
  onboarding only, and the legal pages are always reachable. Sessions read
  `isNewUser` / `onboardingComplete`.
- 75 tests (up from 52): guards for every state, onboarding rules and errors in mock
  mode, API request/response mapping, and widget journeys for the pre-filled
  sign-in, new-account onboarding and the under-18 block.
- 109 tests after the full onboarding flow: view model rules, mock validation,
  the three-step upload (including no auth header to storage and rejected
  media), request JSON, and a widget journey through all twelve steps plus the
  denied-location path.
- **Deferred**: email/password and Apple/Google (open question 1). Photo crop
  and reorder after onboarding stay in Phase 3.
- **Backend dependency**: SMS provider, OTP storage, the onboarding endpoint
  with a server-side age check, and the media endpoints with storage and
  moderation.

## Phase 3 — Profile and media

- Edit profile, preferences screen, editing interests (`PUT /profile/interests`,
  reusing the onboarding picker).
- Photo crop and reorder (up to 6) after onboarding, reusing the onboarding
  picker and pre-signed upload flow. Mock mode uses local files.
- Selfie verification flow and status.
- Permission prompts with an explanation shown first.
- **Backend dependency**: S3-compatible bucket, image moderation, EXIF stripping.

## Phase 4 — Discovery and matching

- ✅ Done early: drag-to-swipe card stack (`SwipeDeck`) with LIKE/PASS stamps,
  spring-back, fly-out, a stacked next card, optimistic swipes that put the card
  back on failure, photo prefetch, Like/Pass accessibility actions and reduced
  motion. Also the brand palette (`#FD2B7B` → `#FF7158`, `#424242`, white) in
  `app_colors.dart` / `app_theme.dart`.
- Remaining: profile detail view, filter sheet (age/distance), "Likes You" with
  paywall (`COUNT_<n>`), disk image cache if CDN caching proves insufficient.
- Swipe quotas (`SUBSCRIPTION_REQUIRED`), undo gated by entitlement.
- Approximate location (city-level) with consent.
- **Backend dependency**: ranking, atomic mutual-match creation, race-condition tests.

## Phase 5 — Chat and notifications

- Socket.IO client (`socket_events.md`): `message:new`, read receipts, typing,
  reconnect and catch-up. Message pagination, optimistic send with retry.
- FCM device registration, notification inbox, deep links to
  conversations and matches.
- Attachments through the media flow.
- **Backend dependency**: Socket.IO server, Firebase project, push worker.

## Phase 6 — Safety, settings and support

- Block/report from profile, chat and message. Safety centre.
- Settings: notification preferences, privacy, sign out of all devices,
  account deletion (14-day grace), data export status.
- Help centre FAQs and support tickets.
- Admin API (RBAC + audit log). The admin UI is a separate web app (out of scope for
  the mobile app).

## Phase 7 — Subscriptions

- `in_app_purchase` integration, paywall, restore, manage subscription link.
- Server verification (`POST /subscriptions/verify`) plus store server
  notifications. Entitlement comes only from the server.
- Mock purchases stay simulated and flagged.
- **Backend dependency**: App Store Connect and Play Console products, server credentials.

## Phase 8 — Optional features

- Voice/video calls (provider SDK, server-issued tokens) and the AI assistant, each behind a
  feature flag and `FEATURE_NOT_CONFIGURED` until configured.

## Phase 9 — QA and release readiness

- Integration tests on devices (`integration_test/`), accessibility pass
  (semantics, text scale, contrast), localisation (`l10n/`), privacy and security review,
  store compliance (age rating, data-safety forms, account deletion), crash
  reporting, privacy-respecting analytics.

## Open questions for the product owner

1. Is phone OTP the main sign-in method, or should email/password come first?
2. Which SMS, storage, push and calls providers?
3. Target regions? This affects age rules, currency and data-protection laws.
4. Should the admin UI be a separate web app (recommended) or in-app?
5. Final brand name and visual identity. "Dating Cloud" is a working title.
6. Final Terms of Service and Privacy Policy text. The app ships drafts at
   version `2026-01`.
7. Gender options: is Woman / Man / Non-binary enough, or should there be more
   options or a free-text field?
