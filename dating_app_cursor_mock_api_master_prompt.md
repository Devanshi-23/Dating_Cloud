# Dating App — API Documentation Specification (Cursor Master Prompt)

**Task type:** documentation only\
**Input:** an existing Flutter dating app (Android/iOS) whose screens and
flows already work with mock data\
**Output:** API documentation files under `docs/api/` that describe
what the app does today and the backend contract it will need\
**Out of scope:** building a backend, integrating APIs, or changing the app

Read sections 1–2 before doing anything. They override every other
section of this document.

------------------------------------------------------------------------

## Contents

1.  Scope and strict restrictions
2.  Sources of truth and evidence rules
3.  Deliverables
4.  Documentation workflow
5.  Document templates
6.  API standards for the proposed contract
7.  Security and privacy requirements the contract must express
8.  Reference: proposed endpoint naming catalogue
9.  Reference: capability checklist for gap analysis
10. Reference: target client architecture (future work)
11. Validation process
12. Acceptance criteria
13. Final report
14. Future phases (not part of this task)

------------------------------------------------------------------------

# 1. Scope and strict restrictions

## 1.1 The task

Produce accurate, usable API documentation for the existing app:

-   An inventory of everything the app currently does (screens, routes,
    dialogs, bottom sheets, menus, pickers, forms, user actions, models,
    fixtures, repositories, ViewModels/providers).
-   A screen-by-screen map from each user action to the API it will need
    (or "no API").
-   A proposed REST/realtime contract (Markdown reference + OpenAPI)
    whose request and response schemas are derived from the app's Dart
    models and mock fixtures.
-   A register of assumptions and open questions, consistency check
    results, and a coverage and gap report based on the files actually
    found.

## 1.2 Strict restrictions

These apply for the whole task and take precedence over anything else
in this document, including the reference sections.

1.  **Do not change Dart source code**, tests, `pubspec.yaml`, assets,
    platform folders or generated files.
2.  **Do not modify** existing screens, navigation, design, mock data,
    fixtures or repositories.
3.  **Do not refactor** the app, rename files or "fix" problems you
    find. Record them in the gap report instead.
4.  **Do not implement or integrate APIs**: no API clients, DTOs,
    repositories, interceptors, sockets, backend code or configuration
    changes.
5.  **Do not invent existing endpoints.** No endpoint may be described
    as implemented, live or available unless backend source code or a
    deployed contract proving it is present in the workspace. Everything
    else is labelled **Proposed — not implemented**.
6.  **Do not add features.** Document only APIs that an existing screen
    or action needs, plus the small set of platform APIs that any
    authenticated app requires (token refresh, logout, device
    registration, account deletion). Capabilities the app lacks go in
    the gap report as findings, not as new screens or endpoints you
    design in detail — unless the user asks for them.
7.  **Only create or edit files listed in section 3.** Do not run the
    app implementation workflow, build scripts that change files, code
    generators or formatters over `lib/`.
8.  **Never use real personal data** in examples (names, phone numbers,
    emails, photos). Use clearly fictional values and `example.invalid`
    domains. Do not use other dating apps' trademarks or brand names in
    the documentation.
9.  **Do not claim a check passed unless it was actually run.** If a
    validator cannot run (e.g. no network), say so and describe what was
    checked instead.

If a reference section (8–10) appears to require building something,
treat it as a description of the future target only.

------------------------------------------------------------------------

# 2. Sources of truth and evidence rules

## 2.1 Order of authority

1.  **Backend source code or a deployed contract in the workspace**, if
    any exists (routes, controllers, DTOs, tests). Only this can make an
    endpoint "existing".
2.  **The app's Dart code**: router configuration, screens, widgets,
    dialogs, ViewModels/providers, repositories, models, enums,
    constants and mock fixtures. This is the source of truth for
    *current behaviour* and for field names, types and enum values.
3.  **Client-side API code already in the app**, if present (endpoint
    constants, `Api…Repository` classes, DTOs, an existing
    `openapi.yaml`). Reuse its paths and names; label them **Defined in
    client code — backend not verified**.
4.  **This specification** (standards in sections 6–7, naming in
    section 8) for anything the code does not establish.
5.  **Assumptions** (section 4.8) for everything else, each recorded
    with an ID.

When sources disagree, document the disagreement as a finding; do not
silently pick one.

## 2.2 Current vs proposed — status labels

Every screen action and every API entry carries exactly one status:

| Status | Meaning |
|---|---|
| `Current — local only` | Works today without data (navigation, toggles, animations). No API needed. |
| `Current — mock data` | Works today using fixtures or in-memory mock state. Needs an API in future. |
| `Current — not implemented` | The control exists but does nothing, or only shows mock feedback (e.g. empty `onPressed`, "saved (mock)" snackbar). |
| `Defined in client code — backend not verified` | The app already has API client code for it. |
| `Proposed — not implemented` | A contract designed in this task. |
| `Existing backend` | Proven by backend code or deployed contract in the workspace (rare). |

