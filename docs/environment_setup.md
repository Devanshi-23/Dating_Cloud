# Environment Setup

## Prerequisites

| Tool | Version used |
| --- | --- |
| Flutter | 3.47.4 (stable) |
| Dart | 3.13.3 |
| Xcode / Android Studio | Current stable, for iOS / Android builds |
| Node.js (optional) | For `npx @redocly/cli lint` (OpenAPI validation) |

```bash
flutter pub get
flutter run            # mock mode on the connected device or simulator
```

## Configuration

All configuration is compile-time (`--dart-define` or `--dart-define-from-file`)
and is read in one place: `AppConfig.fromEnvironment()`
(`lib/app/config/app_config.dart`). It is validated at startup. An invalid
configuration shows a "Invalid app configuration" screen instead of the app.

| Key | Values | Default | Notes |
| --- | --- | --- | --- |
| `APP_ENV` | `development`, `staging`, `production` | `development` | |
| `DATA_MODE` | `mock`, `api`, `hybrid` | `mock` | Production requires `api` |
| `API_BASE_URL` | absolute URL ending in `/api/v1` | — | Required for `api`/`hybrid`; must be `https` in production |
| `SOCKET_BASE_URL` | absolute URL | — | Optional until Phase 5 |
| `HYBRID_MOCK_FEATURES` | comma list of `auth, onboarding, profile, discovery, swipes, matches, chat, subscriptions` | — | Required for `hybrid` |
| `MOCK_LATENCY_MS` | integer ≥ 0 | `600` | |
| `ALLOW_INTERNAL_MOCK` | `true`/`false` | `false` | Internal builds only. Allows mock data in production |
| `FEATURE_CALLS`, `FEATURE_AI_ASSISTANT` | `true`/`false` | `false` | Optional modules |

Files:

- `.env.example` documents every key with placeholders. Copy it to `config/<name>.env`.
- `config/mock.json` is the committed mock profile.
- `config/api.example.json` is a template for a local backend
  (`10.0.2.2` = host machine from the Android emulator; use `localhost` on the
  iOS simulator). Copy it to `config/api.local.json`.
- `config/*.env`, `config/*.local.json` and `.env` are git-ignored.

> Everything passed through `--dart-define` is compiled into the binary and
> can be extracted. **Never** put private API keys, store credentials or
> provider secrets in these files. Those belong on the server.

## Common commands

```bash
# Run
flutter run --dart-define-from-file=config/mock.json
flutter run --dart-define-from-file=config/api.local.json

# Quality gates (run before every change is reported done)
dart format lib test
flutter analyze
flutter test

# Validate the API contract
npx @redocly/cli lint docs/api/openapi.yaml

# Release (example)
flutter build appbundle --dart-define=APP_ENV=production --dart-define=DATA_MODE=api \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

## Platform setup still to do (later phases)

| Item | Phase | Notes |
| --- | --- | --- |
| Android `minSdk`, application ID, signing | 9 | `flutter_secure_storage` needs `minSdk` ≥ 23 (check before release) |
| iOS bundle ID, Keychain sharing (if needed) | 9 | |
| Firebase (`google-services.json`, `GoogleService-Info.plist`) | 5 | Do not commit production Firebase configs to public repos |
| Camera / photo / location / microphone permission strings | 3–5 | Request each only when needed, with an explanation shown first |
| App Store / Play Billing products | 7 | Product IDs must match `GET /subscriptions/products` |
