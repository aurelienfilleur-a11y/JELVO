-- ---------------------------------------------------------------------------
-- Tranche 9 — les tâches et les événements entrent dans la conversation
-- ---------------------------------------------------------------------------
-- Une tâche proposée au groupe n'avait aucun endroit où être vue de tous :
-- l'écran d'attribution s'adresse à **un** assigné, et une tâche sans assigné
-- ne s'adressait donc à personne. La conversation est le seul endroit que tout
-- le groupe regarde.
--
-- **Une carte est une ligne de `messages`.** Ce n'est pas un détail
-- d'implémentation, c'est ce qui fait tenir trois exigences d'un coup :
--
--   - elle reste **à sa place chronologique**, sans qu'aucun code n'ait à
--     fusionner deux listes triées ni à faire coïncider deux paginations ;
--   - elle passe par le **temps réel** déjà en place — `messages` est dans la
--     publication `supabase_realtime` depuis la tranche 5a ;
--   - elle compte dans les **non-lus** de la conversation, comme le reste.
--
-- Idempotent : toute la tranche se rejoue sans effet de bord. Elle s'applique
-- **avant** `tranche7_durcissement.sql`, qui referme l'exécution de toute
-- fonction absente de sa liste.


-- ---------------------------------------------------------------------------
-- 1. Ce qu'une carte ajoute à `messages`
-- ---------------------------------------------------------------------------
-- Deux clés étrangères nullables plutôt qu'un couple `type` + `ref_id` : c'est
-- la forme qu'a déjà `invitations`, et elle laisse la base contrôler ce que le
-- code ne contrôlerait pas. Une ligne ordinaire les a toutes deux à `null`.

alter table public.messages
  add column if not exists task_id uuid references public.tasks(id)
    on delete cascade;

alter table public.messages
  add column if not exists event_id uuid references public.events(id)
    on delete cascade;

-- **Ce que cette colonne retient, et qu'aucun état ne dit.**
--
-- Une tâche à un seul assigné se lit de deux façons opposées : « Thomas a pris
-- la tâche » — il s'est proposé, il peut se désister — ou « Tâche attribuée à
-- Thomas » — on la lui a confiée, il répond mais ne se retire pas. Les deux
-- situations sont **identiques** dans `task_assignees` ; seule l'histoire les
-- sépare, et c'est elle qu'on note ici.
--
-- Le drapeau est posé par `prendre_tache` et retiré par `se_desister`. Le nom
-- du preneur, lui, n'est pas recopié : il reste dans `task_assignees`, qui en
-- est la seule source.
alter table public.messages
  add column if not exists tache_prise boolean not null default false;

create index if not exists messages_task_id_idx
  on public.messages (task_id) where task_id is not null;

create index if not exists messages_event_id_idx
  on public.messages (event_id) where event_id is not null;


-- ---------------------------------------------------------------------------
-- 2. La carte se dépose toute seule
-- ---------------------------------------------------------------------------
-- `content` porte le titre, et ce n'est pas décoratif : `messages_check` exige
-- un contenu **ou** un média, et un client qui ne connaîtrait pas les cartes
-- lirait au moins de quoi savoir de quoi il s'agit.
--
-- Comme toute écriture d'agrément, elle ne doit jamais faire échouer celle qui
-- l'a provoquée : une tâche impossible à créer parce que sa carte a été
-- refusée serait un défaut bien plus grave qu'une carte manquante.

create or replace function public.deposer_carte_tache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Une tâche personnelle n'a pas de conversation où se montrer.
  if new.group_id is null or new.deleted_at is not null then
    return new;
  end if;

  insert into public.messages (group_id, sender_id, content, task_id)
  values (new.group_id, new.created_by, new.title, new.id);

  return new;
exception
  when others then
    raise warning 'Carte de tâche impossible : % (%)', sqlerrm, sqlstate;
    return new;
end;
$$;

drop trigger if exists trg_deposer_carte_tache on public.tasks;

create trigger trg_deposer_carte_tache
after insert on public.tasks
for each row execute function public.deposer_carte_tache();


