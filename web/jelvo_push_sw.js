// Service worker de réception des notifications Web Push.
//
// Il est **distinct** de celui que Flutter génère (`flutter_service_worker.js`)
// et enregistré sur une portée plus étroite, `push/`. Deux raisons :
//
//   1. Deux enregistrements ne peuvent pas partager une même portée : réutiliser
//      celle de Flutter reviendrait à remplacer son cache d'application.
//   2. Le fichier de Flutter est régénéré à chaque compilation. Y ajouter du
//      code le ferait disparaître au build suivant.
//
// Un abonnement Push appartient à l'enregistrement, pas à la page : une portée
// étroite ne gêne en rien la réception.

// Prendre la main sans attendre le rechargement : sans cela, la toute première
// autorisation ne serait suivie d'aucune réception avant un redémarrage.
self.addEventListener('install', (event) => self.skipWaiting());
self.addEventListener('activate', (event) =>
  event.waitUntil(self.clients.claim()),
);

self.addEventListener('push', (event) => {
  // **iOS impose une notification visible à chaque push.** Un push silencieux
  // — ou dont le gestionnaire n'appelle pas `showNotification` — fait révoquer
  // l'abonnement après quelques récidives. D'où un repli plutôt qu'un
  // abandon : mieux vaut « Jelvo » que rien du tout.
  let charge = { title: 'Jelvo', body: 'Vous avez du nouveau.', url: '/' };

  if (event.data) {
    try {
      charge = Object.assign(charge, event.data.json());
    } catch (_) {
      const texte = event.data.text();
      if (texte) charge.body = texte;
    }
  }

  event.waitUntil(
    self.registration.showNotification(charge.title, {
      body: charge.body,
      // `image` et les boutons d'action sont ignorés par iOS : on s'en tient à
      // ce qui passe partout.
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      // Regrouper par type évite d'empiler dix notifications de la même
      // conversation sur l'écran verrouillé.
      tag: charge.type || 'jelvo',
      renotify: true,
      data: { url: charge.url || '/' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  // L'application n'appelle pas `usePathUrlStrategy()` : ses routes vivent
  // après le fragment. Un lien sans `#` servirait `404.html` et démarrerait
  // sur l'accueil, en perdant la destination sans rien dire.
  const chemin = (event.notification.data && event.notification.data.url) || '/';
  const cible = new URL('.', self.registration.scope);
  const destination = cible.href.replace(/push\/$/, '') + '#' + chemin;

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((fenetres) => {
        // Rouvrir un onglet déjà ouvert plutôt qu'en empiler un second.
        for (const fenetre of fenetres) {
          if (fenetre.url.includes(cible.origin) && 'focus' in fenetre) {
            fenetre.navigate?.(destination);
            return fenetre.focus();
          }
        }
        return self.clients.openWindow(destination);
      }),
  );
});
