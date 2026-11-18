import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

/// This runs in a separate isolate on Android. Never access widget state here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const channel = AndroidNotificationChannel(
    'zenithis_notifications',
    'Notifications Zenithis',
    description: 'Notifications envoyées depuis Novu et Firebase FCM',
    importance: Importance.high,
  );

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final List<RemoteMessage> messages = [];
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  String? token;
  String? error;
  bool initialized = false;
  bool registeredWithBackend = false;

  // The endpoint must authenticate the current user and call Novu SERVER-SIDE.
  // Do not put a Novu secret key inside Flutter or in --dart-define.
  static const registerEndpoint = String.fromEnvironment('PUSH_REGISTER_URL');
  static const subscriberId = String.fromEnvironment('NOVU_SUBSCRIBER_ID');

  static const webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  void configurationError(String message) {
    error = message;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (initialized) return;
    if (kIsWeb && webVapidKey.isEmpty) {
      configurationError('Clé VAPID manquante : FIREBASE_WEB_VAPID_KEY.');
      return;
    }

    try {
      if (!kIsWeb) {
        await _local.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        await _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      // On Web, getToken() itself asks the browser for notification permission.
      // Some FlutterFire Web versions fail in requestPermission() before the
      // browser prompt can appear. Keep the native permission flow unchanged.
      if (!kIsWeb) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (!kIsWeb) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      token = await _messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
      await _registerToken();
      _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        token = newToken;
        registeredWithBackend = false;
        notifyListeners();
        await _registerToken();
      });

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((
        message,
      ) async {
        _addMessage(message);
        final notification = message.notification;
        // iOS already displays foreground alerts via presentation options.
        if (defaultTargetPlatform == TargetPlatform.android &&
            notification != null) {
          await _local.show(
            message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch ~/ 1000,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'zenithis_notifications',
                'Notifications Zenithis',
                channelDescription:
                    'Notifications envoyées depuis Novu et Firebase FCM',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _addMessage,
      );
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _addMessage(initialMessage);
      initialized = true;
      error = null;
    } catch (exception) {
      error = 'Initialisation FCM impossible : $exception';
    }
    notifyListeners();
  }

  void _addMessage(RemoteMessage message) {
    if (messages.any(
      (item) => item.messageId != null && item.messageId == message.messageId,
    )) {
      return;
    }
    messages.insert(0, message);
    notifyListeners();
  }

  Future<void> _registerToken() async {
    if (token == null || registerEndpoint.isEmpty || subscriberId.isEmpty)
      return;
    try {
      final uri = Uri.parse(registerEndpoint);
      if (uri.scheme != 'https')
        throw const FormatException('HTTPS obligatoire');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'subscriberId': subscriberId,
              'providerId': 'fcm',
              'token': token,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      registeredWithBackend = true;
      error = null;
    } catch (exception) {
      error = 'Enregistrement Novu impossible : $exception';
    }
    notifyListeners();
  }

  Future<void> retryRegistration() => _registerToken();

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
