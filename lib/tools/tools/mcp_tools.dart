/// MCP domain tools — stub implementations for Phase 4.
///
/// Free users will connect to MCP servers directly (client-side SSE/HTTP).
/// Plus users get cloud-synced configs. Pro users go through fikr.one proxy.
library;

import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  mcp.list_servers
// ───────────────────────────────────────────────────────────────────────────

class McpListServersTool extends FikrTool {
  @override
  String get name => 'mcp.list_servers';

  @override
  String get description => 'List registered MCP servers and their status.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Phase 4 — will read from local config (free) or Firestore (plus/pro)
    return ToolResult.ok({'servers': <Map<String, dynamic>>[]});
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  mcp.register
// ───────────────────────────────────────────────────────────────────────────

class McpRegisterTool extends FikrTool {
  @override
  String get name => 'mcp.register';

  @override
  String get description =>
      'Register a new MCP server connection (URL + optional API key).';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Display name.'},
      'url': {'type': 'string', 'description': 'MCP server SSE/HTTP URL.'},
      'apiKey': {'type': 'string', 'description': 'Optional auth key.'},
    },
    'required': ['name', 'url'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Phase 4
    return ToolResult.fail('MCP registration not yet implemented.');
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  mcp.discover_tools
// ───────────────────────────────────────────────────────────────────────────

class McpDiscoverToolsTool extends FikrTool {
  @override
  String get name => 'mcp.discover_tools';

  @override
  String get description =>
      'List all tools available from a specific MCP server.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'serverId': {'type': 'string', 'description': 'MCP server ID.'},
    },
    'required': ['serverId'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Phase 4
    return ToolResult.ok({'tools': <Map<String, dynamic>>[]});
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  mcp.invoke
// ───────────────────────────────────────────────────────────────────────────

class McpInvokeTool extends FikrTool {
  @override
  String get name => 'mcp.invoke';

  @override
  String get description =>
      'Invoke a tool on an MCP server by name with parameters.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'serverId': {'type': 'string'},
      'toolName': {'type': 'string'},
      'arguments': {'type': 'object'},
    },
    'required': ['serverId', 'toolName'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.mcp;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Phase 4 — will route to client-side or fikr.one proxy based on tier
    return ToolResult.fail('MCP invocation not yet implemented.');
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allMcpTools() => [
      McpListServersTool(),
      McpRegisterTool(),
      McpDiscoverToolsTool(),
      McpInvokeTool(),
    ];
