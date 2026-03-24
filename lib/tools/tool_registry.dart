/// Tool Registry — central catalogue of all available tools.
///
/// The registry is the single source of truth that the LLM tool selector
/// and the skill executor query to discover tools. It supports tier-aware
/// filtering so free users never see Pro-only tools.
library;

import 'tool_interface.dart';

class ToolRegistry {
  ToolRegistry._();

  static final ToolRegistry instance = ToolRegistry._();

  final Map<String, FikrTool> _tools = {};

  // ── Registration ──────────────────────────────────────────────────

  /// Register a single tool.
  void register(FikrTool tool) {
    if (_tools.containsKey(tool.name)) {
      throw StateError(
        'Tool "${tool.name}" is already registered. '
        'Use replace() for intentional overrides.',
      );
    }
    _tools[tool.name] = tool;
  }

  /// Register a list of tools.
  void registerAll(List<FikrTool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  /// Replace an existing tool (e.g. MCP override of a native tool).
  void replace(FikrTool tool) {
    _tools[tool.name] = tool;
  }

  /// Unregister a tool by name.
  void unregister(String name) {
    _tools.remove(name);
  }

  // ── Discovery ─────────────────────────────────────────────────────

  /// Get a tool by exact name.
  FikrTool? get(String name) => _tools[name];

  /// All registered tools (unfiltered).
  List<FikrTool> get all => List.unmodifiable(_tools.values);

  /// Tools available for a given tier (respects [ToolTier] hierarchy).
  List<FikrTool> toolsForTier(ToolTier tier) {
    return _tools.values.where((t) => t.requiredTier.index <= tier.index).toList();
  }

  /// Tools in a specific domain (e.g. "notes", "ai", "tasks").
  List<FikrTool> toolsInDomain(String domain) {
    return _tools.values
        .where((t) => t.name.startsWith('$domain.'))
        .toList();
  }

  /// Number of registered tools.
  int get count => _tools.length;

  /// Whether a tool is registered.
  bool has(String name) => _tools.containsKey(name);

  // ── LLM Schema Export ─────────────────────────────────────────────

  /// Export tool schemas for the LLM system prompt.
  ///
  /// Only includes tools the user's plan tier allows.
  List<Map<String, dynamic>> schemaForTier(ToolTier tier) {
    return toolsForTier(tier).map((t) => t.toSchemaMap()).toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────

  /// Clear all registrations (useful in tests).
  void clear() => _tools.clear();
}
