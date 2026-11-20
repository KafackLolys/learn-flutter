# Passerelle de test Flutter → Novu → FCM

> Pour le CRUD Flutter et l'envoi des pushes après suppression, utiliser désormais le backend NestJS dans `E:\Projet\Test\all-test-backend`. Ce serveur Node local est conservé pour les diagnostics Novu historiques.

Cette passerelle Node.js est **réservée au développement local**. Elle n'implémente pas d'authentification utilisateur et ne doit jamais être exposée sur Internet. Elle écoute seulement sur 127.0.0.1.

## 1. Prérequis

- Node.js >= 20.6
- Une intégration FCM active dans **le même environnement Novu** que la clé API
- Le workflow `com-test-flutter`, avec une étape Push utilisant `{{payload.title}}` et `{{payload.body}}`
- Un token FCM généré par Flutter Web

Copier `backend/.env.example` vers `backend/.env`, puis compléter les paramètres. Ne jamais committer `backend/.env`.

`NOVU_ENVIRONMENT` est une étiquette locale de diagnostic, pas une vérification distante. La clé `NOVU_SECRET_KEY`, le subscriber et l'intégration FCM doivent tous appartenir au même environnement que le workflow. La capture actuelle montre `Production` ; utiliser une clé API Production et une intégration FCM active dans Production. Après tout changement de `.env`, arrêter puis relancer le backend.

L'URL Novu API n'est **pas nécessairement** `https://notify.zenithis.tech`. Utiliser l'URL réelle de l'API qui gère cette installation. `https://api.novu.co` convient seulement à Novu Cloud. Une adresse du tableau de bord (par exemple `https://notify.zenithis.tech`) n'est pas automatiquement l'adresse API. L'URL doit être l'origine HTTPS de l'API, sans le suffixe `/v1`.

## 2. Lancer le backend

Depuis le dossier `backend` :

```powershell
node --env-file=.env server.js
```

## 3. Diagnostiquer l'authentification Novu avant FCM

Après le démarrage, vérifier la passerelle locale (sans clé) :

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health
```

Le champ `novuApiHost` permet de confirmer que le backend pointe vers le serveur prévu. Ensuite, vérifier l'accès authentifié à Novu (clé **locale de test**, pas la clé Novu) :

```powershell
$headers = @{ Authorization = "Bearer VOTRE_TEST_TRIGGER_KEY" }
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3000/push/check-novu" -Headers $headers
```

- `{"connected":true}` : l'API Novu accepte la clé pour cet environnement.
- `NOVU_AUTH_FAILED_401` ou `_403` : contrôler `NOVU_SECRET_KEY`, l'environnement Development et `NOVU_API_BASE_URL` dans `backend/.env`. **Une clé de Novu Cloud ne fonctionnera pas automatiquement sur un Novu auto-hébergé.**
- `NOVU_HTTP_404` : probablement la mauvaise URL de l'API ou un préfixe de route incorrect.

Redémarrer le backend après chaque modification du fichier `.env`. Ne jamais coller la clé secrète dans les logs ou dans Flutter.

## 4. Enregistrer le token depuis Flutter Web

Dans le fichier `.env.json` du projet Flutter :

```json
{
  "PUSH_REGISTER_URL": "http://127.0.0.1:3000/push/register",
  "PUSH_PRODUCT_DELETED_URL": "http://127.0.0.1:3000/push/product-deleted",
  "NOVU_SUBSCRIBER_ID": "flutter-test-001"
}
```

Après suppression d'un produit, Flutter appelle `PUSH_PRODUCT_DELETED_URL`. La passerelle déclenche le workflow configuré par `NOVU_WORKFLOW_ID` avec `payload.title` et `payload.body`. Le Push step du workflow doit utiliser ces champs. Cette route cible uniquement le subscriber de test configuré dans `backend/.env` ; elle est réservée au bridge local sans authentification utilisateur.

Ajouter les variables ci-dessus à ton fichier Firebase déjà existant (ne pas supprimer les autres entrées). Le client Flutter autorise HTTP **uniquement pour les adresses loopback Web de développement**. Sur Android, utiliser une véritable API HTTPS.

Démarrer Flutter par :

```powershell
flutter run -d web-server --web-hostname localhost --web-port 8080 --dart-define-from-file=.env.json
```

Ouvrir manuellement `http://localhost:8080` dans Chrome/Edge : le navigateur lancé automatiquement par `flutter run -d chrome` désactive les notifications Web. Ouvrir la cloche et cliquer sur « Initialiser FCM » ou « Réessayer l'enregistrement ».

Si Novu renvoie `NOVU_VALIDATION_400`, regarder la route indiquée dans l'erreur :

- `GET /v1/subscribers/:subscriberId` : vérifier le support de cette API par la version auto-hébergée.
- `POST /v1/subscribers` : vérifier le format requis par la version Novu installée.
- `PUT /v1/subscribers/:subscriberId/credentials` : vérifier que l'intégration FCM est active dans le même environnement. `NOVU_FCM_INTEGRATION_IDENTIFIER` est facultatif lorsqu'il n'existe qu'une seule intégration FCM active ; laissez-le vide pour que Novu choisisse l'intégration par défaut. Si plusieurs intégrations FCM existent, renseignez l'`integrationIdentifier` affiché dans les détails de l'intégration FCM. Ne confondez pas cet identifiant avec l'`Application Identifier` de la page API Keys, l'identifiant du workflow ou `providerId: fcm`.

La passerelle tente maintenant de récupérer le subscriber avant de le créer, afin d'éviter certaines erreurs 400 liées aux doublons.

Une réponse `{"registered":true}` signifie que le backend a réussi l'association FCM dans Novu. Le backend utilise `PUT /v1/subscribers/{id}/credentials` : cette version de test maintient **un seul token par subscriber** et peut remplacer les autres. Pour le multi-appareil, prévoir la conservation des tokens existants.

## 5. Déclencher le workflow avec la structure demandée

Dans un second terminal PowerShell (ne pas mettre la clé de test dans Flutter) :

```powershell
$headers = @{ Authorization = "Bearer VOTRE_TEST_TRIGGER_KEY" }
$body = @{ title = "Bonjour Flutter"; body = "Push envoyé via Novu et FCM" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3000/push/trigger" -Headers $headers -ContentType "application/json" -Body $body
```

Le backend appelle ensuite Novu avec :

```json
{
  "name": "com-test-flutter",
  "to": ["flutter-test-001"],
  "payload": {"title": "Bonjour Flutter", "body": "Push envoyé via Novu et FCM"}
}
```

Si `WEB_PUSH_LINK` est une URL HTTPS, il ajoute les `overrides.providers.fcm.webPush.fcmOptions.link` demandés. L'option peut dépendre de la version et de l'intégration Novu; laisser vide lors du premier test.

## 6. Avant toute production

- Authentifier réellement chaque utilisateur côté backend (Firebase Auth / session serveur) et dériver son subscriberId de la session, jamais du JSON client.
- Autoriser uniquement les origines approuvées, utiliser HTTPS, limiter le trafic et journaliser sans exposer les tokens.
- Conserver les tokens des différents appareils, gérer leur renouvellement et leur suppression à la déconnexion.
- Séparer la route administrative de déclenchement de la route d'enregistrement.
- Déployer le backend avec les clés Novu dans les secrets du serveur, **jamais** dans Flutter.
