-- Tranche 3 — tâches et événements.
--
-- À exécuter dans l'éditeur SQL du projet Supabase, en une fois, après les
-- scripts des tranches précédentes. Idempotent.
--
--
-- SCHÉMA RÉEL, VÉRIFIÉ AVANT ÉCRITURE
--
--   tasks              id, group_id, created_by, title, description, due_at,
--                      priority, reminder_at, rrule, completed_at, created_at,
--                      deleted_at
--   task_assignees     task_id, user_id, status          (pas de colonne id)
--   task_list_items    id, task_id, label, position, checked_at, checked_by,
--                      created_at
--   events             id, group_id, owner_id, title, description, starts_at,
--                      ends_at, location, rrule, image_url, reminder_minutes,
--                      created_at, deleted_at
--   event_participants event_id, user_id, response, responded_at
--                                                        (pas de colonne id)
--
--   task_priority      low | medium | high
--   assignee_status    pending | accepted | declined | done
--   event_response     yes | no | maybe | pending
--
-- `tasks` porte `reminder_at` (un instant) et `events` `reminder_minutes` (un
-- délai avant le début). L'asymétrie vient du schéma initial ; l'application
-- s'y plie.
--
--
-- POURQUOI DES FONCTIONS PLUTÔT QUE DES REQUÊTES DIRECTES
--
-- Trois raisons, chacune suffisante :
--
--   1. `insert(...).select()` repasse par la politique SELECT. Sur `groups`,
--      cela avait coûté un 42501 (voir correctif_creation_groupe.sql). Une
--      fonction `security definer` renvoie la ligne sans dépendre de la forme
--      exacte de la politique — inconnue de l'application.
--   2. Rien ne garantit qu'un membre puisse lire la ligne `profiles` d'un
--      autre. Les listes d'assignés et de participants passent donc par des
--      fonctions, comme `membres_du_groupe` en tranche 2.
--   3. `task_assignees` et `event_participants` n'ont **pas de politique
--      DELETE**. Modifier la liste des assignés ou des participants est donc
--      impossible depuis le client : il faut une fonction.


-- ---------------------------------------------------------------------------
-- 1. Accès à une tâche et à un événement
-- ---------------------------------------------------------------------------
-- Prédicats réutilisés par les fonctions ci-dessous. Un événement personnel
-- n'a pas de groupe : son propriétaire seul y accède.

create or replace function public.peut_voir_tache(p_task_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.tasks t
    where t.id = p_task_id
      and t.deleted_at is null
      and (
        t.created_by = auth.uid()
        or (t.group_id is not null
            and public.est_membre_du_groupe(t.group_id, auth.uid()))
        or exists (
          select 1 from public.task_assignees a
          where a.task_id = t.id and a.user_id = auth.uid()
        )
      )
  );
$$;

create or replace function public.peut_voir_evenement(p_event_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.events e
    where e.id = p_event_id
      and e.deleted_at is null
      and (
        e.owner_id = auth.uid()
        or (e.group_id is not null
            and public.est_membre_du_groupe(e.group_id, auth.uid()))
        or exists (
          select 1 from public.event_participants p
          where p.event_id = e.id and p.user_id = auth.uid()
        )
      )
  );
$$;

