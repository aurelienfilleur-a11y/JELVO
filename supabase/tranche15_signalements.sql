-- ===========================================================================
-- Tranche 15 — Signaler un abus
-- ===========================================================================
--
-- Obligation légale : depuis un message, un groupe ou un profil, pouvoir
-- signaler un contenu ou un comportement. Le signalement doit arriver quelque
-- part où il se traite — et permettre de **voir le contexte et d'agir**, pas
-- seulement de recevoir une alerte.
--
-- ---------------------------------------------------------------------------
-- Une table consultable dans l'application, et non un envoi d'e-mail
-- ---------------------------------------------------------------------------
--
-- Un e-mail aurait demandé une adresse dédiée, un service d'envoi et une
-- clé de plus dans les secrets — et il n'aurait porté qu'une alerte : le
-- contenu signalé n'y serait pas, et il ne s'y traiterait pas. Une table
-- lue par un écran de modération fait les deux, sans dépendance nouvelle.
--
-- ---------------------------------------------------------------------------
-- La table n'est pas exposée du tout, et c'est ce qui rend la règle
-- incontournable
-- ---------------------------------------------------------------------------
--
-- La demande est explicite : l'écran de modération ne doit être visible que
-- de son propriétaire, « sans que ce soit contournable ». Une politique RLS
-- qui vérifierait le lecteur serait déjà correcte, mais elle laisserait la
-- table **atteignable** par PostgREST : il suffirait d'une politique de trop
-- posée à côté — ce qui est précisément arrivé au stockage, voir « Le
-- durcissement du stockage était sans effet » — pour que la règle tombe, les
-- politiques s'additionnant en « ou ».
--
-- `signalements` ne reçoit donc **aucune politique**, et son privilège est
-- retiré à `anon` et `authenticated`. La table est invisible de l'API : les
-- trois fonctions ci-dessous sont la seule porte, et chacune porte sa règle.
-- C'est la règle de la tranche 7, appliquée dès la création plutôt qu'après
-- coup : « une nouvelle table écrite par une fonction ne reçoit pas de
-- politique d'écriture ».
--
-- ---------------------------------------------------------------------------
-- Qui est modérateur se dit une fois, et ne se devine pas
-- ---------------------------------------------------------------------------
--
-- `moderateurs` est une table **vide à la création**, sans politique et sans
-- privilège : personne ne peut s'y inscrire, pas même en connaissant son
-- propre identifiant. Seul `postgres` écrit dedans, donc seul l'éditeur SQL
-- du projet — ou une migration.
--
-- Elle est vide exprès, et le dépôt ne porte ni l'adresse ni l'identifiant du
-- propriétaire : **le dépôt est public.** La désignation est donc une ligne à
-- passer une fois, prête à copier dans `supabase/designer_moderateur.sql`.
-- Tant qu'elle n'est pas passée, personne n'est modérateur, l'écran n'est
-- atteignable par personne et les trois fonctions de lecture ne rendent rien
-- — l'état sûr par défaut.
--
-- Un secret GitHub aurait pu la semer automatiquement. Écarté : le workflow
-- des migrations ne tourne que sur un push touchant `supabase/`, si bien que
-- poser le secret n'aurait rien déclenché, et la panne aurait été muette — on
-- aurait cherché du côté de la fonction plutôt que du côté du déclencheur.
--
-- ---------------------------------------------------------------------------
-- Le contenu signalé est recopié, et il faut le dire
-- ---------------------------------------------------------------------------
--
-- `contexte` garde le texte du message au moment du signalement. Ce n'est pas
-- du confort : sans lui, le signalement serait l'alerte sans le contexte,
-- écartée en toutes lettres par la consigne. Deux raisons, et chacune suffit.
--
--   1. **Celui qu'on signale est précisément celui qui veut effacer.**
--      `supprimer_message` vide `content` — la preuve disparaîtrait avec un
--      geste que son auteur peut faire à tout moment.
--   2. **Le modérateur n'est pas membre du groupe.** `msg_select` ne lui
--      laisserait rien lire, et lui ouvrir les conversations du service pour
--      qu'il puisse juger un message serait payer bien trop cher.
--
-- La recopie se borne au message signalé. **Les messages voisins n'y entrent
-- pas** : ils sont d'auteurs tiers que personne n'a signalés, et les recopier
-- mettrait leurs propos dans un dossier de modération sans qu'ils y soient
-- pour rien.
--
-- Côté suppression de compte, le contenu recopié suit la règle déjà posée en
-- tranche 14 : **le contenu reste, l'identité part.** C'est le même arbitrage
-- que pour les messages eux-mêmes, et non une exception.


