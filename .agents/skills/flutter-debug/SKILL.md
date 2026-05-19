---
name: flutter-debug
description: QA agent — audits, debugs, and validates Flutter code against Fikr architecture rules, GetX patterns, tool-based architecture invariants, and strict linting. Produces a QA report. Zero tolerance on all checks.
---

# Flutter Debug & QA Skill

**Triggers:** "QA this" | "QA this flutter code" | "debug this widget/controller" | "review my flutter implementation" | "run flutter QA"

Run the following phases **in order**. **Do not skip phases. Fix every violation before moving to the next phase.**

---

## Phase 1 — Static Analysis

```bash
flutter analyze
```

- Fix **every** warning and error before continuing. Zero tolerance.
- Common auto-fixes: add `const`, remove unused imports, fix null-safety violations, add missing `override`.
- Re-run until output is exactly: `No issues found!`

---

## Phase 2 — GetX State Management Audit

Read each file in scope and check against these rules. Fix violations directly with code edit tools.

| Rule | Pass Condition |
|---|---|
| Reactive vars | All mutable state is `.obs`; no plain `var` used for reactive data |
| Obx scope | Only widgets that *actually change* are wrapped in `Obx()`; no purely static subtrees inside `Obx` |
| Controller base | All controllers extend `GetxController` or `GetxService` |
| `onClose()` | Streams, timers, animation controllers disposed in `onClose()` |
| No BuildContext | Controllers hold **zero** stored references to `BuildContext` |
| DI | Services use `Get.find<T>()` — never re-instantiated locally if already registered in `main.dart` |
| Navigation | `Get.to()`, `Get.dialog()`, `Get.bottomSheet()`, `Get.snackbar()` only — **no** `Navigator.push` in controllers or business logic |

---

## Phase 3 — Tool-Based Architecture Compliance (MANDATORY — Zero Tolerance)

> **Reference:** `.agents/knowledge/fikr/tool-architecture.md`  
> **Core mandate:** Every domain mutation goes through `EngineController.executeTool()`. No exceptions.

Work through each invariant below. For every violation: **locate the offending code, fix it immediately, then re-run `flutter analyze`.**

### 3A — The Golden Rule: No Bypass of EngineController

Search for any code that mutates domain state (notes, tasks, reminders, audio, config, sync) **without** going through `EngineController.executeTool()` or `EngineController.executeSkill()`.

Run these searches on the files in scope:

```bash
# Direct service calls in controllers that bypass the tool engine:
grep -rn "StorageService\|FikrApiService\|AudioSyncService\|FirebaseService" lib/controllers/ --include="*.dart"
grep -rn "\.add(\|\.remove(\|\.clear(" lib/controllers/ --include="*.dart"
grep -rn "saveNotes\|saveTasks\|saveReminders" lib/controllers/ --include="*.dart"
```

**Pass condition:** All domain mutations in controllers are calls to `engine.executeTool(...)` or `engine.executeSkill(...)`. Direct service calls are only permitted inside `FikrTool.execute()` implementations.

**Exception allowed:** `AppController` methods that are implementations of `IAppState` (e.g. `finalizeNote`, `playAudio`, `updateNoteAudioUrl`) are the *target* of tool calls — they are permitted to call storage/services directly only when invoked from tool code.

### 3B — FikrTool Interface Completeness

For every new or modified tool class, verify ALL of the following are implemented:

| Field | Requirement |
|---|---|
| `name` | Dot-namespaced, globally unique: `domain.action` (e.g. `notes.create`) |
| `description` | Non-empty, human-readable, LLM-facing |
| `parametersSchema` | Valid JSON Schema object with `type: 'object'` and `properties` map |
| `requiredTier` | One of `ToolTier.free`, `ToolTier.plus`, `ToolTier.pro` — must be the **minimum** correct tier |
| `location` | One of `ToolLocation.local`, `cloud`, `mcp`, `webhook` |
| `execute()` | Returns `Future<ToolResult>` — **never throws** |

