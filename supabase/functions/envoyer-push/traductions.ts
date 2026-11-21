// Les gabarits des notifications système, dans les quatre langues.
//
//
// POURQUOI UNE SECONDE COPIE DES TEXTES, ET POURQUOI ELLE EST ACCEPTABLE
//
// Ces phrases ne sont **pas** dans `lib/l10n/app_*.arb`, et c'est délibéré :
// l'application ne les affiche jamais. Elles ne vivent que sur l'écran de
// verrouillage d'un téléphone, composées ici parce que c'est le seul endroit
// qui connaisse à la fois la clé déposée par la base et la langue de
// l'appareil visé (`push_tokens.langue`).
//
// Ce n'est donc pas une recopie de l'ARB mais un jeu propre — avec la
// contrepartie qu'il faut tenir : les quatre langues doivent porter les mêmes
// clés et les mêmes paramètres. `test/notifications_traduites_test.dart` le
// vérifie, et confronte en outre ces clés à celles que le SQL dépose
// réellement. C'est le même genre de contrat que celui de `web/index.html`,
// tenu par `test/launch_screen_test.dart`.
//
//
// LA RÈGLE DE FORMULATION N'EST PAS ICI
//
// **titre = le contexte, corps = qui fait quoi.** Le titre n'est pas un
// gabarit : c'est `params.titre` — le nom du groupe, ou celui de la personne
// pour un anniversaire —, et `push.personnel` le remplace quand il n'y en a
// pas. Une seule règle, aucune branche par type.
//
//
// LES PARAMÈTRES D'HORODATAGE
//
// `instant` et `heure` portent un horodatage ISO, et non un texte déjà
// formaté : « 24/08 à 19:30 » est un format français. Ils sont rendus ici par
// `Intl.DateTimeFormat`, dans le fuseau **Europe/Paris** — la convention de
// tout l'envoyeur, le schéma ne portant aucun fuseau par événement.

/** Les langues servies. Le français est le repli. */
export const LANGUES = ['fr', 'en', 'es', 'de'] as const;
export type Langue = typeof LANGUES[number];

export const LANGUE_PAR_DEFAUT: Langue = 'fr';

const FUSEAU = 'Europe/Paris';

type Gabarits = Record<string, string>;

const FR: Gabarits = {
  'push.personnel': 'Personnel',
  'push.quelquun': 'Quelqu’un',
  'push.chat.texte': '{auteur} : {message}',
  'push.chat.photo': '{auteur} a envoyé une photo',
  'push.chat.video': '{auteur} a envoyé une vidéo',
  'push.chat.vocal': '{auteur} a envoyé un message vocal',
  'push.invitation.groupe': '{auteur} vous invite dans le groupe',
  'push.invitation.evenement': '{auteur} vous convie à {evenement}',
  'push.invitation.evenementSansAuteur': 'Vous êtes convié à {evenement}',
  'push.tache.confiee': '{auteur} vous a confié : {tache}',
  'push.tache.confieeSansAuteur': 'Nouvelle tâche : {tache}',
  'push.tache.reponse.accepte': '{auteur} accepte : {tache}',
  'push.tache.reponse.refuse': '{auteur} décline : {tache}',
  'push.tache.reponse.accepteSansAuteur': '{tache} — acceptée',
  'push.tache.reponse.refuseSansAuteur': '{tache} — déclinée',
  'push.evenement.reponse.oui': '{evenement} — {auteur} vient',
  'push.evenement.reponse.non': '{evenement} — {auteur} ne vient pas',
  'push.evenement.reponse.peutEtre': '{evenement} — {auteur} hésite',
  'push.evenement.reponse.autre': '{evenement} — {auteur} a répondu',
  'push.evenement.deplace': '{evenement} déplacé au {instant}',
  'push.rappel.tache': 'Rappel — {tache}',
  'push.rappel.evenement': 'Rappel — {evenement} à {heure}',
  'push.anniversaire': 'fête son anniversaire aujourd’hui',
};

