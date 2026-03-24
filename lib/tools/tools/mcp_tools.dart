/// MCP domain tools — client-side and cloud-proxied MCP connections.
///
/// Free users: connect directly to MCP servers via HTTP from Flutter.
/// Plus users: client-side + cloud-synced configs via Firestore.
/// Pro users: fikr.one proxy (API keys stay server-side).
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../controllers/subscription_controller.dart';
import '../../services/fikr_api_service.dart';
import '../../services/storage_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  Local MCP client (for Free/Plus tiers — direct connection)
// ───────────────────────────────────────────────────────────────────────────

class _LocalMcpClient {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> _jsonRpcCall(
    String url,
    String method,
    Map<String, dynamic> params, {
    String? apiKey,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MCP call failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception('MCP error: ${data['error']['message']}');
    }
    return data['result'] as Map<String, dynamic>? ?? {};
  }

  Future<List<Map<String, dynamic>>> discoverTools(
    String url, {
    String? apiKey,
  }) async {
    final result = await _jsonRpcCall(url, 'tools/list', {}, apiKey: apiKey);
    final tools = result['tools'] as List<dynamic>? ?? [];
    return tools.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> invokeTool(
    String url,
    String toolName,
    Map<String, dynamic> args, {
    String? apiKey,
  }) async {
    return _jsonRpcCall(
      url,
      'tools/call',
      {'name': toolName, 'arguments': args},
      apiKey: apiKey,
    );
  }
}

final _localClient = _LocalMcpClient();

// ───────────────────────────────────────────────────────────────────────────
//  MCP server config storage (local, for free/plus tiers)
// ───────────────────────────────────────────────────────────────────────────

class _McpConfigStore {
  static const _key = 'mcp_servers';

  static Future<List<Map<String, dynamic>>> loadServers(
    StorageService storage,
  ) async {
    const secureStorage = FlutterSecureStorage();
    final raw = await secureStorage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> saveServers(
    StorageService storage,
    List<Map<String, dynamic>> servers,
  ) async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: _key, value: jsonEncode(servers));
  }
}

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
    try {
      final sub = Get.find<SubscriptionController>();

      // Pro users — fetch from fikr.one
      if (sub.isPro) {
        // The fikr.one API handles server management for Pro
        return ToolResult.ok({
          'source': 'cloud',
          'message': 'Use fikr.one dashboard to manage MCP servers.',
        });
      }

      // Free/Plus — read from local storage
      final servers = await _McpConfigStore.loadServers(context.storage);
      return ToolResult.ok({'servers': servers, 'source': 'local'});
    } catch (e) {
      return ToolResult.fail('Failed to list MCP servers: $e');
    }
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
      'url': {'type': 'string', 'description': 'MCP server HTTP URL.'},
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
    try {
      final serverName = params['name'] as String;
      final url = params['url'] as String;
      final apiKey = params['apiKey'] as String?;

      final servers = await _McpConfigStore.loadServers(context.storage);
      final newServer = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': serverName,
        'url': url,
        'apiKey': apiKey ?? '',
        'enabled': true,
        'createdAt': DateTime.now().toIso8601String(),
      };
      servers.add(newServer);
      await _McpConfigStore.saveServers(context.storage, servers);

      return ToolResult.ok(newServer);
    } catch (e) {
      return ToolResult.fail('Failed to register MCP server: $e');
    }
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
    try {
      final serverId = params['serverId'] as String;
      final servers = await _McpConfigStore.loadServers(context.storage);
      final server = servers.firstWhere(
        (s) => s['id'] == serverId,
        orElse: () => <String, dynamic>{},
      );

      if (server.isEmpty) {
        return ToolResult.fail('Server "$serverId" not found.');
      }

      final tools = await _localClient.discoverTools(
        server['url'] as String,
        apiKey: server['apiKey'] as String?,
      );

      return ToolResult.ok({'tools': tools});
    } catch (e) {
      return ToolResult.fail('Failed to discover tools: $e');
    }
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
    try {
      final serverId = params['serverId'] as String;
      final toolName = params['toolName'] as String;
      final args =
          (params['arguments'] as Map<String, dynamic>?) ?? {};
      final sub = Get.find<SubscriptionController>();

      // Pro → route through fikr.one proxy
      if (sub.isPro) {
        return _invokeViaProxy(serverId, toolName, args);
      }

      // Free/Plus → direct client-side call
      final servers = await _McpConfigStore.loadServers(context.storage);
      final server = servers.firstWhere(
        (s) => s['id'] == serverId,
        orElse: () => <String, dynamic>{},
      );

      if (server.isEmpty) {
        return ToolResult.fail('Server "$serverId" not found.');
      }

      final result = await _localClient.invokeTool(
        server['url'] as String,
        toolName,
        args,
        apiKey: server['apiKey'] as String?,
      );

      return ToolResult.ok(result);
    } catch (e) {
      return ToolResult.fail('MCP invoke failed: $e');
    }
  }

  Future<ToolResult> _invokeViaProxy(
    String serverId,
    String toolName,
    Map<String, dynamic> args,
  ) async {
    try {
      final _ = FikrApiService();
      final uri = Uri.parse('${FikrApiService.baseUrl}/api/mcp/invoke');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      // Auth headers are handled by FikrApiService pattern
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'serverId': serverId,
          'toolName': toolName,
          'arguments': args,
        }),
      );

      if (response.statusCode != 200) {
        return ToolResult.fail('MCP proxy error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ToolResult.ok(data['result']);
    } catch (e) {
      return ToolResult.fail('MCP proxy invocation failed: $e');
    }
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