**Fix:** Any tool missing a field or throwing instead of returning `ToolResult.fail(...)` must be corrected.

### 3C — FikrToolMixin.guard() Usage (Mandatory on All New Tools)

> Invariant from `tool-architecture.md` §9: *"New tools must use `FikrToolMixin.guard()`"*

Check that every tool added or modified in this session uses `FikrToolMixin`:

```bash
grep -n "class.*FikrTool" lib/tools/tools/*.dart
```

- **New tools:** MUST use `extends FikrTool with FikrToolMixin` and wrap `execute()` body in `guard(context, () async { ... })`.
- **Pre-existing tools without mixin:** Flag in the QA report as a **Recommendation** (do not break them, but note them for migration).
- **Any new tool that extends bare `FikrTool` without `FikrToolMixin`:** This is a **VIOLATION** — add the mixin and `guard()` wrapper immediately.

### 3D — IAppState, Not AppController

> Invariant: *"Tools call `Get.find<IAppState>()`, never `AppController` directly."*

Search all tool files:

```bash
grep -rn "Get.find<AppController>" lib/tools/ --include="*.dart"
```

**Pass condition:** Zero results. Any hit must be changed to `Get.find<IAppState>()`.

### 3E — No ToolResult.okMeta() in Tool Implementations

> Invariant: *"Tools call `ToolResult.ok(data)`. Only `EngineController` calls `ToolResult.okMeta()`."*

```bash
grep -rn "ToolResult.okMeta" lib/tools/tools/ --include="*.dart"
```

**Pass condition:** Zero results. If found, replace with `ToolResult.ok(data)`.

### 3F — Registration in tool_initializer.dart

For every new tool domain file added in this session:

- [ ] Domain file exports an `allXxxTools()` function returning `List<FikrTool>`
- [ ] `tool_initializer.dart` imports the domain file
- [ ] `tool_initializer.dart` calls `toolRegistry.registerAll(allXxxTools())` inside `initializeTools()`

Verify with:

```bash
grep -n "registerAll" lib/tools/tool_initializer.dart
```

### 3G — Tool Naming Convention

> Invariant: *"Tool names are globally unique and follow `domain.action` convention."*

Check every `name` getter in new/modified tools:
- Format MUST be `domain.action` (e.g. `notes.create`, `communication.call`)
- No spaces, no uppercase, no slashes
- Must not duplicate an existing tool name

```bash
grep -rn "String get name =>" lib/tools/tools/ --include="*.dart"
```

Verify uniqueness by scanning the full list.

### 3H — AI Output Sanitization

> Invariant: *"Every AI output passes through `util.text_sanitize` before persistence."*

If any new tool receives AI-generated text (from `ai.transcribe`, `ai.analyze`, `ai.insights`, or any LLM response) and writes it to storage or Firestore, verify it chains through `util.text_sanitize`:

```bash
grep -rn "util.text_sanitize\|UtilTextSanitize" lib/tools/ --include="*.dart"
```

**Pass condition:** Any tool that persists AI-generated strings either calls `util.text_sanitize` itself or delegates to a pipeline that does (e.g. `notes.finalize` already sanitizes).

### 3I — Archived Note Exclusion

> Invariant: *"`notes.list` always defaults to `excludeArchived: true`."*

If `notes_tools.dart` was modified:

```bash
grep -n "excludeArchived\|isArchived\|archived" lib/tools/tools/notes_tools.dart
```

**Pass condition:** Default list behavior excludes archived notes. The AI insights pipeline must never see archived notes.

### 3J — Platform Permissions for Device Capabilities

For any tool that accesses a device capability (contacts, camera, microphone, location, etc.):

- [ ] iOS: `NSXxxUsageDescription` present in `ios/Runner/Info.plist`
- [ ] Android: `<uses-permission>` declared in `android/app/src/main/AndroidManifest.xml`
- [ ] Android 11+: `<queries>` block includes scheme/intent for any `canLaunchUrl` schemes

### 3K — tools.md Knowledge Base Updated

After any change to the tool registry:

