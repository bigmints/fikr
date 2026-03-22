import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home/desktop_home.dart';
import 'home/mobile_home.dart';

import '../utils/layout.dart';
import '../controllers/app_controller.dart';
import '../widgets/empty_state.dart';

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.isDesktop;
        final isTablet = constraints.isTablet;
        final useWideLayout = isDesktop || isTablet;
        return Obx(() {
          if (appController.loading.value) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          final filteredNotes = appController.filteredNotes;
          final notes = appController.notes;

          const emptyState = EmptyState(
            icon: Icons.mic_none_outlined,
            title: 'Your first spark of genius',
            description:
                'Your next big idea is just a tap away. Record a thought and start building your legacy of knowledge.',
          );

          if (!useWideLayout) {
            return MobileHome(
              notes: filteredNotes,
              allNotes: notes,
              emptyState: emptyState,
            );
          }

          return DesktopHome(
            notes: filteredNotes,
            allNotes: notes,
            emptyState: emptyState,
          );
        });
      },
    );
  }
}
