/// Scheduling domain tools — calendar integration via MCP servers.
///
/// These tools connect to calendar MCP servers (Google Calendar, Outlook, etc.)
/// through the MCP gateway. They wrap mcp.invoke calls with structured schemas.
library;

import '../tool_interface.dart';
import '../tool_registry.dart';

// ───────────────────────────────────────────────────────────────────────────
//  schedule.check_free_time
// ───────────────────────────────────────────────────────────────────────────

class ScheduleCheckFreeTimeTool extends FikrTool {
  @override
  String get name => 'schedule.check_free_time';

  @override
  String get description =>
      'Check calendar availability for a given time range via MCP.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'serverId': {
        'type': 'string',
        'description': 'Calendar MCP server ID.',
      },
      'startTime': {
        'type': 'string',
        'description': 'ISO 8601 start time.',
      },
      'endTime': {
        'type': 'string',
        'description': 'ISO 8601 end time.',
      },
    },
    'required': ['serverId', 'startTime', 'endTime'],
  };

  @override
  ToolTier get requiredTier => ToolTier.plus;

  @override
  ToolLocation get location => ToolLocation.mcp;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final mcpInvoke = ToolRegistry.instance.get('mcp.invoke');
      if (mcpInvoke == null) return ToolResult.fail('MCP invoke not available.');

      return mcpInvoke.execute({
        'serverId': params['serverId'],
        'toolName': 'calendar.check_free_time',
        'arguments': {
          'startTime': params['startTime'],
          'endTime': params['endTime'],
        },
      }, context);
    } catch (e) {
      return ToolResult.fail('Failed to check free time: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  schedule.create_event
// ───────────────────────────────────────────────────────────────────────────

class ScheduleCreateEventTool extends FikrTool {
  @override
  String get name => 'schedule.create_event';

  @override
  String get description => 'Create a calendar event via MCP server.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'serverId': {
        'type': 'string',
        'description': 'Calendar MCP server ID.',
      },
      'title': {
        'type': 'string',
        'description': 'Event title.',
      },
      'startTime': {
        'type': 'string',
        'description': 'ISO 8601 start time.',
      },
      'endTime': {
        'type': 'string',
        'description': 'ISO 8601 end time.',
      },
      'description': {
        'type': 'string',
        'description': 'Optional event description.',
      },
    },
    'required': ['serverId', 'title', 'startTime'],
  };

  @override
  ToolTier get requiredTier => ToolTier.plus;

  @override
  ToolLocation get location => ToolLocation.mcp;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final mcpInvoke = ToolRegistry.instance.get('mcp.invoke');
      if (mcpInvoke == null) return ToolResult.fail('MCP invoke not available.');

      return mcpInvoke.execute({
        'serverId': params['serverId'],
        'toolName': 'calendar.create_event',
        'arguments': {
          'title': params['title'],
          'startTime': params['startTime'],
          'endTime': params['endTime'],
          'description': params['description'],
        },
      }, context);
    } catch (e) {
      return ToolResult.fail('Failed to create event: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allScheduleTools() => [
      ScheduleCheckFreeTimeTool(),
      ScheduleCreateEventTool(),
    ];
