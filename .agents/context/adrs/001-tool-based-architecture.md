# ADR 001 — Tool-Based Architecture Mandate

**Date:** 2026-05-04
**Status:** Accepted
**Scope:** `fikr/` Flutter app

---

## Context

The Fikr app needed a scalable approach to handling all domain operations (notes, tasks, reminders, audio, AI) that would support:
- Subscription tier enforcement across all capabilities
- Traceability and auditability for every operation
- LLM-driven orchestration where the model selects and calls tools
- Testability without Firebase or real audio hardware

A traditional approach (direct service calls from controllers) would scatter tier checks and logging across the codebase, making it impossible to audit or test consistently.

---

## Decision

**Every domain mutation in the Fikr app routes through `EngineController.executeTool()` or `EngineController.executeSkill()`. No exceptions.**

The execution pipeline is:
```
UI → AppController (IAppState) → EngineController
  → Trace ID → Tier Gate → Validation → FikrTool.execute()
  → Metadata stamp → ToolExecutionLog → ToolResult
```

Key interfaces:
- `FikrTool` — every capability is a class with `name`, `requiredTier`, `parametersSchema`, `execute()`
- `FikrToolMixin.guard()` — wraps all tool logic; catches exceptions and returns `ToolResult.fail` instead of crashing
- `ToolResult` — sealed return type: `ok`, `fail`, `tierDenied`, `notFound`
- `ToolContext` — injected into every `execute()` call with userId, tier, traceId, logger

---

## Consequences

**Positive:**
- Tier gating is enforced in one place — `EngineController` — not scattered across the app
- Every tool call is traced (traceId UUID), logged (ToolExecutionLog ring buffer), and validated (JSON Schema) automatically
- Tools are independently testable using `ToolRegistry.forTesting()` and `_FakeAppState`
- LLM can discover and call any tool via the schema without code changes

**Negative / Trade-offs:**
- All new features require implementing a `FikrTool` class — more boilerplate than a direct method call
- Direct `AppController` calls from tools are prohibited — must use `Get.find<IAppState>()`

**Invariants (never break):**
- Tools call `Get.find<IAppState>()`, never `Get.find<AppController>()` — keeps tools decoupled
- Tools return `ToolResult.ok()` — never `ToolResult.okMeta()` (engine-only, prevents metadata forgery)
- Tool names follow `domain.action` convention and are globally unique
- New tools must use `FikrToolMixin.guard()` — no bare try/catch in tools
- `notes.list` always defaults `excludeArchived: true` — prevents deleted notes leaking into AI
- Every AI output passes through `util.text_sanitize` before Firestore persistence

---

## File Map

```
lib/tools/
  tool_interface.dart       ← FikrTool, ToolResult, ToolContext, FikrToolMixin
  tool_registry.dart        ← ToolRegistry singleton
  tool_initializer.dart     ← initializeTools() — registers all built-in tools
  tool_execution_log.dart   ← In-memory ring buffer log
  tool_validator.dart       ← JSON Schema validation
  engine/
    engine_controller.dart  ← THE gateway — executeTool(), executeSkill()
    tool_selector.dart      ← LLM tool selection
  tools/                    ← Domain implementations (notes, tasks, ai, etc.)
```