const EN: Gabarits = {
  'push.personnel': 'Personal',
  'push.quelquun': 'Someone',
  'push.chat.texte': '{auteur}: {message}',
  'push.chat.photo': '{auteur} sent a photo',
  'push.chat.video': '{auteur} sent a video',
  'push.chat.vocal': '{auteur} sent a voice message',
  'push.invitation.groupe': '{auteur} invited you to the group',
  'push.invitation.evenement': '{auteur} invited you to {evenement}',
  'push.invitation.evenementSansAuteur': 'You are invited to {evenement}',
  'push.tache.confiee': '{auteur} assigned you: {tache}',
  'push.tache.confieeSansAuteur': 'New task: {tache}',
  'push.tache.reponse.accepte': '{auteur} accepted: {tache}',
  'push.tache.reponse.refuse': '{auteur} declined: {tache}',
  'push.tache.reponse.accepteSansAuteur': '{tache} — accepted',
  'push.tache.reponse.refuseSansAuteur': '{tache} — declined',
  'push.evenement.reponse.oui': '{evenement} — {auteur} is coming',
  'push.evenement.reponse.non': '{evenement} — {auteur} is not coming',
  'push.evenement.reponse.peutEtre': '{evenement} — {auteur} might come',
  'push.evenement.reponse.autre': '{evenement} — {auteur} replied',
  'push.evenement.deplace': '{evenement} moved to {instant}',
  'push.rappel.tache': 'Reminder — {tache}',
  'push.rappel.evenement': 'Reminder — {evenement} at {heure}',
  'push.anniversaire': 'has a birthday today',
};

const ES: Gabarits = {
  'push.personnel': 'Personal',
  'push.quelquun': 'Alguien',
  'push.chat.texte': '{auteur}: {message}',
  'push.chat.photo': '{auteur} ha enviado una foto',
  'push.chat.video': '{auteur} ha enviado un vídeo',
  'push.chat.vocal': '{auteur} ha enviado un mensaje de voz',
  'push.invitation.groupe': '{auteur} te invita al grupo',
  'push.invitation.evenement': '{auteur} te invita a {evenement}',
  'push.invitation.evenementSansAuteur': 'Estás invitado a {evenement}',
  'push.tache.confiee': '{auteur} te ha asignado: {tache}',
  'push.tache.confieeSansAuteur': 'Nueva tarea: {tache}',
  'push.tache.reponse.accepte': '{auteur} acepta: {tache}',
  'push.tache.reponse.refuse': '{auteur} rechaza: {tache}',
  'push.tache.reponse.accepteSansAuteur': '{tache} — aceptada',
  'push.tache.reponse.refuseSansAuteur': '{tache} — rechazada',
  'push.evenement.reponse.oui': '{evenement} — {auteur} viene',
  'push.evenement.reponse.non': '{evenement} — {auteur} no viene',
  'push.evenement.reponse.peutEtre': '{evenement} — {auteur} duda',
  'push.evenement.reponse.autre': '{evenement} — {auteur} ha respondido',
  'push.evenement.deplace': '{evenement} se traslada al {instant}',
  'push.rappel.tache': 'Recordatorio — {tache}',
  'push.rappel.evenement': 'Recordatorio — {evenement} a las {heure}',
  'push.anniversaire': 'cumple años hoy',
};

const DE: Gabarits = {
  'push.personnel': 'Persönlich',
  'push.quelquun': 'Jemand',
  'push.chat.texte': '{auteur}: {message}',
  'push.chat.photo': '{auteur} hat ein Foto gesendet',
  'push.chat.video': '{auteur} hat ein Video gesendet',
  'push.chat.vocal': '{auteur} hat eine Sprachnachricht gesendet',
  'push.invitation.groupe': '{auteur} lädt dich in die Gruppe ein',
  'push.invitation.evenement': '{auteur} lädt dich zu {evenement} ein',
  'push.invitation.evenementSansAuteur': 'Du bist zu {evenement} eingeladen',
  'push.tache.confiee': '{auteur} hat dir zugewiesen: {tache}',
  'push.tache.confieeSansAuteur': 'Neue Aufgabe: {tache}',
  'push.tache.reponse.accepte': '{auteur} nimmt an: {tache}',
  'push.tache.reponse.refuse': '{auteur} lehnt ab: {tache}',
  'push.tache.reponse.accepteSansAuteur': '{tache} — angenommen',
  'push.tache.reponse.refuseSansAuteur': '{tache} — abgelehnt',
  'push.evenement.reponse.oui': '{evenement} — {auteur} kommt',
  'push.evenement.reponse.non': '{evenement} — {auteur} kommt nicht',
  'push.evenement.reponse.peutEtre': '{evenement} — {auteur} ist unsicher',
  'push.evenement.reponse.autre': '{evenement} — {auteur} hat geantwortet',
  'push.evenement.deplace': '{evenement} verschoben auf {instant}',
  'push.rappel.tache': 'Erinnerung — {tache}',
  'push.rappel.evenement': 'Erinnerung — {evenement} um {heure}',
  'push.anniversaire': 'hat heute Geburtstag',
};

