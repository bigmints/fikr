import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Manages communication between Flutter and native home-screen widgets.
///
/// On iOS/macOS the data is stored in an App Group UserDefaults container.
/// On Android the data is stored in SharedPreferences accessible to the
/// AppWidget receiver.
///
/// The widget itself only provides a quick-launch shortcut – actual recording
/// happens inside the Flutter app after it opens via the `fikr://record`
/// deep-link.
class WidgetService {
  WidgetService._();

  /// App Group identifier configured in the Apple Developer portal and Xcode.
  /// Must match the value in the Widget Extension's Info.plist / entitlements.
  static const _appGroupId = 'group.com.bigmints.fikr';

  /// Native class name for the iOS WidgetKit widget.
  static const _iOSWidgetName = 'FikrRecordWidget';

  /// Fully-qualified receiver class name for Android.
  static const _androidWidgetName = 'com.bigmints.fikr.RecordWidget';

  /// Initialise the home_widget package.
  /// Must be called after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> init() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }
    } catch (e) {
      debugPrint('WidgetService.init error: $e');
    }
  }

  /// Registers a callback for when the user taps a widget and the app is
  /// launched (or brought to the foreground) via the `fikr://record` URI.
  static void registerWidgetClickedCallback(
    void Function(Uri? uri) onLaunched,
  ) {
    HomeWidget.widgetClicked.listen((uri) {
      debugPrint('Widget tapped: $uri');
      onLaunched(uri);
    });

    // Handle the case where the app is launched cold from a widget tap.
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        debugPrint('App launched from widget: $uri');
        onLaunched(uri);
      }
    });
  }

  /// Pushes the latest note title to the widget and requests a UI refresh.
  /// Call this after every successful note save.
  static Future<void> updateLastNote(String title) async {
    try {
      await HomeWidget.saveWidgetData<String>('lastNoteTitle', title);
      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService.updateLastNote error: $e');
    }
  }
}
