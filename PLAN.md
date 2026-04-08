# Quick Log Flutter App Plan

## Summary
- Build an Android-first Flutter app with exactly 3 screens: `Splash`, `Logs`, and `Settings`.
- Use `flutter_riverpod` for lightweight state management and a simple clean architecture split into presentation, domain models, repositories, and platform services.
- Use `Hive` with manual `TypeAdapter`s instead of codegen so the project stays runnable without `build_runner`.
- Use `flutter_local_notifications` for interval reminders, and `path_provider` + `share_plus` for CSV/JSON export with a low-friction save/share flow.
- Optimize the main flow for fast capture: FAB opens a compact bottom sheet, time is auto-filled, only `Task / Activity` is required, and last-used category/result are remembered.

## Implementation Changes
- App shell
  - Keep routing simple with `Navigator` and 3 named routes only.
  - Add a soft, minimal neumorphic-inspired theme for both light and dark modes.
  - Use a short splash delay, then auto-navigate to the logs screen.

- Intended folder structure
  - `lib/src/app` for app bootstrap, theme, routing, and dependency initialization
  - `lib/src/core` for constants, formatters, shared widgets, and platform services
  - `lib/src/features/splash` for the splash screen
  - `lib/src/features/logs` for entry models, repositories, controller/providers, timeline UI, and quick-entry bottom sheet
  - `lib/src/features/settings` for reminder, category, theme, and export management

- Domain types and interfaces
  - `LogEntry { id, timestamp, task, categoryId, problem, solutionTried, result, notes, isImportant, createdAt, updatedAt }`
  - `EntryResult` enum: `worked`, `notWorked`, `partial`
  - `Category { id, name, isDefault }`
  - `AppSettings { themeMode, remindersEnabled, reminderIntervalMinutes, reminderMessage, lastUsedCategoryId, lastUsedResult }`
  - Repository/service contracts:
    - `EntriesRepository`
    - `CategoriesRepository`
    - `SettingsRepository`
    - `NotificationsService`
    - `ExportService`

- Main logs screen
  - Show a chat-like timeline grouped by hour, newest first, with soft cards instead of dense tables.
  - FAB opens a bottom sheet quick-entry form with:
    - auto-filled editable time
    - task text field
    - category dropdown
    - optional problem/solution/notes fields
    - result segmented choice
  - Support add, edit, delete, duplicate, and swipe-to-toggle-important.
  - Include lightweight search and filter on the same screen without creating extra pages.
  - Keep entry creation fast by preselecting last-used category/result and collapsing optional fields by default.

- Settings screen
  - Reminder toggle, interval picker (`30m`, `1h`, `2h`), and editable reminder text.
  - Category CRUD with seeded defaults: `IoT`, `Flutter`, `Learning`, `Communication`, `Other`.
  - Theme toggle between light and dark.
  - Export buttons for CSV and JSON; export creates a timestamped file in app-accessible storage, then opens the Android share flow.

- Data and platform integration
  - Initialize Hive on startup and use separate boxes for entries, categories, and app settings.
  - Add a concise code comment near storage bootstrap explaining why Hive was chosen here: fast local writes, simple offline setup, no schema-heavy overhead, and acceptable in-memory filtering for this app size.
  - Configure Android notification permission handling for Android 13+ and use interval-based local notifications rather than exact alarms.
  - Update Android manifest/app labeling as needed for notifications and app name; keep package ID unchanged unless a custom one is later provided.

- Packages to include
  - `flutter_riverpod`
  - `hive`, `hive_flutter`
  - `flutter_local_notifications`
  - `timezone`
  - `path_provider`
  - `share_plus`
  - `intl`
  - `uuid`

## Test Plan
- Unit tests
  - Hive adapter serialization/deserialization for all models
  - repository CRUD behavior
  - export formatting for CSV and JSON
  - reminder settings persistence and scheduling input validation

- Widget tests
  - splash auto-navigation
  - quick-add bottom sheet saves a new log
  - edit/delete/duplicate/important actions update the timeline correctly
  - search and filters narrow visible entries
  - settings changes persist across app restart

- Manual Android validation
  - reminders still appear when the app is closed
  - export opens a valid share flow with a readable file
  - theme selection persists
  - category add/edit/delete behaves correctly
  - timeline grouping and timestamps remain correct after multiple entries in the same hour

## Assumptions And Defaults
- App name will be `Quick Log` with a minimal text-based splash/logo treatment.
- Android is the only platform fully implemented in this pass; Dart code stays portable for future iOS support.
- Reminder default is `off`, with `1 hour` as the initial interval when enabled.
- Export behavior is `save to app storage + share`, not direct Downloads-folder writing.
- Bonus scope included in v1 is limited to `important`, `duplicate`, and `search/filter`; no extra screens or advanced analytics.
