
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'pages/product_page.dart';
import 'services/push_notification_service.dart';

// Web config values are public Firebase project identifiers, never service keys.
const webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const webSenderId = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
const webProjectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
const webAuthDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      if (webApiKey.isEmpty ||
          webAppId.isEmpty ||
          webSenderId.isEmpty ||
          webProjectId.isEmpty ||
          webAuthDomain.isEmpty) {
        PushNotificationService.instance.configurationError(
          'Firebase Web non configuré. Consulte WEB_PUSH_SETUP.md.',
        );
      } else {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: webApiKey,
            appId: webAppId,
            messagingSenderId: webSenderId,
            projectId: webProjectId,
            authDomain: webAuthDomain,
          ),
        );
        await PushNotificationService.instance.initialize();
      }
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationService.instance.initialize();
    }
  } catch (error) {
    PushNotificationService.instance.configurationError(
      'Firebase non configuré : $error',
    );
    debugPrint('Firebase non configuré : $error');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRUD Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const ProductPage(),
    );
  }
}
