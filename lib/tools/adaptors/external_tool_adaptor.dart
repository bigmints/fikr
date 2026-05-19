/// External Tool Adaptor — wraps HTTP endpoints as first-class [FikrTool]s.
///
/// Supports three transports:
/// - [McpToolAdaptor]     — JSON-RPC 2.0 (Model Context Protocol)
/// - [WebhookToolAdaptor] — HTTP POST with optional HMAC-SHA256 signing
/// - [RestToolAdaptor]    — Generic REST endpoint (any method/headers)
///
/// All adaptors implement [FikrTool] and can be registered dynamically
/// into [ToolRegistry] at runtime. Dynamic tools appear in the LLM schema
/// alongside built-in tools seamlessly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../tool_interface.dart';
import '../tool_registry.dart';

// ---------------------------------------------------------------------------
// Transport configs
// ---------------------------------------------------------------------------

/// Config for an MCP server connection.
class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.apiKey,
    this.timeoutSeconds = 30,
    this.tier = ToolTier.free,
  });

  final String id;
  final String name;
  final String url;
  final String? apiKey;
  final int timeoutSeconds;
  final ToolTier tier;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        if (apiKey != null) 'apiKey': apiKey,
        'timeoutSeconds': timeoutSeconds,
        'tier': tier.name,
      };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) => McpServerConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        apiKey: json['apiKey'] as String?,
        timeoutSeconds: json['timeoutSeconds'] as int? ?? 30,
        tier: ToolTier.values.firstWhere(
          (t) => t.name == (json['tier'] as String? ?? 'free'),
          orElse: () => ToolTier.free,
        ),
      );
}

/// Config for a webhook endpoint.
class WebhookConfig {
  const WebhookConfig({
    required this.id,
    required this.name,
    required this.toolName,
    required this.url,
    this.secret,
    this.description = '',
    this.parametersSchema = const {'type': 'object', 'properties': {}},
    this.tier = ToolTier.free,
    this.headers = const {},
  });

  final String id;
  final String name;
  final String toolName;
  final String url;
  final String? secret; // HMAC-SHA256 signing secret
  final String description;
  final Map<String, dynamic> parametersSchema;
  final ToolTier tier;
  final Map<String, String> headers;
}

/// Config for a generic REST endpoint.
class RestConfig {
  const RestConfig({
    required this.id,
    required this.name,
    required this.toolName,
    required this.url,
    this.method = 'POST',
    this.description = '',
    this.parametersSchema = const {'type': 'object', 'properties': {}},
    this.tier = ToolTier.free,
    this.headers = const {},
    this.apiKey,
  });

  final String id;
  final String name;
  final String toolName;
  final String url;
  final String method;
  final String description;
  final Map<String, dynamic> parametersSchema;
  final ToolTier tier;
  final Map<String, String> headers;
  final String? apiKey;
}

// ---------------------------------------------------------------------------
// MCP Tool Adaptor
// ---------------------------------------------------------------------------

/// Wraps a single MCP server tool as a [FikrTool].
///
/// Tool name pattern: `mcp.<serverId>.<mcpToolName>`
/// e.g. `mcp.notion.search_pages`
class McpToolAdaptor extends FikrTool with FikrToolMixin {
  McpToolAdaptor({
    required this.serverConfig,
    required this.mcpToolName,
    required String mcpDescription,
    required Map<String, dynamic> mcpParametersSchema,
  })  : _description = mcpDescription,
        _parametersSchema = mcpParametersSchema;

  final McpServerConfig serverConfig;
  final String mcpToolName;
  final String _description;
  final Map<String, dynamic> _parametersSchema;

  @override
  String get name => 'mcp.${serverConfig.id}.$mcpToolName';

  @override
  String get description => _description;

  @override
  Map<String, dynamic> get parametersSchema => _parametersSchema;

  @override
  ToolTier get requiredTier => serverConfig.tier;

  @override
  ToolLocation get location => ToolLocation.mcp;