- [ ] `.agents/knowledge/fikr/tools.md` reflects the updated tool count and lists all new tools with name, description, and required tier

---

## Phase 4 — Fikr Ecosystem Checklist

Work through each item. Fix any violation found.

**SSO & Auth**
- [ ] Auth flows call `FirebaseService.signInWithCustomToken()` — no direct Google Sign-In or standalone Firebase Auth
- [ ] API calls to `fikr.one` pass `Authorization: Bearer <idToken>` header

**Subscription Gates**
- [ ] Every premium tool correctly gates on `ToolTier.plus` or `ToolTier.pro`
- [ ] Tier violations surface `ToolResult.tierDenied(...)` — never silently fail

**Branding**
- [ ] No hardcoded hex colors or font family strings — uses global Fikr theme tokens
- [ ] New module/game icons are 3D isometric generated images (no flat 2D SVGs or placeholders)

**Page Structure**
- [ ] New screens registered in `home_shell.dart`, `mobile_shell.dart`, `desktop_shell.dart`
- [ ] Responsive layouts use `LayoutBuilder` / `AspectRatio` — no hardcoded pixel widths

**User Flows**
- [ ] List screens handle: loading (shimmer), empty state (CTA), error state (retry)
- [ ] Settings changes reflected in both `mobile_settings.dart` and `desktop_settings.dart`

---

## Phase 5 — App Store & Play Store Compliance (MANDATORY)

Work through each item to ensure the app will not be rejected during review. Fix any violation found.

**Permission Descriptions (iOS `Info.plist`)**
- [ ] Every `NS...UsageDescription` string must be non-empty and explicitly state *why* the app needs the permission (e.g., "Fikr needs camera access to scan documents"). Vague descriptions will cause App Store rejection.

**External Payments (Apple/Google IAP Guidelines)**
- [ ] No hardcoded external payment links (e.g., Stripe, PayPal, or web-based checkout URLs) are present in the app UI. Subscriptions must be managed either strictly via native In-App Purchases (IAP) or handled purely out-of-band without directing users from the app.

**Account Deletion (Apple Requirement)**
- [ ] If the app supports account creation, it must also provide a clear, accessible "Delete Account" or "Delete Data" option within the app settings.

**Production Readiness**
- [ ] No placeholder text ("Lorem Ipsum", "Test text", "TODO") visible in the UI.
- [ ] No placeholder icons or default Flutter logos (`flutter_logo`) used in production screens.

---

## Phase 6 — Bug Trace (if a specific bug was reported)

1. Isolate the minimal reproduction path: user action → controller method → `executeTool()` call → `FikrTool.execute()` → service call → state update → UI rebuild.
2. Check: null dereferences, unhandled `Future` errors, race conditions, missing `await`, platform permission gaps.
3. Apply fix. Re-run `flutter analyze`. Confirm zero issues.

---

## Phase 7 — Final flutter analyze

```bash
flutter analyze
```

Must return `No issues found!` before the QA is considered complete.

---

## Phase 8 — QA Report

Write a Markdown artifact to `<appDataDir>/brain/<conversation-id>/qa_report.md` with:

### Required Sections

1. **Static Analysis** — issues found and fixed (or "None")
2. **GetX Audit** — violations fixed (or "All clean")
3. **Tool Architecture Compliance** — one row per invariant (3A–3K):
   - `✅ PASS` / `❌ FAIL → Fixed` / `⚠️ Pre-existing (flagged for future migration)`
4. **Ecosystem Checklist** — any items that failed and were fixed
5. **App Store & Play Store Compliance** — any violations fixed (or "All clean")
6. **Bugs** — root cause and fix summary (or "None")
7. **Recommendations** — pre-existing issues not in scope for this session; prioritized by severity

### Compliance Score

At the end of section 3, output a compliance score:

```
Tool Architecture Compliance: X / 11 invariants passing (Y% compliant)
```

A score below 100% is not acceptable for new code. Pre-existing violations may be flagged as Recommendations if fixing them is out of scope.
