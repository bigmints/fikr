/// Next Best Actions hook initializer — registers all built-in NBA hooks
/// during app startup.
///
/// Call [initializeHooks] once during app initialization (after [initializeTools])
/// to populate the [ActionHookRegistry] singleton.
library;

import 'hook_engine.dart';
import 'domain/intelligent_llm_hook.dart';

/// Return all built-in NBA hooks.
List<ActionHook> allNbaHooks() => [
      // ── Intelligent Engine ─────────────────────────────────────────
      IntelligentLlmHook(),
    ];

/// Register all built-in NBA hooks in the global registry.
///
/// Idempotent — safe to call multiple times (clears and re-registers).
void initializeHooks() {
  final registry = ActionHookRegistry.instance;
  registry.clear();
  registry.registerAll(allNbaHooks());
}
