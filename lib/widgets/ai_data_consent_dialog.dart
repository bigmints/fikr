import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/llm_provider.dart';
import '../services/storage_service.dart';

/// A screen that informs the user about AI data sharing and asks for consent.
///
/// Required by App Store guidelines 5.1.1(i) and 5.1.2(i).
/// Must be shown before any data is sent to a third-party AI service.
///
/// On mobile: shown as a full-screen modal.
/// On desktop: shown as a centered dialog.
class AIDataConsentDialog extends StatelessWidget {
  const AIDataConsentDialog({super.key, this.provider});

  /// The currently-configured LLM provider (if any) to personalise the message.
  final LLMProvider? provider;

  /// Shows the consent screen and returns `true` if the user agrees.
  static Future<bool> show(
    BuildContext context, {
    LLMProvider? provider,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AIDataConsentDialog(provider: provider),
      );
      return result ?? false;
    }

    // Mobile: full-screen modal
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AIDataConsentDialog(provider: provider),
      ),
    );
    return result ?? false;
  }

  /// Persist consent so the dialog is not shown again.
  static Future<void> persistConsent(StorageService storage) async {
    await storage.setAIDataConsent(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      return _buildDesktopDialog(context);
    }
    return _buildMobileScreen(context);
  }

  /// Full-screen layout for mobile.
  Widget _buildMobileScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final providerName =
        provider?.type.displayName ?? 'your configured AI provider';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header icon
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: colorScheme.primary,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'How Fikr uses AI',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'To turn your voice into notes, Fikr sends your '
                          'recordings to an AI service. Here\'s what happens:',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildInfoTile(
                        context,
                        icon: Icons.mic_outlined,
                        title: 'What we send',
                        description:
                            'Your voice recordings and the text from them '
                            'are sent to the AI to be written down and organized.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        context,
                        icon: Icons.business_outlined,
                        title: 'Who helps',
                        description:
                            'An AI service like $providerName listens to '
                            'your recording and writes it down for you.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        context,
                        icon: Icons.auto_awesome_outlined,
                        title: 'Why',
                        description:
                            'So Fikr can write down what you said and '
                            'help you keep your notes neat and tidy.',
                      ),
                      const SizedBox(height: 20),

                      // Privacy links
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildLink(
                            context,
                            label: 'Privacy Policy',
                            url: 'https://www.fikr.one/privacy',
                          ),
                          _buildLink(
                            context,
                            label: 'OpenAI',
                            url: 'https://openai.com/privacy',
                          ),
                          _buildLink(
                            context,
                            label: 'Google AI',
                            url: 'https://policies.google.com/privacy',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('I Agree'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog overlay for desktop.
  Widget _buildDesktopDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final providerName =
        provider?.type.displayName ?? 'your configured AI provider';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'How Fikr uses AI',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'To turn your voice into notes, Fikr sends your '
                  'recordings to an AI service. Here\'s what happens:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoTile(
                  context,
                  icon: Icons.mic_outlined,
                  title: 'What we send',
                  description:
                      'Your voice recordings and the text from them '
                      'are sent to the AI to be written down and organized.',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  context,
                  icon: Icons.business_outlined,
                  title: 'Who helps',
                  description:
                      'An AI service like $providerName listens to '
                      'your recording and writes it down for you.',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  context,
                  icon: Icons.auto_awesome_outlined,
                  title: 'Why',
                  description:
                      'So Fikr can write down what you said and '
                      'help you keep your notes neat and tidy.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildLink(
                      context,
                      label: 'Privacy Policy',
                      url: 'https://www.fikr.one/privacy',
                    ),
                    _buildLink(
                      context,
                      label: 'OpenAI',
                      url: 'https://openai.com/privacy',
                    ),
                    _buildLink(
                      context,
                      label: 'Google AI',
                      url: 'https://policies.google.com/privacy',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('I Agree'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLink(
    BuildContext context, {
    required String label,
    required String url,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => launchUrl(Uri.parse(url)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
