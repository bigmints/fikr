import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:toastification/toastification.dart';

import 'controllers/app_controller.dart';
import 'controllers/record_controller.dart';
import 'controllers/theme_controller.dart';
import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'services/openai_service.dart';
import 'services/widget_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await WidgetService.init();

  // Initialize Firebase Service (Vertex AI)
  await FirebaseService().initialize();

  // Setup Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;

  // Notification permission is now requested during onboarding flow.
  // Get token for debugging (may be null if permission not yet granted).
  try {
    final fcmToken = await messaging.getToken();
    debugPrint('FCM Token: $fcmToken');
  } catch (e) {
    debugPrint('Failed to get FCM token (likely APNS not ready): $e');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint(
        'Message also contained a notification: ${message.notification}',
      );
      // Show toast or snackbar
    }
  });

  // Analytics example
  await FirebaseAnalytics.instance.logAppOpen();

  // Inject Dependencies
  Get.put(StorageService());
  Get.put(LLMService());

  final appController = Get.put(AppController());
  Get.put(ThemeController());
  await appController.initialize();

  // Show onboarding only when the user hasn't completed it yet.
  final onboardingDone =
      await Get.find<StorageService>().isOnboardingComplete();
  final showOnboarding = !onboardingDone;

  runApp(FikrApp(showOnboarding: showOnboarding));
}

class FikrApp extends StatelessWidget {
  const FikrApp({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Fikr',
        theme: ThemeController.lightTheme,
        darkTheme: ThemeController.darkTheme,
        themeMode: ThemeMode.system,
        home: showOnboarding ? const OnboardingScreen() : HomeShell(),
        builder: (context, child) {
          // Register widget deep-link handler once the app tree is ready.
          WidgetService.registerWidgetClickedCallback((uri) {
            if (uri?.scheme == 'fikr' && uri?.host == 'record') {
              // Find or create the RecordController and start recording.
              if (Get.isRegistered<RecordController>()) {
                final recordController = Get.find<RecordController>();
                if (!recordController.isRecording.value) {
                  recordController.startRecording();
                }
              }
            }
          });
          return child!;
        },
      ),
    );
  }
}
