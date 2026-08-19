// Envoi des notifications Web Push — fonction Edge (Deno).
//
// Elle vide `public.push_outbox` : lit les lignes en attente jointes aux
// abonnements, signe chaque envoi avec la clé VAPID, poste vers le service de
// notification du navigateur, puis marque la ligne traitée.
//
//
// POURQUOI UNE FONCTION PLUTÔT QU'UN APPEL DEPUIS UN DÉCLENCHEUR
//
// Trois raisons, chacune suffisante :
//
//   1. Une notification est un effet de bord et ne doit **jamais** faire
//      échouer l'écriture qui l'a provoquée. Un appel réseau dans la
//      transaction violerait cette règle à la première panne.
//   2. La clé VAPID privée n'a rien à faire dans la base : ici elle vit dans
//      les secrets de la fonction, et ne quitte jamais le serveur.
//   3. La tranche 5d dépose ses rappels dans la même file. Un seul envoyeur.
//
//
// SECRETS ATTENDUS — SANS EUX, RIEN NE PART
//
//   VAPID_PUBLIC_KEY    clé publique, au format base64url brut
//   VAPID_PRIVATE_KEY   clé privée, au format base64url brut
//   VAPID_SUBJECT       « mailto:… » ou l'URL du site
//   SUPABASE_URL        fourni automatiquement par la plateforme
//   SUPABASE_SERVICE_ROLE_KEY  idem
//
// Générer la paire :
//
//   npx web-push generate-vapid-keys
//
// puis, depuis la racine du dépôt :
//
//   supabase secrets set VAPID_PUBLIC_KEY=… VAPID_PRIVATE_KEY=… \
//                        VAPID_SUBJECT=mailto:vous@exemple.fr
//
// La **publique** doit aussi être passée à la compilation Flutter, via
// `--dart-define=VAPID_PUBLIC_KEY=…` : le navigateur en a besoin pour
// s'abonner. Elle est publique par conception, comme la clé « publishable ».
//
//
// CETTE FONCTION DOIT ÊTRE PLANIFIÉE — SANS CELA, RIEN NE PART NON PLUS
//
// Elle ne s'exécute pas toute seule. Tant que rien ne l'appelle, la file se
// remplit et personne ne la vide : c'est exactement ce qui s'est passé entre
// les tranches 5c et 5d.
//
// Tableau de bord Supabase → Integrations → Cron → nouvelle tâche, type
// « Edge Function », `envoyer-push`, toutes les minutes (`* * * * *`).
//
// C'est **la seule chose à planifier** : la fonction empile les rappels dus
// avant de vider la file. Voir l'en-tête de `supabase/tranche5d_rappels.sql`
// pour la raison du choix.
//
// Le délai d'attente de la tâche n'a plus d'importance — l'interface le
// plafonne à 5000 ms, et la fonction répond en quelques dizaines de
// millisecondes puisqu'elle n'accuse que réception. Ce que fait un passage se
// lit dans **les journaux de la fonction**, pas dans l'historique de la
// planification, qui ne saura plus que dire « appelée ».

import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? '';
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? '';
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:contact@jelvo.app';

// LE PASSAGE DOIT TENIR DANS LE DÉLAI DE LA PLANIFICATION
//
// L'interface Cron de Supabase plafonne le délai d'attente à **5000 ms**. Un
// passage qui déborde est compté en échec à chaque minute, ce qui détruit le
// seul signal dont on dispose pour savoir si la chaîne fonctionne.
//
// Trois choses pouvaient déborder, et réduire le lot n'en réglait qu'une :
//
//   1. le démarrage à froid — l'import de `web-push` coûte une à trois
//      secondes après un déploiement ou une période d'inactivité ;
//   2. un endpoint qui pend : `allSettled` attend le plus lent, et
//      `sendNotification` n'impose aucun délai maximal. **Un seul endpoint
//      lent bloquait le lot entier, fût-il de taille 1** ;
//   3. le volume, seul cas que la taille du lot gouverne.
//
// D'où trois bornes, et non une :
//
//   - la réponse part **avant** le travail (voir `enArrierePlan`), si bien que
//     la planification n'attend plus que l'accusé de réception ;
//   - chaque envoi est borné par `DELAI_ENVOI_MS` ;
//   - le lot est petit, et ce qui reste s'écoule aux passages suivants — la
//     file est ordonnée par `created_at`, rien ne se perd ni ne double.

/** Combien de lignes au plus par passage. */
const LOT = 20;

/** Au-delà, un envoi est abandonné pour ce passage et retenté au suivant. */
const DELAI_ENVOI_MS = 3000;

