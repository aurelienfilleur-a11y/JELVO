#!/usr/bin/env node
//
// Fabrique les deux écrans de lancement d'iOS (`apple-touch-startup-image`).
//
// **Deux fichiers, et non deux par modèle d'iPhone.** La version précédente
// photographiait l'écran de lancement de la page à la taille exacte de douze
// iPhone, soit vingt-quatre fichiers. Cette liste était en retard par
// construction : Apple sort des tailles chaque année, et une taille absente
// retombe en silence sur ce que le système décide.
//
// **Ce qui a permis de s'en passer, c'est de ne plus dessiner le logo ici.**
// Un seul endroit le dessine désormais — le voile de `web/index.html` —, si
// bien qu'il n'y a plus deux tailles à faire coïncider. L'image de lancement
// n'est plus qu'un **aplat** de la couleur de fond, dont le seul rôle est
// d'épargner le blanc que Safari affiche sinon pendant que la page charge.
//
// Un aplat n'a pas de géométrie : iOS peut l'étirer, le rogner ou le centrer,
// cela ne se voit pas. Il ne reste qu'une proportion à viser, et non une
// taille : celle des iPhone depuis l'iPhone X, que les deux dimensions
// ci-dessous reprennent. Sur un écran d'une autre proportion, le pire cas est
// une bande de quelques pixels — à comparer à l'écran blanc d'avant.
//
// Usage : node tool/preparer_ecrans_de_lancement.js
// Aucun prérequis : rien n'est compilé, rien n'est servi, rien n'est
// photographié.

const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const RACINE = path.resolve(__dirname, '..');
const PAGE = path.join(RACINE, 'web', 'index.html');
const SORTIE = path.join(RACINE, 'web', 'splash');

// La proportion des iPhone à encoche et à îlot — 1320 × 2868 est celle du plus
// grand d'entre eux. Ce n'est pas un modèle visé : c'est le rapport de forme,
// et l'image est mise à l'échelle pour tous les autres.
const LARGEUR = 1320;
const HAUTEUR = 2868;

/// Les deux teintes sont **lues dans la page**, qui les tient déjà de
/// `JelvoColors` — `test/launch_screen_test.dart` confronte les deux. Les
/// recopier ici en ferait une troisième source, et c'est toujours la troisième
/// qui dérive.
function fonds() {
  const texte = fs.readFileSync(PAGE, 'utf8');
  const m = /clair:\s*'(#[0-9A-Fa-f]{6})',\s*sombre:\s*'(#[0-9A-Fa-f]{6})'/.exec(
    texte,
  );
  if (!m) {
    throw new Error(
      "Les deux fonds n'ont pas été trouvés dans web/index.html — " +
        'la forme de `FONDS` a changé, les écrans de lancement ne sont pas écrits.',
    );
  }
  return { clair: m[1], sombre: m[2] };
}

const TABLE_CRC = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = TABLE_CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function morceau(type, donnees) {
  const entete = Buffer.alloc(4);
  entete.writeUInt32BE(donnees.length, 0);
  const corps = Buffer.concat([Buffer.from(type, 'ascii'), donnees]);
  const somme = Buffer.alloc(4);
  somme.writeUInt32BE(crc32(corps), 0);
  return Buffer.concat([entete, corps, somme]);
}

/// Un PNG d'une seule couleur, écrit à la main. Aucune bibliothèque d'images
/// n'est tirée pour deux aplats, et le résultat est reproductible à l'octet.
function aplat(largeur, hauteur, hexa) {
  const r = parseInt(hexa.slice(1, 3), 16);
  const v = parseInt(hexa.slice(3, 5), 16);
  const b = parseInt(hexa.slice(5, 7), 16);

  const pas = 1 + largeur * 3; // l'octet de filtre, puis les pixels
  const ligne = Buffer.alloc(pas);
  for (let x = 0; x < largeur; x++) {
    ligne[1 + x * 3] = r;
    ligne[2 + x * 3] = v;
    ligne[3 + x * 3] = b;
  }
  const brut = Buffer.alloc(pas * hauteur);
  for (let y = 0; y < hauteur; y++) ligne.copy(brut, y * pas);

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(largeur, 0);
  ihdr.writeUInt32BE(hauteur, 4);
  ihdr[8] = 8; // 8 bits par canal
  ihdr[9] = 2; // couleur vraie, sans alpha
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    morceau('IHDR', ihdr),
    morceau('IDAT', zlib.deflateSync(brut, { level: 9 })),
    morceau('IEND', Buffer.alloc(0)),
  ]);
}

const teintes = fonds();
fs.mkdirSync(SORTIE, { recursive: true });

// Les fichiers par modèle de la version précédente ne doivent pas survivre :
// laissés là, leurs balises retirées, ils feraient échouer le contrôle qui
// veut qu'à chaque fichier corresponde une déclaration.
for (const nom of fs.readdirSync(SORTIE)) {
  if (nom.endsWith('.png')) fs.unlinkSync(path.join(SORTIE, nom));
}

for (const [apparence, hexa] of Object.entries(teintes)) {
  const nom = `lancement-${apparence}.png`;
  const octets = aplat(LARGEUR, HAUTEUR, hexa);
  fs.writeFileSync(path.join(SORTIE, nom), octets);
  console.log(
    `${nom} — ${LARGEUR}×${HAUTEUR}, ${hexa}, ${(octets.length / 1024).toFixed(1)} Kio`,
  );
}
