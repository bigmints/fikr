# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Fikr** is a Flutter voice-to-insights note-taking app. Voice recordings are transcribed via LLM APIs, analyzed for intent/bucket/topics, and organized with AI-generated insights.

Target platforms: iOS, macOS, Android (Windows secondary). Version: 1.0.3+4.

## Common Commands

```bash
flutter pub get              # Install dependencies
flutter clean                # Clean build cache
flutter run -d macos         # Run on macOS (primary dev target)
flutter run -d iphone        # Run on connected iPhone
flutter run -d emulator      # Run on Android emulator
flutter build ios            # Build iOS archive
flutter build macos          # Build macOS app
flutter test                 # Run all tests
flutter analyze              # Static analysis
```

## Architecture

### State Management: GetX

All state lives in GetX controllers registered at startup in `main.dart`. Use `Get.find<ControllerType>()` to access them. Reactive fields use `RxT` (e.g., `RxList<Note>`, `Rx<AppConfig>`).

**Controllers:**
- `AppController` (~1100 lines) — core app state: notes CRUD, AI processing pipeline, insights generation, audio playback
- `SubscriptionController` — feature gating by tier (free/plus/pro/proPlus)
- `ThemeController` — Material 3 light/dark themes
- `RecordController` — audio recording state
- `NavigationController` — minimal routing

### AI Processing Pipeline

```
Audio → Transcribe (LLMService) → Clean → Analyze (intent/bucket/topics) → Note → Sync (if Pro)
```

**LLMService** (`lib/services/openai_service.dart`) abstracts three providers:
- OpenAI (GPT-4o + Whisper-1)
- Google Gemini (gemini-2.0-flash)
- OpenRouter (proxy)

The app uses a **single active provider** model — only one `LLMProvider` is active at a time (recently refactored from multi-provider). Config lives in `AppConfig.activeProvider`.

**Managed AI path:** Pro/ProPlus users get Firebase Vertex AI (no API keys needed). Free/Plus users provide their own API keys, stored via `flutter_secure_storage`.

### Services

- `StorageService` — local persistence to `getApplicationSupportDirectory()`. Files: `notes.json`, `config.json`, `tasks.json`, `reminders.json`, `audio/`. API keys in secure storage.
- `FirebaseService` — Firebase Auth (anonymous/email/Google/Apple), Vertex AI, Remote Config, Firestore
- `SyncService` — bidirectional Firestore sync (Plus+ only)
- `WidgetService` — native home screen widget integration with `fikr://record` deep link

### Data Models

- `Note` — id, createdAt, updatedAt, title, text, transcript, intent, bucket, topics[], audioPath?, archived
- `AppConfig` — activeProvider, model selections, language, bucket definitions, themeMode. Includes migration logic from legacy multi-provider format.
- `InsightEdition` / `GeneratedInsights` — AI-generated insight snapshots with highlights, themes, tasks, reminders

### Screen Organization

Screens follow a mobile/desktop split pattern:
```
lib/screens/
  home/           mobile_home.dart + desktop_home.dart
  details/        mobile_note_detail.dart
  insights/       mobile_insights.dart + desktop_insights.dart
  settings/       mobile_settings.dart + desktop_settings.dart
  shells/         mobile_shell.dart + desktop_shell.dart
  auth/
  tasks/
```

Route entry points (`home_shell.dart`, `note_detail_screen.dart`, `insights_screen.dart`) delegate to the appropriate mobile/desktop variant.

### Subscription Tiers & Feature Gating

Check `SubscriptionController` before enabling features:
- `canSync` — Firestore sync (plus+)
- `hasManagedVertexAI` — no API key required (pro+)
- `needsOwnKeys` — must configure provider (free/plus)
- `isPro` — full feature set

### Firebase

Project ID: `fikr-apps`. Firebase configs auto-generated in platform directories + `lib/firebase_options.dart`. Remote Config is used for feature flags and available model lists.

### Bucket Colors

5 fixed buckets with associated colors defined in `ThemeController`: Personal Life, Health & Fitness, Work Life, Finance, General.
