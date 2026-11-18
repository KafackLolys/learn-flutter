// Firebase Messaging service worker for browser push notifications.
// Replace the public Firebase Web identifiers below before deploying.
// They must match the FIREBASE_WEB_* --dart-define values.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WITH_FIREBASE_WEB_API_KEY',
  authDomain: 'REPLACE_WITH_FIREBASE_WEB_AUTH_DOMAIN',
  projectId: 'REPLACE_WITH_FIREBASE_WEB_PROJECT_ID',
  messagingSenderId: 'REPLACE_WITH_FIREBASE_WEB_MESSAGING_SENDER_ID',
  appId: 'REPLACE_WITH_FIREBASE_WEB_APP_ID',
});

const messaging = firebase.messaging();

// FCM automatically displays notification payloads in the background.
// Only display a notification manually for data-only messages.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  const title = data.title || 'Notification Zenithis';
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    data: { url: data.url || '/' },
  };
  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  const url = event.notification.data && event.notification.data.url;
  event.notification.close();
  if (url && new URL(url, self.location.origin).origin === self.location.origin) {
    event.waitUntil(clients.openWindow(url));
  }
});
