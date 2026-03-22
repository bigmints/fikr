import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'note_detail_controller.dart';
import 'widgets/detail_audio_player.dart';
import 'widgets/detail_content.dart';

class DesktopNoteDetail extends StatelessWidget {
  const DesktopNoteDetail({super.key, required this.controller, this.onClose});

  final NoteDetailController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FeatherIcons.x, size: 20),
          onPressed: () {
            if (onClose != null) {
              onClose!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              FeatherIcons.trash2,
              size: 18,
              color: theme.colorScheme.error,
            ),
            onPressed: () async {
              final confirmed = await _showDeleteDialog(context);
              if (confirmed == true) {
                await controller.deleteNote();
                if (context.mounted) {
                  if (onClose != null) {
                    onClose!();
                  } else {
                    Navigator.of(context).pop();
                  }
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailContent(controller: controller),
            const SizedBox(height: 32),
            DetailAudioPlayer(controller: controller),
            const SizedBox(height: 32),
            Obx(() {
              if (!controller.isEditing.value) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 40, bottom: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.saveEdit,
                    child: const Text('Save Changes'),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