interface LigneAEnvoyer {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  url: string | null;
  token: string;
  platform: string;
  p256dh: string | null;
  auth_key: string | null;
}

Deno.serve(async (): Promise<Response> => {
  // **Journaliser l'entrée, toujours, avant toute sortie anticipée.**
  //
  // Sans cette ligne, une invocation ne laissait dans les journaux que le
  // `booted` / `shutdown` du runtime, et **deux pannes très différentes
  // rendaient exactement la même trace** : une clé VAPID absente, qui sort
  // immédiatement, et un `waitUntil` inopérant, qui laisse le travail
  // commencer puis se faire interrompre. Impossible de les départager.
  //
  // C'est arrivé, et cela a coûté un aller-retour de diagnostic. Une
  // fonction qui ne dit pas qu'elle a démarré n'est pas diagnosticable.
  console.log('envoyer-push : invocation');

  const manquants = [
    !VAPID_PUBLIC ? 'VAPID_PUBLIC_KEY' : null,
    !VAPID_PRIVATE ? 'VAPID_PRIVATE_KEY' : null,
  ].filter((nom): nom is string => nom !== null);

  if (manquants.length > 0) {
    // **`VAPID_PUBLIC_KEY` se pose ici aussi**, dans les secrets de la
    // fonction, et pas seulement dans le workflow web. Ce sont deux
    // environnements sans aucun rapport : le `--dart-define` du build ne
    // fournit la clé qu'au bundle Flutter, jamais à ce serveur. Et
    // `setVapidDetails` exige la paire complète — la publique entre dans
    // l'en-tête `Crypto-Key` de chaque envoi.
    console.error(
      `envoyer-push : secrets manquants — ${manquants.join(', ')}. ` +
        'À poser dans Edge Functions → Secrets, pas dans le dépôt.',
    );
    return json({ erreur: 'vapid_absent', manquants }, 500);
  }

  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } },
  );

  const travail = passage(supabase);
  const differe = enArrierePlan(travail);

  if (!differe) {
    // Pas de `waitUntil` : mieux vaut dépasser le délai de la planification
    // que perdre le travail. Un lot borné y passe de toute façon le plus
    // souvent — et le journal dira lequel des deux chemins a été pris.
    try {
      await travail;
    } catch (erreur) {
      console.error('envoyer-push : passage échoué —', erreur);
    }
  }

  // On accuse réception, on ne rend pas compte : le travail commence à peine.
  // Le compte rendu part dans les journaux de la fonction, à la fin du
  // passage — voir `passage`.
  return json({ accepte: true, lot: LOT, differe }, 202);
});

/**
 * Laisse le travail se poursuivre après la réponse. Renvoie `false` si le
 * runtime ne sait pas le faire — à l'appelant, alors, de l'attendre.
 *
 * Sans `waitUntil`, l'instance serait susceptible d'être arrêtée dès que
 * l'appelant se déconnecte, c'est-à-dire aussitôt puisqu'on répond
 * immédiatement. Le global est propre au runtime Supabase : hors de lui, il
 * n'existe pas, et **rendre la main sans attendre perdrait le passage**.
 */
function enArrierePlan(travail: Promise<unknown>): boolean {
  const runtime = (globalThis as {
    EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void };
  }).EdgeRuntime;

  if (typeof runtime?.waitUntil !== 'function') {
    console.warn(
      'envoyer-push : EdgeRuntime.waitUntil indisponible, passage attendu ' +
        'dans la réponse.',
    );
    return false;
  }

  runtime.waitUntil(travail.catch((erreur) => {
    console.error('envoyer-push : passage interrompu —', erreur);
  }));
  return true;
}

