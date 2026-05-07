# QuickLog

A voice-first productivity logging application built with Flutter.

QuickLog helps developers, engineers, freelancers, and technical professionals capture work progress in real time using speech-to-text recording with minimal friction.

The application is designed around a simple principle:

> Capture work as it happens.

Instead of manually remembering and filling spreadsheets at the end of the day, QuickLog allows users to quickly record work updates, issues, debugging notes, experiments, and progress using natural voice input.

---

# ✨ Core Features

## 🎙 Voice-First Logging

* One-tap voice recording
* Real-time speech-to-text transcription
* Editable transcript after recording
* Fast capture workflow
* Minimal interaction design

---

## 📝 Work Timeline

* View all logs in timeline format
* Search logs instantly
* Archive logs
* Restore deleted logs
* Mark important entries

---

## 🔔 Smart Reminder System

* Configurable reminders
* Local notifications
* Custom reminder intervals
* Custom reminder messages
* Offline support

---

## 📤 Export Support

* Export logs as JSON
* Export logs as CSV
* Share exported files
* Local storage only

---

## 🌙 Modern Productivity UI

* Minimal clean interface
* Soft modern UI
* Fast navigation
* Low-friction interaction design
* Designed for engineering workflows

---

# 📱 Application Screens

## 1. Splash Screen

Startup-only screen.

### Responsibilities

* Initialize app resources
* Load settings
* Prepare local database
* Navigate to home screen

### Features

* Animated logo entrance
* Fade + scale transition
* Minimal branded UI
* Startup loader

---

## 2. Home Screen

Main productivity workspace.

### Responsibilities

* Display active logs
* Open voice recording modal
* Access navigation tabs
* Search entries

### Bottom Navigation

| Tab      | Purpose              |
| -------- | -------------------- |
| Home     | Active logs          |
| Archived | Archived logs        |
| Record   | Open recording modal |
| Trash    | Deleted logs         |
| Settings | App settings         |

---

## 3. Settings Screen

Application configuration.

### Features

* Reminder settings
* Theme settings
* Export options
* Category management

---

## 4. Archived Logs Screen

Displays archived logs.

### Features

* Restore archived logs
* Search archived entries
* View/edit logs

---

## 5. Trash Logs Screen

Displays deleted logs.

### Features

* Restore deleted logs
* Permanently delete logs
* Clear trash

---

# 🏗 Architecture

QuickLog uses a modular feature-first architecture.

## Directory Structure

```text
lib/
├── core/
│   ├── constants/
│   ├── router/
│   ├── services/
│   ├── theme/
│   └── utils/
│
├── features/
│   ├── splash/
│   ├── home/
│   ├── recording/
│   ├── logs/
│   │   ├── archived/
│   │   ├── trash/
│   │   └── shared/
│   └── settings/
│
├── shared/
│   ├── widgets/
│   ├── components/
│   └── models/
│
└── main.dart
```

---

# 🧠 Architectural Principles

## Feature-First Structure

Each feature owns:

* presentation
* logic
* widgets
* services
* providers

---

## Reusable UI System

Shared components are centralized.

Reusable widgets include:

* logs list widget
* log cards
* setting tiles
* search bars
* recording controls
* empty states

---

## Separation of Concerns

Business logic is separated from UI.

### UI Layer

Responsible for:

* rendering
* animations
* user interactions

### Logic Layer

Responsible for:

* state management
* speech handling
* reminders
* database operations

### Data Layer

Responsible for:

* local persistence
* export operations
* repositories

---

# ⚙ State Management

## Riverpod

QuickLog uses Riverpod for:

* scalable state management
* dependency injection
* provider isolation
* rebuild optimization

---

# 💾 Local Storage

## Hive Database

QuickLog uses Hive for:

* fast local storage
* offline-first persistence
* lightweight architecture
* efficient performance

---

# 🎤 Speech System

## Speech-to-Text

