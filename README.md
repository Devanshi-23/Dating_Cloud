# Dating Cloud

Flutter dating app (Android and iOS) built with feature-first MVVM, Clean Architecture and the
repository pattern, using Riverpod and GoRouter. It runs fully offline in **mock mode** and switches to
a real backend in **API mode** without code changes.

```bash
flutter pub get
flutter run                 # mock mode: a new-user number and code 123456 are pre-filled; demo account is 9876543210
flutter test
```

| Doc | What's in it |
| --- | --- |
| [docs/mock_mode.md](docs/mock_mode.md) | Demo journey, developer tools, switching modes |
| [docs/environment_setup.md](docs/environment_setup.md) | Configuration keys and commands |
| [docs/architecture.md](docs/architecture.md) | Layers, dependency rules, folder layout |
| [docs/feature_matrix.md](docs/feature_matrix.md) | What's mock-ready, API-ready or waiting on the backend |
| [docs/implementation_plan.md](docs/implementation_plan.md) | Phases 0–9 |
| [docs/api/openapi.yaml](docs/api/openapi.yaml) | Proposed REST contract (OpenAPI 3.0) |
| [docs/api/api_reference.md](docs/api/api_reference.md) | Endpoint guide with examples |
| [docs/api/error_codes.md](docs/api/error_codes.md) | Error envelope and codes |
| [docs/api/socket_events.md](docs/api/socket_events.md) | Proposed realtime events |

The original brief is in
[`dating_app_cursor_mock_api_master_prompt.md`](dating_app_cursor_mock_api_master_prompt.md).
