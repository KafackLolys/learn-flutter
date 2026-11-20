
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
        // Demander la permission du navigateur et récupérer le token FCM automatiquement sur le web.
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
          seedColor: const Color(0xFF5264D8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EAF1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5264D8), width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      home: const ProductPage(),
    );
  }
}
