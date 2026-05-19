import 'package:uuid/uuid.dart';

enum ActionType { buy, recipe, article, post, search, map, read, compare, custom }

/// A ranked action card surfaced by the Next Best Action engine.
///
/// When [toolId] is set, tapping the CTA will execute the named tool via
/// [EngineController.executeTool] with [toolParameters] pre-filled.
/// When [url] is set (legacy), it falls back to launching the URL.
class ActionCard {
  final String id;
  final ActionType type;
  final String title;
  final String subtitle;
  final String? url;
  final String ctaLabel;
  final Map<String, dynamic> metadata;

  /// The registered Fikr tool to invoke on CTA tap (e.g. "tasks.create").
  /// Null for legacy URL-based actions.
  final String? toolId;

  /// Pre-filled parameters the LLM inferred from context. Passed directly
  /// to [EngineController.executeTool] on execution.
  final Map<String, dynamic> toolParameters;

  /// One-sentence explanation of why this action was suggested.
  /// Displayed in the ⓘ trust tooltip on the card.
  final String? reasoning;

  ActionCard({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.url,
    this.ctaLabel = 'Open',
    this.metadata = const {},
    this.toolId,
    this.toolParameters = const {},
    this.reasoning,
  });

  /// Whether this action has an executable internal tool payload.
  bool get isToolAction => toolId != null && toolId!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'url': url,
      'ctaLabel': ctaLabel,
      'metadata': metadata,
      'toolId': toolId,
      'toolParameters': toolParameters,
      'reasoning': reasoning,
    };
  }

  factory ActionCard.fromJson(Map<String, dynamic> json) {
    // Support legacy 'toolName' in metadata as a fallback for toolId
    final legacyToolName = (json['metadata'] as Map<String, dynamic>?)?['toolName'] as String?;

    return ActionCard(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: ActionType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => ActionType.custom,
      ),
      title: json['title'] as String? ?? 'Action',
      subtitle: json['subtitle'] as String? ?? '',
      url: json['url'] as String?,
      ctaLabel: json['ctaLabel'] as String? ?? 'Open',
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      toolId: json['toolId'] as String? ?? legacyToolName,
      toolParameters: (json['parameters'] as Map<String, dynamic>?) ??
          (json['toolParameters'] as Map<String, dynamic>?) ??
          {},
      reasoning: json['reasoning'] as String?,
    );
  }
}
