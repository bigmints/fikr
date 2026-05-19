import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/usage_controller.dart';

/// UsageBanner — shows word quota progress for Plus/Pro users.
///
/// Usage:
///   UsageBanner()           // compact (for Notes header)
///   UsageBanner(expanded: true)  // full breakdown (for Settings)
class UsageBanner extends StatelessWidget {
  final bool expanded;
  const UsageBanner({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<UsageController>();

    return Obx(() {
      final stats = ctrl.stats.value;

      // Free users — nothing to show
      if (stats == null || stats.isUnlimited) return const SizedBox.shrink();

      final pct     = stats.percentUsed / 100.0;
      final isNear  = stats.isNearLimit;
      final isLimit = stats.isAtLimit;

      final barColor = isLimit
          ? const Color(0xFFEF4444)
          : isNear
              ? const Color(0xFFF59E0B)
              : const Color(0xFF3CA6A6);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLimit
                ? const Color(0xFFEF4444).withAlpha(51)
                : isNear
                    ? const Color(0xFFF59E0B).withAlpha(51)
                    : const Color(0xFF3CA6A6).withAlpha(26),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'AI Words — ${_monthLabel(stats.monthKey)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (isLimit || isNear)
                  GestureDetector(
                    onTap: _openTopUp,
                    child: Text(
                      isLimit ? 'Buy more →' : 'Running low →',
                      style: TextStyle(
                        fontSize: 11,
                        color: barColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: barColor.withAlpha(26),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),

            // Stats line
            Text(
              '${_fmt(stats.wordsUsed)} / ${stats.formattedLimit} words'
              '  ·  Resets ${_resetLabel(stats.resetAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              ),
            ),

            // Expanded breakdown
            if (expanded) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _breakdownRow(context, 'Transcription', stats.transcribeWords, stats.wordsLimit),
              _breakdownRow(context, 'Analysis',      stats.analyzeWords,    stats.wordsLimit),
              _breakdownRow(context, 'Insights',      stats.insightsWords,   stats.wordsLimit),
              _breakdownRow(context, 'Chat',          stats.chatWords,       stats.wordsLimit),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openTopUp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3CA6A6),
                    side: const BorderSide(color: Color(0xFF3CA6A6)),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Buy 750,000 more words — \$4.50'),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _breakdownRow(BuildContext context, String label, int words, int limit) {
    final pct = limit <= 0 ? 0.0 : (words / limit).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: const Color(0xFF3CA6A6).withAlpha(26),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3CA6A6)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(
              _fmt(words),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _openTopUp() => launchUrl(Uri.parse('https://www.fikr.one/billing/topup'));

  String _fmt(int words) {
    if (words >= 1_000_000) return '${(words / 1_000_000).toStringAsFixed(1)}M';
    if (words >= 1_000)     return '${(words / 1_000).toStringAsFixed(0)}k';
    return words.toString();
  }

  String _monthLabel(String key) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${months[m - 1]} ${parts[0]}';
  }

  String _resetLabel(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day} ${_monthLabel('${dt.year}-${dt.month.toString().padLeft(2, '0')}').split(' ')[0]}';
    } catch (_) {
      return 'next month';
    }
  }
}