Never write "implemented", "live" or "available" for an API without the
`Existing backend` evidence.

## 2.3 Citing evidence

-   Every inventory row, model field and current-behaviour statement
    cites its source: `path/to/file.dart` plus the class, method or
    line (e.g. `lib/features/chat/.../chat_list_screen.dart:102`).
-   Every proposed schema field states where it comes from: a Dart
    field (`UserProfile.distanceKm`), a fixture value, a UI element
    (a label or input on screen X), or an assumption ID (`A-007`).
-   Statements without a source must be turned into an assumption or an
    open question.

## 2.4 Deriving schemas from Dart models and fixtures

| Dart | JSON / OpenAPI |
|---|---|
| `String` | `string` |
| `int` | `integer` (`format: int32`/`int64` as appropriate) |
| `double` | `number` (money: see 6.6 — record as a model mismatch if the contract uses minor units) |
| `bool` | `boolean` |
| `DateTime` | `string`, `format: date-time` (UTC ISO-8601); birthdays `format: date` |
| `enum E { a, b }` | `string` with `enum: [a, b]` using the Dart values verbatim (or record the mapping if the API uses `snake_case`) |
| `List<T>` | `array` of the mapped `T` |
| `T?` / optional constructor parameter | not in `required`; `nullable: true` |
| Required constructor parameter | listed in `required` |
| Nested model | `$ref` to a reusable component schema |

Rules:

1.  Keep Dart field names unless there is a stated reason to differ;
    every rename, type change, split or added field is listed in the
    model mapping file with the reason.
2.  When the UI shows data that no model holds (hard-coded strings,
    counts, prices, rates, percentages), design the field, cite the
    widget, and add an assumption.
3.  When the app passes display data where an identifier is needed
    (e.g. a name or image URL in a route query), propose an ID-based
    contract and record a finding.
4.  JSON examples reuse fixture values where they are fictional and
    safe. Replace real-looking personal data and third-party image URLs
    with placeholders (`https://cdn.example.invalid/...`) and note it.

------------------------------------------------------------------------

# 3. Deliverables

Create or update only these files in the app repository. If a file
already exists, update it in place and keep correct existing content.

| File | Purpose |
|---|---|
| `docs/api/app_inventory.md` | Everything the app currently has: screens, routes, dialogs/sheets/menus/pickers, forms, actions, models, fixtures, repositories/providers — each with an ID, source and status. |
| `docs/api/screen_api_map.md` | One section per screen: what it shows, every action → API or "no API", request/response models, auth, errors and UI behaviour. |
| `docs/api/api_reference.md` | Every API operation in the template of section 5.3, grouped by feature. |
| `docs/api/openapi.yaml` | Valid OpenAPI 3.0.3 document for the same operations (section 4.6). |
| `docs/api/data_model_mapping.md` | Dart model ↔ API schema mapping, field by field, with mismatches. |
| `docs/api/error_codes.md` | Error codes, HTTP status, meaning, and how the app should present each. |
| `docs/api/socket_events.md` | Realtime events, only if an existing screen shows live data (typing, presence, new messages, calls). |
| `docs/api/assumptions_and_questions.md` | Assumption and open-question register (section 5.5). |
| `docs/api/api_coverage_report.md` | Discovery record, coverage counts, consistency check results and findings (section 5.6). |

`screen_api_map.md` may hold full API entries instead of
`api_reference.md` repeating them, as long as every operation is
written out in full exactly once and linked from everywhere else.

Do not create implementation plans, architecture rewrites, mock-mode
guides or other documents in this task unless the user asks.

------------------------------------------------------------------------

# 4. Documentation workflow

Work through the steps in order. Each step lists its output.

## 4.1 Step 1 — Discover the project

Find, read and list (with paths) every file relevant to behaviour and
data. At minimum:

-   Router configuration (`GoRouter` routes, `ShellRoute`s, redirects
    and guards) and any `Navigator.push`/`pushNamed` calls.
-   Every screen/view file and its widgets.
-   Dialogs, bottom sheets, pickers and menus: search for
    `showDialog`, `showModalBottomSheet`, `showCupertino…`,
    `showDatePicker`, `showTimePicker`, `PopupMenuButton`,
    `DropdownButton`, `showSearch`, `SnackBar`.
-   Forms and inputs: `Form`, `TextField`, `TextFormField`, sliders,
    switches, chips, radios, segmented buttons, pickers, validators.
-   User actions: `onPressed`, `onTap`, `onChanged`, `onSubmitted`,
    `onSelected`, swipe/drag callbacks, pull-to-refresh, pagination.
-   ViewModels/notifiers/providers, repositories (mock and API),
    services, models/entities/DTOs, enums, constants, mock fixtures.
-   Existing documentation and any API client code or backend code.

