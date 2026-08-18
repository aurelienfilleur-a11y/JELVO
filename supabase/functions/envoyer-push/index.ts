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

import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? '';
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? '';
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:contact@jelvo.app';

/** Combien de lignes au plus par passage. */
const LOT = 100;

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

Deno.serve(async (requete: Request): Promise<Response> => {
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    // Message explicite plutôt qu'un échec obscur : c'est l'oubli le plus
    // probable à la première mise en service.
    return json(
      {
        erreur: 'vapid_absent',
        message:
          'VAPID_PUBLIC_KEY et VAPID_PRIVATE_KEY ne sont pas configurés. ' +
          'Voir l’en-tête de supabase/functions/envoyer-push/index.ts.',
      },
      500,
    );
  }

  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } },
  );

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
    return json({ erreur: 'lecture', message: error.message }, 500);
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

  return json({
    rappels: erreurRappels ? null : (rappels ?? 0),
    lues: lignes.length,
    envoyes,
    echecs,
    purges,
  });
});

type Issue = 'envoye' | 'echec' | 'purge';

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
    await webpush.sendNotification(abonnement, charge, { TTL: 3600 });
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