grant execute on function public.peut_voir_tache(uuid) to authenticated;
grant execute on function public.peut_voir_evenement(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 2. Créer une tâche
-- ---------------------------------------------------------------------------
-- Tâche, assignés et liste de courses dans une seule transaction : une tâche
-- créée sans ses assignés serait invisible de ceux qu'elle concerne.
--
-- `p_group_id` peut être nul : une tâche personnelle n'appartient à aucun
-- groupe.

create or replace function public.creer_tache(
  p_title       text,
  p_group_id    uuid default null,
  p_description text default null,
  p_due_at      timestamptz default null,
  p_priority    text default 'medium',
  p_reminder_at timestamptz default null,
  p_rrule       text default null,
  p_assignees   uuid[] default null,
  p_items       text[] default null
)
returns public.tasks
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur uuid := auth.uid();
  nouvelle    public.tasks%rowtype;
  titre       text := nullif(trim(both ' ' from coalesce(p_title, '')), '');
  assigne     uuid;
  article     text;
  rang        integer := 0;
begin
  if utilisateur is null then
    raise exception 'Session absente' using errcode = '42501';
  end if;
  if titre is null then
    raise exception 'Le titre est obligatoire' using errcode = '23514';
  end if;
  if p_group_id is not null
     and not public.est_membre_du_groupe(p_group_id, utilisateur) then
    raise exception 'Groupe inaccessible' using errcode = '42501';
  end if;

  insert into public.tasks
    (group_id, created_by, title, description, due_at, priority,
     reminder_at, rrule)
  values
    (p_group_id, utilisateur, titre,
     nullif(trim(both ' ' from coalesce(p_description, '')), ''),
     p_due_at, coalesce(p_priority, 'medium')::task_priority,
     p_reminder_at, nullif(trim(both ' ' from coalesce(p_rrule, '')), ''))
  returning * into nouvelle;

  -- L'auteur s'assigne par défaut s'il n'a désigné personne : une tâche sans
  -- assigné n'apparaîtrait dans la liste de personne.
  foreach assigne in array coalesce(p_assignees, array[utilisateur]::uuid[])
  loop
    insert into public.task_assignees (task_id, user_id, status)
    values (nouvelle.id, assigne,
            (case when assigne = utilisateur then 'accepted' else 'pending'
             end)::assignee_status)
    on conflict do nothing;
  end loop;

  foreach article in array coalesce(p_items, array[]::text[])
  loop
    if nullif(trim(both ' ' from article), '') is not null then
      insert into public.task_list_items (task_id, label, position)
      values (nouvelle.id, trim(both ' ' from article), rang);
      rang := rang + 1;
    end if;
  end loop;

  return nouvelle;
end;
$$;

grant execute on function public.creer_tache(
  text, uuid, text, timestamptz, text, timestamptz, text, uuid[], text[]
) to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Lire les tâches
-- ---------------------------------------------------------------------------
-- Une ligne par tâche, les assignés agrégés en JSON : l'écran fait une seule
-- lecture et n'a ni jointure ni requête de complément à sa charge.

create or replace function public.mes_taches(p_group_id uuid default null)
returns table (
  id            uuid,
  group_id      uuid,
  created_by    uuid,
  title         text,
  description   text,
  due_at        timestamptz,
  priority      text,
  reminder_at   timestamptz,
  rrule         text,
  completed_at  timestamptz,
  created_at    timestamptz,
  mon_statut    text,
  assignes      jsonb,
  articles      integer,
  articles_coches integer
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.id, t.group_id, t.created_by, t.title, t.description, t.due_at,
    t.priority::text, t.reminder_at, t.rrule, t.completed_at, t.created_at,
    (select a.status::text from public.task_assignees a
      where a.task_id = t.id and a.user_id = auth.uid()),
    coalesce((
      select jsonb_agg(jsonb_build_object(
               'user_id', a.user_id,
               'status',  a.status::text,
               'nom',     coalesce(
                 nullif(trim(both ' ' from
                   coalesce(p.first_name, '') || ' ' ||
                   coalesce(p.last_name, '')), ''),
                 p.pseudo, 'Membre'),
               'avatar_url',
               coalesce('preset:' || p.avatar_preset, p.avatar_url))
             order by p.first_name nulls last)
      from public.task_assignees a
      left join public.profiles p on p.id = a.user_id
      where a.task_id = t.id
    ), '[]'::jsonb),
    (select count(*)::integer from public.task_list_items i
      where i.task_id = t.id),
    (select count(*)::integer from public.task_list_items i
      where i.task_id = t.id and i.checked_at is not null)
  from public.tasks t
  where t.deleted_at is null
    and (p_group_id is null or t.group_id = p_group_id)
    and (
      t.created_by = auth.uid()
      or (t.group_id is not null
          and public.est_membre_du_groupe(t.group_id, auth.uid()))
      or exists (select 1 from public.task_assignees a
                  where a.task_id = t.id and a.user_id = auth.uid())
    )
  order by t.completed_at nulls first, t.due_at nulls last, t.created_at;
$$;

grant execute on function public.mes_taches(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Répondre à une tâche, la terminer, gérer ses assignés
-- ---------------------------------------------------------------------------

-- L'assigné accepte ou refuse. Renvoie le statut réellement enregistré.
create or replace function public.repondre_tache(
  p_task_id uuid,
  p_statut  text
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if p_statut not in ('accepted', 'declined', 'pending', 'done') then
    raise exception 'Statut inconnu' using errcode = '22P02';
  end if;
  if not public.peut_voir_tache(p_task_id) then
    raise exception 'Tâche inaccessible' using errcode = '42501';
  end if;

  update public.task_assignees
  set status = p_statut::assignee_status
  where task_id = p_task_id and user_id = auth.uid();

  if not found then
    return 'non_assigne';
  end if;
  return p_statut;
end;
$$;

-- Terminer ou rouvrir. `completed_at` est la seule source du statut :
-- « terminée » si renseigné, « en retard » si l'échéance est passée, « à
-- faire » sinon. Aucun statut n'est stocké en double.
create or replace function public.terminer_tache(
  p_task_id uuid,
  p_terminee boolean default true
)
returns timestamptz
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  quand timestamptz;
begin
  if not public.peut_voir_tache(p_task_id) then
    raise exception 'Tâche inaccessible' using errcode = '42501';
  end if;

  update public.tasks
  set completed_at = case when p_terminee then now() else null end
  where id = p_task_id
  returning completed_at into quand;

  -- Le statut de l'assigné suit : une tâche terminée ne reste pas « en
  -- attente » dans sa liste.
  update public.task_assignees
  set status = (case when p_terminee then 'done' else 'accepted'
                end)::assignee_status
  where task_id = p_task_id and user_id = auth.uid();

  return quand;
end;
$$;

-- Remplacer la liste des assignés. `task_assignees` n'a pas de politique
-- DELETE : sans cette fonction, on ne pourrait qu'ajouter.
create or replace function public.definir_assignes_tache(
  p_task_id   uuid,
  p_assignees uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  assigne uuid;
  total   integer := 0;
begin
  if not public.peut_voir_tache(p_task_id) then
    raise exception 'Tâche inaccessible' using errcode = '42501';
  end if;

  delete from public.task_assignees
  where task_id = p_task_id
    and not (user_id = any(coalesce(p_assignees, array[]::uuid[])));

  foreach assigne in array coalesce(p_assignees, array[]::uuid[])
  loop
    insert into public.task_assignees (task_id, user_id, status)
    values (p_task_id, assigne, 'pending'::assignee_status)
    on conflict do nothing;
    total := total + 1;
  end loop;

  return total;
end;
$$;

-- Suppression douce : `tasks` n'a pas de politique DELETE non plus.
create or replace function public.supprimer_tache(p_task_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if not public.peut_voir_tache(p_task_id) then
    return false;
  end if;
  update public.tasks set deleted_at = now()
  where id = p_task_id and deleted_at is null;
  return true;
end;
$$;

grant execute on function public.repondre_tache(uuid, text) to authenticated;
grant execute on function public.terminer_tache(uuid, boolean) to authenticated;
grant execute on function public.definir_assignes_tache(uuid, uuid[])
  to authenticated;
grant execute on function public.supprimer_tache(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Liste de courses
-- ---------------------------------------------------------------------------
-- `checked_by` retient qui a coché : dans une colocation, savoir qui a pris le
-- pain évite de le prendre en double.

-- `"position"` est cité à dessein : ne pas retirer les guillemets. POSITION est
-- un `col_name_keyword` de PostgreSQL. La grammaire l'accepte comme nom de
-- colonne dans un `create table` ou une liste d'insertion (règle `ColId`), mais
-- pas comme nom de colonne de sortie d'un `returns table` ni comme nom
-- d'argument de fonction : ces deux positions sont bâties sur
-- `type_function_name`, qui exclut les `col_name_keyword`. Sans les guillemets,
-- la création de la fonction échoue en `42601: syntax error at or near
-- "position"`. Les guillemets ne changent pas le nom exposé — il reste
-- `position` en minuscules, donc la clé JSON lue côté Flutter ne bouge pas.
create or replace function public.articles_de_tache(p_task_id uuid)
returns table (
  id           uuid,
  label        text,
  "position"   integer,
  checked_at   timestamptz,
  checked_by   uuid,
  coche_par    text
)
language sql
security definer
set search_path = public
stable
as $$
  select i.id, i.label, i.position, i.checked_at, i.checked_by,
         coalesce(
           nullif(trim(both ' ' from
             coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')),
             ''),
           p.pseudo)
  from public.task_list_items i
  left join public.profiles p on p.id = i.checked_by
  where i.task_id = p_task_id
    and public.peut_voir_tache(p_task_id)
  order by i.position, i.created_at;
$$;

create or replace function public.cocher_article(
  p_item_id uuid,
  p_coche   boolean default true
)
returns timestamptz
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  tache public.task_list_items%rowtype;
  quand timestamptz;
begin
  select * into tache from public.task_list_items where id = p_item_id;
  if not found or not public.peut_voir_tache(tache.task_id) then
    raise exception 'Article inaccessible' using errcode = '42501';
  end if;

  update public.task_list_items
  set checked_at = case when p_coche then now() else null end,
      checked_by = case when p_coche then auth.uid() else null end
  where id = p_item_id
  returning checked_at into quand;

  return quand;
end;
$$;

create or replace function public.ajouter_article(
  p_task_id uuid,
  p_label   text
)
returns uuid
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  libelle  text := nullif(trim(both ' ' from coalesce(p_label, '')), '');
  suivant  integer;
  nouveau  uuid;
begin
  if libelle is null then
    raise exception 'Libellé vide' using errcode = '23514';
  end if;
  if not public.peut_voir_tache(p_task_id) then
    raise exception 'Tâche inaccessible' using errcode = '42501';
  end if;

  select coalesce(max(position), -1) + 1 into suivant
  from public.task_list_items where task_id = p_task_id;

  insert into public.task_list_items (task_id, label, position)
  values (p_task_id, libelle, suivant)
  returning id into nouveau;

  return nouveau;
end;
$$;

create or replace function public.supprimer_article(p_item_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  article public.task_list_items%rowtype;
begin
  select * into article from public.task_list_items where id = p_item_id;
  if not found or not public.peut_voir_tache(article.task_id) then
    return false;
  end if;
  delete from public.task_list_items where id = p_item_id;
  return true;
end;
$$;

grant execute on function public.articles_de_tache(uuid) to authenticated;
grant execute on function public.cocher_article(uuid, boolean) to authenticated;
grant execute on function public.ajouter_article(uuid, text) to authenticated;
grant execute on function public.supprimer_article(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 6. Créer un événement
-- ---------------------------------------------------------------------------
-- Sans liste de participants explicite et avec un groupe, tous les membres
-- sont conviés : c'est le cas courant d'un agenda familial.
--
-- `p_group_id` nul crée un rendez-vous personnel : aucun participant n'est
-- inscrit, et seul le propriétaire le voit.

create or replace function public.creer_evenement(
  p_title            text,
  p_starts_at        timestamptz,
  p_ends_at          timestamptz default null,
  p_group_id         uuid default null,
  p_description      text default null,
  p_location         text default null,
  p_rrule            text default null,
  p_image_url        text default null,
  p_reminder_minutes integer default null,
  p_participants     uuid[] default null
)
returns public.events
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur uuid := auth.uid();
  nouveau     public.events%rowtype;
  titre       text := nullif(trim(both ' ' from coalesce(p_title, '')), '');
  fin         timestamptz := coalesce(p_ends_at, p_starts_at + interval '1 hour');
  participant uuid;
begin
  if utilisateur is null then
    raise exception 'Session absente' using errcode = '42501';
  end if;
  if titre is null then
    raise exception 'Le titre est obligatoire' using errcode = '23514';
  end if;
  if p_starts_at is null then
    raise exception 'La date de début est obligatoire' using errcode = '23514';
  end if;
  if fin < p_starts_at then
    raise exception 'La fin précède le début' using errcode = '23514';
  end if;
  if p_group_id is not null
     and not public.est_membre_du_groupe(p_group_id, utilisateur) then
    raise exception 'Groupe inaccessible' using errcode = '42501';
  end if;

  insert into public.events
    (group_id, owner_id, title, description, starts_at, ends_at, location,
     rrule, image_url, reminder_minutes)
  values
    (p_group_id, utilisateur, titre,
     nullif(trim(both ' ' from coalesce(p_description, '')), ''),
     p_starts_at, fin,
     nullif(trim(both ' ' from coalesce(p_location, '')), ''),
     nullif(trim(both ' ' from coalesce(p_rrule, '')), ''),
     p_image_url, p_reminder_minutes)
  returning * into nouveau;

  -- Participants : la liste fournie, sinon tous les membres du groupe.
  if p_participants is not null then
    foreach participant in array p_participants loop
      insert into public.event_participants (event_id, user_id, response)
      values (nouveau.id, participant,
              (case when participant = utilisateur then 'yes' else 'pending'
               end)::event_response)
      on conflict do nothing;
    end loop;
  elsif p_group_id is not null then
    insert into public.event_participants (event_id, user_id, response)
    select nouveau.id, m.user_id,
           (case when m.user_id = utilisateur then 'yes' else 'pending'
            end)::event_response
    from public.group_members m
    where m.group_id = p_group_id
      and (m.expires_at is null or m.expires_at > now())
    on conflict do nothing;
  end if;

  return nouveau;
end;
$$;

grant execute on function public.creer_evenement(
  text, timestamptz, timestamptz, uuid, text, text, text, text, integer,
  uuid[]
) to authenticated;


-- ---------------------------------------------------------------------------
-- 7. Lire l'agenda
-- ---------------------------------------------------------------------------
-- Bornes optionnelles : l'accueil demande la journée, le calendrier le mois,
-- l'écran de groupe ce qui vient.

create or replace function public.mon_agenda(
  p_debut    timestamptz default null,
  p_fin      timestamptz default null,
  p_group_id uuid default null
)
returns table (
  id               uuid,
  group_id         uuid,
  owner_id         uuid,
  title            text,
  description      text,
  starts_at        timestamptz,
  ends_at          timestamptz,
  location         text,
  rrule            text,
  image_url        text,
  reminder_minutes integer,
  ma_reponse       text,
  participants     jsonb,
  nombre_oui       integer
)
language sql
security definer
set search_path = public
stable
as $$
  select
    e.id, e.group_id, e.owner_id, e.title, e.description, e.starts_at,
    e.ends_at, e.location, e.rrule, e.image_url, e.reminder_minutes,
    (select p.response::text from public.event_participants p
      where p.event_id = e.id and p.user_id = auth.uid()),
    coalesce((
      select jsonb_agg(jsonb_build_object(
               'user_id',  p.user_id,
               'response', p.response::text,
               'nom',      coalesce(
                 nullif(trim(both ' ' from
                   coalesce(pr.first_name, '') || ' ' ||
                   coalesce(pr.last_name, '')), ''),
                 pr.pseudo, 'Membre'),
               'avatar_url',
               coalesce('preset:' || pr.avatar_preset, pr.avatar_url))
             order by pr.first_name nulls last)
      from public.event_participants p
      left join public.profiles pr on pr.id = p.user_id
      where p.event_id = e.id
    ), '[]'::jsonb),
    (select count(*)::integer from public.event_participants p
      where p.event_id = e.id and p.response = 'yes')
  from public.events e
  where e.deleted_at is null
    and (p_group_id is null or e.group_id = p_group_id)
    and (p_debut is null or e.ends_at >= p_debut)
    and (p_fin is null or e.starts_at <= p_fin)
    and (
      e.owner_id = auth.uid()
      or (e.group_id is not null
          and public.est_membre_du_groupe(e.group_id, auth.uid()))
      or exists (select 1 from public.event_participants p
                  where p.event_id = e.id and p.user_id = auth.uid())
    )
  order by e.starts_at;
$$;

grant execute on function public.mon_agenda(timestamptz, timestamptz, uuid)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 8. Répondre à un événement, le modifier, le supprimer
-- ---------------------------------------------------------------------------

create or replace function public.repondre_evenement(
  p_event_id uuid,
  p_reponse  text
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if p_reponse not in ('yes', 'no', 'maybe', 'pending') then
    raise exception 'Réponse inconnue' using errcode = '22P02';
  end if;
  if not public.peut_voir_evenement(p_event_id) then
    raise exception 'Événement inaccessible' using errcode = '42501';
  end if;

  -- L'invité peut ne pas figurer dans la liste : un membre du groupe ajouté
  -- après coup répond quand même.
  insert into public.event_participants (event_id, user_id, response,
                                         responded_at)
  values (p_event_id, auth.uid(), p_reponse::event_response, now())
  on conflict (event_id, user_id) do update
    set response = excluded.response, responded_at = now();

  return p_reponse;
end;
$$;

create or replace function public.supprimer_evenement(p_event_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  evenement public.events%rowtype;
begin
  select * into evenement from public.events where id = p_event_id;
  if not found then
    return false;
  end if;
  -- Seuls le propriétaire et un admin du groupe peuvent supprimer.
  if evenement.owner_id <> auth.uid()
     and not (evenement.group_id is not null
              and public.est_admin_du_groupe(evenement.group_id, auth.uid()))
  then
    return false;
  end if;

  update public.events set deleted_at = now()
  where id = p_event_id and deleted_at is null;
  return true;
end;
$$;

grant execute on function public.repondre_evenement(uuid, text)
  to authenticated;
grant execute on function public.supprimer_evenement(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 9. Vérification du schéma
-- ---------------------------------------------------------------------------
-- Même requête qu'en tranche 2, étendue aux tables de cette tranche. Toute
-- colonne obligatoire sans valeur par défaut qui apparaît ici doit figurer
-- dans les insertions ci-dessus.

select c.table_name, c.column_name, c.udt_name as type_sql
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('tasks', 'task_assignees', 'task_list_items',
                       'events', 'event_participants')
  and c.is_nullable = 'NO'
  and c.column_default is null
order by c.table_name, c.ordinal_position;
