# G Pinger

A lightweight Android network connectivity monitor. Sends periodic HTTP HEAD requests to a configurable target URL and displays real-time latency, success/failure counts, and last-ping timestamp.

## Requirements

| Tool | Version |
|------|---------|
| Flutter | ≥ 3.22.0 |
| Dart | ≥ 3.0.0 |
| Android minSdk | 21 (Android 5.0) |

## Setup

```bash
# 1. Get dependencies
flutter pub get

# 2. Run in debug mode (connected device or emulator)
flutter run
```

## Build

### Debug APK
```bash
flutter build apk --debug
```

### Release APK (split per ABI, obfuscated, ~10 MB each)
```bash
flutter build apk --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info=build/debug-info
```

Output APKs are in `build/app/outputs/flutter-apk/`:
- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

### Release App Bundle (for Play Store)
```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info
```

## Features

- **Animated start/stop button** — green play / red stop with scale tap feedback
- **Real-time stats card** — status, latency (ms), last ping time, success/failure counters
- **Configurable interval** — 5 s, 10 s, 15 s, 30 s, 1 m, 5 m
- **Configurable target** — preset URLs + unlimited custom URLs (persisted)
- **App lifecycle aware** — pinging pauses automatically when app is backgrounded
- **Material 3** — adaptive light/dark theme following system setting

## Project Structure

```
lib/
├── main.dart                          # App entry + ProviderScope setup
├── core/
│   └── models/
│       └── ping_state.dart            # PingState model + PingStatus enum
└── features/
    └── pinger/
        ├── pinger_service.dart        # Riverpod providers + PingerNotifier
        └── pinger_screen.dart         # UI — screen, button, stats, settings
```

## Packages

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `http` | HTTP HEAD requests |
| `shared_preferences` | Persist interval + URL selections |

## Signing for Release

Add a `key.properties` file and configure `signingConfigs` in `android/app/build.gradle.kts`
before distributing. See the [Flutter deployment guide](https://docs.flutter.dev/deployment/android).