-- ---------------------------------------------------------------------------
-- 1. Les types
-- ---------------------------------------------------------------------------
-- Des types énumérés plutôt que du texte libre : c'est la forme du schéma
-- initial pour tout ce qui discrimine — `invitation_type`, `media_type` —, et
-- elle refuse en base une valeur que l'application n'écrirait pas.
--
-- `create type` n'accepte pas `if not exists` : le bloc le fait.

do $$
begin
  if not exists (
    select 1 from pg_type t
      join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'public' and t.typname = 'signalement_cible'
  ) then
    create type public.signalement_cible as enum ('message', 'group', 'profile');
  end if;

  if not exists (
    select 1 from pg_type t
      join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'public' and t.typname = 'signalement_motif'
  ) then
    create type public.signalement_motif as enum (
      'spam', 'harcelement', 'haine', 'sexuel', 'violence', 'autre'
    );
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 2. Les modérateurs
-- ---------------------------------------------------------------------------

create table if not exists public.moderateurs (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  ajoute_le  timestamptz not null default now()
);

alter table public.moderateurs enable row level security;

-- Aucune politique, et le privilège retiré : la table est hors de portée de
-- l'API. Un `revoke` est idempotent, il n'a pas besoin de garde.
revoke all on public.moderateurs from anon, authenticated;

comment on table public.moderateurs is
  'Qui peut lire les signalements. Vide à la création : la désignation se '
  'fait une fois, hors du dépôt, qui est public. Voir '
  'supabase/designer_moderateur.sql.';

-- `stable` et non `volatile` : l'appartenance ne change pas pendant une
-- requête, et le planificateur peut donc n'appeler la fonction qu'une fois.
create or replace function public.est_moderateur()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.moderateurs m where m.user_id = auth.uid()
  );
$$;

comment on function public.est_moderateur() is
  'Vrai si l''appelant peut lire les signalements. Lue par l''application '
  'pour savoir si la ligne de modération a lieu d''être, et par les trois '
  'fonctions de signalement, qui ne s''en remettent pas à l''écran.';


-- ---------------------------------------------------------------------------
-- 3. La table des signalements
-- ---------------------------------------------------------------------------
--
-- Une seule table pour les trois cibles, comme `invitations` en porte trois
-- sortes : `cible_type` discrimine, et une seule des trois clés est
-- renseignée. C'est la forme que le schéma initial a déjà choisie pour le même
-- besoin, et la reprendre évite trois tables à tenir d'accord.
--
-- Les trois clés sont `on delete set null` et non `cascade` : un groupe
-- supprimé ou un message effacé ne doit pas emporter le signalement qui le
-- concerne — ce serait l'effacement de la trace par le geste signalé.

create table if not exists public.signalements (
  id            uuid primary key default gen_random_uuid(),

  -- `null` après la suppression du compte de celui qui a signalé : le
  -- signalement survit, son auteur devient anonyme. Garder le lien
  -- conserverait ce que la tranche 14 promet d'effacer ; supprimer la ligne
  -- laisserait effacer un signalement en fermant son compte.
  auteur_id     uuid references public.profiles(id) on delete set null,

  cible_type    public.signalement_cible not null,
  message_id    uuid references public.messages(id) on delete set null,
  group_id      uuid references public.groups(id) on delete set null,
  profil_id     uuid references public.profiles(id) on delete set null,

  motif         public.signalement_motif not null,
  commentaire   text,

  -- Ce qu'il y avait à voir au moment du signalement. Voir l'en-tête.
  contexte      jsonb not null default '{}'::jsonb,

  cree_le       timestamptz not null default now(),
  traite_le     timestamptz,
  traite_par    uuid references public.profiles(id) on delete set null,
  note          text,

  -- **La contrainte interdit, elle n'exige pas**, et c'est délibéré : les
  -- trois clés sont `on delete set null`, si bien qu'une contrainte exigeant
  -- la présence de l'une d'elles serait réévaluée à la mise à `null` et
  -- **refuserait la suppression** de l'objet visé. Ce qui garantit la
  -- présence de la bonne clé, c'est que `signaler` est le seul écrivain
  -- possible — la table n'a aucun privilège —, et c'est une garantie plus
  -- forte qu'un `check`.
  --
  -- Un signalement de message porte **aussi** `profil_id`, l'auteur du
  -- message : sans lui, la modération lirait un identifiant brut dans la
  -- recopie, et deux signalements visant la même personne — l'un sur son
  -- message, l'autre sur son profil — ne se rapprocheraient pas.
  constraint signalements_cible_coherente check (
    case cible_type
      when 'message' then true
      when 'group'   then message_id is null and profil_id is null
      when 'profile' then message_id is null and group_id is null
    end
  ),

  constraint signalements_commentaire_borne check (
    commentaire is null or length(commentaire) <= 2000
  )
);

