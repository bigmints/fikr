import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/app_controller.dart';
import '../../../models/llm_provider.dart';
import '../../../services/openai_service.dart';
import '../../../services/toast_service.dart';
import '../../../widgets/ai_data_consent_dialog.dart';

class ProviderSetupDialog extends StatefulWidget {
  const ProviderSetupDialog({super.key});

  @override
  State<ProviderSetupDialog> createState() => _ProviderSetupDialogState();
}

class _ProviderSetupDialogState extends State<ProviderSetupDialog> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  bool _isValid = false;
  LLMProviderType _selectedType = LLMProviderType.google;

  @override
  void initState() {
    super.initState();
    _keyController.addListener(_validate);
  }

  void _validate() {
    final isValid = _keyController.text.trim().isNotEmpty;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  String _getKeyHint(LLMProviderType type) {
    switch (type) {
      case LLMProviderType.openai:
        return 'sk-...';
      case LLMProviderType.google:
        return 'AIza...';
      case LLMProviderType.openrouter:
        return 'sk-or-...';
    }
  }

  String _getHelpUrl(LLMProviderType type) {
    switch (type) {
      case LLMProviderType.openai:
        return 'https://platform.openai.com/api-keys';
      case LLMProviderType.google:
        return 'https://aistudio.google.com/app/apikey';
      case LLMProviderType.openrouter:
        return 'https://openrouter.ai/keys';
    }
  }

  String _getSubtitle(LLMProviderType type) {
    switch (type) {
      case LLMProviderType.openai:
        return 'ChatGPT & Whisper';
      case LLMProviderType.google:
        return 'Recommended · Free to start';
      case LLMProviderType.openrouter:
        return 'Use many different AI models';
    }
  }

  IconData _getProviderIcon(LLMProviderType type) {
    switch (type) {
      case LLMProviderType.openai:
        return FeatherIcons.cpu;
      case LLMProviderType.google:
        return Icons.g_mobiledata;
      case LLMProviderType.openrouter:
        return FeatherIcons.navigation;
    }
  }

  Future<void> _submit() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);
    try {
      final controller = Get.find<AppController>();
      final String id = '${_selectedType.name}-default';

      final provider = LLMProvider(
        id: id,
        name: _selectedType.displayName,
        type: _selectedType,
        baseUrl: _selectedType.defaultBaseUrl,
      );

      final currentConfig = controller.config.value;

      final llmService = LLMService();
      final isKeyValid = await llmService.validateApiKey(
        _keyController.text.trim(),
        provider: provider,
      );
      if (!isKeyValid) {
        if (mounted) {
          ToastService.showError(
            context,
            title: 'Invalid API Key',
            description:
                'That key didn\u0027t work. Please check and try again.',
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Show AI data consent dialog before saving provider
      final hasConsent = await controller.storage.hasAIDataConsent();
      if (!hasConsent) {
        if (!mounted) return;
        final agreed = await AIDataConsentDialog.show(
          context,
          provider: provider,
        );
        if (!agreed) {
          setState(() => _isLoading = false);
          return;
        }
        await controller.storage.setAIDataConsent(true);
      }

      final newConfig = currentConfig.copyWith(
        activeProvider: provider,
        analysisModel: _selectedType.defaultAnalysisModel,
        transcriptionModel: _selectedType.defaultTranscriptionModel,
      );

      // Save Key first, then Config (so refreshCanRecord reads the persisted key)
      await controller.storage.saveApiKey(id, _keyController.text.trim());
      await controller.updateConfig(newConfig);

      if (mounted) {
        Navigator.pop(context, true);
        ToastService.showSuccess(
          context,
          title: 'Ready to Record',
          description: 'You\u0027re all set!',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          context,
          title: 'Setup Failed',
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        FeatherIcons.zap,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Set up Fikr',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick an AI service below so Fikr can turn your voice into notes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Provider selector
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose a service',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...LLMProviderType.values.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProviderCard(
                        title: type.displayName,
                        subtitle: _getSubtitle(type),
                        icon: _getProviderIcon(type),
                        isSelected: _selectedType == type,
                        onTap: () {
                          setState(() {
                            _selectedType = type;
                            _keyController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // API Key
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Secret Key',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: _getKeyHint(_selectedType),
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1F2937)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Saved safely on your phone only',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            launchUrl(Uri.parse(_getHelpUrl(_selectedType))),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Get your key →',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isLoading || !_isValid ? null : _submit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Get Started', style: TextStyle()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'By continuing, you agree to our terms and privacy policy.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('https://www.fikr.one/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Terms'),
                      ),
                      Text(
                        '·',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('https://www.fikr.one/privacy'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Privacy'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.1)
                    : isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                FeatherIcons.checkCircle,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
