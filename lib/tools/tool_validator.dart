/// Tool Validator — JSON-Schema-based parameter validation.
///
/// Validates tool params against `parametersSchema.required` before execution.
/// Provides a clear [ToolResult.fail] with a [ToolResultCode.validationError]
/// so tools never receive invalid, missing, or wrong-typed inputs.
library;

import 'tool_interface.dart';

class ToolValidator {
  const ToolValidator._();

  static const ToolValidator instance = ToolValidator._();

  /// Validate [params] against [schema] for [toolName].
  ///
  /// Returns null if valid, or a [ToolResult.fail] if validation fails.
  ToolResult? validate(
    String toolName,
    Map<String, dynamic> params,
    Map<String, dynamic> schema,
    String traceId,
  ) {
    // Check required fields
    final required = schema['required'];
    if (required is List) {
      for (final field in required) {
        final key = field as String;
        if (!params.containsKey(key) || params[key] == null) {
          return ToolResult.fail(
            'Missing required parameter "$key" for tool "$toolName".',
            code: ToolResultCode.validationError,
            toolName: toolName,
            traceId: traceId,
          );
        }
      }
    }

    // Check property types where declared
    final properties = schema['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      for (final entry in properties.entries) {
        final key = entry.key;
        final propSchema = entry.value as Map<String, dynamic>?;
        final value = params[key];
        if (value == null || propSchema == null) continue;

        final expectedType = propSchema['type'] as String?;
        if (expectedType == null) continue;

        final typeError = _checkType(toolName, key, value, expectedType, traceId);
        if (typeError != null) return typeError;
      }
    }

    return null; // valid
  }

  ToolResult? _checkType(
    String toolName,
    String key,
    dynamic value,
    String expectedType,
    String traceId,
  ) {
    final valid = switch (expectedType) {
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num,
      'boolean' => value is bool,
      'array' => value is List,
      'object' => value is Map,
      _ => true, // unknown type — pass through
    };

    if (!valid) {
      return ToolResult.fail(
        'Parameter "$key" for tool "$toolName" must be $expectedType, '
        'got ${value.runtimeType}.',
        code: ToolResultCode.validationError,
        toolName: toolName,
        traceId: traceId,
      );
    }
    return null;
  }
}
