import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fikr/controllers/app_controller.dart';

Future<void> showInsightsBucketDialog(
  BuildContext context,
  AppController controller,
) async {
  final buckets = controller.config.value.buckets;
  final current = controller.selectedInsightBuckets.toList();
  final next = await showDialog<List<String>>(
    context: context,
    builder: (context) {
      final selected = current.toSet();
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Insight Buckets'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: buckets
                  .map(
                    (bucket) => CheckboxListTile(
                      value: selected.contains(bucket),
                      title: Text(bucket),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(bucket);
                          } else {
                            selected.remove(bucket);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
    },
  );

  if (next != null) {
    controller.selectedInsightBuckets.value = next;
  }
}

Future<void> showInsightsHistoryDialog(
  BuildContext context,
  AppController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Insights History'),
      content: SizedBox(
        width: 420,
        child: Obx(() {
          final editions = controller.insightEditions;
          if (editions.isEmpty) {
            return const Text('No editions yet. Update insights to save one.');
          }
          return ListView.separated(
            shrinkWrap: true,
            itemCount: editions.length,
            separatorBuilder: (context, index) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final edition = editions[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, y - h:mm a').format(edition.createdAt),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    edition.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (edition.highlights.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: edition.highlights
                          .take(3)
                          .map((item) => Chip(label: Text(item.title)))
                          .toList(),
                    ),
                  ],
                ],
              );
            },
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
