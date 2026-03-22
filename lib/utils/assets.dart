import 'package:flutter/material.dart';

class Assets {
  static String getLogo(BuildContext context) {
    return 'assets/images/logo.svg';
  }

  static String getSplashLogo(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? 'assets/images/fikr-logo-light.png'
        : 'assets/images/fikr-logo-dark.png';
  }
}
