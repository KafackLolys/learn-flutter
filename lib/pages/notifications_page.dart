import 'package:flutter/material.dart';

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
        builder: (context, _) {
          if (push.messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDEFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 42,
                        color: Color(0xFF5264D8),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Tout est calme',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vos nouvelles notifications apparaîtront ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF85899A)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: push.messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final message = push.messages[index];
              final title = message.notification?.title ??
                  message.data['title']?.toString() ??
                  'Notification';
              final body = message.notification?.body ??
                  message.data['body']?.toString() ??
                  '';
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDEFFF),
                    child: Icon(Icons.notifications_active_outlined,
                        color: Color(0xFF5264D8)),
                  ),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: body.isEmpty ? null : Text(body),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
