-- Schéma factice — NE PAS EXÉCUTER SUR LE PROJET SUPABASE.
--
-- Ce fichier n'est pas une migration. Il reconstitue, sur une base PostgreSQL
-- jetable et locale, le décor minimal dont les fichiers de `supabase/` ont
-- besoin pour être *compilés* : les tables et les types décrits dans
-- CLAUDE.md, un `auth.uid()` factice, et les deux prédicats de la tranche 2
-- réduits à leur signature.
--
-- Ce qu'il prouve : que les fichiers livrés se parsent et que chaque fonction
-- résout les noms qu'elle emploie. C'est exactement ce qui manquait le jour où
-- `articles_de_tache` a été livrée avec un `position` non cité.
--
-- Ce qu'il ne prouve pas : que le schéma réel ressemble à celui-ci. Les
-- colonnes ci-dessous sont recopiées de la documentation, donc d'une
-- connaissance faillible — c'est ainsi qu'`invitations.type` était passée
-- inaperçue. Le schéma initial reste seul juge des colonnes obligatoires, des
-- contraintes et des valeurs d'énumération.
--
-- Usage : voir `supabase/verification/rejouer.sh`.

do $r$ begin create role authenticated; exception when duplicate_object then null; end $r$;
do $r$ begin create role anon; exception when duplicate_object then null; end $r$;
create schema if not exists auth;

-- Même définition que chez Supabase : le sujet du jeton, ou nul hors session.
-- Le rejeu ordinaire ne pose aucun jeton et obtient donc nul, mais
-- `diagnostic_taches_evenements.sql` en pose un — autant que le décor sache le
-- lire, sinon la PARTIE B de ce script ne pourrait pas être éprouvée ici.
create function auth.uid() returns uuid language sql stable as $$
  select nullif(
    current_setting('request.jwt.claims', true)::json ->> 'sub', ''
  )::uuid;
$$;

create type public.member_role      as enum ('admin', 'member');
create type public.task_priority    as enum ('low', 'medium', 'high');
create type public.assignee_status  as enum ('pending', 'accepted', 'declined', 'done');
create type public.event_response   as enum ('yes', 'no', 'maybe', 'pending');

create table public.profiles (
  id         uuid primary key,
  pseudo     text,
  first_name text,
  last_name  text,
  avatar_url text
);

create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  photo_url   text,
  is_private  boolean not null default true,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.group_members (
  group_id   uuid not null references public.groups(id),
  user_id    uuid not null,
  role       public.member_role not null default 'member',
  joined_at  timestamptz not null default now(),
  expires_at timestamptz,
  primary key (group_id, user_id)
);