Record the search patterns used and the file list in
`api_coverage_report.md` (discovery section) so the counts can be
reproduced.

**Output:** discovery section of the coverage report.

## 4.2 Step 2 — Build the inventory

Fill `app_inventory.md` using the templates in section 5.1:

-   **Screens** (`SCR-###`): route, file, entry points, how it gets its
    data today.
-   **Overlays** (`DLG-###`): dialogs, bottom sheets, menus, pickers,
    snackbars with meaningful feedback — parent screen and trigger.
-   **Forms** (`FRM-###`): fields, types, defaults, validation rules as
    coded (min/max, required, formatters).
-   **Actions** (`ACT-###`): every interactive control, what it does
    today, classification (`Navigation`, `Local state`, `Data read`,
    `Data write`, `Not implemented`, `Mock feedback only`), status
    (2.2) and source line.
-   **Models** (`MDL-###`), **fixtures** (`FIX-###`) and
    **repositories/providers** (`REP-###`).

Include screens with no API (intro slides, demo or state screens) and
mark them "No API" so nothing is skipped.

**Output:** `app_inventory.md`.

## 4.3 Step 3 — Map data models

For each model and enum, write the field table in
`data_model_mapping.md` (template 5.4): Dart field, type, nullability,
example fixture value, proposed API field, JSON type, change type
(`same`, `renamed`, `type changed`, `added`, `removed`, `split`,
`merged`) and reason. Also list UI data that no model holds.

**Output:** `data_model_mapping.md`.

## 4.4 Step 4 — Map each screen to APIs

For every `SCR-###`, write a section in `screen_api_map.md` (template
5.2): what the screen shows (citing widgets), the action table (every
`ACT-###` → API operation or "no API"), load/refresh/pagination
behaviour, and the UI behaviour for loading, empty, success and each
error.

Every action in the inventory must appear in exactly one screen
section.

**Output:** `screen_api_map.md`.

## 4.5 Step 5 — Write the API reference

Write every operation once, in the template of section 5.3, with its
status, the screens and actions that use it, request model, response
model, complete JSON examples, auth, errors and UI behaviour. Reuse
names from client code (2.1 item 3) and section 8 before inventing new
ones.

**Output:** `api_reference.md` (or the full entries inside
`screen_api_map.md`).

## 4.6 Step 6 — Write the OpenAPI document

`docs/api/openapi.yaml` must be a valid OpenAPI **3.0.3** document:

-   `info`: title, version, and a description stating the contract is
    **Proposed — not implemented** (except operations with
    `Existing backend` evidence).
-   `servers`: placeholder URLs only (`https://example.invalid/api/v1`).
-   `tags`: one per feature area.
-   `components.securitySchemes`: `bearerAuth` (`type: http`,
    `scheme: bearer`, `bearerFormat: JWT`). Public operations set
    `security: []`. Role requirements (`moderator`, `admin`) are stated
    in the description and in `x-required-role`.
-   `components.schemas`: reusable schemas for every model, the success
    envelope, list envelope with `meta.nextCursor`, error envelope,
    `Money` and enums. Operations reference them with `$ref`; avoid
    repeating inline objects.
-   `components.parameters`: reusable `cursor`, `limit`,
    `Idempotency-Key` and path ID parameters.
-   `components.responses`: reusable error responses (400, 401, 402,
    403, 404, 409, 422, 429, 500, 501, 502).
-   Every operation: unique `operationId` matching the API name in the
    Markdown docs (camelCase of the name), `summary`, `tags`,
    `security`, parameters, `requestBody` where relevant, success and
    error responses, at least one **example** per request and success
    response, and these extensions:
    -   `x-status`: one of the labels in 2.2
    -   `x-screens`: list of `SCR-###` IDs (or `platform` for
        refresh/logout/device registration)
    -   `x-source-models`: Dart models the schemas derive from
    -   `x-assumptions`: assumption IDs, if any
-   Examples must validate against their schemas.
-   Do not use features not in 3.0.3 (e.g. `type: [string, "null"]`);
    use `nullable: true`. Do not put `nullable` next to a bare `$ref`;
    wrap with `allOf` or leave the field non-nullable.

**Output:** `openapi.yaml`.

## 4.7 Step 7 — Errors, realtime events and push payloads

-   `error_codes.md`: every code used in the docs (6.3), HTTP status,
    meaning, retryable or not, and the exact UI behaviour (message,
    redirect, retry button).
-   `socket_events.md` (only if a screen shows live data): connection
    and auth, rooms, each event name, direction, payload schema,
    acknowledgements, reconnect behaviour, authorization rules and the
    screens that use it.
-   Push payloads (in `socket_events.md` or the screen map): type,
    data fields and the screen each opens.

**Output:** `error_codes.md`, `socket_events.md` if needed.

## 4.8 Step 8 — Record assumptions and open questions

