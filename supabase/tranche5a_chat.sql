-- Tranche 5a — chat de groupe et temps réel.
--
-- Appliqué automatiquement au push sur `main` : voir `supabase/migrations.txt`.
-- Idempotent.
--
--
-- LES TROIS TABLES EXISTAIENT DÉJÀ, ET ELLES ONT ÉTÉ VÉRIFIÉES
--
-- `messages`, `message_reactions` et `message_reads` viennent du schéma
-- initial. Rien ici ne les crée. Leurs colonnes et leurs contraintes ont été
-- relevées sur `supabase/schema_actuel.sql`, pas devinées :
--
--   messages           id, group_id, sender_id, content, media_url,
--                      media_kind, created_at, deleted_at
--     CHECK (content is not null or media_url is not null)
--     CHECK (char_length(content) <= 2000)
--
--   message_reactions  message_id, user_id, emoji
--     PRIMARY KEY (message_id, user_id)   ← une réaction par personne
--     CHECK (char_length(emoji) <= 8)
--
--   message_reads      group_id, user_id, last_read_at
--     PRIMARY KEY (group_id, user_id)     ← l'accusé est par CONVERSATION
--
--   media_type         image | video — d'où « pas de documents », verrouillé
--                      par le type et non par une règle d'écran
--
--
-- TROIS CONSÉQUENCES QUI NE SE NÉGOCIENT PAS
--
-- 1. **La PK de `message_reactions` tient déjà la règle** « une réaction par
--    personne et par message ». `reagir_message` n'a donc rien à vérifier :
--    elle fait un `on conflict` sur la clé, et bascule la réaction.
--
-- 2. **`message_reads` ne connaît que `last_read_at` par groupe.** Il n'existe
--    aucun accusé par message dans le schéma. « Lu » se déduit donc :
--    quelqu'un d'autre a lu le message si son `last_read_at` est postérieur à
--    `created_at`. C'est ce que renvoie `lu_par` ci-dessous.
--
-- 3. **`messages` n'a pas de politique DELETE** — seulement `msg_insert`,
--    `msg_select` et `msg_update using (sender_id = auth.uid())`. Supprimer
--    est donc forcément **doux**, par `deleted_at`. Cela tombe bien : c'est ce
--    qu'il faut pour laisser « Message supprimé » à la place.
--
--
-- POURQUOI DES FONCTIONS PLUTÔT QUE DES REQUÊTES DIRECTES
--
-- Même motif qu'aux tranches précédentes : rien ne garantit qu'un membre
-- puisse lire la ligne `profiles` d'un autre. `messages_du_groupe` agrège
-- l'expéditeur, les réactions et l'état de lecture en une seule lecture, comme
-- `mes_taches` et `mon_agenda`.
--
-- S'y ajoute la règle apprise en tranche 3b : **une écriture dont l'effet
-- dépend d'une politique RLS ne se juge pas à l'absence d'erreur.** PostgREST
-- répond 200 sur zéro ligne touchée. `supprimer_message` renvoie donc un
-- booléen, et non rien du tout.


-- ---------------------------------------------------------------------------
-- 1. Le temps réel doit être autorisé table par table
-- ---------------------------------------------------------------------------
-- Sans cette publication, `postgres_changes` ne reçoit rien — et **sans la
-- moindre erreur** : le client s'abonne, le canal passe à `subscribed`, et
-- aucun événement n'arrive jamais. C'est le genre de panne muette qui coûte
-- une soirée.
--
-- RLS continue de s'appliquer : Supabase n'envoie à chacun que les lignes que
-- sa politique `msg_select` lui laisse voir.
--
-- En rejeu local, `create publication` émet « wal_level is insufficient to
-- publish logical changes ». C'est attendu et sans portée : la base jetable de
-- `rejouer.sh` n'est pas configurée pour la réplication logique, alors que
-- celle de Supabase l'est. La publication se crée quand même.

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['messages', 'message_reactions', 'message_reads']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
      raise notice 'Realtime activé sur public.%', t;
    end if;
  end loop;
end;
$$;

-- `postgres_changes` ne transporte par défaut que la clé primaire dans les
-- `old_record` d'un update. Pour qu'une suppression douce parvienne au client
-- avec de quoi retrouver la ligne, on demande l'image complète.
alter table public.messages replica identity full;


-- ---------------------------------------------------------------------------
-- 2. Lire la conversation d'un groupe
-- ---------------------------------------------------------------------------
-- Pagination par curseur (`p_avant`) et non par `offset` : dans une
-- conversation qui s'allonge pendant qu'on la remonte, un `offset` saute ou
-- répète des lignes.
--
-- Renvoie les plus récents d'abord ; l'écran affiche en liste inversée.