Uses:

```yaml
speech_to_text
```

### Features

* Real-time transcription
* Live transcript updates
* Automatic silence detection
* Editable transcript
* Microphone permission handling

---

# 🔔 Notification System

## flutter_local_notifications

Used for:

* reminder notifications
* recurring reminders
* offline notifications

### Reminder Examples

* What are you working on?
* Capture your progress.
* Log your current task.
* Save your debugging notes.

---

# 📤 Export System

## CSV Export

Exports:

* date
* time
* transcript
* importance status

---

## JSON Export

Exports complete structured log data.

---

# 📦 Dependencies

## Core Packages

```yaml
flutter_riverpod:
hive:
hive_flutter:
speech_to_text:
flutter_local_notifications:
permission_handler:
path_provider:
intl:
share_plus:
```

---

# 🎨 UI Philosophy

QuickLog is intentionally minimal.

The UI prioritizes:

* speed
* clarity
* low friction
* fast capture
* productivity

Avoided intentionally:

* social-style UI
* gamification
* complex dashboards
* excessive animations
* cluttered forms

---

# 🎯 User Workflow

## Recording Flow

1. User taps Record
2. Recording modal opens
3. User speaks naturally
4. Speech converts to text live
5. User edits transcript if needed
6. User saves log
7. Entry appears in timeline

---

# 🔄 Log Lifecycle

## Active Log

Normal working entry.

↓

## Archived Log

Hidden but preserved.

↓

## Trash Log

Soft deleted.

↓

## Permanent Delete

Fully removed.

---

# 🔍 Search System

Quick local transcript search.

Supports:

* instant filtering
* timeline filtering
* archived search
* deleted logs search

---

# 🚀 Performance Goals

QuickLog is optimized for:

* fast startup
* smooth scrolling
* low rebuild count
* lightweight local storage
* efficient list rendering

---

# 🔐 Privacy Philosophy

QuickLog is local-first.

Version 1:

* No cloud sync
* No analytics
* No external servers
* No authentication
* No user tracking

All data stays on device.

---

# 🔮 Future Roadmap

## Planned Future Features

### AI Parsing

Convert natural speech into structured fields:

* activity
* issue
* solution
* result
* category

---

### Daily Summaries

Generate:

* productivity reports
* debugging summaries
* work history

---

### Semantic Search

Search by meaning instead of exact text.

---

### Cloud Sync

Optional future sync support.

---

### Smart Categorization

Automatic category prediction using AI.

---

# 🛠 Development Setup

## Requirements

* Flutter SDK
* Dart SDK
* Android Studio OR VS Code

---

# ▶ Running the Project

## Install Dependencies

```bash
flutter pub get
```

---

## Run Application

```bash
flutter run
```

---

# 📂 Build APK

```bash
flutter build apk
```

---

# 🧪 Recommended Development Flow

## Suggested Build Order

### Phase 1

* routing
* navigation
* screens

### Phase 2

* voice recording
* speech-to-text

### Phase 3

* local database
* timeline system

### Phase 4

* reminders
* export system

### Phase 5

* optimization
* polish
* animations

---

# 📌 Engineering Notes

## Why Voice-First?

Typing creates friction.

Voice capture:

* improves consistency
* reduces mental load
* works better during debugging
* captures context faster
* improves real-time logging

---

# 📖 Example Use Cases

## Developer Workflow

Example:

> Fixed websocket reconnect issue. Tried exponential retry logic. Partial success.

Saved instantly as a searchable timeline entry.

---

## IoT Debugging Workflow

Example:

> ESP32 restarting after WiFi reconnect. Added capacitor near VIN. Stability improved.

---

# 📄 License

This project is intended for personal productivity and workflow tracking.

Modify and extend freely.

---

# ❤️ Philosophy

QuickLog is built around one idea:

> Great work is often forgotten because capturing it is harder than doing it.

The app exists to remove that friction.