/** Un passage complet : empiler les rappels dus, puis vider un lot. */
async function passage(
  supabase: ReturnType<typeof createClient>,
): Promise<void> {
  const debut = Date.now();

  // Empiler **avant** de lire la file, et non après : un rappel dont l'heure
  // vient d'arriver part dans le même passage, au lieu d'attendre le suivant.
  // C'est ce qui permet de ne planifier qu'une seule chose.
  //
  // L'échec n'interrompt pas : les notifications déjà en attente n'ont pas à
  // subir un défaut du calcul des rappels.
  const { data: rappels, error: erreurRappels } = await supabase.rpc(
    'empiler_rappels',
  );
  if (erreurRappels) {
    console.error('empiler_rappels :', erreurRappels.message);
  }

  const { data, error } = await supabase.rpc('push_a_envoyer', {
    p_limite: LOT,
  });

  if (error) {
    console.error('push_a_envoyer :', error.message);
    return;
  }

  const lignes = (data ?? []) as LigneAEnvoyer[];
  let envoyes = 0;
  let echecs = 0;
  let purges = 0;

  // Les envois sont indépendants : un endpoint mort ne doit pas retarder les
  // autres. `allSettled` plutôt que `all`, pour la même raison.
  const resultats = await Promise.allSettled(
    lignes.map((ligne) => envoyer(supabase, ligne)),
  );

  for (const resultat of resultats) {
    if (resultat.status === 'fulfilled') {
      if (resultat.value === 'envoye') envoyes++;
      else if (resultat.value === 'purge') purges++;
      else echecs++;
    } else {
      echecs++;
    }
  }

  // La planification ne verra plus que l'accusé de réception : c'est ici, et
  // ici seulement, que l'on peut constater ce qu'a fait un passage — et
  // combien de temps il a pris.
  console.log(JSON.stringify({
    rappels: erreurRappels ? null : (rappels ?? 0),
    lues: lignes.length,
    envoyes,
    echecs,
    purges,
    duree_ms: Date.now() - debut,
  }));
}

type Issue = 'envoye' | 'echec' | 'purge';

/**
 * Borne une promesse dans le temps.
 *
 * Le dépassement ne perd rien : `marquer_push_traite` reçoit l'erreur, donc
 * `attempts` avance et la ligne repart au passage suivant — puis est
 * abandonnée après trois échecs, comme n'importe quel autre.
 *
 * La requête sous-jacente n'est pas annulée, et n'a pas à l'être : ce qu'il
 * faut borner, c'est **l'attente**, pas l'envoi. Si le service de
 * notification finit par répondre, tant mieux ; simplement, on ne l'aura pas
 * attendu.
 */
function avecDelai<T>(travail: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resoudre, rejeter) => {
    const minuteur = setTimeout(
      () => rejeter(new Error(`délai de ${ms} ms dépassé`)),
      ms,
    );
    travail.then(resoudre, rejeter).finally(() => clearTimeout(minuteur));
  });
}

async function envoyer(
  supabase: ReturnType<typeof createClient>,
  ligne: LigneAEnvoyer,
): Promise<Issue> {
  // Un abonnement sans clés n'est pas un abonnement Web Push : c'est une
  // ligne ios/android héritée du schéma initial, qu'on laisse tranquille.
  if (ligne.platform !== 'web' || !ligne.p256dh || !ligne.auth_key) {
    await supabase.rpc('marquer_push_traite', {
      p_id: ligne.id,
      p_erreur: `plateforme non gérée : ${ligne.platform}`,
    });
    return 'echec';
  }

  const abonnement = {
    endpoint: ligne.token,
    keys: { p256dh: ligne.p256dh, auth: ligne.auth_key },
  };

  // iOS ignore `image`, `badge` et les boutons d'action : on s'en tient au
  // titre, au corps et à l'icône, qui passent partout.
  const charge = JSON.stringify({
    title: ligne.title,
    body: ligne.body,
    url: ligne.url ?? '/',
    type: ligne.type,
  });

  try {
    // Le délai est **la** borne qui compte : sans lui, un endpoint qui pend
    // retient tout le lot, et la taille du lot n'y peut rien.
    await avecDelai(
      webpush.sendNotification(abonnement, charge, { TTL: 3600 }),
      DELAI_ENVOI_MS,
    );
    await supabase.rpc('marquer_push_traite', { p_id: ligne.id });
    return 'envoye';
  } catch (erreur) {
    const code = (erreur as { statusCode?: number }).statusCode;

    // 404 et 410 : l'abonnement n'existe plus. C'est le cas **courant** sur
    // iOS — retirer l'icône de l'écran d'accueil le détruit sans prévenir
    // personne. Le garder ferait retenter à chaque passage, indéfiniment.
    if (code === 404 || code === 410) {
      await supabase.rpc('purger_push', { p_token: ligne.token });
      await supabase.rpc('marquer_push_traite', {
        p_id: ligne.id,
        p_erreur: `abonnement expiré (${code})`,
      });
      return 'purge';
    }

    await supabase.rpc('marquer_push_traite', {
      p_id: ligne.id,
      p_erreur: `${code ?? '?'} ${(erreur as Error).message ?? ''}`.slice(0, 400),
    });
    return 'echec';
  }
}

function json(corps: unknown, statut = 200): Response {
  return new Response(JSON.stringify(corps), {
    status: statut,
    headers: { 'Content-Type': 'application/json' },
  });
}