create or replace function public.messages_du_groupe(
  p_group_id uuid,
  p_avant timestamptz default null,
  p_limite integer default 50
)
returns table (
  id uuid,
  group_id uuid,
  sender_id uuid,
  content text,
  media_url text,
  media_kind text,
  created_at timestamptz,
  deleted_at timestamptz,
  pseudo text,
  first_name text,
  last_name text,
  avatar_url text,
  reactions jsonb,
  lu_par integer
)
language sql
security definer
set search_path = public
as $$
  select
    m.id,
    m.group_id,
    m.sender_id,
    -- Un message supprimé ne renvoie plus rien de son contenu. Le masquer à
    -- l'écran seulement le laisserait dans la réponse réseau, donc lisible.
    case when m.deleted_at is null then m.content end,
    case when m.deleted_at is null then m.media_url end,
    case when m.deleted_at is null then m.media_kind::text end,
    m.created_at,
    m.deleted_at,
    p.pseudo,
    p.first_name,
    p.last_name,
    p.avatar_url,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
                'user_id', r.user_id, 'emoji', r.emoji) order by r.emoji)
         from public.message_reactions r
        where r.message_id = m.id),
      '[]'::jsonb),
    -- « Lu » se déduit de `last_read_at`, seule chose que le schéma stocke.
    -- L'expéditeur ne se compte pas lui-même : il a évidemment lu.
    (select count(*)::integer
       from public.message_reads lr
      where lr.group_id = m.group_id
        and lr.user_id <> m.sender_id
        and lr.last_read_at >= m.created_at)
  from public.messages m
  join public.profiles p on p.id = m.sender_id
  where m.group_id = p_group_id
    and public.est_membre_du_groupe(p_group_id, auth.uid())
    and (p_avant is null or m.created_at < p_avant)
  order by m.created_at desc
  limit least(coalesce(p_limite, 50), 200);
$$;

grant execute on function public.messages_du_groupe(uuid, timestamptz, integer)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Envoyer
-- ---------------------------------------------------------------------------
-- La contrainte `messages_check` exige un contenu **ou** un média. On le
-- vérifie ici pour rendre un message français plutôt qu'un `23514` brut.

