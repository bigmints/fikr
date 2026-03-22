import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../services/toast_service.dart';

/// Directly opens in-app browser for Fikr Cloud authentication.
/// No intermediate screen — goes straight to the web auth flow.
class AuthScreen {
  AuthScreen._();

  /// Opens the in-app auth browser directly.
  /// [mode] can be 'login' or 'register' (defaults to 'login').
  static Future<void> show(BuildContext context, {String mode = 'login'}) async {
    try {
      // Open in-app auth browser — blocks until redirect to fikr:// happens
      final resultUrl = await FlutterWebAuth2.authenticate(
        url: 'https://www.fikr.one/$mode?returnUrl=fikr://auth/callback',
        callbackUrlScheme: 'fikr',
      );

      // Extract the custom token from the callback URL
      final uri = Uri.parse(resultUrl);
      final token = uri.queryParameters['token'];

      if (token == null || token.isEmpty) {
        throw Exception('No token received from auth server');
      }

      // Sign in to Firebase with the custom token
      await FirebaseAuth.instance.signInWithCustomToken(token);

      // Success
      if (context.mounted) {
        ToastService.showSuccess(
          context,
          title: 'Successfully signed in to Fikr Cloud',
        );
      }
    } on Exception catch (e) {
      debugPrint('Web auth error: $e');
      // User cancelled or something went wrong
      if (context.mounted && !e.toString().contains('CANCELED')) {
        ToastService.showError(
          context,
          title: 'Sign in failed. Please try again.',
        );
      }
    }
  }
}
