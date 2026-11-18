# Push Web Firebase FCM + Novu

La branche `dev` peut recevoir des notifications FCM dans Chrome (ainsi que sur Android/iOS), une fois la configuration Firebase Web renseignée.

## 1. Créer l'application Web Firebase

Dans Firebase Console > Paramètres du projet > Mes applications, créer/enregistrer une application Web. Copier les valeurs publiques `apiKey`, `appId`, `messagingSenderId`, `projectId` et `authDomain`. Utiliser **le même projet Firebase** que l'intégration FCM de Novu.

Dans Firebase Console > Paramètres du projet > Cloud Messaging > Web Push certificates, générer/copier la **clé publique VAPID**. Ne jamais utiliser la clé privée VAPID dans Flutter.

## 2. Configurer le service worker

Modifier `web/firebase-messaging-sw.js` et remplacer les cinq valeurs `REPLACE_WITH_...` par les identifiants Firebase Web réels. Ce fichier est déployé à la racine du site. Firebase Messaging enregistre automatiquement ce worker par son nom `firebase-messaging-sw.js`.

La configuration du worker et les `--dart-define` doivent provenir **du même projet Firebase**. Le worker utilise les SDK Firebase Compat pour ne pas nécessiter de bundler JavaScript.

## 3. Lancer dans Chrome

```powershell
flutter run -d chrome `
  --dart-define=FIREBASE_WEB_API_KEY=VOTRE_API_KEY `
  --dart-define=FIREBASE_WEB_APP_ID=VOTRE_WEB_APP_ID `
  --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=VOTRE_SENDER_ID `
  --dart-define=FIREBASE_WEB_PROJECT_ID=VOTRE_PROJECT_ID `
  --dart-define=FIREBASE_WEB_AUTH_DOMAIN=VOTRE_AUTH_DOMAIN `
  --dart-define=FIREBASE_WEB_VAPID_KEY=VOTRE_CLE_PUBLIQUE_VAPID
```

Sur le site, ouvrir la cloche puis cliquer sur **Initialiser FCM** : le navigateur demandera l'autorisation d'afficher des notifications. Vérifier ensuite la présence du token FCM.

Les notifications Web demandent HTTPS (ou localhost en développement), l'autorisation de l'utilisateur, un service worker valide, et un navigateur compatible. La réception au premier plan actualise la liste des notifications de l'application ; lorsque l'onglet est en arrière-plan, le service worker affiche les notifications système.

## 4. Relier Novu

Le **token FCM Web** doit être enregistré sur le subscriber Novu, exactement comme celui d'Android/iOS, via un backend HTTPS sécurisé et authentifié. Sur chaque navigateur, Novu doit conserver le token sans écraser ceux des autres appareils.

L'URL `PUSH_REGISTER_URL` dans Flutter correspond au **backend applicatif** (pas à la page d'administration `notify.zenithis.tech/integrations`). Le projet d'exemple ne dispose pas encore d'authentification : ne pas exposer de clé API Novu dans les `--dart-define`.

Dans Novu, configurer l'intégration FCM et utiliser le workflow `com-test-flutter` pour envoyer une première notification au subscriber enregistré.

## 5. Dépannage

- `Firebase Web non configuré` : ajouter les cinq `FIREBASE_WEB_*` ci-dessus.
- `Clé VAPID manquante` : renseigner la clé publique VAPID.
- Échec `getToken()` : vérifier les valeurs du service worker, sa présence à `/firebase-messaging-sw.js`, les permissions du navigateur et la console Chrome.
- La liste de l'écran Notifications n'est pas un historique durable : elle ne reflète que les messages de la session.
- Sur mobile, garder `google-services.json` / `GoogleService-Info.plist` configurés. Ces fichiers ne sont pas remplacés par les paramètres Web.
