import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import '../../models/scan.dart';
import '../../models/action_card.dart';
import '../../widgets/nba_actions_widget.dart';
import '../../widgets/action_preview_sheet.dart';
import '../../tools/hooks/hook_engine.dart';
import '../../services/storage_service.dart';

class ScanDetailScreen extends StatelessWidget {
  final Scan scan;

  const ScanDetailScreen({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Next Best Actions', style: theme.textTheme.titleMedium),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ScanImageWidget(scan: scan),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scan.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Hook-generated NBA Actions ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NbaActionsWidget(
                context: NbaContext(
                  source: NbaSource.scan,
                  scan: scan,
                  text: scan.description,
                  existingActions: scan.actions,
                ),
                trigger: HookTrigger.onScanCreated,
                initiallyExpanded: true,
              ),
            ),
          ),
          // ── Legacy LLM Actions (from vision.analyse) ─────────────────
          if (scan.actions.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Divider(height: 32),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      FeatherIcons.layers,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Suggested',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final action = scan.actions[index];
                    return _ActionCardWidget(action: action);
                  },
                  childCount: scan.actions.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _ActionCardWidget extends StatelessWidget {
  final ActionCard action;

  const _ActionCardWidget({required this.action});

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

  Future<void> _onTap(BuildContext context) async {
    if (action.isToolAction) {
      Get.bottomSheet(
        ActionPreviewSheet(action: action),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } else if (action.url != null) {
      // Legacy URL fallback
      final uri = Uri.parse(action.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _showReasoning(BuildContext context) {
    if (action.reasoning == null || action.reasoning!.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why this action?'),
        content: Text(action.reasoning!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasReasoning = action.reasoning != null && action.reasoning!.isNotEmpty;
    final canExecute = action.isToolAction || action.url != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(action.type),
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          action.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Phase 4: Trust / Explainability ⓘ button
                      if (hasReasoning)
                        GestureDetector(
                          onTap: () => _showReasoning(context),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              FeatherIcons.info,
                              size: 16,
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (action.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canExecute) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _onTap(context),
                child: Text(action.ctaLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Smart image widget: prefers a valid local file, falls back to the
/// Firebase Storage URL (Plus/Pro), then shows a neutral placeholder.
/// Free users only ever see the local file since imageUrl is never set.
class _ScanImageWidget extends StatelessWidget {
  final Scan scan;
  const _ScanImageWidget({required this.scan});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const height = 250.0;

    // 1️⃣ Local file — fastest, always preferred
    final localPath = scan.imagePath;
    if (localPath != null && localPath.isNotEmpty) {
      File localFile = File(localPath);
      if (!localFile.existsSync()) {
         try {
           final storage = Get.find<StorageService>();
           localFile = File(p.join(storage.audioDirPath, p.basename(localPath)));
         } catch (_) {}
      }
      if (localFile.existsSync()) {
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(image: FileImage(localFile), fit: BoxFit.cover),
          ),
        );
      }
    }

    // 2️⃣ Remote URL — set for Plus/Pro after GCS upload completes
    final remoteUrl = scan.imageUrl;
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: remoteUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _placeholder(height, colorScheme, loading: true),
          errorWidget: (context, url, error) => _placeholder(height, colorScheme, loading: false),
        ),
      );
    }

    // 3️⃣ No image (Free user on a new device — no GCS upload ever happened)
    return _placeholder(height, colorScheme, loading: false);
  }

  Widget _placeholder(double height, ColorScheme colorScheme, {required bool loading}) {
    return Container(
      height: height,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Icon(
                FeatherIcons.image,
                size: 48,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
      ),
    );
  }
}
