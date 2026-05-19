import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../models/scan.dart';
import '../../../services/storage_service.dart';
import '../scan_detail_screen.dart';

class ScanCard extends StatelessWidget {
  const ScanCard({super.key, required this.scan});

  final Scan scan;

  File? _getLocalFile() {
    if (scan.imagePath == null || scan.imagePath!.isEmpty) return null;
    var file = File(scan.imagePath!);
    if (!file.existsSync()) {
      try {
        final storage = Get.find<StorageService>();
        file = File(p.join(storage.audioDirPath, p.basename(scan.imagePath!)));
      } catch (_) {}
    }
    return file.existsSync() ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: scan.isProcessing
            ? null
            : () => Get.to(() => ScanDetailScreen(scan: scan)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  image: () {
                    final f = _getLocalFile();
                    return f != null
                        ? DecorationImage(image: FileImage(f), fit: BoxFit.cover)
                        : null;
                  }(),
                ),
                child: scan.isProcessing
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scan.isProcessing ? 'Analyzing image...' : scan.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                FeatherIcons.chevronRight,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
