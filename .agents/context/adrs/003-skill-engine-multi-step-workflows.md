# ADR 003 — Skill Engine for Multi-Step Workflows

**Date:** 2026-05-04
**Status:** Accepted
**Scope:** `fikr/` Flutter app

---

## Context

Several user flows require multiple tools to run in sequence or parallel (e.g., voice note capture: transcribe → analyze → finalize → upload audio). Encoding these as procedural code in `AppController` would scatter multi-step logic, making it hard to test steps individually or reuse them.

---

## Decision

Multi-step workflows are expressed as **Skills** — named, reusable DAGs of tool steps. Each step references a tool by name. The `SkillExecutor` handles variable passing, parallel execution, conditional steps, and forEach iteration.

```dart
Skill(
  name: 'voice_note_capture',
  requiredTier: ToolTier.free,
  steps: [
    SkillStep(toolName: 'ai.transcribe',  input: {'audioPath': r'$audioPath'}, outputKey: 'transcriptResult'),
    SkillStep(toolName: 'ai.analyze',     input: {'text': r'$transcriptResult.transcript'}, outputKey: 'analysis'),
    SkillStep(toolName: 'notes.finalize', input: {'id': r'$noteId', 'transcript': r'$transcriptResult.transcript', 'analysis': r'$analysis'}, outputKey: 'note'),
    SkillStep(toolName: 'audio.upload',   input: {'noteId': r'$noteId', 'localPath': r'$audioPath'},
      requiredTier: ToolTier.plus, onError: StepErrorPolicy.skip),
  ],
);
```

Step features:
- `r'$varName'` — variable reference; `r'$result.data.field'` — dot-path resolution
- `parallel: true` — concurrent steps
- `forEach: r'$list'` — step per item
- `condition: r'$flag'` — skip if falsy
- `onError: StepErrorPolicy.fail | skip | retryOnce`

Every step routes through `EngineController.executeTool()` — full tracing applies.

---

## Consequences

**Positive:**
- Multi-step flows are declarative and testable step by step
- Tier gating and error handling are handled per-step by the executor
- New skills compose from existing tools without new code
- `EngineController.executeSkill()` is the only entry point — same trace discipline as single tools

**Negative:**
- Complex data transformations between steps require careful `outputKey`/`r'$...'` wiring
- Skills must be registered in `SkillRegistry.initialize()` in `built_in_skills.dart`

**Registration:**
1. Define `Skill(...)` in `lib/tools/skill_engine/skills/built_in_skills.dart`
2. Add to `skillRegistry.registerAll([...])` in `SkillRegistry.initialize()`
