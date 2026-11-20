import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/push_notification_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final push = PushNotificationService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListenableBuilder(
        listenable: push,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(push.initialized ? 'FCM initialisé' : 'FCM non initialisé',
                style: Theme.of(context).textTheme.titleMedium),
            if (push.error != null) ...[
              const SizedBox(height: 8),
              Text(push.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            SelectableText('Token FCM : ${push.token ?? "indisponible"}'),
            if (!kIsWeb && push.token != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier le token FCM'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: push.token!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Token FCM copié')),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
            if (!kIsWeb)
              const Text('Mode Android sans backend : envoyez un message de test '
                  'depuis Firebase Console vers le token affiché ci-dessus.')
            else Text(push.registeredWithBackend
                ? 'Appareil enregistré auprès du backend Novu.'
                : 'Appareil non encore enregistré auprès du backend Novu.'),
            Wrap(spacing: 8, children: [
              OutlinedButton(
                onPressed: push.initialize,
                child: const Text('Initialiser FCM'),
              ),
              if (kIsWeb) OutlinedButton(
                onPressed: push.retryRegistration,
                child: const Text('Réessayer l’enregistrement'),
              ),
            ]),
            const Divider(height: 32),
            Text('Notifications reçues pendant cette session',
                style: Theme.of(context).textTheme.titleMedium),
            if (push.messages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune notification reçue pour le moment.'),
              ),
            for (final message in push.messages)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(message.notification?.title ?? message.data['title']?.toString() ?? 'Notification'),
                  subtitle: Text(message.notification?.body ?? message.data['body']?.toString() ?? ''),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