create or replace function public.deposer_carte_evenement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.group_id is null or new.deleted_at is not null then
    return new;
  end if;

  insert into public.messages (group_id, sender_id, content, event_id)
  values (new.group_id, new.owner_id, new.title, new.id);

  return new;
exception
  when others then
    raise warning 'Carte d''événement impossible : % (%)', sqlerrm, sqlstate;
    return new;
end;
$$;

drop trigger if exists trg_deposer_carte_evenement on public.events;

create trigger trg_deposer_carte_evenement
after insert on public.events
for each row execute function public.deposer_carte_evenement();


-- ---------------------------------------------------------------------------
-- 3. Prendre une tâche — et ne pas la prendre à deux
-- ---------------------------------------------------------------------------
-- **C'est le point qui justifie une fonction plutôt qu'une insertion.** Deux
-- personnes qui touchent « Oui » à la même seconde liraient toutes deux une
-- tâche sans assigné, et s'insèreraient toutes deux : la tâche serait prise
-- deux fois, et personne ne saurait par qui.
--
-- Le `for update` sur la ligne de `tasks` sérialise les deux transactions : la
-- seconde attend la première, puis voit l'assigné qu'elle vient de poser et
-- ressort `deja_prise`. Aucun test préalable ne donnerait cette garantie — il
-- se doublerait d'une course entre le test et l'insertion.

create or replace function public.prendre_tache(p_task_id uuid)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  tache public.tasks%rowtype;
begin
  if auth.uid() is null then
    return 'non_connecte';
  end if;

  select * into tache from public.tasks t where t.id = p_task_id for update;

  if not found or tache.deleted_at is not null then
    return 'supprimee';
  end if;
  if tache.group_id is null
     or not public.est_membre_du_groupe(tache.group_id, auth.uid()) then
    return 'non_membre';
  end if;

  -- Le verrou tient : à cet instant, personne d'autre ne peut être en train
  -- d'insérer un assigné pour cette tâche.
  if exists (select 1 from public.task_assignees a
              where a.task_id = p_task_id) then
    return 'deja_prise';
  end if;

  insert into public.task_assignees (task_id, user_id, status)
  values (p_task_id, auth.uid(), 'accepted'::assignee_status);

  update public.messages
     set tache_prise = true
   where task_id = p_task_id;

  return 'prise';
end;
$$;

grant execute on function public.prendre_tache(uuid) to authenticated;


-- Se désister rouvre la tâche : la ligne d'assignation part, le drapeau
-- retombe, et la carte redonne ses deux boutons à tout le monde.
--
-- **Réservé à ce qui a été pris depuis la carte.** Une tâche qu'on vous a
-- confiée se refuse — `repondre_tache` —, elle ne se rend pas : le refus reste
-- visible pour celui qui l'a confiée, la disparition non.
create or replace function public.se_desister(p_task_id uuid)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  tache public.tasks%rowtype;
begin
  if auth.uid() is null then
    return 'non_connecte';
  end if;

  select * into tache from public.tasks t where t.id = p_task_id for update;

  if not found or tache.deleted_at is not null then
    return 'supprimee';
  end if;

  if not exists (select 1 from public.messages m
                  where m.task_id = p_task_id and m.tache_prise) then
    return 'non_desistable';
  end if;

  if not exists (select 1 from public.task_assignees a
                  where a.task_id = p_task_id and a.user_id = auth.uid()) then
    return 'non_assigne';
  end if;

  delete from public.task_assignees a
   where a.task_id = p_task_id and a.user_id = auth.uid();

  update public.messages
     set tache_prise = false
   where task_id = p_task_id;

  return 'desiste';
end;
$$;

