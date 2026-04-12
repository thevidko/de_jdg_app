# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter judge app (`de_jdg_app`) for a dance competition scoring system. Judges receive real-time events via WebSocket (Centrifugo) and submit scores via REST API.

## Commands

```bash
# Dependencies
flutter pub get

# Code generation (required after modifying Riverpod providers with @riverpod annotation)
flutter pub run build_runner build
flutter pub run build_runner watch   # watch mode during development

# Lint / static analysis
flutter analyze

# Tests
flutter test
flutter test test/path/to/test.dart  # single test file

# Run app
flutter run
flutter run -d <device_id>

# Build
flutter build apk
flutter build ios
```

## Architecture

**State management:** Riverpod 2.x (`StateNotifierProvider`, `FutureProvider.autoDispose`)
**Routing:** GoRouter with auth-guarded routes and `GoRouterRefreshStream` adapter
**HTTP:** Dio with a JWT interceptor (auto-refresh on 401) and cookie persistence
**Real-time:** Centrifugo WebSocket client — subscribes to `judges:{user_uuid}` channel

### Directory layout

```
lib/
├── core/
│   ├── models/          # Immutable data classes with copyWith
│   ├── router/          # GoRouter config, redirect logic
│   └── services/        # ApiService (Dio), CentrifugoService, StorageService, ScoreQueueService
└── features/
    ├── auth/            # AuthController (StateNotifier), login screen
    ├── competitions/    # Competition list + detail, Centrifugo subscribe point
    ├── judging/         # JudgingController, scoring widgets, debug panel
    └── realtime/        # CentrifugoService provider, auto-connect on auth
```

### Data & event flow

```
Centrifugo event (START_ROUND / START_DANCE / END_ROUND)
  → JudgingController handles event
  → REST call to ApiService (GET /rounds/{uuid}, GET /disciplines/{uuid}/active-state)
  → JudgingState updated → ConsumerWidget rebuilds

Judge submits scores
  → POST /api/v1/scores/bulk  (idempotent upsert, always sends all pairs)
  → On network failure → ScoreQueueService enqueues to SharedPreferences
  → _flushQueue() retries on reconnect or app restart
```

### Key services

| Service | Responsibility |
|---|---|
| `ApiService` | Singleton Dio client; all REST endpoints; JWT + cookie management |
| `CentrifugoService` | WebSocket lifecycle; subscription token via `/broadcasting/auth` |
| `StorageService` | Wraps `flutter_secure_storage` (tokens) and `shared_preferences` (profile, settings) |
| `ScoreQueueService` | Offline score queue persisted in SharedPreferences; JSON-serialized `ScorePayload` |
| `JudgingController` | Central business logic; `JudgingPhase` state machine; 200-item debug log |

### Scoring rules

- **Kolo (round):** Křížky mode — judge marks exactly N advancing pairs (crosses = 0 or 1)
- **Finále (final):** Umístění mode — placement rankings 1–6; all placements must be unique before submission

### Storage

- `flutter_secure_storage` — JWT access token, WebSocket token
- `shared_preferences` — User profile, offline score queue (key: `score_queue`)

### Auth flow

Login → `POST /auth/login` → JWT access token stored securely + HttpOnly refresh cookie → 401 interceptor calls `POST /auth/refresh` automatically → token refreshed transparently.
