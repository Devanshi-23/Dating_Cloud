# Architecture

Feature-first MVVM + Clean Architecture + repository pattern, using Riverpod 3 for
dependency injection and state, and GoRouter for navigation.

## Audit (Phase 0)

- **Flutter app**: fresh `flutter create` template (Flutter 3.47.4, Dart 3.13.3).
  No prior app code, assets or packages.
- **Backend**: none for this project. The neighbouring `Dating_app/` folder is a
  separate product that talks to a different backend (`premshetu.com`), so it is **not**
  reused. All API contracts are therefore *proposed* (see `docs/api/`).
- **Integrations**: no Firebase, store billing or storage configuration exists yet.

## Layers and dependency rule

```text
presentation ──► domain ◄── data
 (views,          (entities,      (DTOs, Mock*/Api* repositories,
  viewmodels)      repository      data sources)
                   contracts)
                        ▲
         core/di/repository_providers.dart  (composition root: picks Mock* or Api*)
```

| Layer | Contains | May import |
| --- | --- | --- |
| `domain/` | Plain Dart entities and `abstract interface class XRepository` | Other features' `domain/`, `core/network/pagination.dart`, `core/errors/` |
| `data/` | DTOs (`fromJson`/`toEntity`), `MockXRepository`, `ApiXRepository` | Its own `domain/`, `core/network`, `core/storage`, `dev/mock` (mock repositories only) |
| `presentation/` | Views (widgets), ViewModels (`Notifier` / `AsyncNotifier`) | `domain/`, `core/di/repository_providers.dart`, `core/widgets`, `app/` |
| `core/di/` | Composition root | Everything (only place that imports `data/`) |

Rules that are enforced by convention and covered by tests:

1. ViewModels depend on repository **contracts** via providers and never
   check `DATA_MODE`.
2. Widgets never touch DTOs, Dio or JSON.
3. Only `ApiClient` speaks HTTP. It returns the envelope's `data` and throws
   `Failure` for every error.
4. Repositories throw only `Failure` (`core/errors/failure.dart`), in both
   modes.
5. API mode never falls back to mock data. `mockBackendProvider` throws if it is
   built while no feature uses mocks, and `apiClientProvider` throws if it is built in pure
   mock mode.

## Folder layout

```text
lib/
  main.dart                      # validates AppConfig, then runs ProviderScope (retry disabled)
  app/
    app.dart                     # MaterialApp.router + ConfigErrorApp
    config/app_config.dart       # AppConfig.fromEnvironment / parse + validation, appConfigProvider
    config/environment.dart      # AppEnv, DataMode, DataFeature
    router/                      # app_router.dart, route_names.dart, route_guards.dart (pure), home_shell.dart
    theme/                       # app_theme, app_colors, app_typography, app_spacing
  core/
    di/core_providers.dart       # tokenStore, clock, apiClient, mockBackend providers (guarded)
    di/repository_providers.dart # mock/API selection per DataFeature
    errors/                      # Failure + ErrorCode, ConfigException
    network/                     # ApiClient, AuthInterceptor, ApiEnvelope, ApiEndpoints, Paginated, json helpers
    storage/secure_storage_service.dart  # TokenStore (secure + in-memory)
    widgets/                     # AsyncValueView, Loading/Empty/ErrorView, ProfilePhoto/Avatar
  dev/                           # development-only; unreachable in production API builds
    mock/                        # MockBackend (in-memory store), MockSettings, MockFixtures (fictional), MockAuthDefaults (dev pre-fill)
    presentation/                # Developer tools screen + ViewModel
  features/
    auth/ onboarding/ profile/ discovery/ swipes/ matches/ chat/ subscriptions/   # data/ domain/ presentation/
    settings/presentation/views/me_view.dart
test/
  fixtures/ support/ unit/ widget/
docs/
```

Planned feature folders from the spec (`likes_you`, `calls`,
`notifications`, `moderation`, `support`, `l10n`) are created in the phase
that implements them, so the tree has no empty placeholder folders.

### Deviations from the spec's suggested layout (intentional)

- ViewModel providers are declared next to their ViewModel in
  `presentation/viewmodels/`, instead of in a separate `presentation/providers/` folder.
- Repository bindings live in `core/di/repository_providers.dart`, not in each
  feature, so `presentation/` never imports `data/`.
- Fixtures the running app needs (mock mode) live in `lib/dev/mock/`. Fixtures
  used only by tests live in `test/fixtures/`.
- `GET /conversations/{id}` was added to the API contract. The chat screen needs it to load its header on its own.

## Request lifecycle (API mode)

```text
View ─► ViewModel ─► XRepository (contract)
                         │  ApiXRepository
                         ▼
                     ApiClient ─► AuthInterceptor (Bearer, 401 → refresh once → retry)
                         │
                         ▼
                     Dio ─► server
                         │
         ApiEnvelope.unwrapData / toFailure, mapDioException
                         ▼
             DTO.fromJson ─► entity  |  throw Failure
```

## Request lifecycle (mock mode)

```text
View ─► ViewModel ─► XRepository (contract)
                         │  MockXRepository
                         ▼
                 MockBackend.run(op, body)
                   ├─ simulated latency
                   ├─ failure injection (next / all requests, chosen ErrorCode)
                   ├─ session check (UNAUTHENTICATED when signed out)
                   └─ body(): read/mutate in-memory state → entity | throw Failure
```

## State and navigation

- `sessionViewModelProvider` (app-wide `AsyncNotifier<AuthSession?>`) drives
  GoRouter redirects through `redirectFor()`, which is pure and unit-tested:
  - loading or error → `/splash` (the splash screen shows retry on error)
  - signed out → `/sign-in`
  - signed in → `/discover` and the tab shell (`StatefulShellRoute.indexedStack`)
  - `/me/developer` is blocked unless `AppConfig.showDeveloperTools`
- Screen ViewModels are `autoDispose` and use `ref.mounted` checks after every `await`.
- Riverpod's automatic retry is turned off (`ProviderScope(retry: (_, _) => null)`),
  so failures show up straight away with an explicit **Try again** button.

## Security-relevant design

- Tokens live only in `flutter_secure_storage` (Keychain on iOS, keystore on Android).
- No secrets in the app. `AppConfig` holds URLs and flags only.
- Production builds refuse `mock` or `hybrid` mode unless `ALLOW_INTERNAL_MOCK=true`,
  and the developer tools route is blocked.
- Mock photos use `mock://` URLs rendered as local gradients, so mock mode
  makes **no** network requests (asserted in tests).
- Simulated purchases carry `Entitlement.isSimulated = true` and never reach
  a server.
