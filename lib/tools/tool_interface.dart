/// Core interfaces for the Fikr Tools engine.
///
/// Every tool in the system implements [FikrTool], which provides a typed
/// contract for discovery (by the LLM tool selector), tier gating, tracing,
/// and execution.
///
/// Architecture rule: ALL app events route through [EngineController] and
/// resolve to a [FikrTool.execute] call. No UI or controller code may call
/// services, storage, or state directly for domain operations.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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

  /// Delivered via an external webhook endpoint.
  webhook,
}

/// Minimum subscription tier required to invoke the tool.
enum ToolTier {
  free,
  plus,
  pro,
}

/// Typed result code for every tool invocation.
enum ToolResultCode {
  /// Operation succeeded.
  ok,

  /// Generic failure.
  fail,

  /// User's tier is insufficient.
  tierDenied,

  /// Requested resource was not found.
  notFound,

  /// Network or HTTP error.
  networkError,

  /// Operation timed out.
  timeout,

  /// Input params failed schema validation.
  validationError,

  /// Tool is not registered.
  toolNotFound,
}

// ---------------------------------------------------------------------------
// ToolLogLevel / ToolLogEntry / ToolLogger
// ---------------------------------------------------------------------------

enum ToolLogLevel { debug, info, warn, error }

/// A single structured log entry emitted by a tool.
class ToolLogEntry {
  ToolLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.data,
    this.exception,
    this.stack,
  });

  final ToolLogLevel level;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final Object? exception;
  final StackTrace? stack;

  @override
  String toString() =>
      '[${level.name.toUpperCase()}] ${timestamp.toIso8601String()} — $message'
      '${data != null ? ' | data=$data' : ''}'
      '${exception != null ? ' | error=$exception' : ''}';
}

/// Per-invocation structured logger attached to every [ToolContext].
///
/// Tools call `context.logger.info(...)` etc. All entries are collected and
/// forwarded to [ToolExecutionLog] by [EngineController].
class ToolLogger {
  ToolLogger(this.toolName, this.traceId);

  final String toolName;
  final String traceId;
  final List<ToolLogEntry> _entries = [];

  List<ToolLogEntry> get entries => List.unmodifiable(_entries);

  void debug(String msg, {Map<String, dynamic>? data}) =>
      _add(ToolLogLevel.debug, msg, data: data);

  void info(String msg, {Map<String, dynamic>? data}) =>
      _add(ToolLogLevel.info, msg, data: data);

  void warn(String msg, {Map<String, dynamic>? data}) =>
      _add(ToolLogLevel.warn, msg, data: data);

  void error(String msg, {Object? exception, StackTrace? stack, Map<String, dynamic>? data}) {
    _add(ToolLogLevel.error, msg, data: data, exception: exception, stack: stack);
    if (kDebugMode) {
      debugPrint('[Tool:$toolName][$traceId] ERROR: $msg'
          '${exception != null ? '\n$exception' : ''}');
    }
  }

  void metric(String key, dynamic value) =>
      _add(ToolLogLevel.info, 'metric:$key=$value', data: {key: value});

  void _add(
    ToolLogLevel level,
    String message, {
    Map<String, dynamic>? data,
    Object? exception,
    StackTrace? stack,
  }) {
    final entry = ToolLogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      data: data,
      exception: exception,
      stack: stack,
    );
    _entries.add(entry);
    if (kDebugMode) {
      debugPrint('[Tool:$toolName][$traceId] ${entry.level.name.toUpperCase()}: $message');
    }
  }
}

// ---------------------------------------------------------------------------
// ToolResult
// ---------------------------------------------------------------------------

/// Uniform result envelope returned by every tool invocation.
class ToolResult {
  const ToolResult._({
    required this.success,
    required this.code,
    this.data,
    this.error,
    this.toolName,
    this.traceId,
    this.duration,
    this.meta,
  });

  /// Successful result with optional payload.
  factory ToolResult.ok([dynamic data]) =>
      ToolResult._(success: true, code: ToolResultCode.ok, data: data);

  /// Successful result with full tracing metadata.
  /// Used by [EngineController] to stamp results after execution.
  factory ToolResult.okMeta(
    dynamic data, {
    String? toolName,
    String? traceId,
    Duration? duration,
  }) =>
      ToolResult._(
        success: true,
        code: ToolResultCode.ok,
        data: data,
        toolName: toolName,
        traceId: traceId,
        duration: duration,
      );


  /// Failed result with a typed code and error message.
  factory ToolResult.fail(
    String error, {
    ToolResultCode code = ToolResultCode.fail,
    String? toolName,
    String? traceId,
    Duration? duration,
    Map<String, dynamic>? meta,
  }) =>
      ToolResult._(
        success: false,
        code: code,
        error: error,
        toolName: toolName,
        traceId: traceId,
        duration: duration,
        meta: meta,
      );

  /// Tier gate rejection.
  factory ToolResult.tierDenied(String toolName, ToolTier required) => ToolResult._(
        success: false,
        code: ToolResultCode.tierDenied,
        error: 'Tool "$toolName" requires ${required.name} tier.',
        toolName: toolName,
      );

  /// Tool not registered.
  factory ToolResult.notFound(String toolName) => ToolResult._(
        success: false,
        code: ToolResultCode.toolNotFound,
        error: 'Tool not found: $toolName',
        toolName: toolName,
      );

  final bool success;
  final ToolResultCode code;

  /// Arbitrary payload — can be a Map, List, String, etc.
  final dynamic data;

  /// Human-readable error when [success] is false.
  final String? error;

  /// Which tool produced this result.
  final String? toolName;

  /// Trace ID propagated from the engine call.
  final String? traceId;

