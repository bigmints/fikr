/// Tool + Skill initializer — registers all built-in tools and skills
/// during app startup.
///
/// Call [initializeTools] once during app initialization (e.g. in main.dart
/// or AppController.initialize) to populate the global registries.
library;

import 'tool_registry.dart';
import 'skill_engine/skill_registry.dart';
import 'skill_engine/skills/built_in_skills.dart';
import 'tools/ai_tools.dart';
import 'tools/audio_tools.dart';
import 'tools/config_tools.dart';
import 'tools/mcp_tools.dart';
import 'tools/notes_tools.dart';
import 'tools/notifications_tools.dart';
import 'tools/reminders_tools.dart';
import 'tools/schedule_tools.dart';
import 'tools/sync_tools.dart';
import 'tools/tasks_tools.dart';

/// Register all built-in tools and skills in the global registries.
///
/// Idempotent — safe to call multiple times (clears and re-registers).
void initializeTools() {
  // ── Tools ────────────────────────────────────────────────────────────
  final toolRegistry = ToolRegistry.instance;
  toolRegistry.clear();

  toolRegistry.registerAll(allNotesTools());
  toolRegistry.registerAll(allTasksTools());
  toolRegistry.registerAll(allRemindersTools());
  toolRegistry.registerAll(allAiTools());
  toolRegistry.registerAll(allAudioTools());
  toolRegistry.registerAll(allConfigTools());
  toolRegistry.registerAll(allSyncTools());
  toolRegistry.registerAll(allNotificationsTools());
  toolRegistry.registerAll(allMcpTools());
  toolRegistry.registerAll(allScheduleTools());

  // ── Skills ───────────────────────────────────────────────────────────
  final skillRegistry = SkillRegistry.instance;
  skillRegistry.clear();
  skillRegistry.registerAll(allBuiltInSkills());
}
