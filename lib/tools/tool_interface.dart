/// Core interfaces for the Fikr Tools engine.
///
/// Every tool in the system implements [FikrTool], which provides a typed
/// contract for discovery (by the LLM tool selector), tier gating, and
/// execution.
library;

import '../models/app_config.dart';
import '../services/storage_service.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Where the tool actually executes.
enum ToolLocation {
  /// Runs entirely on the client device (Flutter).
  local,

  /// Requires a round-trip to fikr.one cloud API.
  cloud,

  /// Proxied through an MCP server (local or cloud, depending on tier).
  mcp,
}

/// Minimum subscription tier required to invoke the tool.
enum ToolTier {
  free,
  plus,
  pro,
}

// ---------------------------------------------------------------------------
// ToolResult
// ---------------------------------------------------------------------------

/// Uniform result envelope returned by every tool invocation.
class ToolResult {
  const ToolResult._({
    required this.success,
    this.data,
    this.error,
  });

  /// Successful result.
  factory ToolResult.ok([dynamic data]) =>
      ToolResult._(success: true, data: data);

  /// Failed result with an error message.
  factory ToolResult.fail(String error) =>
      ToolResult._(success: false, error: error);

  final bool success;

  /// Arbitrary payload — can be a Map, List, String, etc.
  final dynamic data;

  /// Human-readable error when [success] is false.
  final String? error;

  @override
  String toString() =>
      success ? 'ToolResult.ok($data)' : 'ToolResult.fail($error)';
}

// ---------------------------------------------------------------------------
// ToolContext
// ---------------------------------------------------------------------------

/// Ambient runtime context passed to every tool execution.
///
/// This avoids tools needing to locate services themselves and makes testing
/// trivial (inject mocks).
class ToolContext {
  const ToolContext({
    this.userId,
    required this.planTier,
    required this.config,
    required this.storage,
  });

  /// Current Firebase UID (null if signed out / free tier).
  final String? userId;

  /// Active subscription tier.
  final ToolTier planTier;

  /// Current app configuration snapshot.
  final AppConfig config;

  /// Local storage service.
  final StorageService storage;
}

// ---------------------------------------------------------------------------
// FikrTool
// ---------------------------------------------------------------------------

/// Base class for all tools in the Fikr engine.
///
/// Each tool declares its schema (for LLM discovery) and implements
/// [execute] with validated parameters.
abstract class FikrTool {
  /// Unique dot-namespaced identifier, e.g. `notes.list`, `ai.transcribe`.
  String get name;

  /// Human-readable description used in LLM system prompts for tool selection.
  String get description;

  /// JSON Schema (draft-07 compatible) describing the expected parameters.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "type": "object",
  ///   "properties": {
  ///     "bucket": { "type": "string" },
  ///     "limit":  { "type": "integer", "default": 50 }
  ///   }
  /// }
  /// ```
  Map<String, dynamic> get parametersSchema;

  /// Minimum tier required. Tools with a higher tier than the user's plan
  /// will be filtered out of the registry before LLM prompting.
  ToolTier get requiredTier;

  /// Where the tool runs (local, cloud, mcp).
  ToolLocation get location;

  /// Execute the tool.
  ///
  /// [params] have already been validated against [parametersSchema].
  /// [context] carries ambient state (user, config, storage).
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  );

  /// Converts the tool's schema into a format suitable for LLM system prompts.
  Map<String, dynamic> toSchemaMap() {
    return {
      'name': name,
      'description': description,
      'parameters': parametersSchema,
      'requiredTier': requiredTier.name,
      'location': location.name,
    };
  }
}
