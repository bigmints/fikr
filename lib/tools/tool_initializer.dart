/// Tool initializer — registers all built-in tools during app startup.
///
/// Call [initializeTools] once during app initialization (e.g. in main.dart
/// or AppController.initialize) to populate the global [ToolRegistry].
library;

import 'tool_registry.dart';
import 'tools/ai_tools.dart';
import 'tools/audio_tools.dart';
import 'tools/config_tools.dart';
import 'tools/mcp_tools.dart';
import 'tools/notes_tools.dart';
import 'tools/notifications_tools.dart';
import 'tools/reminders_tools.dart';
import 'tools/sync_tools.dart';
import 'tools/tasks_tools.dart';

/// Register all built-in tools in the global [ToolRegistry].
///
/// Idempotent — safe to call multiple times (clears and re-registers).
void initializeTools() {
  final registry = ToolRegistry.instance;
  registry.clear();

  registry.registerAll(allNotesTools());
  registry.registerAll(allTasksTools());
  registry.registerAll(allRemindersTools());
  registry.registerAll(allAiTools());
  registry.registerAll(allAudioTools());
  registry.registerAll(allConfigTools());
  registry.registerAll(allSyncTools());
  registry.registerAll(allNotificationsTools());
  registry.registerAll(allMcpTools());
}
