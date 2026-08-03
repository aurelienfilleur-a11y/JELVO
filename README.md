# JELVO

Application de gestion d'emploi du temps personnel et de groupe.

Projet **Flutter** ciblant le **web**, **iOS** et **Android** : agenda partagé,
groupes, tâches et carnet de contacts, dans une interface en français.

## Démarrer

```bash
flutter pub get
flutter run -d chrome
```

Flutter **3.44.8** (Dart 3.12) est la version de référence, épinglée dans le
workflow de déploiement.

## Vérifications

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Ces trois commandes, suivies de la compilation web, sont exécutées par la CI à
chaque push sur `main`.

## Déploiement

`.github/workflows/deploy-web.yml` compile la cible web et la publie sur
**GitHub Pages** à chaque push sur `main`.

Pour l'activer sur un dépôt neuf : **Settings → Pages → Source → GitHub
Actions**. Le `--base-href` est déduit du nom du dépôt, et `index.html` est
copié en `404.html` pour que les routes GoRouter fonctionnent en accès direct.

## Documentation

L'architecture, le design system et les conventions de code sont décrits dans
[`CLAUDE.md`](CLAUDE.md).
