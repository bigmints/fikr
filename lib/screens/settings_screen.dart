import 'package:flutter/material.dart';
import 'settings/desktop_settings.dart';
import 'settings/mobile_settings.dart';
import '../utils/layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.isDesktop;
        if (isDesktop) {
          return const DesktopSettings();
        } else {
          return const MobileSettings();
        }
      },
    );
  }
}
