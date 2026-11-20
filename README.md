# learn_flutter

A new Flutter project.
# Utiliser le backend NestJS `all-test-backend`

Le CRUD des produits n'utilise plus `learn_flutter/backend/server.js`. Lance le backend NestJS dans le dossier `E:\Projet\Test\all-test-backend` :

```powershell
npm run start:dev
```

Il écoute sur l'adresse IPv4 locale configurée dans `all-test-backend/.env` (`HOST`) et conserve les produits dans `data/learn_flutter.sqlite`. Flutter charge les URL du CRUD et de l'enregistrement FCM depuis `.env.json`. Pour BlueStacks, les deux URL doivent utiliser l'adresse IPv4 Wi-Fi du PC (par exemple `192.168.1.73`) sur le port `3000`.

Lancer Flutter Web depuis ce dossier :

```powershell
flutter run -d web-server --web-hostname localhost --web-port 8080 --dart-define-from-file=.env.json
```

La suppression appelle `DELETE /learn-flutter/products/:id`. Le backend supprime la ligne SQLite puis déclenche le workflow Novu configuré pour le subscriber de test. Il faut une intégration FCM active dans le même environnement Novu. Cette configuration est réservée au développement local et ne fournit pas d'authentification utilisateur.