export const GABARITS: Record<Langue, Gabarits> = {
  fr: FR,
  en: EN,
  es: ES,
  de: DE,
};

/**
 * La langue à servir pour un appareil.
 *
 * `null`, une langue inconnue, ou une variante régionale (`es-MX`) : seul le
 * code de langue compte, exactement comme côté Flutter — exiger la région
 * reviendrait à servir le français à tout le Mexique.
 */
export function langueDe(valeur: string | null | undefined): Langue {
  const code = (valeur ?? '').trim().toLowerCase().split(/[-_]/)[0];
  return (LANGUES as readonly string[]).includes(code)
    ? code as Langue
    : LANGUE_PAR_DEFAUT;
}

/** Rend un gabarit, ou `null` si la clé est inconnue de cette langue. */
export function rendre(
  cle: string,
  params: Record<string, unknown> | null | undefined,
  langue: Langue,
): string | null {
  const gabarit = GABARITS[langue][cle] ?? GABARITS[LANGUE_PAR_DEFAUT][cle];
  if (gabarit === undefined) return null;

  return gabarit.replace(/\{(\w+)\}/g, (_, nom: string) => {
    const brut = params?.[nom];

    // **Le seul paramètre qui a un repli.** Les autres — un titre de tâche, un
    // nom de groupe — sont des données : une donnée absente fait changer de
    // clé côté SQL, elle ne prend pas de valeur par défaut.
    if (nom === 'auteur' && (brut === null || brut === undefined)) {
      return GABARITS[langue]['push.quelquun'];
    }
    if (brut === null || brut === undefined) return '';

    const texte = String(brut);
    if (nom === 'instant') return dateEtHeure(texte, langue);
    if (nom === 'heure') return heureSeule(texte, langue);
    return texte;
  });
}

/**
 * Le titre et le corps d'une ligne de la file, dans la langue de l'appareil.
 *
 * **Le texte déjà rédigé reste le repli**, et c'est voulu : une ligne déposée
 * avant la tranche 14 n'a pas de clé, et une fonction en retard d'un
 * déploiement sur la base en verrait une qu'elle ne connaît pas. Dans les deux
 * cas, du français vaut mieux que rien.
 */
export function composer(
  ligne: {
    title: string | null;
    body: string | null;
    cle: string | null;
    params: Record<string, unknown> | null;
    langue: string | null;
  },
): { title: string; body: string } {
  const langue = langueDe(ligne.langue);
  const corps = ligne.cle === null ? null : rendre(ligne.cle, ligne.params, langue);

  if (corps === null) {
    return { title: ligne.title ?? 'Jelvo', body: ligne.body ?? '' };
  }

  const titre = ligne.params?.['titre'];
  return {
    title: typeof titre === 'string' && titre.length > 0
      ? titre
      : GABARITS[langue]['push.personnel'],
    body: corps,
  };
}

function formate(iso: string, langue: Langue, options: Intl.DateTimeFormatOptions): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat(langue, { ...options, timeZone: FUSEAU })
    .format(date);
}

/// « 24/08 19:30 », « 08/24, 7:30 PM », « 24.08., 19:30 » — y compris le
/// séparateur, qui n'est pas le même d'une langue à l'autre.
///
/// **L'année est volontairement absente** : un événement se déplace de
/// quelques jours, et « déplacé au 24/08/2026 » dirait une chose exacte et
/// sans intérêt. `dateStyle: 'short'` l'aurait imposée.
function dateEtHeure(iso: string, langue: Langue): string {
  return formate(iso, langue, {
    day: '2-digit',
    month: '2-digit',
    hour: 'numeric',
    minute: '2-digit',
  });
}

/// « 09:00 », « 9:00 AM ».
///
/// `timeStyle: 'short'` plutôt que deux composantes : c'est le motif court du
/// CLDR, exactement ce que rend `DateFormat.jm` côté Dart. Avec
/// `hour: '2-digit'`, l'anglais écrivait « 07:30 PM », que personne n'écrit.
function heureSeule(iso: string, langue: Langue): string {
  return formate(iso, langue, { timeStyle: 'short' });
}