create table public.tasks (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid references public.groups(id),
  created_by   uuid not null,
  title        text not null,
  description  text,
  due_at       timestamptz,
  priority     public.task_priority not null default 'medium',
  reminder_at  timestamptz,
  rrule        text,
  completed_at timestamptz,
  created_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

create table public.task_assignees (
  task_id uuid not null references public.tasks(id),
  user_id uuid not null,
  status  public.assignee_status not null default 'pending',
  primary key (task_id, user_id)
);

create table public.task_list_items (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references public.tasks(id),
  label      text not null,
  position   integer not null default 0,
  checked_at timestamptz,
  checked_by uuid,
  created_at timestamptz not null default now()
);

create table public.events (
  id               uuid primary key default gen_random_uuid(),
  group_id         uuid references public.groups(id),
  owner_id         uuid not null,
  title            text not null,
  description      text,
  starts_at        timestamptz not null,
  ends_at          timestamptz,
  location         text,
  rrule            text,
  image_url        text,
  reminder_minutes integer,
  created_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

create table public.event_participants (
  event_id     uuid not null references public.events(id),
  user_id      uuid not null,
  response     public.event_response not null default 'pending',
  responded_at timestamptz,
  primary key (event_id, user_id)
);

-- Fournies par la tranche 2 ; simplifiées ici, seule leur signature compte.
create function public.est_membre_du_groupe(p_group_id uuid, p_user_id uuid)
returns boolean language sql stable as $$ select true $$;

create function public.est_admin_du_groupe(p_group_id uuid, p_user_id uuid)
returns boolean language sql stable as $$ select true $$;

-- Complément pour rejouer aussi les fichiers des tranches précédentes.
create table auth.users (
  id    uuid primary key,
  email text
);

create type public.contact_status    as enum ('pending', 'accepted');
create type public.invitation_status as enum ('pending', 'accepted', 'declined', 'expired');
create type public.invitation_type   as enum ('group', 'event', 'task');

create table public.contacts (
  requester_id       uuid not null,
  addressee_id       uuid not null,
  status             public.contact_status not null default 'pending',
  is_favorite        boolean not null default false,
  created_at         timestamptz not null default now(),
  primary key (requester_id, addressee_id)
);

create table public.invitations (
  id         uuid primary key default gen_random_uuid(),
  type       public.invitation_type not null,
  group_id   uuid references public.groups(id),
  event_id   uuid references public.events(id),
  task_id    uuid references public.tasks(id),
  inviter_id uuid not null,
  invitee_id uuid not null,
  status     public.invitation_status not null default 'pending',
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null,
  type       text not null,
  payload    jsonb not null default '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

-- Disponibilités : table et fonction du schéma initial, relevées sur le
-- projet par sondage de PostgREST (colonnes, types énumérés et signature).
create type public.availability_status as enum ('available', 'unavailable');
create type public.availability_kind   as enum ('recurring', 'exception');

-- Les trois contraintes `check` sont recopiées de `schema_actuel.sql`, et non
-- devinées. Celle sur `weekday` a coûté un aller-retour : la vraie base borne
-- le jour à **0..6**, et le décor, qui l'ignorait, laissait passer un 7.
create table public.availabilities (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null,
  weekday    integer,
  on_date    date,
  start_time time not null,
  end_time   time not null,
  status     public.availability_status not null default 'available',
  kind       public.availability_kind not null default 'recurring',
  created_at timestamptz not null default now(),
  constraint availabilities_check check (end_time > start_time),
  constraint availabilities_check1 check (
    (kind = 'recurring' and weekday is not null and on_date is null)
    or (kind = 'exception' and on_date is not null and weekday is null)
  ),
  constraint availabilities_weekday_check check (weekday >= 0 and weekday <= 6)
);

-- Réduite à sa signature : la vraie porte la règle de visibilité — contacts et
-- co-membres seulement —, que ce décor n'a pas à rejouer.
create function public.get_availability_status(at_ts timestamptz, target uuid)
returns text language sql stable as $$ select 'unknown'::text $$;

-- Chat (tranche 5a) : les trois tables viennent du schéma initial. Leurs
-- contraintes sont recopiées de `schema_actuel.sql` — y compris les deux clés
-- primaires composées, qui portent à elles seules deux règles de produit :
-- une réaction par personne et par message, un accusé de lecture par
-- conversation et par personne.
create type public.media_type as enum ('image', 'video');

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null,
  sender_id  uuid not null,
  content    text,
  media_url  text,
  media_kind public.media_type,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint messages_check check (content is not null or media_url is not null),
  constraint messages_content_check check (char_length(content) <= 2000)
);

create table public.message_reactions (
  message_id uuid not null,
  user_id    uuid not null,
  emoji      text not null,
  constraint message_reactions_pkey primary key (message_id, user_id),
  constraint message_reactions_emoji_check check (char_length(emoji) <= 8)
);

create table public.message_reads (
  group_id     uuid not null,
  user_id      uuid not null,
  last_read_at timestamptz not null default now(),
  constraint message_reads_pkey primary key (group_id, user_id)
);

-- Supabase accorde les privilèges de table à `authenticated` et laisse RLS
-- filtrer. On reproduit le `grant` — sans lui, une lecture légitime échouerait
-- en « permission denied » et ferait croire à un défaut du code. Les politiques
-- RLS, elles, ne sont pas rejouées ici : ce décor sert à éprouver les
-- fonctions, pas les politiques du projet.
grant usage on schema public, auth to authenticated, anon;
grant select, insert, update, delete on all tables in schema public
  to authenticated;
grant select on all tables in schema auth to authenticated;
