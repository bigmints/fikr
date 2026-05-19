# ADR 005 — Subscription Tier Enforcement at Tool Level

**Date:** 2026-05-04
**Status:** Accepted
**Scope:** `fikr/` Flutter app

---

## Context

Fikr has three subscription tiers (Free, Plus, Pro) with different capability access. Enforcing tier limits in UI code (screens, controllers) would be brittle — any new screen or path could accidentally bypass checks. The enforcement needed to be in one authoritative place that every operation passes through.

---

## Decision

Every `FikrTool` declares `ToolTier requiredTier` (`free | plus | pro`). `EngineController` checks the tier from `ToolContext.planTier` before calling `execute()`. If the user's tier is insufficient, `ToolResult.tierDenied()` is returned — the tool implementation never runs.

```dart
abstract class FikrTool {
  ToolTier get requiredTier;  // declared per tool
  // ...
}
// EngineController enforces:
if (context.planTier.index < tool.requiredTier.index) {
  return ToolResult.tierDenied(toolName, requiredTier: tool.requiredTier);
}
```

Tier is read from Firestore: `users/{uid}.plan` — written **only** by the `fikr.one` Admin SDK (never client-side). Tools receive it via `ToolContext.planTier`.

**Tier → capability:**
| Tier | Capabilities |
|---|---|
| `free` | All local operations, BYOK AI, no cloud sync |
| `plus` | + Cloud Sync (Firestore), Managed AI, 500k words/mo |
| `pro` | + Managed AI, 1.5M words/mo, advanced analysis |

---

## Consequences

**Positive:**
- Tier enforcement is impossible to bypass — it happens before any tool logic runs
- Adding a new Plus/Pro feature requires only setting `requiredTier` on the tool class — no UI changes
- `ToolResult.tierDenied` gives the LLM a structured signal to show an upgrade prompt

**Negative:**
- `ToolContext.planTier` must be correctly populated on every `executeTool()` call
- Tier state comes from Firestore — offline usage falls back to cached plan value
