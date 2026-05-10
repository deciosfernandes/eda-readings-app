# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install deps
flutter run              # run on default device
flutter run -d windows   # run on specific platform (android, ios, chrome, linux, macos)
flutter analyze          # static analysis
flutter test             # run all tests
flutter test test/widget_test.dart  # run single test file
```

**Web only:** start CORS proxy before `flutter run -d chrome`:
```bash
dart bin/proxy.dart      # runs on localhost:8080
```

## Architecture

**No external state management.** Singleton services hold shared state; screens use `StatefulWidget` local state.

### Services (singletons, `lib/services/`)
- `HistoryService` — write-through cache: in-memory profile-indexed map → `flutter_secure_storage`. O(1) profile lookup.
- `SecureStorageService` — all sensitive data (`AppStateData`, credentials, tutorial flags) in encrypted storage with in-memory cache.
- `ThemeService` — `ChangeNotifier` singleton; persists to `SharedPreferences` (non-sensitive).
- `NotificationService` — reading reminders via `flutter_local_notifications` + `timezone`.

### Data Flow
`main.dart` initializes all services in parallel via `Future.wait()`, then mounts `MyApp`. Screens call service singletons directly — no dependency injection.

### API (`lib/api/`)
`EDAClient` — instantiated per profile, 15s timeout. Two methods: `getReading()` (fetches meter state + auth token), `sendReading()` (submits counters). Web builds route through the CORS proxy automatically.

### Models (`lib/models/`)
- `ReadingResponse` — API response: meter metadata, CIL token, up to 3 counter readings with min/max validation ranges.
- `SendReadingPayload` — API request: counter values + token.
- `LocalReadingHistory` — local cache entry: date, counter values, profile ID.
- `AppStateData` — app config: user profile, list of `ContractProfile`, active profile index.

### Storage decisions
- All sensitive data → `flutter_secure_storage` (history, credentials, tutorial flags)
- Theme only → `SharedPreferences`
- No SQLite/Hive — history stored as JSON strings in secure storage

### Chart data
All `FlSpot` objects and labels are pre-computed in `_loadData()`, never inside `build()`.

## Development Personas

Commits and comments are tagged with persona prefixes defined in `CONTRIBUTING.md`:
- **BOLT** — performance (caching, O(1) lookups, pre-calculation)
- **PALETTE** — UX/accessibility (haptics, semantics, adaptive theme)
- **INK** — documentation (tagged comments, architecture notes)
- **SENTINEL** — security (input validation, injection protection, permission handling)

Follow the same tagging in new code when relevant.

## Platform Notes

All six platforms are supported (Android, iOS, Web, Windows, macOS, Linux). Android 13+ requires runtime notification permission — handled in `NotificationService`. CSV export uses formula-injection protection in `lib/utils/csv_helper.dart`.