alter table public.signalements enable row level security;

revoke all on public.signalements from anon, authenticated;

comment on table public.signalements is
  'Signalements d''abus. Aucune politique et aucun privilège : la table est '
  'invisible de PostgREST, et les trois fonctions sont la seule porte.';

-- Un signalement de message porte le groupe aussi, pour que la modération
-- sache de quelle conversation il vient sans relire `messages`.
comment on column public.signalements.group_id is
  'Le groupe visé, ou celui du message visé.';

create index if not exists signalements_a_traiter_idx
  on public.signalements (cree_le desc)
  where traite_le is null;


-- ---------------------------------------------------------------------------
-- 4. Signaler
-- ---------------------------------------------------------------------------
--
-- Un mot d'état plutôt qu'un `void`, comme `prendre_tache` : « déjà signalé »
-- n'est pas une panne, c'est la réponse à la question, et l'écran doit
-- pouvoir le dire au lieu de laisser croire à un second envoi.

create or replace function public.signaler(
  p_cible_type  text,
  p_cible_id    uuid,
  p_motif       text,
  p_commentaire text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  utilisateur uuid := auth.uid();
  cible       public.signalement_cible;
  motif       public.signalement_motif;
  msg         record;
  grp         record;
  prof        record;
  contexte    jsonb := '{}'::jsonb;
  groupe      uuid;
  vise        uuid;
begin
  if utilisateur is null then
    return 'non_connecte';
  end if;

  -- Une valeur hors énumération ne doit pas lever : l'écran n'enverra que les
  -- siennes, mais un appel direct ne doit pas obtenir une erreur Postgres
  -- brute là où un mot d'état dit la même chose.
  begin
    cible := p_cible_type::public.signalement_cible;
    motif := p_motif::public.signalement_motif;
  exception
    when invalid_text_representation then return 'motif_inconnu';
  end;

  if cible = 'message' then
    select m.id, m.group_id, m.sender_id, m.content, m.media_kind,
           m.media_duree_s, m.created_at, m.deleted_at
      into msg
      from public.messages m
     where m.id = p_cible_id;

    if msg.id is null then
      return 'introuvable';
    end if;

    -- **On ne signale que ce qu'on peut voir.** Sans ce contrôle, n'importe
    -- qui pourrait déposer un signalement sur n'importe quel identifiant de
    -- message et en obtenir le texte par ricochet — la recopie du contexte
    -- deviendrait un oracle de lecture sur toutes les conversations.
    if not public.is_group_member(msg.group_id) then
      return 'non_membre';
    end if;

    groupe := msg.group_id;
    vise := msg.sender_id;

    -- Recopié parce que l'auteur peut l'effacer, et parce que le modérateur
    -- n'est pas membre du groupe. Les voisins n'y entrent pas.
    contexte := jsonb_build_object(
      'contenu', msg.content,
      'media_kind', msg.media_kind,
      'media_duree_s', msg.media_duree_s,
      'ecrit_le', msg.created_at,
      'deja_supprime', msg.deleted_at is not null,
      'auteur_id', msg.sender_id,
      'groupe_nom', (select g.name from public.groups g where g.id = groupe)
    );

  elsif cible = 'group' then
    select g.id, g.name, g.description, g.created_by
      into grp
      from public.groups g
     where g.id = p_cible_id and g.deleted_at is null;

    if grp.id is null then
      return 'introuvable';
    end if;

    -- Même règle : on signale un groupe dont on est membre. Un groupe est
    -- invisible aux autres de toute façon — `groups_select` exige
    -- l'appartenance —, donc un étranger n'aurait rien à signaler.
    if not public.is_group_member(grp.id) then
      return 'non_membre';
    end if;

    groupe := grp.id;
    contexte := jsonb_build_object(
      'groupe_nom', grp.name,
      'groupe_description', grp.description,
      'cree_par', grp.created_by
    );

  else
    select p.id, p.pseudo, p.first_name, p.last_name, p.bio, p.supprime_le
      into prof
      from public.profiles p
     where p.id = p_cible_id;

    if prof.id is null or prof.supprime_le is not null then
      return 'introuvable';
    end if;

    -- Se signaler soi-même n'a pas de sens, et encombrerait la file.
    if prof.id = utilisateur then
      return 'soi_meme';
    end if;

    vise := prof.id;
    contexte := jsonb_build_object(
      'pseudo', prof.pseudo,
      'nom', public.nom_affiche(prof.id),
      'bio', prof.bio
    );
  end if;

  -- **Deux signalements identiques non traités n'apprennent rien de plus.**
  -- Le contrôle est ici et non dans une contrainte d'unicité : la règle porte
  -- sur « non encore traité », qu'un index unique partiel dirait mal — et le
  -- second signalement du même geste, après traitement, est légitime.
  if exists (
    select 1 from public.signalements s
     where s.auteur_id = utilisateur
       and s.cible_type = cible
       and s.traite_le is null
       and (s.message_id = p_cible_id
            or s.group_id = p_cible_id
            or s.profil_id = p_cible_id)
  ) then
    return 'deja_signale';
  end if;

  insert into public.signalements (
    auteur_id, cible_type, message_id, group_id, profil_id,
    motif, commentaire, contexte
  )
  values (
    utilisateur,
    cible,
    case when cible = 'message' then p_cible_id end,
    groupe,
    -- `vise` porte l'auteur du message pour un signalement de message, la
    -- personne pour un signalement de profil, et rien pour un groupe.
    vise,
    motif,
    nullif(btrim(coalesce(p_commentaire, '')), ''),
    contexte
  );

  return 'signale';
end;
$$;

comment on function public.signaler(text, uuid, text, text) is
  'Dépose un signalement et renvoie un mot d''état. Recopie le contenu visé : '
  'celui qu''on signale est celui qui veut l''effacer.';


-- ---------------------------------------------------------------------------
-- 5. Lire la file — modérateurs seulement
-- ---------------------------------------------------------------------------
--
-- Zéro ligne pour qui n'est pas modérateur, et non une erreur : un appel
-- direct avec un identifiant arbitraire obtient exactement ce qu'obtient un
-- écran vide, et n'apprend donc pas qu'il y avait quelque chose à voir.
--
-- `traites` dit lequel des deux onglets on lit. Le défaut est la file à
-- traiter : c'est ce qu'on ouvre l'écran pour voir.

create or replace function public.signalements_a_traiter(
  p_traites boolean default false
)
returns table (
  id              uuid,
  cible_type      text,
  motif           text,
  commentaire     text,
  contexte        jsonb,
  cree_le         timestamptz,
  traite_le       timestamptz,
  note            text,
  message_id      uuid,
  group_id        uuid,
  profil_id       uuid,
  -- Les profils sont joints ici plutôt que relus côté client : `profiles` est
  -- fermé aux étrangers depuis la tranche 7, et le modérateur n'a aucun lien
  -- social avec les gens qu'il modère. C'est la raison d'être de toutes les
  -- lectures `security definer` de ce projet.
  auteur_nom      text,
  auteur_avatar   text,
  vise_nom        text,
  vise_avatar     text,
  groupe_nom      text,
  -- L'état réel de la cible, à côté de la recopie : c'est l'écart entre les
  -- deux qui dit « le message a été effacé depuis ».
  message_efface  boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id,
         s.cible_type::text,
         s.motif::text,
         s.commentaire,
         s.contexte,
         s.cree_le,
         s.traite_le,
         s.note,
         s.message_id,
         s.group_id,
         s.profil_id,
         public.nom_affiche(s.auteur_id),
         coalesce('preset:' || pa.avatar_preset, pa.avatar_url),
         public.nom_affiche(s.profil_id),
         coalesce('preset:' || pv.avatar_preset, pv.avatar_url),
         coalesce(g.name, s.contexte ->> 'groupe_nom'),
         case when s.cible_type = 'message'
              then m.id is null or m.deleted_at is not null
         end
    from public.signalements s
    left join public.profiles pa on pa.id = s.auteur_id
                                and pa.supprime_le is null
    left join public.profiles pv on pv.id = s.profil_id
                                and pv.supprime_le is null
    left join public.groups g on g.id = s.group_id
    left join public.messages m on m.id = s.message_id
   where public.est_moderateur()
     and (s.traite_le is not null) = coalesce(p_traites, false)
   order by s.cree_le desc
   limit 200;
$$;

comment on function public.signalements_a_traiter(boolean) is
  'La file de modération. Zéro ligne pour qui n''est pas modérateur, et non '
  'une erreur : un appel direct n''apprend pas qu''il y avait à voir.';


-- ---------------------------------------------------------------------------
-- 6. Traiter
-- ---------------------------------------------------------------------------
--
-- « Marquer traité pour ne pas le revoir » est la demande, et c'est
-- `traite_le` qui la porte : la lecture par défaut ne rend que les lignes où
-- il est nul. Pas de colonne « vu », pas de table de suivi — le même parti
-- que la suppression de la ligne d'adhésion en tranche 6, qui *est* la
-- mémoire.
--
-- Rouvrir est possible — `p_traite` à faux —, parce qu'un traitement posé par
-- erreur n'aurait sinon aucun recours.

create or replace function public.traiter_signalement(
  p_signalement_id uuid,
  p_note           text default null,
  p_traite         boolean default true
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  utilisateur uuid := auth.uid();
  touche      bigint;
begin
  if not public.est_moderateur() then
    return 'non_moderateur';
  end if;

  update public.signalements s
     set traite_le = case when coalesce(p_traite, true) then now() end,
         traite_par = case when coalesce(p_traite, true) then utilisateur end,
         note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), s.note)
   where s.id = p_signalement_id;

  get diagnostics touche = row_count;
  if touche = 0 then
    return 'introuvable';
  end if;

  return case when coalesce(p_traite, true) then 'traite' else 'rouvert' end;
end;
$$;

comment on function public.traiter_signalement(uuid, text, boolean) is
  'Marque un signalement traité, avec une note facultative. Rouvrable : un '
  'traitement posé par erreur doit avoir un recours.';


-- ---------------------------------------------------------------------------
-- 7. Agir sur le message signalé
-- ---------------------------------------------------------------------------
--
-- C'est la seconde moitié de la consigne — « voir le contexte **et agir** ».
-- Sans elle, l'écran serait la liste d'alertes qu'elle écarte : le modérateur
-- n'est pas membre du groupe, et `supprimer_message` n'obéit qu'à l'auteur du
-- message.
--
-- La suppression est **douce**, comme partout : `messages` n'a pas de
-- politique DELETE, `content` passe à la chaîne vide et non à `null` —
-- `messages_check` exige un contenu ou un média —, et la bulle se referme en
-- « message supprimé » chez tout le monde. La recopie du signalement garde,
-- elle, ce qui a été écrit : c'est le dossier, pas la conversation.
--
-- **Un message seulement.** Supprimer un groupe ou fermer un compte depuis cet
-- écran n'est pas livré : ce sont des décisions dont la portée dépasse ce
-- qu'une migration peut trancher, et pour un groupe ou un profil la note et
-- le blocage — tranche 16 — sont les leviers.

create or replace function public.supprimer_message_signale(
  p_signalement_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  vise uuid;
begin
  if not public.est_moderateur() then
    return 'non_moderateur';
  end if;

  select s.message_id into vise
    from public.signalements s
   where s.id = p_signalement_id and s.cible_type = 'message';

  if vise is null then
    return 'introuvable';
  end if;

  update public.messages m
     set deleted_at = now(),
         content = '',
         media_url = null,
         media_kind = null,
         media_duree_s = null
   where m.id = vise and m.deleted_at is null;

  if not found then
    return 'deja_supprime';
  end if;

  return 'supprime';
end;
$$;

comment on function public.supprimer_message_signale(uuid) is
  'Suppression douce d''un message signalé, par un modérateur. Le fichier du '
  'média reste dans le bucket : seule l''API Storage l''efface.';


-- ---------------------------------------------------------------------------
-- 8. Les privilèges
-- ---------------------------------------------------------------------------
-- La tranche 7 referme toute fonction absente de sa liste, et elle ne se
-- rejoue que si son propre contenu change : les `grant` sont donc reposés ici.

grant execute on function public.est_moderateur() to authenticated;
grant execute on function public.signaler(text, uuid, text, text)
  to authenticated;
grant execute on function public.signalements_a_traiter(boolean)
  to authenticated;
grant execute on function public.traiter_signalement(uuid, text, boolean)
  to authenticated;
grant execute on function public.supprimer_message_signale(uuid)
  to authenticated;
