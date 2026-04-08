# Quick Log

Quick Log is an Android-first Flutter app for fast daily work logging and productivity tracking.

## Features

- 3-screen flow: splash, logs, settings
- Quick-add bottom sheet with auto-filled time
- Chat-like timeline grouped by hour
- Edit, delete, duplicate, and important entry actions
- Search and lightweight filters
- Local reminders with configurable interval and message
- Category management
- Light and dark soft UI themes
- Local export to CSV or JSON with share flow

## Tech Stack

- Flutter + Material 3
- `flutter_riverpod` for state management
- Hive for local persistence
- `flutter_local_notifications` for reminders
- `share_plus` + `path_provider` for export

## Structure

```text
lib/
  main.dart
  src/
    app/
    core/
    features/
      splash/
      logs/
      settings/
test/
```

## Verification

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
