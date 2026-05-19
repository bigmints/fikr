import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

import '../models/action_card.dart';
import '../tools/engine/engine_controller.dart';
import '../tools/tool_registry.dart';

class ActionPreviewSheet extends StatefulWidget {
  final ActionCard action;

  const ActionPreviewSheet({super.key, required this.action});

  @override
  State<ActionPreviewSheet> createState() => _ActionPreviewSheetState();
}

class _ActionPreviewSheetState extends State<ActionPreviewSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isExecuting = false;
  Map<String, dynamic>? _schema;

  @override
  void initState() {
    super.initState();
    if (widget.action.isToolAction) {
      final tool = ToolRegistry.instance.get(widget.action.toolId!);
      _schema = tool?.parametersSchema;
      
      // Initialize controllers for each parameter
      if (_schema != null && _schema!['properties'] != null) {
        final props = _schema!['properties'] as Map<String, dynamic>;
        for (final key in props.keys) {
          final initialValue = widget.action.toolParameters[key]?.toString() ?? '';
          _controllers[key] = TextEditingController(text: initialValue);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _execute() async {
    if (!widget.action.isToolAction) return;

    setState(() {
      _isExecuting = true;
    });

    final engine = Get.find<EngineController>();
    final params = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      params[entry.key] = entry.value.text;
    }

    try {
      final result = await engine.executeTool(widget.action.toolId!, params);
      if (result.success) {
        Get.back(result: true);
        Get.snackbar(
          'Action Completed',
          widget.action.title,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Action Failed',
          result.error ?? 'Unknown error',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not execute action: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  IconData _getIconForType(ActionType type) {
    switch (type) {
      case ActionType.buy:
        return FeatherIcons.shoppingCart;
      case ActionType.recipe:
        return FeatherIcons.bookOpen;
      case ActionType.article:
      case ActionType.read:
        return FeatherIcons.fileText;
      case ActionType.post:
        return FeatherIcons.send;
      case ActionType.search:
        return FeatherIcons.search;
      case ActionType.map:
        return FeatherIcons.mapPin;
      case ActionType.compare:
        return FeatherIcons.barChart2;
      case ActionType.custom:
        return FeatherIcons.zap;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasReasoning = widget.action.reasoning != null && widget.action.reasoning!.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(widget.action.type),
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.action.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.action.subtitle.isNotEmpty)
                        Text(
                          widget.action.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reasoning
            if (hasReasoning) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      FeatherIcons.info,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.action.reasoning!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Dynamic Form Fields
            if (_schema != null && _schema!['properties'] != null) ...[
              Text(
                'Parameters',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...(_schema!['properties'] as Map<String, dynamic>).entries.map((entry) {
                final key = entry.key;
                final controller = _controllers[key];
                if (controller == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: key,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: key.toLowerCase().contains('description') ? 3 : 1,
                  ),
                );
              }),
            ],

            const SizedBox(height: 10),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isExecuting ? null : () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isExecuting || !widget.action.isToolAction ? null : _execute,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isExecuting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.action.ctaLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
