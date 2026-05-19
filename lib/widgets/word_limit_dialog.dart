import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/usage_controller.dart';

/// WordLimitDialog — shown when any AI route returns HTTP 429.
///
/// Usage:
///   Get.dialog(const WordLimitDialog());
class WordLimitDialog extends StatelessWidget {
  const WordLimitDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl  = Get.find<UsageController>();
    final stats = ctrl.stats.value;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Monthly word limit reached',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Usage line
            if (stats != null)
              Text(
                '${_fmt(stats.wordsUsed)} / ${stats.formattedLimit} words used',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            const SizedBox(height: 4),

            if (stats != null)
              Text(
                'Resets ${_resetLabel(stats.resetAt)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 24),

            // Top-up CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  launchUrl(Uri.parse('https://www.fikr.one/billing/topup'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CA6A6),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Buy 750,000 more words — \$4.50'),
              ),
            ),
            const SizedBox(height: 10),

            // Upgrade if Plus
            if (stats?.plan == 'plus')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Get.back();
                    launchUrl(Uri.parse('https://www.fikr.one/billing'));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF18212F),
                    side: const BorderSide(color: Color(0xFF18212F), width: 0.5),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Upgrade to Pro — 1.5M words'),
                ),
              ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: Get.back,
              child: const Text('Maybe later', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int words) {
    if (words >= 1_000_000) return '${(words / 1_000_000).toStringAsFixed(1)}M';
    if (words >= 1_000)     return '${(words / 1_000).toStringAsFixed(0)}k';
    return words.toString();
  }

  String _resetLabel(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return 'next month';
    }
  }
}
