import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../tool_interface.dart';
import '../../services/fikr_api_service.dart';
import '../../services/openai_service.dart';
import '../../controllers/subscription_controller.dart';

class VisionAnalyseTool extends FikrTool {
  @override
  String get name => 'vision.analyse';

  @override
  String get description =>
      'Analyzes an image and returns actionable insights and identified objects.';

  @override
  ToolTier get requiredTier => ToolTier.free; // Let the backend gate it based on user plan

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'imagePath': {
        'type': 'string',
        'description': 'Local file path to the image to analyze',
      },
    },
    'required': ['imagePath'],
  };

  @override
  ToolLocation get location => ToolLocation.cloud;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    final imagePath = params['imagePath'] as String?;
    if (imagePath == null || imagePath.isEmpty) {
      return ToolResult.fail('imagePath is required');
    }

    try {
      final sub = Get.find<SubscriptionController>();
      final provider = context.config.activeProvider;

      // ── Pro tier → Managed Vertex AI via fikr.one ──────────────────────────
      if (sub.hasManagedVertexAI) {
        final apiService = FikrApiService();
        final result = await apiService.analyzeImage(imagePath);
        return ToolResult.ok(result);
      }

      // ── BYOK path (OpenAI / Google / OpenRouter / OpenAI-Compatible) ────────
      if (provider == null) {
        return ToolResult.fail('No AI provider configured.');
      }

      final apiKey = await context.storage?.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        return ToolResult.fail('Missing API key.');
      }

      final llmService = Get.find<LLMService>();
      

      final result = await llmService.analyzeImage(
        imageFile: File(imagePath),
        provider: provider,
        
        apiKey: apiKey,
      );

      return ToolResult.ok(result);
    } catch (e) {
      debugPrint('vision.analyse tool error: $e');
      final errStr = e.toString();

      if (errStr.contains('At most 0 image') ||
          errStr.contains('image_url') ||
          errStr.contains('vision') && errStr.contains('not supported')) {
        return ToolResult.fail(
          'The configured AI model does not support image analysis. '
          'Switch to a vision-capable model (e.g. gpt-4o, gemini-2.0-flash, '
          'or google/gemini-2.0-flash-lite-001 on OpenRouter).',
        );
      }

      return ToolResult.fail('Failed to analyze image: $e');
    }
  }
}

List<FikrTool> allVisionTools() => [VisionAnalyseTool()];
