# Tester les notifications FCM Android sans backend

Cette branche permet la **réception** de vrais messages push sur un téléphone
Android sans utiliser le serveur Node/Novu. L'envoi se fait depuis **Firebase
Console**, pas directement depuis l'application. La suppression d'un produit
reste locale sur Android : elle ne déclenche pas de push distant.

## Construire l'APK

Le client Android Firebase inclus est configuré pour `com.test_flutter`.

```bash
flutter pub get
flutter build apk --release
```

Installer `build/app/outputs/flutter-apk/app-release.apk` sur le téléphone.
Aucun fichier `.env.json`, aucun secret Novu et aucune URL backend ne sont
nécessaires pour ce test Android.

## Recevoir un vrai push

1. Ouvrir l'application sur le téléphone connecté à Internet et accepter les
   notifications Android lorsqu'elles sont demandées.
2. Ouvrir **Notifications** et attendre que **FCM initialisé** et le token
   apparaissent. Cliquer sur **Copier le token FCM**.
3. Dans [Firebase Console](https://console.firebase.google.com/), ouvrir le
   projet correspondant à `android/app/google-services.json`, puis
   **Messaging** / **Cloud Messaging** et créer une notification.
4. Choisir **Send test message** / **Envoyer un message de test** et saisir le
   token du téléphone. Envoyer un titre et un texte.
5. Tester l'application en premier plan, en arrière-plan et fermée. En premier
   plan, la notification est affichée localement par le plugin Flutter après
   réception du message FCM.

La réception requiert généralement un appareil avec les services Google Play.
La génération de l'APK ne prouve pas que le projet Firebase et les paramètres
FCM sont corrects : vérifier la réception sur l'appareil réel.

## Limitation importante

La suppression d'un produit **ne peut pas envoyer un push FCM directement**
depuis un APK sans une partie serveur de confiance : les identifiants Firebase
Admin ne doivent jamais être intégrés dans une application mobile. Pour
déclencher automatiquement un push lors de la suppression, utiliser une
Cloud Function Firebase, un backend ou un autre service serveur authentifié.

Le comportement de la passerelle Novu pour Flutter Web reste inchangé.
