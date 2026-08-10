-- Tranche 3b — modification, auto-assignation, administration des membres.
--
-- À exécuter dans l'éditeur SQL du projet Supabase, en une fois, après
-- `tranche3_taches_et_evenements.sql`. Idempotent.
--
--
-- POURQUOI CE FICHIER
--
-- Trois manques que l'interface de détail rend visibles :
--
--   1. Rien ne permet de **modifier** une tâche ou un événement. `tasks` et
--      `events` ont bien une politique UPDATE, mais un `update(...).select()`
--      depuis le client repasserait par la politique SELECT — le piège qui a
--      coûté un 42501 à la création de groupe. Une fonction règle les deux.
--
--   2. Une tâche sans assigné doit pouvoir être **prise** par n'importe quel
--      membre du groupe, puis lâchée. `definir_assignes_tache` ne convient pas :
--      elle remplace toute la liste, donc un membre pourrait en évincer un
--      autre. Il faut une fonction qui ne touche qu'à sa propre ligne.
--
--   3. **Promouvoir et retirer un membre ne fonctionnaient pas.** L'application
--      écrivait directement dans `group_members` par PostgREST. Si les
--      politiques UPDATE et DELETE de cette table ne couvrent pas le cas d'un
--      admin agissant sur autrui, la requête ne touche aucune ligne — et
--      PostgREST répond **200 sans erreur**. L'écran affichait donc « X est
--      désormais administrateur » alors que rien n'avait changé. Un échec
--      silencieux est pire qu'une erreur : il se diagnostique mal, longtemps.
--
-- Les fonctions ci-dessous renvoient un mot d'état plutôt que `void` :
-- l'application peut alors dire ce qui s'est réellement passé.
--
--
-- RAPPEL DE TYPAGE
--
-- Toute valeur d'énumération écrite porte une conversion explicite. Un littéral
-- seul est de type `unknown` et se laisse convertir vers la colonne visée, mais
-- dès qu'il entre dans une expression il devient `text`, et il n'existe pas de
-- conversion implicite de `text` vers un type énuméré (42804). La tranche 3 a
-- été livrée avec ce défaut sur quatre sites.


-- ---------------------------------------------------------------------------
-- 1. Modifier une tâche
-- ---------------------------------------------------------------------------
-- Remplace **tous** les champs modifiables : l'écran de détail envoie l'état
-- complet du formulaire. Une sémantique « ne change que ce qui est fourni »
-- interdirait de vider une échéance, ce qui est un geste légitime.
--
-- Le droit de modifier suit celui de voir, comme `supprimer_tache` : dans une
-- famille, celui qui a rangé la course l'ajuste sans demander la permission au
-- créateur.

create or replace function public.modifier_tache(
  p_task_id     uuid,
  p_title       text,
  p_description text default null,
  p_due_at      timestamptz default null,
  p_priority    text default 'medium',
  p_reminder_at timestamptz default null,
  p_rrule       text default null
)
returns public.tasks
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  modifiee public.tasks%rowtype;
  titre    text := nullif(trim(both ' ' from coalesce(p_title, '')), '');
begin
  if titre is null then
    raise exception 'Le titre est obligatoire' using errcode = '23514';
  end if;
  if not public.peut_voir_tache(p_task_id) then
    raise exception 'Tâche inaccessible' using errcode = '42501';
  end if;

  update public.tasks
  set title       = titre,
      description = nullif(trim(both ' ' from coalesce(p_description, '')), ''),
      due_at      = p_due_at,
      priority    = coalesce(p_priority, 'medium')::task_priority,
      reminder_at = p_reminder_at,
      rrule       = nullif(trim(both ' ' from coalesce(p_rrule, '')), '')
  where id = p_task_id
    and deleted_at is null
  returning * into modifiee;

  if not found then
    raise exception 'Tâche introuvable' using errcode = '42501';
  end if;

  return modifiee;
end;
$$;

grant execute on function public.modifier_tache(
  uuid, text, text, timestamptz, text, timestamptz, text
) to authenticated;


-- ---------------------------------------------------------------------------
-- 2. Prendre ou lâcher une tâche libre
-- ---------------------------------------------------------------------------
-- Une tâche sans assigné est « libre » : tout membre du groupe peut se
-- l'attribuer. Une tâche déjà assignée à quelqu'un d'autre ne se prend pas —
-- s'en emparer reviendrait à décider pour autrui.
--
-- `task_assignees` n'a pas de politique DELETE : sans cette fonction, on
-- pourrait se déclarer volontaire sans jamais pouvoir se rétracter.

