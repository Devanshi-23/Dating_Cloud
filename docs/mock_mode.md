# Mock Mode

Mock mode runs the entire app with **no backend and no network**. It is the
default when no `DATA_MODE` is passed.

```bash
flutter run                                   # mock mode, 600 ms simulated latency
flutter run --dart-define-from-file=config/mock.json
flutter run --dart-define=DATA_MODE=mock --dart-define=MOCK_LATENCY_MS=0
```

## Demo journey

1. **Sign in.** Tap **Get started** and type the demo number **`9876543210`**
   (country code `+91`). The code (**`123456`**) is **pre-filled** on the next
   screen. Code `000000` shows the "expired" error and any other code shows
   "incorrect". (The pre-filled number is a new user; see below.)
2. **Discover.** The first card is *Avery, 29*. Swipe right (or tap ♥) to like,
   swipe left (or tap ✕) to pass. Avery already liked you, so liking her shows
   **It's a match!**
3. **Send a message.** This opens the new conversation. Type and send.
4. **Matches / Chats tabs.** Avery appears next to the seeded matches Noor and Theo.
5. **Me tab.** Tap a plan to make a **simulated** purchase. The status line says
   "SIMULATED purchase — mock mode only".

### New-account journey (onboarding)

The sign-in screen pre-fills a **random** Indian mobile number (never the demo
number) until an account has been saved. Just tap **Next** twice: this creates
a **fresh account** with no matches or chats, and the app opens onboarding. Any
other number you type works the same way:

1. First name (1–40 characters).
2. Birthday as DD / MM / YYYY. Under 18 shows a blocking "adults only" screen
   whose only action is **Sign out**.
3. Gender (Woman, Man, Non-binary) and "Show my gender on my profile".
4. Who you want to see (Women, Men, Everyone).
5. Distance preference slider (1–160 km, default 80).
6. What you're looking for (6 tiles).
7. Lifestyle habits (drinking, smoking, workout, pets). Optional: **Skip**.
8. "What else makes you—you?" (communication, love style, education,
   zodiac). Optional: **Skip**.
9. 1–10 interests from the catalogue.
10. Photos: pick 2–6 from the gallery. This is the **real** device picker in
    mock mode too; the mock "upload" keeps the file on the device and shows it
    from a `file://` path. Failed uploads show **Retry** on the tile.
11. Bio and one prompt answer. Optional: **Skip**.
12. Location: accept the Terms, then **Allow location**. In mock mode the
    location is **simulated** (a fixed demo point; the screen says so) and no
    permission is requested. **Continue without location** is always offered.
    Either one goes to Discover.

