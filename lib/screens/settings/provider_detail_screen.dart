import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/app_controller.dart';
import '../../models/llm_provider.dart';
import '../../services/openai_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/ai_data_consent_dialog.dart';

class ProviderDetailScreen extends StatefulWidget {
  final LLMProvider? provider;
  const ProviderDetailScreen({super.key, this.provider});

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  late final TextEditingController _keyController;
  late LLMProviderType _selectedType;

  bool _isLoading = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    _keyController.addListener(_validate);

    final p = widget.provider;
    if (p != null) {
      _selectedType = p.type;
      _loadApiKey(p.id);
    } else {
      _selectedType = LLMProviderType.google;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
  }

  void _validate() {
    final isValid = _keyController.text.trim().isNotEmpty;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  void _loadApiKey(String providerId) async {
    final key = await Get.find<AppController>().storage.getApiKey(providerId);
    if (key != null && mounted) {
      setState(() => _keyController.text = key);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    final controller = Get.find<AppController>();
    final id = widget.provider?.id ?? '${_selectedType.name}-default';

    final newProvider = LLMProvider(
      id: id,
      name: _selectedType.displayName,
      type: _selectedType,
      baseUrl: _selectedType.defaultBaseUrl,
    );

    setState(() => _isLoading = true);

    try {
      // Validate API key
      final llmService = LLMService();
      final isKeyValid = await llmService.validateApiKey(
        _keyController.text.trim(),
        provider: newProvider,
      );
      if (!isKeyValid) {
        if (mounted) {
          ToastService.showError(
            context,
            title: 'Invalid API Key',
            description: 'That key didn\'t work. Please check and try again.',
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Save API Key
      await controller.storage.saveApiKey(id, _keyController.text.trim());

      // Show AI data consent dialog before saving provider
      final hasConsent = await controller.storage.hasAIDataConsent();
      if (!hasConsent) {
        if (!mounted) return;
        final agreed = await AIDataConsentDialog.show(
          context,
          provider: newProvider,
        );
        if (!agreed) {
          setState(() => _isLoading = false);
          return;
        }
        await controller.storage.setAIDataConsent(true);
      }

      // Update config — models are auto-set from provider type defaults
      final nextConfig = controller.config.value.copyWith(
        activeProvider: newProvider,
        analysisModel: _selectedType.defaultAnalysisModel,
        transcriptionModel: _selectedType.defaultTranscriptionModel,
      );

      await controller.updateConfig(nextConfig);
      await controller.refreshCanRecord();

      if (mounted) {
        Get.back();
        ToastService.showSuccess(
          context,
          title: 'Saved',
          description: '${_selectedType.displayName} is ready to go.',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          context,
          title: 'Error',
          description: 'Failed to save: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove AI Service'),
        content: const Text(
          'This will remove your key and reset Fikr\'s AI setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final controller = Get.find<AppController>();
      final id = widget.provider!.id;

      final nextConfig = controller.config.value.copyWith(
        clearProvider: true,
        analysisModel: '',
        transcriptionModel: '',
      );

      await controller.updateConfig(nextConfig);
      await controller.storage.deleteApiKey(id);
      await controller.refreshCanRecord();

      if (mounted) {
        Get.back();
        ToastService.showSuccess(
          context,
          title: 'Removed',
          description: 'AI service removed.',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          context,
          title: 'Error',
          description: 'Something went wrong. Please try again.',
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.provider == null ? 'Add AI Service' : 'Edit AI Service',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Provider type selector
              Text('Service', style: theme.textTheme.labelLarge),
              const SizedBox(height: 12),
              ...LLMProviderType.values.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProviderOption(
                    type: type,
                    isSelected: _selectedType == type,
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        _keyController.clear();
                      });
                      _validate();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // API Key
              Text('Your Secret Key', style: theme.textTheme.labelLarge),
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

              const SizedBox(height: 48),

              // Save button
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading || !_isValid ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.provider == null ? 'Save' : 'Update',
                          style: const TextStyle(),
                        ),
                ),
              ),

              if (widget.provider != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _isLoading ? null : _delete,
                  child: const Text('Remove AI Service'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderOption extends StatelessWidget {
  const _ProviderOption({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final LLMProviderType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
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
            Text(type.displayName, style: theme.textTheme.titleSmall),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