  @override
  List<String> get tags => ['mcp', serverConfig.name];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        context.logger.info(
          'MCP invoke $mcpToolName on ${serverConfig.name}',
          data: {'serverId': serverConfig.id, 'url': serverConfig.url},
        );

        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        if (serverConfig.apiKey != null && serverConfig.apiKey!.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${serverConfig.apiKey}';
        }

        final body = jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {'name': mcpToolName, 'arguments': params},
        });

        final response = await http
            .post(Uri.parse(serverConfig.url), headers: headers, body: body)
            .timeout(Duration(seconds: serverConfig.timeoutSeconds));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          context.logger.error('MCP HTTP error ${response.statusCode}');
          return ToolResult.fail(
            'MCP server returned ${response.statusCode}: ${response.body}',
            code: ToolResultCode.networkError,
            toolName: name,
            traceId: context.traceId,
          );
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['error'] != null) {
          final err = decoded['error'] as Map<String, dynamic>;
          return ToolResult.fail(
            'MCP error: ${err['message']}',
            toolName: name,
            traceId: context.traceId,
          );
        }

        return ToolResult.okMeta(
          decoded['result'],
          toolName: name,
          traceId: context.traceId,
        );
      });
}

// ---------------------------------------------------------------------------
// Webhook Tool Adaptor
// ---------------------------------------------------------------------------

/// Wraps an HTTP webhook endpoint as a [FikrTool].
///
/// Signs the request body with HMAC-SHA256 if a [WebhookConfig.secret] is set.
class WebhookToolAdaptor extends FikrTool with FikrToolMixin {
  WebhookToolAdaptor(this.config);

  final WebhookConfig config;

  @override
  String get name => 'webhook.${config.id}';

  @override
  String get description => config.description;

  @override
  Map<String, dynamic> get parametersSchema => config.parametersSchema;

  @override
  ToolTier get requiredTier => config.tier;

  @override
  ToolLocation get location => ToolLocation.webhook;

  @override
  List<String> get tags => ['webhook', config.name];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        context.logger.info('Webhook invoke ${config.name}', data: {'url': config.url});

        final body = jsonEncode({
          'params': params,
          'traceId': context.traceId,
          'userId': context.userId,
          'tier': context.planTier.name,
        });

        final headers = <String, String>{
          'Content-Type': 'application/json',
          ...config.headers,
        };

        // HMAC-SHA256 signing
        if (config.secret != null && config.secret!.isNotEmpty) {
          final mac = Hmac(sha256, utf8.encode(config.secret!));
          final digest = mac.convert(utf8.encode(body));
          headers['X-Fikr-Signature'] = 'sha256=$digest';
        }

        final response = await http.post(
          Uri.parse(config.url),
          headers: headers,
          body: body,
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ToolResult.fail(
            'Webhook returned ${response.statusCode}: ${response.body}',
            code: ToolResultCode.networkError,
            toolName: name,
            traceId: context.traceId,
          );
        }

        dynamic result;
        try {
          result = jsonDecode(response.body);
        } catch (_) {
          result = {'raw': response.body};
        }

        return ToolResult.okMeta(result, toolName: name, traceId: context.traceId);
      });
}

// ---------------------------------------------------------------------------
// REST Tool Adaptor
// ---------------------------------------------------------------------------

/// Wraps a generic REST endpoint as a [FikrTool].
class RestToolAdaptor extends FikrTool with FikrToolMixin {
  RestToolAdaptor(this.config);

  final RestConfig config;

  @override
  String get name => 'rest.${config.id}';

  @override
  String get description => config.description;

  @override
  Map<String, dynamic> get parametersSchema => config.parametersSchema;

  @override
  ToolTier get requiredTier => config.tier;

  @override
  ToolLocation get location => ToolLocation.cloud;

  @override
  List<String> get tags => ['rest', config.name];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        context.logger.info('REST invoke ${config.name} [${config.method}]');

