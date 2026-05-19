---
project: fikr
role: flutter-developer
authority: CANONICAL
---

# Fikr — Agent Entry Point

> Read this file at the start of every session before taking any action.

## Project Overview

**Fikr** is an AI-powered voice note-taking app for iOS, Android, macOS, and Windows built with Flutter/Dart.

| | |
|---|---|
| **Stack** | Flutter / Dart |
| **State** | GetX (`get` package) |
| **Storage** | Hive (local) + Firestore (Plus/Pro) |
| **Auth** | `fikr.one` custom Firebase token → `FirebaseService.signInWithCustomToken()` |
| **AI** | BYOK (Free) / OpenRouter managed presets (Plus/Pro via `fikr.one`) |

---

## Rules — Read Before Any Task

| File | Scope |
|---|---|
| `.agents/rules/fikr-tool-rules.md` | **MANDATORY** — 11 non-negotiable tool architecture rules |
| `.agents/rules/rules-app.md` | App-level rules (Flutter versions, linting, tiers) |

**Critical invariants:**
- Every domain mutation routes through `EngineController.executeTool()` — **no exceptions**
- `flutter analyze` must report **0 issues** before any commit
- `flutter pub get` must run without error
- All new asset folders declared in `pubspec.yaml`

---

## Session Lifecycle

```
START → .agents/workflows/_shared/bootstrap.md → [WORK] → .agents/workflows/_shared/maintain-context.md → END
```

**Quick commands:**
```bash
.agents/skills/heartbeat/pulse.sh "<task>"
.agents/skills/task-manager/manage.sh list
.agents/skills/task-manager/manage.sh start <id>
.agents/skills/task-manager/manage.sh complete --id <id> --summary "<what>"
.agents/skills/validate-code/validate.sh
.agents/skills/auto-context/update-context.sh "<msg>"
git log --oneline -20
```

---

## Skills

| Skill | Path | Purpose |
|---|---|---|
| heartbeat | `.agents/skills/heartbeat/pulse.sh` | Liveness timestamp before/after tasks |
| task-manager | `.agents/skills/task-manager/manage.sh` | Task lifecycle (list/start/complete) |
| validate-code | `.agents/skills/validate-code/validate.sh` | flutter analyze + tests (must pass before commit) |
| auto-context | `.agents/skills/auto-context/update-context.sh` | Append to worklog.toon |
| compress-worklog | `.agents/skills/compress-worklog/compress.sh` | Compress worklog when >64k tokens |
| minions | `.agents/skills/minions/scripts/minions` | Run YAML prompt queues |
| toon | `.agents/skills/toon/SKILL.md` | TOON format converter |
| flutter-debug | `.agents/skills/flutter-debug/SKILL.md` | QA audit skill |

---

## Workflows

| Workflow | Trigger |
|---|---|
| `process.md` | **Always** — canonical agent process |
| `bootstrap.md` | Session start |
| `release.md` | Build, sign, notarize macOS DMG |
| `deploy.md` | Mobile build + Cloud Run deploy |
| `update-tool-catalog.md` | Sync tools.md with Dart implementations |
| `manage-ai-config.md` | Update OpenRouter presets |
| `log.md` | Log implementation summary to Fikr Studio |
| `queue.md` | Execute YAML prompt queues |

---

## Architecture

```
lib/
  main.dart              ← Service registration (Get.put)
  tools/
    tools/               ← FikrTool implementations per domain
    tool_registry.dart   ← Registers all tools
    engine/
      engine_controller.dart  ← executeTool() — ALL mutations go here
    skill_engine/
      skills/            ← Skill definitions
      skill_executor.dart
  screens/
  services/
```

**Adding a tool:** Read `fikr-tool-rules.md` → implement `FikrTool with FikrToolMixin` → add to `allXxxTools()` → run analyze + tests → update `tools.md`

**Adding a screen:** Create `lib/screens/<area>/<name>_screen.dart` → register in `home_shell.dart`, `mobile_shell.dart`, `desktop_shell.dart`

---

## Subscription Tiers

| Tier | Capability |
|---|---|
| **Free** | BYOK, local storage only |
| **Plus** | Managed AI + Cloud Sync, 500k words/mo |
| **Pro** | Managed AI + Cloud Sync, 1.5M words/mo |

Tier read from Firestore: `users/{uid}.plan` (written only by `fikr.one` Admin SDK).

---

## Knowledge

- `.agents/context/knowledge/tools.md` — All 47+ registered tools
- `.agents/context/knowledge/tool-architecture.md` — Full architecture reference
- `.agents/context/context.toon` — Live project state

## Git Hooks (install once)

```bash
bash .agents/skills/heartbeat/setup-hooks.sh
```
