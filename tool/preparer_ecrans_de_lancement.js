#!/usr/bin/env node
//
// Fabrique les écrans de lancement d'iOS (`apple-touch-startup-image`).
//
// **Pourquoi ils existent.** Une application ajoutée à l'écran d'accueil
// affiche d'abord un écran de lancement fabriqué par iOS — fond du
// `manifest.json`, icône à la taille qu'iOS décide — puis la page affiche le
// sien. Deux écrans se succèdent donc, et le logo change de taille entre les
// deux. Fournir nos propres images supprime le premier des deux : iOS affiche
// alors exactement ce que la page affichera ensuite, et il n'y a plus de
// rupture.
//
// **Pourquoi une capture et non un dessin.** Le piège d'un générateur qui
// redessine, c'est qu'il recopie la géométrie de la page — taille du logo,
// rayon des coins, couleur du fond — et qu'il en devient une seconde source,
// qui dérive au premier changement de CSS. Ici on photographie la **vraie
// page**, à la taille exacte de chaque appareil : la coïncidence n'est pas
// visée, elle est obtenue par construction.
//
// Usage : node tool/preparer_ecrans_de_lancement.js
// Prérequis : `flutter build web` au moins une fois (on sert `build/web`).

const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const RACINE = path.resolve(__dirname, '..');
const SERVI = path.join(RACINE, 'build', 'web');
const SORTIE = path.join(RACINE, 'web', 'splash');
const PORT = 8137;

// Les iPhone en orientation portrait, en pixels CSS et densité. iOS n'accepte
// **que** des dimensions exactes : une taille absente de cette liste retombe
// sur l'écran de lancement fabriqué par le système, donc sur l'ancien défaut.
// L'iPad et le paysage sont écartés — voir `web/splash/README.md`.
const APPAREILS = [
  { l: 320, h: 568, d: 2 }, // SE (1re génération)
  { l: 375, h: 667, d: 2 }, // 6, 7, 8, SE 2 et 3
  { l: 414, h: 736, d: 3 }, // 6+, 7+, 8+
  { l: 375, h: 812, d: 3 }, // X, XS, 11 Pro, 12 mini, 13 mini
  { l: 414, h: 896, d: 2 }, // XR, 11
  { l: 414, h: 896, d: 3 }, // XS Max, 11 Pro Max
  { l: 390, h: 844, d: 3 }, // 12, 13, 14
  { l: 428, h: 926, d: 3 }, // 12 Pro Max, 13 Pro Max, 14 Plus
  { l: 393, h: 852, d: 3 }, // 14 Pro, 15, 15 Pro, 16
  { l: 430, h: 932, d: 3 }, // 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus
  { l: 402, h: 874, d: 3 }, // 16 Pro
  { l: 440, h: 956, d: 3 }, // 16 Pro Max
];

const APPARENCES = [
  { mot: 'clair', nom: 'clair' },
  { mot: 'sombre', nom: 'sombre' },
];

function servir() {
  const types = {
    '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
    '.png': 'image/png', '.json': 'application/json',
  };
  const serveur = http.createServer((req, res) => {
    // La version compilée porte `<base href="/JELVO/">` : ses ressources sont
    // donc demandées sous ce préfixe, qu'on retire pour servir à plat.
    const rel = decodeURIComponent(req.url.split('?')[0])
      .replace(/^\/+/, '')
      .replace(/^JELVO\//, '');
    const fichier = path.join(SERVI, rel === '' ? 'index.html' : rel);
    if (!fichier.startsWith(SERVI) || !fs.existsSync(fichier) ||
        fs.statSync(fichier).isDirectory()) {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, { 'Content-Type': types[path.extname(fichier)] || 'application/octet-stream' });
    fs.createReadStream(fichier).pipe(res);
  });
  return new Promise((ok) => serveur.listen(PORT, () => ok(serveur)));
}

(async () => {
  if (!fs.existsSync(path.join(SERVI, 'index.html'))) {
    console.error(`Rien à servir dans ${SERVI} — lancez d'abord « flutter build web ».`);
    process.exit(1);
  }
  fs.mkdirSync(SORTIE, { recursive: true });

  const serveur = await servir();
  const nav = await chromium.launch();
  let total = 0;

  for (const ap of APPARENCES) {
    for (const a of APPAREILS) {
      const ctx = await nav.newContext({
        viewport: { width: a.l, height: a.h },
        deviceScaleFactor: a.d,
        // Le mot enregistré décide du fond : on le pose avant le premier
        // pixel, exactement comme au démarrage réel.
        storageState: {
          cookies: [],
          origins: [{
            origin: `http://localhost:${PORT}`,
            localStorage: [{ name: 'jelvo-apparence', value: ap.mot }],
          }],
        },
      });
      const page = await ctx.newPage();
      // Sans Flutter, l'écran de lancement ne se retire jamais : c'est lui
      // qu'on veut photographier, et rien d'autre.
      await page.route('**/flutter_bootstrap.js', (r) => r.abort());
      await page.goto(`http://localhost:${PORT}/`, { waitUntil: 'domcontentloaded' });
      await page.waitForSelector('#jelvo-amorce img');

      // **Contrôlé, pas supposé.** Un logo qui ne charge pas laisse l'élément
      // en place : la capture serait écrite quand même, et l'écran de
      // lancement d'iOS afficherait un carré vide sans que rien ne l'ait dit.
      const charge = await page.evaluate(() => {
        const img = document.querySelector('#jelvo-amorce img');
        return !!img && img.complete && img.naturalWidth > 0;
      });
      if (!charge) {
        throw new Error(
          `Le logo ne s'est pas chargé pour ${a.l}x${a.h}@${a.d}x — ` +
          'écrans de lancement non écrits.',
        );
      }

      const nom = `${a.l}x${a.h}@${a.d}x-${ap.nom}.png`;
      await page.screenshot({ path: path.join(SORTIE, nom) });
      total += 1;
      await ctx.close();
    }
  }

  await nav.close();
  serveur.close();
  console.log(`${total} écrans de lancement écrits dans web/splash/`);
})();
