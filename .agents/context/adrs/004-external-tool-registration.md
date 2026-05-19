# ADR 004 — External Tool Registration (MCP / Webhook / REST)

**Date:** 2026-05-04
**Status:** Accepted
**Scope:** `fikr/` Flutter app

---

## Context

Users can connect third-party services (Notion, Zapier, custom REST APIs) to their Fikr workspace. These services need to be callable by the LLM alongside built-in tools, without requiring app updates. The registration model must support runtime hot-loading and must slot into the existing `ToolRegistry` + `EngineController` pipeline transparently.

---

## Decision

External services register as first-class `FikrTool` implementations at runtime via `ToolRegistrar`. Three adaptor types are supported:

**MCP server** (auto-discovers all tools from the server's manifest):
```dart
await ToolRegistrar.instance.registerMcpServer(McpServerConfig(
  id: 'notion', name: 'Notion', url: 'https://...', apiKey: '...',
));
// → registers mcp.notion.search_pages, mcp.notion.create_page, etc.
```

**Webhook** (single POST endpoint):
```dart
ToolRegistrar.instance.registerWebhook(WebhookConfig(
  id: 'zapier', name: 'Zapier', toolName: 'webhook.zapier',
  url: 'https://hooks.zapier.com/...', secret: 'hmac-secret',
));
```

**REST endpoint**:
```dart
ToolRegistrar.instance.registerRest(RestConfig(
  id: 'my-api', name: 'My API', toolName: 'rest.my-api',
  url: 'https://api.example.com/action', method: 'POST',
));
```

Dynamic tools appear in `ToolRegistry` alongside built-ins. The LLM schema includes them automatically. Tool names follow the same `domain.action` convention: `mcp.<serverId>.<toolName>`, `webhook.<id>`, `rest.<id>`.

---

## Consequences

**Positive:**
- Users extend Fikr capabilities without waiting for app updates
- External tools go through the same `EngineController` pipeline — traced, validated, tier-gated
- LLM discovers dynamic tools via schema automatically

**Negative:**
- Network latency for external calls vs. local tools
- MCP server availability is outside Fikr's control — `onError: StepErrorPolicy.skip` recommended in skills that call external tools

**Implementation:** `lib/tools/adaptors/external_tool_adaptor.dart`