        final headers = <String, String>{
          'Content-Type': 'application/json',
          ...config.headers,
        };
        if (config.apiKey != null && config.apiKey!.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${config.apiKey}';
        }

        final uri = Uri.parse(config.url);
        http.Response response;

        if (config.method.toUpperCase() == 'GET') {
          final queryUri = uri.replace(queryParameters: {
            for (final e in params.entries) e.key: e.value.toString(),
          });
          response = await http.get(queryUri, headers: headers);
        } else {
          response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(params),
          );
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ToolResult.fail(
            'REST ${config.method} returned ${response.statusCode}',
            code: ToolResultCode.networkError,
            toolName: name,
            traceId: context.traceId,
          );
        }

        dynamic result;
        try {
          result = jsonDecode(response.body);
        } on FormatException {
          result = {'raw': response.body};
        }

        return ToolResult.okMeta(result, toolName: name, traceId: context.traceId);
      });
}

// ---------------------------------------------------------------------------
// MCP Tool Discoverer — discovers and registers all tools from an MCP server
// ---------------------------------------------------------------------------

/// Connects to an MCP server, calls `tools/list`, and returns
/// a [McpToolAdaptor] for each discovered tool.
class McpToolDiscoverer {
  const McpToolDiscoverer._();

  static Future<List<McpToolAdaptor>> discover(McpServerConfig config) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    final response = await http.post(
      Uri.parse(config.url),
      headers: headers,
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
        'params': {},
      }),
    ).timeout(Duration(seconds: config.timeoutSeconds));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'MCP discover failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw Exception('MCP list error: ${decoded['error']}');
    }

    final tools = (decoded['result']?['tools'] as List<dynamic>?) ?? [];
    return tools.map((raw) {
      final t = raw as Map<String, dynamic>;
      return McpToolAdaptor(
        serverConfig: config,
        mcpToolName: t['name'] as String,
        mcpDescription: t['description'] as String? ?? '',
        mcpParametersSchema: t['inputSchema'] as Map<String, dynamic>? ??
            {'type': 'object', 'properties': {}},
      );
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// ToolRegistrar — registers external tools into ToolRegistry
// ---------------------------------------------------------------------------

/// Service for registering dynamic tools (MCP servers, webhooks, REST) at
/// runtime. Call [registerMcpServer] after connecting a server, and
/// [unregisterSource] on disconnect.
class ToolRegistrar {
  const ToolRegistrar._();

  static final ToolRegistrar instance = ToolRegistrar._();

  /// Discover all tools from an MCP server and register them.
  ///
  /// Returns the number of tools registered.
  Future<int> registerMcpServer(McpServerConfig config) async {
    final adaptors = await McpToolDiscoverer.discover(config);
    final source = ToolRegistrationSource(
      type: 'mcp',
      sourceId: config.id,
      sourceName: config.name,
      registeredAt: DateTime.now(),
    );
    for (final adaptor in adaptors) {
      ToolRegistry.instance.registerDynamic(adaptor, source: source);
    }
    return adaptors.length;
  }

  /// Register a single webhook as a tool.
  FikrTool registerWebhook(WebhookConfig config) {
    final adaptor = WebhookToolAdaptor(config);
    ToolRegistry.instance.registerDynamic(
      adaptor,
      source: ToolRegistrationSource(
        type: 'webhook',
        sourceId: config.id,
        sourceName: config.name,
        registeredAt: DateTime.now(),
      ),
    );
    return adaptor;
  }

  /// Register a REST endpoint as a tool.
  FikrTool registerRest(RestConfig config) {
    final adaptor = RestToolAdaptor(config);
    ToolRegistry.instance.registerDynamic(
      adaptor,
      source: ToolRegistrationSource(
        type: 'rest',
        sourceId: config.id,
        sourceName: config.name,
        registeredAt: DateTime.now(),
      ),
    );
    return adaptor;
  }

  /// Unregister all tools from a given source (server disconnect / removal).
  void unregisterSource(String sourceId) {
    ToolRegistry.instance.unregisterSource(sourceId);
  }
}
