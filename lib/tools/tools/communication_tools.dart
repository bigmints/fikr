import 'package:url_launcher/url_launcher.dart';
import '../tool_interface.dart';

class CommunicationCallTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'communication.call';

  @override
  String get description => 'Initiate a phone call to a given number.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'phone': {'type': 'string'},
    },
    'required': ['phone'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params, ToolContext context) =>
      guard(context, () async {
        final phone = params['phone'] as String;
        final uri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return ToolResult.ok({'success': true});
        }
        return ToolResult.fail('Could not launch dialer.');
      });
}

class CommunicationSmsTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'communication.sms';

  @override
  String get description => 'Open SMS app to send a message.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'phone': {'type': 'string'},
      'message': {'type': 'string'},
    },
    'required': ['phone'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params, ToolContext context) =>
      guard(context, () async {
        final phone = params['phone'] as String;
        final message = params['message'] as String? ?? '';
        final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return ToolResult.ok({'success': true});
        }
        return ToolResult.fail('Could not launch SMS app.');
      });
}

class CommunicationWhatsappTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'communication.whatsapp';

  @override
  String get description => 'Open WhatsApp to send a message.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'phone': {'type': 'string'},
      'message': {'type': 'string'},
    },
    'required': ['phone'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params, ToolContext context) =>
      guard(context, () async {
        final phone = params['phone'] as String;
        final message = params['message'] as String? ?? '';
        // remove any non-numeric characters for whatsapp url except +
        final cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
        final uri = Uri.parse('https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return ToolResult.ok({'success': true});
        }
        return ToolResult.fail('Could not launch WhatsApp.');
      });
}

class CommunicationEmailTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'communication.email';

  @override
  String get description => 'Open email app to send an email.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'email': {'type': 'string'},
      'subject': {'type': 'string'},
      'body': {'type': 'string'},
    },
    'required': ['email'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params, ToolContext context) =>
      guard(context, () async {
        final email = params['email'] as String;
        final subject = params['subject'] as String? ?? '';
        final body = params['body'] as String? ?? '';
        final uri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return ToolResult.ok({'success': true});
        }
        return ToolResult.fail('Could not launch email app.');
      });
}

class CommunicationVisitSiteTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'communication.visit_site';

  @override
  String get description => 'Open a URL in the browser.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'url': {'type': 'string'},
    },
    'required': ['url'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params, ToolContext context) =>
      guard(context, () async {
        final urlString = params['url'] as String;
        // ensure http/https prefix
        final finalUrl = urlString.startsWith('http') ? urlString : 'https://$urlString';
        final uri = Uri.parse(finalUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return ToolResult.ok({'success': true});
        }
        return ToolResult.fail('Could not launch URL.');
      });
}

List<FikrTool> allCommunicationTools() => [
      CommunicationCallTool(),
      CommunicationSmsTool(),
      CommunicationWhatsappTool(),
      CommunicationEmailTool(),
      CommunicationVisitSiteTool(),
    ];