create or replace function public.envoyer_message(
  p_group_id uuid,
  p_content text default null,
  p_media_url text default null,
  p_media_kind text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  utilisateur uuid := auth.uid();
  texte text := nullif(btrim(coalesce(p_content, '')), '');
  nouveau uuid;
begin
  if utilisateur is null then
    raise exception 'non_authentifie';
  end if;

  if not public.est_membre_du_groupe(p_group_id, utilisateur) then
    raise exception 'non_membre';
  end if;

  if texte is null and p_media_url is null then
    raise exception 'message_vide';
  end if;

  if char_length(texte) > 2000 then
    raise exception 'message_trop_long';
  end if;

  insert into public.messages (
    group_id, sender_id, content, media_url, media_kind)
  values (
    p_group_id, utilisateur, texte, p_media_url,
    -- Conversion explicite : un littéral seul est `unknown` et se laisserait
    -- convertir, mais dès qu'il entre dans une expression la résolution donne
    -- du `text`, et il n'existe pas de conversion implicite vers un énuméré.
    -- C'est le défaut qui a bloqué toute la tranche 3.
    (case when p_media_url is null then null
          else coalesce(p_media_kind, 'image') end)::public.media_type)
  returning id into nouveau;

  -- Envoyer, c'est avoir lu : sans cela le compteur de non-lus de
  -- l'expéditeur s'allumerait sur son propre message.
  insert into public.message_reads (group_id, user_id, last_read_at)
  values (p_group_id, utilisateur, now())
  on conflict (group_id, user_id)
    do update set last_read_at = excluded.last_read_at;

  return nouveau;
end;
$$;

grant execute on function public.envoyer_message(uuid, text, text, text)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Supprimer son propre message — en douceur
-- ---------------------------------------------------------------------------
-- Renvoie un booléen, et c'est lui qui fait foi : `messages` n'a pas de
-- politique DELETE, et une écriture qui ne touche aucune ligne se solde par un
-- 200 côté PostgREST. Sans ce retour, l'écran annoncerait une suppression qui
-- n'a pas eu lieu.

create or replace function public.supprimer_message(p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  utilisateur uuid := auth.uid();
begin
  -- `content` passe à la chaîne vide, et non à `null` : `messages_check`
  -- exige un contenu **ou** un média, si bien qu'une ligne où les deux sont
  -- nuls est refusée en `23514`. La contrainte dicte donc la forme de la
  -- suppression douce ; ce n'est pas une préférence.
  --
  -- Le contenu part quand même : `messages_du_groupe` ne renvoie plus rien
  -- pour une ligne supprimée, et il ne reste ici aucune trace du texte.
  update public.messages
     set deleted_at = now(),
         content = '',
         media_url = null,
         media_kind = null
   where id = p_message_id
     and sender_id = utilisateur
     and deleted_at is null;

  if not found then
    return false;
  end if;

  -- Les réactions d'un message supprimé n'ont plus d'objet.
  delete from public.message_reactions where message_id = p_message_id;
  return true;
end;
$$;

grant execute on function public.supprimer_message(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Réagir
-- ---------------------------------------------------------------------------
-- La clé primaire `(message_id, user_id)` tient la règle « une réaction par
-- personne et par message » : il n'y a rien à vérifier, seulement à basculer.
-- Renvoie l'emoji retenu, ou `null` si la réaction a été retirée.

create or replace function public.reagir_message(
  p_message_id uuid,
  p_emoji text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  utilisateur uuid := auth.uid();
  groupe uuid;
  actuel text;
begin
  select m.group_id into groupe
    from public.messages m
   where m.id = p_message_id and m.deleted_at is null;

  if groupe is null then
    return null;
  end if;

  if not public.est_membre_du_groupe(groupe, utilisateur) then
    raise exception 'non_membre';
  end if;

  select r.emoji into actuel
    from public.message_reactions r
   where r.message_id = p_message_id and r.user_id = utilisateur;

  -- Retirer : soit on ne passe rien, soit on repose le même emoji.
  if p_emoji is null or actuel = p_emoji then
    delete from public.message_reactions
     where message_id = p_message_id and user_id = utilisateur;
    return null;
  end if;

  if char_length(p_emoji) > 8 then
    raise exception 'emoji_trop_long';
  end if;

  insert into public.message_reactions (message_id, user_id, emoji)
  values (p_message_id, utilisateur, p_emoji)
  on conflict (message_id, user_id)
    do update set emoji = excluded.emoji;

  return p_emoji;
end;
$$;

grant execute on function public.reagir_message(uuid, text) to authenticated;


-- ---------------------------------------------------------------------------
-- 6. Marquer la conversation comme lue
-- ---------------------------------------------------------------------------
-- `last_read_at` n'avance jamais en arrière : ouvrir une vieille conversation
-- ne doit pas « dé-lire » ce qui l'était déjà.

create or replace function public.marquer_lu(
  p_group_id uuid,
  p_jusqua timestamptz default null
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  utilisateur uuid := auth.uid();
  instant timestamptz := coalesce(p_jusqua, now());
  retenu timestamptz;
begin
  if not public.est_membre_du_groupe(p_group_id, utilisateur) then
    raise exception 'non_membre';
  end if;

  insert into public.message_reads (group_id, user_id, last_read_at)
  values (p_group_id, utilisateur, instant)
  on conflict (group_id, user_id)
    do update set last_read_at = greatest(
      public.message_reads.last_read_at, excluded.last_read_at)
  returning last_read_at into retenu;

  return retenu;
end;
$$;

grant execute on function public.marquer_lu(uuid, timestamptz) to authenticated;


-- ---------------------------------------------------------------------------
-- 7. Non-lus par groupe
-- ---------------------------------------------------------------------------
-- Alimente la pastille de l'écran des groupes. Un groupe jamais ouvert n'a pas
-- de ligne dans `message_reads` : le `coalesce` sur une date lointaine compte
-- alors tout, ce qui est le comportement attendu.

create or replace function public.messages_non_lus()
returns table (group_id uuid, non_lus integer, dernier timestamptz)
language sql
security definer
set search_path = public
as $$
  select
    g.group_id,
    count(*) filter (
      where m.created_at > coalesce(lr.last_read_at, 'epoch'::timestamptz)
    )::integer,
    max(m.created_at)
  from public.group_members g
  join public.messages m
    on m.group_id = g.group_id
   and m.deleted_at is null
   and m.sender_id <> g.user_id
  left join public.message_reads lr
    on lr.group_id = g.group_id and lr.user_id = g.user_id
  where g.user_id = auth.uid()
    and (g.expires_at is null or g.expires_at > now())
  group by g.group_id;
$$;

grant execute on function public.messages_non_lus() to authenticated;
