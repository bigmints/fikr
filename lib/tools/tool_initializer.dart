/// Tool + Skill + Hook initializer — registers all built-in tools, skills,
/// and NBA (Next Best Actions) hooks during app startup.
///
/// Call [initializeTools] once during app initialization (e.g. in main.dart
/// or AppController.initialize) to populate the global registries.
library;

import 'tool_registry.dart';
import 'skill_engine/skill_registry.dart';
import 'skill_engine/skills/built_in_skills.dart';
import 'tools/ai_tools.dart';
import 'tools/audio_tools.dart';
import 'tools/communication_tools.dart';
import 'tools/contacts_tools.dart';
import 'tools/config_tools.dart';
import 'tools/mcp_tools.dart';
import 'tools/notes_tools.dart';
import 'tools/notifications_tools.dart';
import 'tools/reminders_tools.dart';
import 'tools/schedule_tools.dart';
import 'tools/sync_tools.dart';
import 'tools/tasks_tools.dart';
import 'tools/util_tools.dart';
import 'tools/usage_tools.dart';
import 'tools/vision_tools.dart';
import 'hooks/hook_initializer.dart';

/// Register all built-in tools, skills, and hooks in the global registries.
///
/// Idempotent — safe to call multiple times (clears and re-registers).
/// Dynamic tools (MCP servers, webhooks) are registered separately at runtime
/// via [ToolRegistrar] after saved server configs are loaded.
void initializeTools() {
  // ── Tools ────────────────────────────────────────────────────────────
  final toolRegistry = ToolRegistry.instance;
  toolRegistry.clear();

  // Core data tools
  toolRegistry.registerAll(allNotesTools());
  toolRegistry.registerAll(allTasksTools());
  toolRegistry.registerAll(allRemindersTools());

  // AI tools
  toolRegistry.registerAll(allAiTools());

  // Audio tools
  toolRegistry.registerAll(allAudioTools());

  // Utility tools (pure functions — no side effects)
  toolRegistry.registerAll(allUtilTools());

  // Usage / billing
  toolRegistry.registerAll(allUsageTools());

  // Config
  toolRegistry.registerAll(allConfigTools());

  // Sync
  toolRegistry.registerAll(allSyncTools());

  // Notifications
  toolRegistry.registerAll(allNotificationsTools());

  // Contacts
  toolRegistry.registerAll(allContactsTools());

  // Communication
  toolRegistry.registerAll(allCommunicationTools());

  // MCP management
  toolRegistry.registerAll(allMcpTools());

  // Scheduling
  toolRegistry.registerAll(allScheduleTools());

  // Vision
  toolRegistry.registerAll(allVisionTools());

  // ── Skills ───────────────────────────────────────────────────────────
  final skillRegistry = SkillRegistry.instance;
  skillRegistry.clear();
  skillRegistry.registerAll(allBuiltInSkills());

  // ── NBA Hooks ────────────────────────────────────────────────────────
  initializeHooks();
}
