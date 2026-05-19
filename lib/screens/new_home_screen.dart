import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home/desktop_home.dart';
import 'home/mobile_home.dart';

import '../utils/layout.dart';
import 'package:fikr/controllers/app_controller.dart';
import '../controllers/vision_controller.dart';
import '../widgets/empty_state.dart';
import '../models/feed_item.dart';
import '../models/note.dart';
import '../models/scan.dart';

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

          final visionController = Get.isRegistered<VisionController>() ? Get.find<VisionController>() : Get.put(VisionController());

          final List<FeedItem> allItems = [
            ...appController.notes,
            ...visionController.scans,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final List<FeedItem> filteredItems = allItems.where((item) {
             final q = appController.searchQuery.value.toLowerCase();
             if (q.isEmpty) return true;
             
             if (item is Note) {
                 return item.title.toLowerCase().contains(q) || item.text.toLowerCase().contains(q) || item.transcript.toLowerCase().contains(q);
             } else if (item is Scan) {
                 return item.title.toLowerCase().contains(q) || item.description.toLowerCase().contains(q);
             }
             return false;
          }).toList();

          // Apply bucket filter if not "All"
          final bucketFilter = appController.selectedBucket.value;
          final finalItems = bucketFilter == 'All' 
              ? filteredItems 
              : filteredItems.where((item) => item.bucket == bucketFilter).toList();

          const emptyState = EmptyState(
            icon: Icons.mic_none_outlined,
            title: 'Your first spark of genius',
            description:
                'Your next big idea is just a tap away. Record a thought and start building your legacy of knowledge.',
          );

          if (!useWideLayout) {
            return MobileHome(
              notes: finalItems,
              allNotes: allItems,
              emptyState: emptyState,
            );
          }

          return DesktopHome(
            notes: finalItems,
            allNotes: allItems,
            emptyState: emptyState,
          );
        });
      },
    );
  }
}
