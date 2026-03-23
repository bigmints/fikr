import 'package:flutter/material.dart';
import '../../controllers/app_controller.dart';
import '../../utils/layout.dart';
import 'widgets/topic_mind_map.dart';

class DesktopInsights extends StatelessWidget {
  const DesktopInsights({
    super.key,
    required this.mainContent,
    required this.controller,
  });

  final Widget mainContent;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            child: ResponsiveCenter(
              maxWidth: kContentMaxWidth,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: mainContent,
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        Expanded(
          flex: 8,
          child: TopicMindMap(notes: controller.notes),
        ),
      ],
    );
  }
}
