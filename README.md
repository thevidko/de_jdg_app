# DanceEval Judge App

A Flutter application for judges to score and evaluate dance performances in competitions. Features real-time score synchronization, secure authentication, automatic backend discovery, and offline queue support.

## Features

- **Real-time Judging** — Score performances with instant synchronization via Centrifugo WebSocket
- **Secure Authentication** — Token-based authentication with secure credential storage
- **Automatic Backend Discovery** — Auto-discover and connect to available judge backends on the network
- **Offline Support** — Queue scores locally when offline, sync when connection restored
- **Multi-Competition Support** — Manage scores across multiple concurrent competitions
- **Screen Persistence** — Screen stays active during judging sessions with wakelock
- **Cross-Platform** — Android and iOS support with platform-specific optimizations

## Tech Stack

- **Framework**: Flutter 3.10+
- **State Management**: Riverpod with Riverpod Generator
- **Routing**: GoRouter
- **Real-time Communication**: Centrifuge Dart client
- **HTTP Client**: Dio with cookie management
- **Storage**: SharedPreferences, Flutter Secure Storage
- **Local Database**: Part of core models

## Project Structure

```
lib/
├── core/
│   ├── models/              # Data models (competitions, scoring)
│   ├── services/            # Core services (API, Centrifugo, storage)
│   ├── router/              # Navigation routing
│   └── theme/               # UI theming
├── features/
│   ├── auth/                # Authentication feature
│   ├── competitions/        # Competition management
│   ├── judging/             # Judging interface & controllers
│   └── realtime/            # Real-time synchronization
└── main.dart                # App entry point
```

## Getting Started

### Prerequisites

- Flutter 3.10.8 or higher
- Dart SDK compatible with Flutter version
- Android SDK (for Android builds)
- Xcode (for iOS builds)

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd de_jdg_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate code (Riverpod annotations):**
   ```bash
   flutter pub run build_runner build
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

## Configuration

### Backend URL Configuration

The app supports two connection methods:

1. **Manual Configuration** — Set backend URL directly in settings
2. **Automatic Discovery** — Auto-discover backends on the network using the discovery service

URLs are stored in SharedPreferences and reused on subsequent launches.

### Environment Variables

Currently configured via SharedPreferences:
- `backend_url` — Base URL for API server
- `ws_url` — WebSocket URL for Centrifugo real-time updates

## Building

### Android

```bash
flutter build apk --release
```

For Play Store distribution:
```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Development

### Code Generation

This project uses Riverpod annotations. When modifying providers:

```bash
flutter pub run build_runner watch
```

### Running Tests

```bash
flutter test
```

## Dependencies

Key packages:
- `flutter_riverpod` — State management
- `go_router` — Navigation
- `dio` — HTTP requests
- `centrifuge` — Real-time communication
- `flutter_secure_storage` — Secure credential storage
- `wakelock_plus` — Keep screen on during judging

See `pubspec.yaml` for full dependency list.

## Troubleshooting

### App won't connect to backend
- Verify backend URL is correctly set
- Check network connectivity
- Ensure WebSocket URL is accessible

### Scores not syncing
- Check real-time connection status
- Review offline queue in debug panel
- Verify backend is running

### Build issues
- Clean build: `flutter clean && flutter pub get`
- Regenerate code: `flutter pub run build_runner clean && flutter pub run build_runner build`

## License

[Specify your license here]

## Contact

For issues or questions, please contact the development team.
