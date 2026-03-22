import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'details/desktop_note_detail.dart';
import 'details/mobile_note_detail.dart';
import 'details/note_detail_controller.dart';
import '../models/note.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note note;
  final VoidCallback? onClose;

  const NoteDetailScreen({super.key, required this.note, this.onClose});

  static Future<void> show(BuildContext context, Note note) {
    final isDesktop = MediaQuery.of(context).size.width >= 980;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: NoteDetailScreen(note: note),
            ),
          ),
        ),
      );
    } else {
      return Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => NoteDetailScreen(note: note),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the controller for this specific note with a unique tag
    final controller = Get.put(NoteDetailController(note), tag: note.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;
        if (isDesktop) {
          return DesktopNoteDetail(controller: controller, onClose: onClose);
        } else {
          return MobileNoteDetail(controller: controller, onClose: onClose);
        }
      },
    );
  }
}
