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

  // Si le message est "data-only" (sans payload notification natif), Android n'affiche rien par défaut.
  // On utilise flutter_local_notifications pour forcer l'affichage dans la barre d'état.
  if (message.notification == null && (message.data.isNotEmpty)) {
    final title = message.data['title']?.toString() ?? 'Notification';
    final body = message.data['body']?.toString() ?? '';
    final local = FlutterLocalNotificationsPlugin();
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await local.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'zenithis_notifications',
          'Notifications Zenithis',
          channelDescription: 'Notifications envoyées depuis Novu et Firebase FCM',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
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
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final List<RemoteMessage> messages = [];
  RemoteMessage? latestForegroundMessage;
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

        final androidImplementation = _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        // Créer le canal de notification avec haute importance
        await androidImplementation?.createNotificationChannel(channel);

        // Demande explicite de permission d'affichage sur Android 13+ (POST_NOTIFICATIONS)
        await androidImplementation?.requestNotificationsPermission();
      }

      // Demande de permission FCM
      if (!kIsWeb) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
      if (!kIsWeb) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      token = await _messaging.getToken(
        vapidKey: kIsWeb ? webVapidKey : null,
      );
      _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        token = newToken;
        registeredWithBackend = false;
        notifyListeners();
        if (kIsWeb) await _registerToken();
      });

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) async {
        _addMessage(message);
        latestForegroundMessage = message;
        notifyListeners();

        // Récupérer titre et corps que le message soit un payload notification ou data-only
        final title = message.notification?.title ?? message.data['title']?.toString();
        final body = message.notification?.body ?? message.data['body']?.toString();

        if (defaultTargetPlatform == TargetPlatform.android && (title != null || body != null)) {
          await _local.show(
            message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title ?? 'Notification',
            body ?? '',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'zenithis_notifications',
                'Notifications Zenithis',
                channelDescription: 'Notifications envoyées depuis Novu et Firebase FCM',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_addMessage);
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _addMessage(initialMessage);
      initialized = true;
      error = null;
      notifyListeners();
      initialized = true;
      error = null;
      notifyListeners();
      await _registerToken();
    } catch (exception) {
      error = 'Initialisation FCM impossible : $exception';
    }
    notifyListeners();
  }

  void _addMessage(RemoteMessage message) {
    if (messages.any((item) => item.messageId != null && item.messageId == message.messageId)) {
      return;
    }
    messages.insert(0, message);
    notifyListeners();
  }

  Future<void> _registerToken() async {
    registeredWithBackend = false;
    if (token == null || token!.isEmpty) {
      error = 'Token FCM indisponible. Initialisez FCM avant de vous enregistrer.';
      notifyListeners();
      return;
    }
    if (registerEndpoint.isEmpty || subscriberId.isEmpty) {
      // Si les variables ne sont pas fournies en mode natif, pas d'erreur bloquante mais information
      if (!kIsWeb) {
        error = null;
        notifyListeners();
        return;
      }
      error = 'Configuration Novu manquante : '
          '${registerEndpoint.isEmpty ? "PUSH_REGISTER_URL" : ""}'
          '${registerEndpoint.isEmpty && subscriberId.isEmpty ? " et " : ""}'
          '${subscriberId.isEmpty ? "NOVU_SUBSCRIBER_ID" : ""}. '
          'Ajoutez ces valeurs au fichier de configuration puis redémarrez Flutter.';
      notifyListeners();
      return;
    }
    try {
      final uri = Uri.parse(registerEndpoint);
      // HTTP is allowed for local development (localhost, 127.0.0.1, 10.0.2.2 or local LAN 192.168.x / 10.x)
      final isLocal = uri.scheme == 'http' &&
          (uri.host == '127.0.0.1' ||
           uri.host == 'localhost' ||
           uri.host == '10.0.2.2' ||
           uri.host.startsWith('192.168.') ||
           uri.host.startsWith('10.'));
      if (uri.scheme != 'https' && !isLocal) {
        throw const FormatException('HTTPS obligatoire hors du développement local');
      }
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subscriberId': subscriberId, 'providerId': 'fcm', 'token': token}),
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        throw Exception('HTTP ${response.statusCode} : $detail');
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
