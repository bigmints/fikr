/// Tool Registry — central catalogue of all available tools.
///
/// The registry is the single source of truth that the LLM tool selector
/// and the skill executor query to discover tools. Supports:
/// - Tier-aware filtering
/// - Dynamic registration at runtime (MCP servers, webhooks)
/// - Source tracking (know which MCP server registered a tool)
/// - Hot-swap override for MCP tools replacing built-in tools
library;

import 'tool_interface.dart';

/// Describes where a registered tool came from.
class ToolRegistrationSource {
  const ToolRegistrationSource({
    required this.type,
    this.sourceId,
    this.sourceName,
    this.registeredAt,
  });

  /// 'builtin' | 'mcp' | 'webhook' | 'rest'
  final String type;

  /// Server/connection ID (for dynamic sources).
  final String? sourceId;

  /// Human-readable name of the source.
  final String? sourceName;

  /// When it was registered.
  final DateTime? registeredAt;

  static const ToolRegistrationSource builtin = ToolRegistrationSource(type: 'builtin');
}

class _RegistryEntry {
  _RegistryEntry({required this.tool, required this.source});
  final FikrTool tool;
  final ToolRegistrationSource source;
}

class ToolRegistry {
  ToolRegistry._();

  static final ToolRegistry instance = ToolRegistry._();

  /// Creates a fresh, isolated registry for unit testing.
  /// Does not share state with [instance].
  factory ToolRegistry.forTesting() => ToolRegistry._();

  final Map<String, _RegistryEntry> _entries = {};


  // ── Registration ──────────────────────────────────────────────────

  /// Register a built-in tool. Throws if already registered.
  void register(
    FikrTool tool, {
    ToolRegistrationSource source = ToolRegistrationSource.builtin,
  }) {
    if (_entries.containsKey(tool.name)) {
      throw StateError(
        'Tool "${tool.name}" is already registered. '
        'Use replace() for intentional overrides.',
      );
    }
    _entries[tool.name] = _RegistryEntry(tool: tool, source: source);
  }

  /// Register a list of built-in tools.
  void registerAll(
    List<FikrTool> tools, {
    ToolRegistrationSource source = ToolRegistrationSource.builtin,
  }) {
    for (final tool in tools) {
      register(tool, source: source);
    }
  }

  /// Register a dynamic tool (MCP / webhook). Never throws — silently replaces.
  void registerDynamic(
    FikrTool tool, {
    required ToolRegistrationSource source,
  }) {
    _entries[tool.name] = _RegistryEntry(tool: tool, source: source);
  }

  /// Replace an existing tool (e.g. MCP override of a native tool, or hot-swap).
  void replace(
    FikrTool tool, {
    ToolRegistrationSource source = ToolRegistrationSource.builtin,
  }) {
    _entries[tool.name] = _RegistryEntry(tool: tool, source: source);
  }

  /// Unregister a single tool by name.
  void unregister(String name) => _entries.remove(name);

  /// Unregister all tools belonging to a specific source (e.g. on MCP disconnect).
  void unregisterSource(String sourceId) {
    _entries.removeWhere((_, e) => e.source.sourceId == sourceId);
  }

  // ── Discovery ─────────────────────────────────────────────────────

  /// Get a tool by exact name.
  FikrTool? get(String name) => _entries[name]?.tool;

  /// All registered tools (unfiltered).
  List<FikrTool> get all => List.unmodifiable(_entries.values.map((e) => e.tool));

  /// Tools available for a given tier (respects [ToolTier] hierarchy).
  List<FikrTool> toolsForTier(ToolTier tier) {
    return _entries.values
        .where((e) => e.tool.requiredTier.index <= tier.index)
        .map((e) => e.tool)
        .toList();
  }

  /// Tools in a specific domain (e.g. "notes", "ai", "tasks").
  List<FikrTool> toolsInDomain(String domain) {
    return _entries.values
        .where((e) => e.tool.name.startsWith('$domain.'))
        .map((e) => e.tool)
        .toList();
  }

  /// Tools registered from a specific source ID (e.g. an MCP server).
  List<FikrTool> toolsFromSource(String sourceId) {
    return _entries.values
        .where((e) => e.source.sourceId == sourceId)
        .map((e) => e.tool)
        .toList();
  }

  /// Tools with a specific tag.
  List<FikrTool> toolsWithTag(String tag) {
    return _entries.values
        .where((e) => e.tool.tags.contains(tag))
        .map((e) => e.tool)
        .toList();
  }

  /// Number of registered tools.
  int get count => _entries.length;

  /// Whether a tool is registered.
  bool has(String name) => _entries.containsKey(name);

  /// Source info for a given tool name.
  ToolRegistrationSource? sourceOf(String name) => _entries[name]?.source;

  // ── LLM Schema Export ─────────────────────────────────────────────

  /// Export tool schemas for the LLM system prompt.
  /// Only includes public tools the user's plan tier allows.
  List<Map<String, dynamic>> schemaForTier(ToolTier tier) {
    return toolsForTier(tier)
        .where((t) => t.isPublic)
        .map((t) => t.toSchemaMap())
        .toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────

  /// Clear all registrations (useful in tests).
  void clear() => _entries.clear();

  /// Summary of all registered tools grouped by domain.
  Map<String, List<String>> get domainSummary {
    final map = <String, List<String>>{};
    for (final name in _entries.keys) {
      final domain = name.contains('.') ? name.split('.').first : 'other';
      map.putIfAbsent(domain, () => []).add(name);
    }
    return map;
  }
}
