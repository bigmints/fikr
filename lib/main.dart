import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:toastification/toastification.dart';

import 'package:fikr/controllers/app_controller.dart';
import 'package:fikr/controllers/i_app_state.dart';
import 'package:fikr/controllers/record_controller.dart';
import 'package:fikr/controllers/theme_controller.dart';
import 'package:fikr/controllers/usage_controller.dart';
import 'package:fikr/firebase_options.dart';
import 'package:fikr/screens/home_shell.dart';
import 'package:fikr/screens/onboarding_screen.dart';
import 'package:fikr/services/firebase_service.dart';
import 'package:fikr/services/storage_service.dart';
import 'package:fikr/services/openai_service.dart';
import 'package:fikr/services/audio_sync_service.dart';
import 'package:fikr/services/widget_service.dart';
import 'package:fikr/tools/tool_initializer.dart';
import 'package:fikr/tools/engine/engine_controller.dart';
import 'package:fikr/tools/tool_execution_log.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("Handling a background message: ${message.messageId}");
  } catch (e) {
    debugPrint("Background handler error: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize home widget (may fail on device without widget extension)
  try {
    await WidgetService.init();
  } catch (e) {
    debugPrint('WidgetService.init failed: $e');
  }

  // Initialize Firebase Service (Vertex AI)
  try {
    final firebaseService = FirebaseService();
    await firebaseService.initialize();
  } catch (e) {
    debugPrint('FirebaseService.initialize failed: $e');
  }

  // Setup Firebase Messaging with error handling
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Get FCM token with error handling
  try {
    final messaging = FirebaseMessaging.instance;
    final fcmToken = await messaging.getToken();
    debugPrint('FCM Token: $fcmToken');
  } catch (e) {
    debugPrint('Failed to get FCM token: $e');
  }

  // Setup foreground message handler with error handling
  try {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
      }
    });
  } catch (e) {
    debugPrint('Failed to setup message listener: $e');
  }

  // Analytics example with error handling
  try {
    await FirebaseAnalytics.instance.logAppOpen();
  } catch (e) {
    debugPrint('Analytics logAppOpen failed: $e');
  }

  // Inject Dependencies
  try {
    Get.put(StorageService(), permanent: true);
  } catch (e) {
    debugPrint('StorageService init failed: $e');
  }

  try {
    Get.put(LLMService(), permanent: true);
  } catch (e) {
    debugPrint('LLMService init failed: $e');
  }

  try {
    Get.put(AudioSyncService(), permanent: true);
  } catch (e) {
    debugPrint('AudioSyncService init failed: $e');
  }

  try {
    Get.put(ThemeController(), permanent: true);
  } catch (e) {
    debugPrint('ThemeController init failed: $e');
  }

  AppController? appController;
  try {
    final ctrl = Get.put(AppController(), permanent: true);
    // Also register under the IAppState interface so Get.find<IAppState>() works
    // in all tools. Must happen before initialize() so the engine can resolve it.
    Get.put<IAppState>(ctrl, permanent: true);
    await ctrl.initialize();
    appController = ctrl;
  } catch (e) {
    debugPrint('AppController init failed: $e');
  }


  // Initialize tools + skills engine (must be after AppController)
  try {
    initializeTools();
  } catch (e) {
    debugPrint('initializeTools failed: $e');
  }

  // Register ToolExecutionLog BEFORE EngineController — the engine's onInit
  // calls ToolExecutionLog.instance (Get.find) which will throw if not registered.
  try {
    Get.put(ToolExecutionLog(), permanent: true);
  } catch (e) {
    debugPrint('ToolExecutionLog init failed: $e');
  }

  try {
    await Get.putAsync(() async => EngineController(), permanent: true);
  } catch (e) {
    debugPrint('EngineController init failed: $e');
  }

  // Register UsageController — after AppController so plan is available
  try {
    Get.put(UsageController(), permanent: true);
  } catch (e) {
    debugPrint('UsageController init failed: $e');
  }

  // Show onboarding only when the user hasn't completed it yet.
  bool onboardingDone = false;
  try {
    onboardingDone = await Get.find<StorageService>().isOnboardingComplete();
  } catch (e) {
    debugPrint('Failed to check onboarding status: $e');
  }
  final showOnboarding = !onboardingDone;

  runApp(FikrApp(
    showOnboarding: showOnboarding,
    appController: appController,
  ));
}

class FikrApp extends StatelessWidget {
  const FikrApp({
    super.key,
    required this.showOnboarding,
    required this.appController,
  });

  final bool showOnboarding;
  final AppController? appController;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Fikr',
        theme: ThemeController.lightTheme,
        darkTheme: ThemeController.darkTheme,
        themeMode: ThemeMode.system,
        initialBinding: BindingsBuilder(() {
          if (appController != null) {
            Get.put<AppController>(appController!, permanent: true);
          }
        }),
        home: showOnboarding ? const OnboardingScreen() : HomeShell(appController: appController!),
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
