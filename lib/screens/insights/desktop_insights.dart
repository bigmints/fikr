import 'package:flutter/material.dart';
import '../../controllers/app_controller.dart';

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: mainContent,
    );
  }
}