**Saved account.** When onboarding finishes, that number and profile
(including photos, copied into the app's documents folder) are **saved on the
device** (`DeviceMockAccountStore`, shared preferences). From then on, sign-in
pre-fills the saved number, and signing in with it opens the finished account
without onboarding, even after restarting the app. Matches and chats are not
saved. Profile and preference edits update the saved copy. Only one account is
saved: finishing onboarding with another number replaces it.

- `+919876543210` always opens the demo account; it is never saved.
- **Reset mock data** (developer tools) forgets the saved account, so the next
  sign-in offers a new random number. Deleting the app also clears it.

The pre-filled values come from `mockAuthDefaultsProvider`
(`lib/dev/mock/mock_auth_defaults.dart`). It returns `null`, so nothing is
pre-filled, whenever auth uses the API or developer tools are hidden. The
random number never leaves the device: mock mode sends no SMS.

Members who already liked you (liking them creates a match): **Avery
(`usr_001`), Priya (`usr_003`), Mira (`usr_005`), Rohan (`usr_008`)**. Liking
anyone else, or passing anyone, never creates a match.

## Developer tools

Go to **Me → Developer tools**. This is only available when `APP_ENV` is not `production`, or
when `ALLOW_INTERNAL_MOCK=true`.

| Control | Effect |
| --- | --- |
| Simulated latency | 0–3000 ms before every mock call |
| Failure injection | **Next request**: the next call fails once. **All requests**: every call fails until turned off |
| Failure type | `NETWORK_ERROR` (offline UI), `SERVER_ERROR`, `RATE_LIMITED`, `UNAUTHENTICATED` |
| Force empty lists | Discovery, matches and chats return no items, to show the empty states |
| Reset mock data | Restores every fixture (swipes, matches, messages, purchases), forgets the saved account, and signs out |

## How it works

- `MockBackend` (`lib/dev/mock/mock_backend.dart`) is an in-memory store
  seeded from `MockFixtures`. Every `Mock*Repository` call goes through
  `MockBackend.run()`, which applies latency, then failure injection, then the session check,
  then reads or changes the state.
- Writes are shared across features, so a like that creates a match immediately
  shows up in matches and chats.
- State is **not** saved to disk. Restarting the app (or pressing *Reset*) returns
  to the fixtures.
- Mock repositories return the same domain entities and throw the same
  `Failure` codes as the API repositories (checked by
  `test/unit/repository_parity_test.dart`).
- Profile photos use `mock://avatar/<id>` URLs. `profileImageProvider` maps them
  to bundled assets in `assets/mock/profiles/<id>.jpg`, so nothing is
  downloaded. These are **AI-generated portraits of people who do not exist**,
  600×800 JPEG, about 1.3 MB in total. If an asset is missing, the photo falls
  back to a gradient with initials. Leo and Elena have no occupation on
  purpose, to show how missing fields are handled.
- Use the failure-injection control in Developer tools while swiping to see a
  card come back with a "try again" message.

## Switching to API mode

No screen or ViewModel changes are needed. Only the build configuration changes:

```bash
cp config/api.example.json config/api.local.json   # edit API_BASE_URL
flutter run --dart-define-from-file=config/api.local.json
```

To keep some features on mock data while the backend catches up:

```bash
flutter run \
  --dart-define=DATA_MODE=hybrid \
  --dart-define=API_BASE_URL=https://staging.example.com/api/v1 \
  --dart-define=HYBRID_MOCK_FEATURES=chat,subscriptions
```

Hybrid mocks **only** the features listed. Features using the API never fall
back to mock data when they fail; they show the real error with **Try again**.

> In hybrid mode each side keeps its own state. Mixing features that depend on
> each other (for example, mock swipes with API matches) will not show a new match in the
> other list. Mock related features together.

## Safety rules

- Production builds (`APP_ENV=production`) refuse `mock` or `hybrid` mode unless
  `ALLOW_INTERNAL_MOCK=true` is set on purpose for internal builds. The app shows a
  configuration error screen instead of starting.
- Developer tools are hidden and their route is blocked in production.
- Mock purchases set `Entitlement.isSimulated = true` and never contact a
  store or server.
- No real credentials are stored and no push notifications are sent in mock mode.
- All fixture people and messages are fictional (see the header of
  `mock_fixtures.dart`). Never add real personal data.

## Tests that prove it

| Test | Proves |
| --- | --- |
| `test/widget/mock_app_flow_test.dart` | The full UI journeys (pre-filled sign-in, like, match, chat; new-number onboarding; under-18 block) run with the API client **poisoned** (it fails the test if created) |
| `test/unit/discovery_view_model_test.dart` | Optimistic swipes, duplicate and rapid-swipe guards, card restored after a failure, match refreshes Matches; API-mode pagination with no repeated cards |
| `test/widget/discover_swipe_test.dart` | Drag right shows LIKE and saves a like; a short drag springs back; drag left passes; rapid taps; reduced motion; empty deck; API mode shows only API profiles; missing fields; brand palette |
| `test/unit/mock_onboarding_test.dart` | Demo vs new account, onboarding validation (photos 2–6, basics, bio, prompt), upload type/size checks, age boundary, `CONFLICT`, defaults hidden in API mode |
| `test/unit/onboarding_view_model_test.dart` | Required vs optional steps, Skip vs Next, distance clamp, photo upload/retry/remove/cap, picker errors, Terms before location |
| `test/unit/mock_journey_test.dart` | Repository-level journey, idempotency, undo, OTP errors, reset |
| `test/unit/mock_scenarios_test.dart` | Latency, failure injection, empty lists, pagination |
| `test/unit/app_config_test.dart` | Production rejects mock unless the override is set |
| `test/unit/api_repositories_test.dart` | API mode never builds the mock backend; errors surface as `Failure` |