create or replace function public.s_attribuer_tache(
  p_task_id uuid,
  p_prendre boolean default true
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur uuid := auth.uid();
  autres      integer;
begin
  if utilisateur is null then
    raise exception 'Session absente' using errcode = '42501';
  end if;
  if not public.peut_voir_tache(p_task_id) then
    raise exception 'Tâche inaccessible' using errcode = '42501';
  end if;

  if not p_prendre then
    delete from public.task_assignees
    where task_id = p_task_id and user_id = utilisateur;
    return case when found then 'lache' else 'non_assigne' end;
  end if;

  -- Déjà pris par soi : idempotent, l'écran a pu être touché deux fois.
  if exists (
    select 1 from public.task_assignees
    where task_id = p_task_id and user_id = utilisateur
  ) then
    return 'deja_pris';
  end if;

  select count(*) into autres
  from public.task_assignees
  where task_id = p_task_id;

  if autres > 0 then
    return 'deja_assignee';
  end if;

  insert into public.task_assignees (task_id, user_id, status)
  values (p_task_id, utilisateur, 'accepted'::assignee_status);

  return 'pris';
end;
$$;

grant execute on function public.s_attribuer_tache(uuid, boolean)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Modifier un événement
-- ---------------------------------------------------------------------------
-- Réservé au propriétaire et aux admins du groupe, comme `supprimer_evenement` :
-- déplacer la date d'un événement engage tous les participants.

create or replace function public.modifier_evenement(
  p_event_id         uuid,
  p_title            text,
  p_starts_at        timestamptz,
  p_ends_at          timestamptz default null,
  p_description      text default null,
  p_location         text default null,
  p_rrule            text default null,
  p_image_url        text default null,
  p_reminder_minutes integer default null
)
returns public.events
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  courant  public.events%rowtype;
  modifie  public.events%rowtype;
  titre    text := nullif(trim(both ' ' from coalesce(p_title, '')), '');
  fin      timestamptz := coalesce(p_ends_at, p_starts_at + interval '1 hour');
begin
  if titre is null then
    raise exception 'Le titre est obligatoire' using errcode = '23514';
  end if;
  if p_starts_at is null then
    raise exception 'La date de début est obligatoire' using errcode = '23514';
  end if;
  if fin < p_starts_at then
    raise exception 'La fin précède le début' using errcode = '23514';
  end if;

  select * into courant
  from public.events
  where id = p_event_id and deleted_at is null;

  if not found then
    raise exception 'Événement introuvable' using errcode = '42501';
  end if;
  if courant.owner_id <> auth.uid()
     and not (courant.group_id is not null
              and public.est_admin_du_groupe(courant.group_id, auth.uid()))
  then
    raise exception 'Événement inaccessible' using errcode = '42501';
  end if;

  update public.events
  set title            = titre,
      starts_at        = p_starts_at,
      ends_at          = fin,
      description      = nullif(trim(both ' ' from
                                coalesce(p_description, '')), ''),
      location         = nullif(trim(both ' ' from coalesce(p_location, '')),
                                ''),
      rrule            = nullif(trim(both ' ' from coalesce(p_rrule, '')), ''),
      image_url        = p_image_url,
      reminder_minutes = p_reminder_minutes
  where id = p_event_id
  returning * into modifie;

  return modifie;
end;
$$;

grant execute on function public.modifier_evenement(
  uuid, text, timestamptz, timestamptz, text, text, text, text, integer
) to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Administration des membres
-- ---------------------------------------------------------------------------
-- Voir l'en-tête : l'écriture directe par PostgREST échouait sans le dire.
--
-- Les deux fonctions refusent de laisser un groupe sans administrateur. C'est
-- la même règle que `quitter_groupe`, et pour la même raison : un groupe sans
-- admin ne peut plus ni inviter, ni se modifier, ni se supprimer.

create or replace function public.promouvoir_membre(
  p_group_id uuid,
  p_user_id  uuid
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  role_actuel public.member_role;
begin
  if not public.est_admin_du_groupe(p_group_id, auth.uid()) then
    return 'non_admin';
  end if;

  select role into role_actuel
  from public.group_members
  where group_id = p_group_id
    and user_id = p_user_id
    and (expires_at is null or expires_at > now());

  if not found then return 'non_membre'; end if;
  if role_actuel = 'admin'::member_role then return 'deja_admin'; end if;

  update public.group_members
  set role = 'admin'::member_role
  where group_id = p_group_id and user_id = p_user_id;

  return 'promu';
end;
$$;

-- Rétrograder : sans elle, nommer un administrateur serait irréversible depuis
-- l'application, et une promotion faite par erreur y resterait pour toujours.
create or replace function public.retrograder_membre(
  p_group_id uuid,
  p_user_id  uuid
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  admins integer;
begin
  if not public.est_admin_du_groupe(p_group_id, auth.uid()) then
    return 'non_admin';
  end if;

  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id
      and user_id = p_user_id
      and role = 'admin'::member_role
      and (expires_at is null or expires_at > now())
  ) then
    return 'non_admin_cible';
  end if;

  select count(*) into admins
  from public.group_members
  where group_id = p_group_id
    and role = 'admin'::member_role
    and (expires_at is null or expires_at > now());

  if admins <= 1 then return 'dernier_admin'; end if;

  update public.group_members
  set role = 'member'::member_role
  where group_id = p_group_id and user_id = p_user_id;

  return 'retrograde';
end;
$$;

create or replace function public.retirer_membre(
  p_group_id uuid,
  p_user_id  uuid
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  role_cible public.member_role;
  admins     integer;
begin
  if not public.est_admin_du_groupe(p_group_id, auth.uid()) then
    return 'non_admin';
  end if;
  -- On ne se retire pas soi-même par ce chemin : « Quitter le groupe » gère la
  -- promotion du plus ancien membre et la suppression du groupe vide.
  if p_user_id = auth.uid() then
    return 'soi_meme';
  end if;

  select role into role_cible
  from public.group_members
  where group_id = p_group_id and user_id = p_user_id;

  if not found then return 'non_membre'; end if;

  if role_cible = 'admin'::member_role then
    select count(*) into admins
    from public.group_members
    where group_id = p_group_id
      and role = 'admin'::member_role
      and (expires_at is null or expires_at > now());
    if admins <= 1 then return 'dernier_admin'; end if;
  end if;

  delete from public.group_members
  where group_id = p_group_id and user_id = p_user_id;

  return 'retire';
end;
$$;

grant execute on function public.promouvoir_membre(uuid, uuid) to authenticated;
grant execute on function public.retrograder_membre(uuid, uuid) to authenticated;
grant execute on function public.retirer_membre(uuid, uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Notification d'invitation à un événement
-- ---------------------------------------------------------------------------
-- Être convié à un événement ne produisait aucune notification : on ne
-- l'apprenait qu'en ouvrant le calendrier. Le déclencheur ci-dessous en crée
-- une, et son `payload` porte de quoi afficher la ligne **et y répondre** sans
-- aucune lecture de complément — titre, date, groupe, organisateur.
--
-- `notifications` n'a volontairement pas de politique INSERT : personne ne doit
-- pouvoir écrire dans la boîte d'autrui. L'alimentation passe donc par un
-- déclencheur `security definer`, comme ceux de `supabase/notifications.sql`.
--
-- **Une notification est un effet de bord : elle ne doit jamais faire échouer
-- l'écriture principale.** Toute erreur est donc consignée en `warning` et
-- laissée passer. Un événement impossible à créer parce que la notification a
-- été refusée serait un défaut bien plus grave qu'une pastille éteinte.

create or replace function public.notifier_invitation_evenement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  evenement public.events%rowtype;
  groupe    text;
  auteur    text;
begin
  -- L'organisateur n'a pas à être prévenu de son propre événement, et une
  -- réponse déjà donnée n'est pas une invitation.
  if new.user_id = auth.uid()
     or new.response <> 'pending'::event_response then
    return new;
  end if;

  select * into evenement from public.events where id = new.event_id;
  if not found or evenement.deleted_at is not null then
    return new;
  end if;

  select g.name into groupe
  from public.groups g where g.id = evenement.group_id;

  select coalesce(
           nullif(trim(both ' ' from
             coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')),
             ''),
           p.pseudo)
    into auteur
  from public.profiles p where p.id = evenement.owner_id;

  insert into public.notifications (user_id, type, payload)
  values (
    new.user_id,
    'event_invitation',
    jsonb_build_object(
      'event_id',   evenement.id,
      'titre',      evenement.title,
      'starts_at',  evenement.starts_at,
      'ends_at',    evenement.ends_at,
      'lieu',       evenement.location,
      'group_id',   evenement.group_id,
      'group_name', groupe,
      'auteur',     auteur
    )
  );

  return new;
exception
  when others then
    raise warning 'Notification d''événement impossible : % (%)',
      sqlerrm, sqlstate;
    return new;
end;
$$;

drop trigger if exists trg_notifier_invitation_evenement
  on public.event_participants;

create trigger trg_notifier_invitation_evenement
after insert on public.event_participants
for each row execute function public.notifier_invitation_evenement();

-- Répondre referme la notification : un compteur doit refléter ce qui reste à
-- faire, pas ce qui est arrivé un jour.
create or replace function public.clore_notification_evenement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.response <> 'pending'::event_response then
    update public.notifications
    set read_at = coalesce(read_at, now())
    where user_id = new.user_id
      and type = 'event_invitation'
      and payload ->> 'event_id' = new.event_id::text
      and read_at is null;
  end if;
  return new;
exception
  when others then
    raise warning 'Clôture de notification impossible : % (%)',
      sqlerrm, sqlstate;
    return new;
end;
$$;

drop trigger if exists trg_clore_notification_evenement
  on public.event_participants;

create trigger trg_clore_notification_evenement
after update on public.event_participants
for each row execute function public.clore_notification_evenement();


-- ---------------------------------------------------------------------------
-- 6. Vérification du schéma
-- ---------------------------------------------------------------------------
-- Même requête qu'aux tranches précédentes. Toute colonne obligatoire sans
-- valeur par défaut qui apparaît ici doit figurer dans les écritures ci-dessus.

select c.table_name, c.column_name, c.udt_name as type_sql
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('tasks', 'task_assignees', 'events', 'group_members')
  and c.is_nullable = 'NO'
  and c.column_default is null
order by c.table_name, c.ordinal_position;
