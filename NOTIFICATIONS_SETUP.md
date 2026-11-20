# Notifications push Firebase FCM + Novu

L'application reçoit les notifications FCM sur Android/iOS et affiche une notification locale **Android** lorsque l'application est au premier plan. Sur iOS, l'option de présentation FCM affiche la notification. Quand l'utilisateur ouvre une notification système FCM, elle apparaît dans l'écran **Notifications** (icône cloche). L'historique affiché est **en mémoire** et ne constitue pas une boîte de réception persistante Novu.

## 1. Connecter le projet Flutter à Firebase

1. Choisir un identifiant définitif pour Android (`android/app/build.gradle.kts`, `applicationId`) et le Bundle ID iOS. Actuellement Android utilise `com.example.learn_flutter` : ne pas le changer après avoir enregistré l'application Firebase sans mettre Firebase à jour.
2. Installer Flutter, Dart, la CLI Firebase et FlutterFire, puis dans le répertoire `learn_flutter` :

   ```bash
   flutter pub get
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. Choisir le **même projet Firebase** que celui utilisé par l'intégration FCM de Novu. Télécharger ou générer la configuration native : `android/app/google-services.json` et, pour iOS, `ios/Runner/GoogleService-Info.plist` ajouté à la cible Runner dans Xcode. La configuration Android est requise pour compiler avec le plugin Google Services.
4. Pour iOS : activer *Push Notifications* et *Background Modes > Remote notifications* dans Xcode, configurer la clé APNs dans Firebase et tester sur un appareil physique.
5. Pour Android 13+, autoriser les notifications lorsque le système le demande. Tester de préférence sur un appareil réel ou un émulateur avec Google Play Services.

> Si `flutterfire configure` produit `lib/firebase_options.dart`, vous pouvez utiliser `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` avec son import, en cohérence avec les plateformes générées. Le code fourni initialise Firebase depuis la configuration native Android/iOS.

## 2. Configurer Novu sur notify.zenithis.tech

1. Ouvrir https://notify.zenithis.tech/integrations et ajouter ou vérifier une intégration **Firebase Cloud Messaging (FCM)** dans le canal Push.
2. Renseigner les identifiants de **compte de service Firebase** dans Novu (côté serveur uniquement) suivant la version de Novu installée. Vérifier que l'intégration est active. L'`integrationIdentifier` se trouve dans les détails de cette intégration ; ce n'est pas l'`Application Identifier` visible dans **API Keys**. Avec une seule intégration FCM, `NOVU_FCM_INTEGRATION_IDENTIFIER` peut rester vide.
3. Créer un workflow Novu ayant une étape **Push** et tester son déclenchement pour un `subscriberId` connu.

**Le client Flutter ne doit jamais appeler l'API Novu avec une clé secrète.** L'URL `https://notify.zenithis.tech/integrations` est une interface d'administration, pas l'endpoint d'enregistrement des tokens.

## 3. Enregistrer le token FCM chez Novu

L'écran Notifications affiche le token FCM. Pour automatiser son enregistrement, développer un endpoint backend HTTPS authentifié (exemple `POST https://api.exemple.com/push/register`). Le client envoie :

```json
{
  "subscriberId": "user-123",
  "providerId": "fcm",
  "token": "FCM_DEVICE_TOKEN"
}
```

Le backend doit **déduire et vérifier `subscriberId` depuis la session authentifiée**, empêcher un utilisateur d'enregistrer un token au nom d'un autre, puis enregistrer le token dans le subscriber Novu via l'API serveur de votre version (par exemple `PUT /v1/subscribers/{subscriberId}/credentials` avec `providerId: "fcm"`, `credentials.deviceTokens` et éventuellement `integrationIdentifier`). Selon la version, l'opération peut remplacer la liste : conserver les tokens des autres appareils et supprimer ceux devenus invalides. Les secrets Novu sont uniquement côté backend.

Le projet de démonstration actuel n'a **pas de système d'authentification**. Les paramètres de lancement ci-dessous ne conviennent qu'à un test avec un endpoint protégé dans un environnement de confiance ; pour la production, connecter l'enregistrement à l'identité et au jeton de session réels de l'utilisateur.

```bash
flutter run \
  --dart-define=PUSH_REGISTER_URL=https://api.exemple.com/push/register \
  --dart-define=NOVU_SUBSCRIBER_ID=user-123
```

Sans ces paramètres, la réception FCM fonctionne une fois Firebase configuré, mais **aucun token n'est envoyé à Novu**. Au rafraîchissement d'un token, l'application tente une nouvelle inscription. Prévoir la désinscription au logout côté backend.

## 4. Vérifier la réception

1. Démarrer l'application Android/iOS, accepter la permission, puis ouvrir la cloche et vérifier qu'un token FCM est visible.
2. Confirmer côté backend/Novu que le token est rattaché au bon subscriber et que l'intégration FCM est active.
3. Envoyer un workflow test avec titre et corps de notification. Tester application ouverte, en arrière-plan, puis fermée.
4. Une notification avec `notification.title` et `notification.body` est affichée par le système en arrière-plan. En premier plan, le code crée une notification locale **uniquement sur Android** pour éviter les doublons iOS.

## Limites actuelles

- La plateforme Web n'est pas intégrée (VAPID + service worker requis).
- Aucune notification de test n'est simulée dans l'application : le test doit venir de Firebase ou de Novu.
- Les messages reçus en tâche de fond ne sont pas ajoutés à un historique durable ; pour une vraie boîte de réception, il faut ajouter le canal in-app Novu/API backend.
- L'endpoint de registration sécurisé et l'intégration FCM dans l'instance Novu nécessitent des accès/configurations serveur qui ne figurent pas dans cette archive.