grant execute on function public.se_desister(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 4. L'état de la carte voyage avec le message
-- ---------------------------------------------------------------------------
-- Un `jsonb` plutôt qu'une douzaine de colonnes de sortie : la carte d'une
-- tâche et celle d'un événement ne portent pas les mêmes champs, et deux jeux
-- de colonnes dont la moitié est toujours nulle se liraient mal.
--
-- Quatre colonnes de sortie de plus imposent un `drop function` — `create or
-- replace` refuse de changer la signature d'un `returns table`. Même arbitrage
-- qu'en tranche 6 et 8.

drop function if exists public.messages_du_groupe(uuid, timestamptz, integer);

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
  media_duree_s integer,
  created_at timestamptz,
  deleted_at timestamptz,
  pseudo text,
  first_name text,
  last_name text,
  avatar_url text,
  reactions jsonb,
  lu_par integer,
  task_id uuid,
  event_id uuid,
  carte jsonb
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
    case when m.deleted_at is null then m.media_duree_s end,
    m.created_at,
    m.deleted_at,
    p.pseudo,
    p.first_name,
    p.last_name,
    coalesce('preset:' || p.avatar_preset, p.avatar_url),
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
        and lr.last_read_at >= m.created_at),
    m.task_id,
    m.event_id,
    case
      when m.task_id is not null then (
        select jsonb_build_object(
          'sorte',      'tache',
          -- **Supprimée n'est pas introuvable.** Une carte morte ne dirait
          -- rien ; celle-ci dit ce qui est arrivé, et garde son titre.
          'supprimee',  t.deleted_at is not null,
          'titre',      t.title,
          'due_at',     t.due_at,
          'priorite',   t.priority::text,
          'terminee',   t.completed_at is not null,
          'prise',      m.tache_prise,
          'mon_statut', (select a.status::text from public.task_assignees a
                          where a.task_id = t.id and a.user_id = auth.uid()),
          'assignes',   coalesce((
             select jsonb_agg(jsonb_build_object(
                      'user_id', a.user_id,
                      'status',  a.status::text,
                      'nom',     coalesce(public.nom_affiche(a.user_id),
                                          'Un membre'),
                      'avatar_url',
                      coalesce('preset:' || pa.avatar_preset, pa.avatar_url))
                    order by a.user_id)
               from public.task_assignees a
               left join public.profiles pa on pa.id = a.user_id
              where a.task_id = t.id), '[]'::jsonb))
        from public.tasks t where t.id = m.task_id)
      when m.event_id is not null then (
        select jsonb_build_object(
          'sorte',      'evenement',
          'supprimee',  e.deleted_at is not null,
          'titre',      e.title,
          'starts_at',  e.starts_at,
          'ends_at',    e.ends_at,
          'lieu',       e.location,
          'ma_reponse', (select pr.response::text
                           from public.event_participants pr
                          where pr.event_id = e.id
                            and pr.user_id = auth.uid()),
          'oui',        (select count(*)::integer
                           from public.event_participants pr
                          where pr.event_id = e.id and pr.response = 'yes'),
          'peut_etre',  (select count(*)::integer
                           from public.event_participants pr
                          where pr.event_id = e.id and pr.response = 'maybe'),
          'non',        (select count(*)::integer
                           from public.event_participants pr
                          where pr.event_id = e.id and pr.response = 'no'))
        from public.events e where e.id = m.event_id)
    end
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
-- 5. Répondre sur la carte doit se voir chez les autres
-- ---------------------------------------------------------------------------
-- `prendre_tache` et `se_desister` écrivent dans `messages` : le temps réel
-- déjà en place suffit à les propager. Répondre à une tâche nommée ou à un
-- événement, en revanche, ne touche que `task_assignees` ou
-- `event_participants` — et le canal du groupe n'écoute pas ces tables.
--
-- On les ajoute donc à la publication, comme les trois de la tranche 5a. Sans
-- `alter publication`, le client s'abonne, le canal passe à `subscribed`, et
-- **aucun événement n'arrive jamais, sans la moindre erreur**.
--
-- RLS continue de s'appliquer : chacun ne reçoit que ce qu'il a le droit de
-- lire, et le signal ne transporte de toute façon rien d'autre qu'un
-- « relis la fenêtre ».

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'task_assignees'
  ) then
    alter publication supabase_realtime add table public.task_assignees;
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'event_participants'
  ) then
    alter publication supabase_realtime add table public.event_participants;
  end if;
exception
  when undefined_object then
    raise warning 'Publication supabase_realtime absente : cartes non '
                  'rafraîchies en direct.';
  when insufficient_privilege then
    raise warning 'Privilège insuffisant sur supabase_realtime : cartes non '
                  'rafraîchies en direct.';
end;
$$;