Whenever the code does not establish part of a contract (an ID format,
a validation limit, pagination size, a business rule, a price, a
permission), record it in `assumptions_and_questions.md` using
template 5.5:

-   **Assumption** (`A-###`): a decision made so the docs can be
    complete; the docs proceed on it.
-   **Open question** (`Q-###`): a decision only the product owner or
    backend team can make; the docs show the default chosen and mark it.

Reference the IDs from every API entry, schema field and OpenAPI
operation that depends on them.

**Output:** `assumptions_and_questions.md`.

## 4.9 Step 9 — Run consistency checks

Run every check in section 11.2 and record each result (pass, or the
list of failures and how they were fixed) in the coverage report. Fix
documentation until every check passes or the remaining failures are
explained as findings.

**Output:** consistency section of `api_coverage_report.md`.

## 4.10 Step 10 — Produce the coverage and gap report

Complete `api_coverage_report.md` (template 5.6): discovery record,
coverage table with counts, consistency results and findings:

-   **Undocumented items**: screens, overlays, forms or actions found in
    code but missing from the docs (should be zero at the end).
-   **Actions without implementation**: empty handlers, TODOs, controls
    that only show mock feedback, hard-coded values standing in for
    data.
-   **Model mismatches**: differences between Dart models and the
    proposed schemas (types, names, missing fields, display data used
    as identifiers, floating-point money, free-text where an enum is
    needed).
-   **Missing backend dependencies**: services the contract relies on
    that do not exist yet (SMS/OTP provider, push, media storage,
    content moderation, payment gateway or store billing, RTC/calls,
    email, analytics).
-   **Capabilities the app lacks** compared with section 9 (findings
    only; not designed in detail unless asked).
-   **Policy and security concerns** found in the current UI (e.g. card
    details collected in app code, admin entries visible to all users,
    demo controls in production screens).

**Output:** `api_coverage_report.md`.

## 4.11 Step 11 — Final review

Re-read all deliverables for contradictions, duplication and missing
requirements; confirm every acceptance criterion in section 12; confirm
no file outside section 3 changed (11.1); then write the final report
(section 13).

------------------------------------------------------------------------

# 5. Document templates

## 5.1 Inventory rows (`app_inventory.md`)

**Screens**

| ID | Screen | Route (path + params) | File | Reached from | Data source today | Status |
|---|---|---|---|---|---|---|
| SCR-011 | Home swipe deck | `/home` | `lib/features/home/presentation/home_swipe_screen.dart` | bottom nav, onboarding end | `MockData.discoverProfiles` | Current — mock data |

**Overlays** (dialogs, sheets, menus, pickers, snackbars)

| ID | Kind | Parent | Trigger | Contents / options | Source | Status |
|---|---|---|---|---|---|---|

**Forms**

| ID | Screen | Field | Input type | Default | Validation as coded | Source |
|---|---|---|---|---|---|---|

**Actions**

| ID | Screen / overlay | Control | Behaviour today | Class | Status | Source |
|---|---|---|---|---|---|---|
| ACT-045 | SCR-017 Chat detail | Menu → Block | does nothing | Not implemented | Current — not implemented | `chat_detail_screen.dart:91` |

**Models, fixtures, repositories/providers**

| ID | Name | Kind | File | Used by |
|---|---|---|---|---|

## 5.2 Screen section (`screen_api_map.md`)

```` markdown
### SCR-011 Home swipe deck — `/home`

**File:** `lib/features/home/presentation/home_swipe_screen.dart`
**Status today:** Current — mock data (`MockData.discoverProfiles`)
**Shows:** header, filter button, notification bell with count, profile
cards (photos, name, age, verified, job, bio, interests, distance,
online), Rewind / Nope / Super Like / Like / Boost.

| Action | Today | API | Request model | Response model |
|---|---|---|---|---|
| ACT-030 Open screen | mock list | Get Discovery Feed | — (query params) | `DiscoveryProfilePage` |
| ACT-033 Like | local swipe, fake match | Swipe Profile | `SwipeRequest` | `SwipeResult` |
| ACT-036 Filter button | navigation | no API | — | — |

**UI behaviour**

| State | Trigger | Shown as |
|---|---|---|
| Loading | first page request | skeleton cards |
| Empty | `items: []` | "No more profiles" + widen filters |
| Error | `NETWORK_ERROR` / `SERVER_ERROR` | error state with Retry (never mock data) |

**Assumptions / questions:** A-012, Q-004
````

## 5.3 API entry (`api_reference.md`)

Every operation uses this layout, in this order:

1.  **Header table:** API name, Type, URL, Auth, Status.
2.  **Used by:** screen and action IDs.
3.  **Params:** every path, query, header (e.g. `Idempotency-Key`) and
    body parameter with In, Type, Required, Description and Source, or
    `Params: None`. Common headers (`Authorization`, app version,
    platform, language) are documented once in the standards section,
    not repeated.