  /// Wall-clock execution time.
  final Duration? duration;

  /// Arbitrary debug / diagnostic metadata.
  final Map<String, dynamic>? meta;

  @override
  String toString() => success
      ? 'ToolResult.ok($toolName | ${duration?.inMilliseconds}ms)'
      : 'ToolResult.fail[$code]($toolName: $error)';
}

// ---------------------------------------------------------------------------
// ToolContext
// ---------------------------------------------------------------------------

/// Ambient runtime context passed to every tool execution.
///
/// Avoids tools needing to locate services themselves and makes testing
/// trivial — inject mocks via constructor.
class ToolContext {
  ToolContext({
    this.userId,
    required this.planTier,
    required this.config,
    this.storage,
    String? traceId,
    this.callerToolName,
    this.isDryRun = false,
    ToolLogger? logger,
  })  : traceId = traceId ?? const Uuid().v4(),
        logger = logger ?? ToolLogger('unknown', traceId ?? '');

  /// Current Firebase UID (null if signed out / free tier).
  final String? userId;

  /// Active subscription tier.
  final ToolTier planTier;

  /// Current app configuration snapshot.
  final AppConfig config;

  /// Local storage service. May be null for tools that only mutate in-memory
  /// state via [IAppState].
  final StorageService? storage;

  /// Propagated trace ID — shared across all steps in a skill execution.
  final String traceId;

  /// The tool or skill that triggered this invocation (for nested calls).
  final String? callerToolName;

  /// If true, execute logic but skip all side effects (storage, network).
  final bool isDryRun;

  /// Structured logger bound to this invocation.
  final ToolLogger logger;

  /// Create a child context for nested tool calls (propagates traceId).
  ToolContext childContext({required String callerToolName}) {
    return ToolContext(
      userId: userId,
      planTier: planTier,
      config: config,
      storage: storage,
      traceId: traceId,
      callerToolName: callerToolName,
      isDryRun: isDryRun,
      logger: ToolLogger(callerToolName, traceId),
    );
  }
}

// ---------------------------------------------------------------------------
// ToolInvocation — persisted trace record
// ---------------------------------------------------------------------------

/// Immutable record of a single tool invocation, stored in [ToolExecutionLog].
class ToolInvocation {
  const ToolInvocation({
    required this.traceId,
    required this.toolName,
    required this.invokedAt,
    required this.result,
    required this.logEntries,
    this.callerToolName,
    this.skillName,
    this.params,
  });

  final String traceId;
  final String toolName;
  final DateTime invokedAt;
  final ToolResult result;
  final List<ToolLogEntry> logEntries;
  final String? callerToolName;
  final String? skillName;

  /// Redacted params (no secrets).
  final Map<String, dynamic>? params;

  bool get failed => !result.success;
  Duration? get duration => result.duration;
}

// ---------------------------------------------------------------------------
// FikrTool
// ---------------------------------------------------------------------------

/// Base class for all tools in the Fikr engine.
///
/// Each tool is a self-contained microservice:
/// - Declares its schema for LLM discovery
/// - Handles its own error cases and returns typed [ToolResult]
/// - Never throws — all errors are returned as [ToolResult.fail]
/// - Never accesses storage, services, or state via global singletons;
///   all dependencies come through [ToolContext]
///
/// Naming convention: `domain.verb` e.g. `notes.create`, `ai.transcribe`.
abstract class FikrTool {
  /// Unique dot-namespaced identifier, e.g. `notes.list`, `ai.transcribe`.
  String get name;

  /// Human-readable description used in LLM system prompts for tool selection.
  String get description;

  /// JSON Schema (draft-07 compatible) describing the expected parameters.
  Map<String, dynamic> get parametersSchema;

  /// Minimum tier required. Tools with a higher tier than the user's plan
  /// will be filtered out of the registry before LLM prompting.
  ToolTier get requiredTier;

  /// Where the tool runs (local, cloud, mcp, webhook).
  ToolLocation get location;

  /// Optional list of tags for categorization and discovery.
  List<String> get tags => const [];

  /// Whether this tool can be exposed to external LLM callers (MCP/chat).
  bool get isPublic => true;

  /// Execute the tool.
  ///
  /// [params] will have been validated against [parametersSchema] by the engine.
  /// [context] carries ambient state (user, config, storage, logger, traceId).
  ///
  /// MUST NOT throw. Return [ToolResult.fail] for all error cases.
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
      if (tags.isNotEmpty) 'tags': tags,
    };
  }
}

// ---------------------------------------------------------------------------
// FikrToolMixin — convenience helpers for tool implementations
// ---------------------------------------------------------------------------

/// Mixin providing helpers for safer tool implementations.
mixin FikrToolMixin on FikrTool {
  /// Execute [body] and return its result. Any thrown exception is caught and
  /// returned as a [ToolResult.fail] with the tool name populated.
  Future<ToolResult> guard(
    ToolContext context,
    Future<ToolResult> Function() body,
  ) async {
    try {
      return await body();
    } catch (e, st) {
      context.logger.error('Unhandled exception', exception: e, stack: st);
      return ToolResult.fail(
        '$e',
        toolName: name,
        traceId: context.traceId,
        code: ToolResultCode.fail,
      );
    }
  }

  /// Resolve a required string param, returning a fail result if absent.
  ToolResult? requireString(
    Map<String, dynamic> params,
    String key,
    ToolContext context,
  ) {
    final val = params[key];
    if (val == null || (val is String && val.isEmpty)) {
      return ToolResult.fail(
        'Missing required param: $key',
        code: ToolResultCode.validationError,
        toolName: name,
        traceId: context.traceId,
      );
    }
    return null;
  }
}
