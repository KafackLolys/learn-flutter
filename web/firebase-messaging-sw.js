// Firebase Messaging service worker for browser push notifications.
//
// IMPORTANT: les 5 valeurs ci-dessous doivent correspondre EXACTEMENT aux
// --dart-define passés à `flutter run -d chrome` (FIREBASE_WEB_API_KEY,
// FIREBASE_WEB_APP_ID, FIREBASE_WEB_MESSAGING_SENDER_ID,
// FIREBASE_WEB_PROJECT_ID, FIREBASE_WEB_AUTH_DOMAIN), sinon le worker et
// l'application Flutter ciblent deux projets Firebase différents et les
// notifications ne fonctionneront pas.
//
// Ce fichier doit être déployé à la racine du site (accessible à
// /firebase-messaging-sw.js). Firebase l'enregistre automatiquement par ce nom.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCsleSpykstnt2hApXxvejXAJTqhUM3HO0',
  authDomain: 'test-flutter-e5e37.firebaseapp.com',
  projectId: 'test-flutter-e5e37',
  messagingSenderId: '675953719483',
  appId: '1:675953719483:web:405c9ce6a229fb0ad8519e',
});

const messaging = firebase.messaging();

// La clé publique VAPID est injectée côté Dart via
// FirebaseMessaging.instance.getToken(vapidKey: ...). Le worker n'a pas besoin
// de la redéclarer pour recevoir les messages en arrière-plan : l'abonnement
// push a déjà été créé avec cette clé depuis Flutter.

// FCM affiche automatiquement les notifications en arrière-plan lorsqu'elles
// contiennent un champ "notification". On n'affiche manuellement que les
// messages data-only.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  const title = data.title || 'Notification Zenithis';
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
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