4.  **Request model:** schema name (matching OpenAPI) — omit if no body.
5.  **Response:** status code, response model name and the complete
    JSON body including the envelope (`204 No Content` says "empty
    body").
6.  **Errors and UI behaviour:** status, `error.code` and what the
    screen does.
7.  **Notes:** pagination, idempotency, rate limits, security, mock
    behaviour today, assumption/question IDs.

```` markdown
#### API: Request OTP

| API name | Type | URL | Auth | Status |
|---|---|---|---|---|
| Request OTP | `POST` | `/auth/otp/request` | None | Proposed — not implemented |

**Used by:** SCR-003 Login → ACT-010 Continue; SCR-004 OTP → ACT-014 Resend

**Params**

| Param | In | Type | Required | Description | Source |
|---|---|---|---|---|---|
| `phone` | body | string (E.164) | Yes | e.g. `+919000000001` | `login_screen.dart` phone field |
| `channel` | body | string | No | `sms` (default) | A-003 |

**Request model:** `OtpRequest`

**Response — `200 OK`** · model `OtpChallenge`

```json
{
  "success": true,
  "data": { "challengeId": "otp_ch_9f2", "codeLength": 6, "expiresInSec": 300, "resendAfterSec": 42 },
  "meta": { "requestId": "req_004" }
}
```

**Errors and UI behaviour**

| Status | Code | Screen behaviour |
|---|---|---|
| 400 | `VALIDATION_ERROR` | error under the phone field |
| 429 | `RATE_LIMITED` | "Try again in N s" using `details.retryAfterSec` |
| 502 | `PROVIDER_ERROR` | snackbar + Retry |

**Notes:** 5 requests/hour per phone (A-004). Today the screen navigates
to OTP without any request (Current — mock data).
````

## 5.4 Model mapping (`data_model_mapping.md`)

```` markdown
### MDL-003 `ChatThread` → `ConversationSummary`

**Dart source:** `lib/data/models/chat_models.dart`

| Dart field | Dart type | Example (fixture) | API field | JSON type | Change | Reason |
|---|---|---|---|---|---|---|
| `id` | `String` | `c1` | `id` | string | same | — |
| `user` | `String` | `Sofia` | `peer` | `UserSummary` | type changed | chat needs the peer's ID and photo, not only a name |
| `isTyping` | `bool` | `false` | — | — | removed | comes from the `typing` socket event (A-021) |
| — | — | — | `matchId` | string | added | links chat to match (A-022) |
````

## 5.5 Assumption / question entry

| ID | Type | Statement | Why needed | Evidence in code | Affects | Default used | Status |
|---|---|---|---|---|---|---|---|
| A-004 | Assumption | OTP request limit is 5/hour per phone | contract needs a rate limit | none | Request OTP | 5/hour | Open for review |
| Q-002 | Question | Are subscriptions paid via store billing or the in-app wallet? | wallet history shows a subscription debit | `mock_data.dart` transaction `t3` | Premium, Wallet | store billing | Needs product owner |

## 5.6 Coverage report (`api_coverage_report.md`)

Required sections, in this order:

**1. Discovery record** — date, repository path, search patterns used,
and the list of files scanned grouped by kind.

**2. Coverage table** — counts taken from the inventory, never
estimated. `n` stands for the real counted number.

| Category | Found in code | Documented | Missing | Missing IDs |
|---|---|---|---|---|
| Routes | n | n | n | … |
| Screens | n | n | n | … |
| Overlays | n | n | n | … |
| Forms / fields | n | n | n | … |
| Actions | n | n | n | … |
| Actions needing an API | n | n mapped | n | … |
| Models / enums | n | n mapped | n | … |
| API operations | — | n | n not used by any screen | … |

A percentage may be shown only as `documented / found` next to the two
numbers it is computed from.

**3. Consistency check results** — each check in 11.2 with pass/fail
and details.

**4. Findings** — the categories in 4.10, each item with an ID
(`GAP-###`), source, impact and recommended next step (a
recommendation only; nothing is changed in this task).

**5. Not checked** — anything that could not be verified, and why.

------------------------------------------------------------------------

# 6. API standards for the proposed contract

These apply to proposed operations. If an existing backend or client
contract uses different conventions, document and follow those instead
and note the difference.

## 6.1 Base URL, versioning and headers

-   All paths are under `/api/v1`; docs show paths relative to
    `API_BASE_URL` (placeholder `https://example.invalid/api/v1`).
-   Common headers: `Authorization: Bearer <accessToken>` (protected
    operations), `Content-Type: application/json`, `Accept-Language`,
    `X-App-Version`, `X-Platform`.
-   `Idempotency-Key` (UUID, reused on retry) is required for swipes,
    message sends, purchases/recharges, call start, reports and other
    writes where a duplicate would cause harm.

## 6.2 Response envelope

Success:

``` json
{
  "success": true,
  "data": { "id": "usr_demo_001", "name": "Avery" },
  "meta": { "requestId": "req_demo_001" }
}
```

Error:

``` json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Please correct the highlighted fields.",
    "details": [{ "field": "name", "reason": "REQUIRED" }]
  },
  "meta": { "requestId": "req_demo_002" }
}
```

Never expose stack traces, secrets or internal database details.

## 6.3 Error codes

Document and map at least: `VALIDATION_ERROR`, `UNAUTHENTICATED`,
`FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `RATE_LIMITED`, `OTP_INVALID`,
`OTP_EXPIRED`, `ACCOUNT_INELIGIBLE`, `USER_BLOCKED`, `MATCH_REQUIRED`,
`SUBSCRIPTION_REQUIRED`, `MEDIA_REJECTED`, `NETWORK_ERROR` (client
only), `SERVER_ERROR`, `FEATURE_NOT_CONFIGURED`. Add only if the app
needs them: `INSUFFICIENT_BALANCE` (wallet too low), `PAYMENT_FAILED`
(user not charged), `CALL_UNAVAILABLE` (callee busy/offline),
`PROVIDER_ERROR` (SMS, payment, RTC or storage provider failed;
retryable).

## 6.4 Pagination, filtering and sorting

Cursor pagination: `?cursor=<opaque>&limit=<1–50>`; list responses put
items in `data.items` and `nextCursor`/`hasMore` in `meta`. Document the
default sort and every filter parameter with its type and range.

## 6.5 Identifiers and navigation

Opaque prefixed string IDs (`usr_`, `mat_`, `cnv_`, `msg_`, …). Screens
are opened by ID (match, conversation, call, reported user), not by
display names or image URLs in route parameters; where the current app
does otherwise, record a finding.

## 6.6 Data formats

-   Timestamps: ISO-8601 UTC. Birthdays: `YYYY-MM-DD`.
-   Money: integer minor units + ISO currency, e.g.
    `{ "amountMinor": 124950, "currency": "INR" }`. If the Dart model
    uses `double`, record the mapping in `data_model_mapping.md`.
-   Phone numbers: E.164.
-   Distance: rounded kilometres; never exact coordinates.

## 6.7 Authentication and roles

Bearer access token with refresh-token rotation. Roles (`member`,
`moderator`, `admin`) are issued by the server; the client may use them
only to hide UI, and every role-protected operation enforces them.

------------------------------------------------------------------------

# 7. Security and privacy requirements the contract must express

Document these as rules in the relevant API entries (they describe the
future backend; nothing is implemented here):

-   Adults-only eligibility checked server-side.
-   Approximate location only; never expose exact coordinates.
-   No API keys or provider secrets in the app; the app receives only
    short-lived tokens or public keys from API responses.
-   Ownership/authorization checks on every protected operation; blocks
    enforced server-side across discovery, search, chat and calls.
-   Never trust client-provided roles, match state, moderation status
    or subscription entitlement.
-   Rate limits for OTP, swipes, messages, reports, search, calls,
    recharges and purchase verification.
-   Upload type/size limits and content moderation.
-   Purchases verified server-side (store receipts/tokens); payment
    gateway flows use the provider's checkout SDK, and card numbers/CVV
    are never collected by app code or sent to the backend; wallet
    credits happen exactly once (confirm + webhook, idempotent).
-   Calls: short-lived RTC tokens for the two participants only, mutual
    match required, duration metered and charged on the server, rates
    served by the API.
-   RBAC and audit logs for admin/moderator operations; evidence access
    limited to flagged content.
-   Account deletion workflow appropriate to store policy and law.
-   Minimize and redact personal data in logs and analytics; never send
    message content, exact location or sensitive profile fields to
    analytics.
-   Mock/simulated purchases or payments must be labelled simulated and
    never grant real entitlements.

------------------------------------------------------------------------

# 8. Reference: proposed endpoint naming catalogue

Use these names when an existing screen or action needs the capability,
so documentation stays consistent across projects. **Do not document an
operation from this list unless an inventory action, a platform need
(1.2 rule 6) or the user requires it.** All entries are proposed unless
section 2.1 evidence says otherwise.

-   **App config:** `GET /app/config` (minimum version, maintenance,
    legal URLs/version, feature flags)
-   **Auth:** `POST /auth/otp/request`, `POST /auth/otp/verify`,
    `POST /auth/social/{provider}`, `POST /auth/register`,
    `POST /auth/login`, `POST /auth/token/refresh`, `POST /auth/logout`
-   **Devices:** `POST /devices`, `DELETE /devices/{deviceId}`
-   **Profile & onboarding:** `GET/PATCH /profile/me`,
    `GET /profiles/{userId}`, `GET/PUT /profile/preferences`,
    `POST /profile/onboarding` (single submission),
    `POST /profile/onboarding/complete` (step-by-step),
    `GET /profile/stats`, `GET /me/badges`, `GET /interests`,
    `PUT /profile/interests`, `POST /profile/photos`,
    `PATCH /profile/photos/order`, `DELETE /profile/photos/{photoId}`,
    `POST /profile/verification`
-   **Media:** `POST /media/upload-url`, `POST /media/complete`,
    `GET /media/{mediaId}`
-   **Discovery & swipes:** `GET /discovery`, `POST /swipes`,
    `POST /swipes/undo`, `POST /boosts`, `GET /likes/received`,
    `GET /likes/sent`
-   **Search:** `GET /users/search`
-   **Matches:** `GET /matches`, `GET /matches/{matchId}`,
    `POST /matches/{matchId}/unmatch`
-   **Chat:** `GET /conversations`, `GET /conversations/{conversationId}`,
    `GET/POST /conversations/{conversationId}/messages`,
    `POST /messages/{messageId}/read` (marks this and earlier messages),
    `POST /messages/{messageId}/report`
-   **Calls:** `POST /calls`, `GET /calls/{callId}`,
    `POST /calls/{callId}/accept`, `POST /calls/{callId}/decline`,
    `POST /calls/{callId}/end`
-   **Wallet:** `GET /wallet`, `GET /wallet/transactions`,
    `GET /wallet/recharge-options`, `POST /wallet/recharges`,
    `POST /wallet/recharges/{rechargeId}/confirm`,
    `GET /wallet/recharges/{rechargeId}`, `GET /gifts`,
    `POST /gifts/send`
-   **Safety:** `POST/DELETE /users/{userId}/block`, `GET /blocks`,
    `POST /reports`
-   **Notifications:** `GET /notifications`,
    `POST /notifications/{notificationId}/read`,
    `POST /notifications/read-all`,
    `GET/PATCH /notification-preferences`
-   **Privacy:** `GET/PATCH /settings/privacy`
-   **Subscriptions:** `GET /subscriptions/products`,
    `GET /subscriptions/entitlement`, `POST /subscriptions/verify`,
    `POST /subscriptions/restore`
-   **Support & account:** `GET /support/faqs`, `POST /support/tickets`,
    `GET /support/tickets/{ticketId}`,
    `POST /account/deletion-request`, `GET /account/export-status`
-   **Admin (role-protected):** `GET /admin/reports`,
    `PATCH /admin/reports/{reportId}`, `GET /admin/users`,
    `PATCH /admin/users/{userId}/status`, `GET /admin/audit-logs`,
    `GET /admin/analytics/overview`, `GET /admin/fraud-alerts`,
    `GET /admin/moderation/stats`, `GET /admin/moderation/queue`,
    `GET /admin/moderation/items/{itemId}`,
    `POST /admin/moderation/items/{itemId}/dismiss`,
    `POST /admin/moderation/items/{itemId}/action`
-   **Realtime events:** `conversation:join`/`leave`, `message:new`,
    `message:read`, `typing:start`/`stop` → `typing`, `presence`,
    `conversation:updated`, `match:new`, `badges:update`, and if calls
    or wallet exist: `call:incoming`, `call:accepted`, `call:declined`,
    `call:ended`, `call:balance_low`, `wallet:updated`

------------------------------------------------------------------------

# 9. Reference: capability checklist for gap analysis

Compare the inventory with this list and report missing capabilities as
findings in the coverage report. **Do not build them**, and do not
design full contracts for them unless the user asks.

-   **Member:** splash/intro, sign-in (phone OTP, social), terms and
    privacy, age gate, onboarding (name, birthday, gender, bio, photos,
    interests, partner preferences), profile view/edit, photo
    reorder, verification, discovery and filters, like/pass/super
    like/undo, match celebration, match list, Likes You, search, chat
    (text, media, voice notes, typing, read receipts), optional calls,
    notifications inbox and preferences, block/report, blocked users,
    privacy settings, premium paywall and restore, optional wallet and
    gifts, help/support, account deletion, offline/empty/error/
    maintenance states.
-   **Admin/moderator (role-gated):** analytics (aggregates only),
    moderation queue with evidence and actions, report triage, user
    status changes, fraud alerts, audit logs.
-   **Platform:** forced update/maintenance, push registration, token
    refresh, logout.

------------------------------------------------------------------------

# 10. Reference: target client architecture (future work)

This describes how the documented contract is expected to be consumed
later. It helps choose names and boundaries in the documentation. **It
is not part of this task; do not create or change any of it.**

-   Feature-first MVVM + Clean Architecture + Repository Pattern,
    Riverpod for DI/state, GoRouter for navigation.
-   Each feature has a domain repository contract with two
    implementations, `Mock…Repository` and `Api…Repository`, selected
    by configuration (`DATA_MODE=mock|api`); ViewModels depend only on
    the contract.
-   API mode never falls back to mock data silently; it shows the real
    error with Retry. Missing endpoints surface as
    `FEATURE_NOT_CONFIGURED`.
-   DTOs map to domain entities inside repositories; widgets never see
    transport models.
-   Production builds reject mock mode; no secrets in the app; tokens in
    secure storage.

When the documentation reveals that the current app differs from this
target (e.g. widgets reading fixtures directly), record a finding.

------------------------------------------------------------------------

# 11. Validation process

## 11.1 Scope check

Run `git status --porcelain` (and `git diff --stat`) in the app
repository and confirm that the only changed or new files are those in
section 3. If anything else changed, revert your change to it and
report it.

## 11.2 Consistency checks

Run each check (scripted where practical) and record the result in the
coverage report:

1.  **Inventory completeness:** every route in the router, every
    screen file, every overlay call and every interactive control found
    in step 1 has an inventory ID.
2.  **Action mapping:** every `ACT-###` appears in exactly one screen
    section with an API operation or "no API".
3.  **Screen map ↔ API reference:** every operation named in the screen
    map has a full entry; every entry is used by at least one screen
    action or is marked `platform`.
4.  **API reference ↔ OpenAPI:** same set of operations; identical
    method, path, `operationId`, auth, parameters, request/response
    schema names, status codes and error codes.
5.  **OpenAPI ↔ Dart models:** every schema property maps to a Dart
    field (same name and compatible type) or is listed in
    `data_model_mapping.md` as added/renamed/changed with a reason;
    enum values match the Dart enums or a documented mapping.
6.  **Examples:** every JSON example parses and matches its schema
    (required fields present, types and enum values valid, envelope
    correct).
7.  **Errors:** every error code used anywhere is defined in
    `error_codes.md` and in the OpenAPI responses of the operation.
8.  **Assumptions:** every `A-###`/`Q-###` referenced exists in the
    register, and every register entry is referenced at least once.
9.  **Status labels:** no operation is labelled `Existing backend`
    without cited backend evidence; no document says "implemented",
    "live" or "available" for a proposed operation.
10. **Links:** internal Markdown links and anchors resolve.
11. **Privacy:** examples contain no real personal data or real
    third-party image URLs.

## 11.3 OpenAPI validation

Validate `openapi.yaml` with a real validator, for example
`npx --yes @redocly/cli lint docs/api/openapi.yaml` or
`npx --yes @apidevtools/swagger-cli validate docs/api/openapi.yaml`.
Record the command and its output summary. If no validator can run
(e.g. no network), state that clearly, parse the YAML with an available
tool instead, and list OpenAPI validation as "not run" in the report.

------------------------------------------------------------------------

# 12. Acceptance criteria

The task is complete only when all of these are true:

-   [ ] Only the files listed in section 3 were created or changed (11.1).
-   [ ] Every route, screen, overlay, form and action found in the code
    is in `app_inventory.md` with an ID, source and status.
-   [ ] Every screen has a section in `screen_api_map.md`; every action
    is mapped to an operation or "no API", with UI behaviour for
    loading, empty, success and errors.
-   [ ] Every operation has a full entry (5.3) with status, used-by IDs,
    params, request and response models, complete JSON examples,
    auth, errors and UI behaviour.
-   [ ] Every schema is traceable to a Dart model, fixture, UI element
    or assumption; all differences are in `data_model_mapping.md`.
-   [ ] `openapi.yaml` is OpenAPI 3.0.3 with reusable schemas,
    parameters, responses, security scheme, examples and the `x-`
    extensions in 4.6; validation was run, or reported as not run with
    the reason.
-   [ ] All consistency checks in 11.2 pass, or each remaining failure
    is explained as a finding.
-   [ ] The coverage report uses counts from discovered files (no
    estimated percentages) and lists undocumented items, actions
    without implementation, model mismatches, missing backend
    dependencies, missing capabilities and policy/security concerns.
-   [ ] Every gap in the source code's contract is an assumption or open
    question, referenced where it is used.
-   [ ] Every proposed operation is labelled **Proposed — not
    implemented**; nothing claims to be implemented without evidence.
-   [ ] Examples use fictional data only.

------------------------------------------------------------------------

# 13. Final report

Finish with a short report to the user containing:

1.  Files created/updated (paths) and confirmation from 11.1 that no
    other files changed.
2.  Coverage numbers from the coverage table (found / documented /
    missing per category).
3.  Validation and consistency results, including anything not run.
4.  The most important findings: undocumented items (should be none),
    actions without implementation, model mismatches, missing backend
    dependencies and policy/security concerns.
5.  Open questions that need a product or backend decision.

Do not claim that APIs, backend services or app changes were built.

------------------------------------------------------------------------

# 14. Future phases (not part of this task)

After the documentation is reviewed and approved, later tasks may
implement the backend, add `Api…Repository` classes behind the existing
screens, connect realtime and push services, and add contract tests.
Each of those requires a separate, explicit request and its own
specification. Nothing in this document authorises starting them.
