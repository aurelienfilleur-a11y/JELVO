-- Tranche 5c — notifications Web Push.
--
-- Appliqué automatiquement au push sur `main` : voir `supabase/migrations.txt`.
-- Idempotent.
--
--
-- CE FICHIER MODIFIE UNE TABLE PRÉEXISTANTE — ET C'EST ASSUMÉ
--
-- `push_tokens` vient du schéma initial et portait :
--
--   push_tokens_platform_check : CHECK (platform = ANY (ARRAY['ios','android']))
--   PRIMARY KEY (user_id, token)
--
-- **La contrainte interdit `'web'`.** Un abonnement Web Push y échouerait en
-- `23514` — le même défaut que le dimanche de la tranche 4, vu cette fois
-- avant livraison plutôt qu'après. La contrainte est donc élargie, sans rien
-- retirer : les valeurs `ios` et `android` restent acceptées, et les lignes
-- existantes survivent.
--
-- Second écart : un abonnement Web Push n'est pas un jeton mais un triplet
-- (endpoint, clé publique `p256dh`, secret `auth`). Le choix retenu est le plus
-- économe : **`token` porte l'endpoint** — c'est bien l'adresse de destination,
-- donc le jeton au sens de cette table, et la clé primaire garde son sens —, et
-- deux colonnes *nullables* accueillent les clés. Une colonne `endpoint`
-- séparée aurait fait doublon avec `token` sans rien apporter.


-- ---------------------------------------------------------------------------
-- 1. Élargir push_tokens
-- ---------------------------------------------------------------------------

alter table public.push_tokens
  add column if not exists p256dh text,
  add column if not exists auth_key text;

do $$
begin
  alter table public.push_tokens drop constraint if exists push_tokens_platform_check;
  alter table public.push_tokens add constraint push_tokens_platform_check
    check (platform = any (array['ios', 'android', 'web']));
  raise notice 'push_tokens accepte désormais la plateforme web.';
end;
$$;

comment on column public.push_tokens.p256dh is
  'Clé publique de l''abonnement Web Push. Nulle pour ios/android.';
comment on column public.push_tokens.auth_key is
  'Secret d''authentification de l''abonnement Web Push. Nul pour ios/android.';


-- ---------------------------------------------------------------------------
-- 2. Préférences, par type et par personne
-- ---------------------------------------------------------------------------
-- **Absence de ligne = activé.** Le modèle est un opt-out : personne n'a de
-- ligne au départ, et tout arrive. L'inverse aurait demandé de semer des
-- lignes à l'inscription, donc de retoucher un parcours qui marche, pour un
-- résultat que l'utilisateur n'aurait pas compris — une application qui
-- n'envoie rien tant qu'on n'a pas coché six cases.

create table if not exists public.notification_preferences (
  user_id uuid not null references public.profiles(id) on delete cascade,
  type    text not null,
  enabled boolean not null default true,
  primary key (user_id, type)
);

alter table public.notification_preferences enable row level security;

do $$
begin
  drop policy if exists np_all on public.notification_preferences;
  create policy np_all on public.notification_preferences
    for all to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid());
end;
$$;

grant select, insert, update, delete on public.notification_preferences
  to authenticated;

-- Les six types envoyés. Le texte est libre côté base — comme
-- `notifications.type` —, mais cette fonction fait autorité pour l'interface :
-- ajouter un type ici le fait apparaître dans les réglages sans autre code.
create or replace function public.types_de_notification()
returns table (type text, libelle text, description text)
language sql
immutable
as $$
  values
    ('chat_message',     'Nouveaux messages',
     'Quand quelqu''un écrit dans un de vos groupes'),
    ('group_invitation', 'Invitations à un groupe',
     'Quand on vous invite dans un groupe'),
    ('event_invitation', 'Invitations à un événement',
     'Quand on vous convie à un événement'),
    ('task_assigned',    'Tâches assignées',
     'Quand une tâche vous est confiée'),
    ('reminder',         'Rappels',
     'Avant une tâche ou un événement'),
    ('event_response',   'Réponses aux événements',
     'Quand quelqu''un répond à un événement que vous organisez'),
    ('event_changed',    'Changements de date',
     'Quand un événement auquel vous participez est déplacé');
$$;

grant execute on function public.types_de_notification() to authenticated, anon;

create or replace function public.mes_preferences_notification()
returns table (type text, libelle text, description text, enabled boolean)
language sql
security definer
set search_path = public
as $$
  select t.type, t.libelle, t.description,
         coalesce(p.enabled, true)
  from public.types_de_notification() t
  left join public.notification_preferences p
    on p.type = t.type and p.user_id = auth.uid();
$$;

grant execute on function public.mes_preferences_notification() to authenticated;

create or replace function public.definir_preference_notification(
  p_type text,
  p_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'non_authentifie';
  end if;

  -- Un type inconnu serait accepté sans broncher et n'aurait aucun effet :
  -- autant le refuser tout de suite.
  if not exists (
    select 1 from public.types_de_notification() t where t.type = p_type
  ) then
    raise exception 'type_inconnu';
  end if;

  insert into public.notification_preferences (user_id, type, enabled)
  values (auth.uid(), p_type, p_enabled)
  on conflict (user_id, type) do update set enabled = excluded.enabled;

  return p_enabled;
end;
$$;

grant execute on function public.definir_preference_notification(text, boolean)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Abonnements
-- ---------------------------------------------------------------------------
-- Un abonnement Web Push meurt sans prévenir : l'utilisateur retire l'icône de
-- son écran d'accueil, et l'abonnement disparaît sans que personne ne le
-- sache. On réenregistre donc à chaque démarrage, d'où le `on conflict`.

create or replace function public.enregistrer_push(
  p_token text,
  p_platform text default 'web',
  p_p256dh text default null,
  p_auth text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'non_authentifie';
  end if;
  if p_token is null or length(p_token) = 0 then
    raise exception 'jeton_vide';
  end if;

  insert into public.push_tokens (
    user_id, token, platform, p256dh, auth_key, updated_at)
  values (auth.uid(), p_token, p_platform, p_p256dh, p_auth, now())
  on conflict (user_id, token) do update
    set platform   = excluded.platform,
        p256dh     = excluded.p256dh,
        auth_key   = excluded.auth_key,
        updated_at = now();

  return true;
end;
$$;

grant execute on function public.enregistrer_push(text, text, text, text)
  to authenticated;

create or replace function public.oublier_push(p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.push_tokens
   where user_id = auth.uid() and token = p_token;
  return found;
end;
$$;

grant execute on function public.oublier_push(text) to authenticated;


-- ---------------------------------------------------------------------------
-- 4. La file d'envoi
-- ---------------------------------------------------------------------------
-- **Pourquoi une file plutôt qu'un appel HTTP depuis le déclencheur.** Trois
-- raisons, chacune suffisante :
--
-- 1. Une notification est un effet de bord : elle ne doit **jamais** faire
--    échouer l'écriture principale. C'est la règle posée en tranche 2, et un
--    appel réseau dans une transaction la violerait à la première panne.
-- 2. Un appel sortant depuis un déclencheur tiendrait la transaction ouverte le
--    temps du réseau.
-- 3. La tranche 5d y déposera ses rappels : une seule file, un seul envoyeur.
--
-- **Aucune politique d'insertion** : personne ne doit pouvoir déposer dans la
-- file de quelqu'un d'autre. L'alimentation passe par les déclencheurs
-- `security definer`, et la vidange par la fonction Edge sous le rôle service.

create table if not exists public.push_outbox (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text not null,
  url        text,
  created_at timestamptz not null default now(),
  sent_at    timestamptz,
  attempts   integer not null default 0,
  last_error text
);

create index if not exists push_outbox_a_envoyer
  on public.push_outbox (created_at)
  where sent_at is null;

alter table public.push_outbox enable row level security;

-- Lecture de ses propres lignes seulement, et rien d'autre : cela sert au
-- diagnostic, pas au fonctionnement.
do $$
begin
  drop policy if exists outbox_select on public.push_outbox;
  create policy outbox_select on public.push_outbox
    for select to authenticated
    using (user_id = auth.uid());
end;
$$;

grant select on public.push_outbox to authenticated;

-- Empile une notification si — et seulement si — la personne la veut et peut
-- la recevoir. Ne lève jamais : un défaut d'empilement ne doit pas remonter
-- jusqu'à l'écriture qui l'a déclenché.
create or replace function public.empiler_push(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_url text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return false;
  end if;

  -- Absence de ligne = activé : c'est un opt-out.
  if exists (
    select 1 from public.notification_preferences p
     where p.user_id = p_user_id and p.type = p_type and not p.enabled
  ) then
    return false;
  end if;

  -- Personne sans abonnement : rien à empiler. Sans ce filtre, la file
  -- grossirait indéfiniment de messages que nul ne peut recevoir.
  if not exists (
    select 1 from public.push_tokens t where t.user_id = p_user_id
  ) then
    return false;
  end if;

  insert into public.push_outbox (user_id, type, title, body, url)
  values (p_user_id, p_type, left(p_title, 120), left(p_body, 300), p_url);

  return true;
exception
  when others then
    raise warning 'empiler_push (%) : %', p_type, sqlerrm;
    return false;
end;
$$;


-- ---------------------------------------------------------------------------
-- 5. Les déclencheurs
-- ---------------------------------------------------------------------------
-- Tous attrapent leurs erreurs et laissent passer l'écriture principale.
--
--
-- UNE SEULE RÈGLE DE FORMULATION
--
--   **titre = le contexte, corps = qui fait quoi.**
--
-- Le titre porte donc le **nom du groupe** — « Personnel » à défaut —, jamais
-- un mot de catégorie. Sur un écran verrouillé, le titre sert à savoir de
-- quel coin de sa vie vient la notification ; le corps, à savoir quoi.
--
-- Trois conventions cohabitaient avant : le nom du groupe pour les messages,
-- le titre de l'événement pour les réponses et les changements de date, un
-- mot de catégorie — « Invitation », « Nouvelle tâche », « Rappel » — pour le
-- reste. L'empilement se lisait mal, et rien ne permettait de trier d'un coup
-- d'œil. La règle vaut aussi pour `empiler_rappels`, dans la tranche 5d.
--
-- Conséquence à tenir : **le corps doit nommer l'élément**, puisque le titre
-- ne le fait plus.

-- 5.0 Le nom d'une personne, écrit au même endroit pour tous ---------------
--
-- Le même `coalesce` était recopié dans chaque déclencheur. Quatre copies,
-- c'est quatre endroits où la règle peut diverger — et un cinquième arrivait
-- avec l'invitation à un événement.
--
-- Renvoie `null` quand l'identifiant est absent ou sans profil : c'est à
-- l'appelant de décider s'il écrit « Quelqu'un » ou s'il reformule sa phrase
-- sans sujet.
create or replace function public.nom_affiche(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
           nullif(trim(both ' ' from
             coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
           p.pseudo)
    from public.profiles p
   where p.id = p_user_id;
$$;


-- 5.1 Nouveau message ------------------------------------------------------
create or replace function public.push_nouveau_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  expediteur text;
  groupe     text;
  membre     record;
begin
  expediteur := coalesce(public.nom_affiche(new.sender_id), 'Quelqu''un');

  select g.name into groupe from public.groups g where g.id = new.group_id;

  for membre in
    select m.user_id
      from public.group_members m
     where m.group_id = new.group_id
       and m.user_id <> new.sender_id
       and (m.expires_at is null or m.expires_at > now())
  loop
    perform public.empiler_push(
      membre.user_id,
      'chat_message',
      coalesce(groupe, 'Personnel'),
      expediteur || ' : ' || coalesce(
        nullif(new.content, ''),
        case when new.media_kind = 'video' then 'a envoyé une vidéo'
             else 'a envoyé une photo' end),
      '/groupes/' || new.group_id::text || '/discussion'
    );
  end loop;

  return new;
exception
  when others then
    raise warning 'push_nouveau_message : %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_push_nouveau_message on public.messages;
create trigger trg_push_nouveau_message
  after insert on public.messages
  for each row execute function public.push_nouveau_message();


-- 5.2 Invitation reçue -----------------------------------------------------
create or replace function public.push_invitation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  groupe   text;
  emetteur text;
begin
  if new.status is distinct from 'pending' or new.type is distinct from 'group' then
    return new;
  end if;

  select g.name into groupe from public.groups g where g.id = new.group_id;
  emetteur := coalesce(public.nom_affiche(new.inviter_id), 'Quelqu''un');

  perform public.empiler_push(
    new.invitee_id,
    'group_invitation',
    coalesce(groupe, 'Personnel'),
    emetteur || ' vous invite dans le groupe',
    '/invitations/' || new.id::text
  );

  return new;
exception
  when others then
    raise warning 'push_invitation : %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_push_invitation on public.invitations;
create trigger trg_push_invitation
  after insert on public.invitations
  for each row execute function public.push_invitation();


-- 5.3 Tâche assignée -------------------------------------------------------
-- C'est ce déclencheur qui rend vraie la promesse affichée par l'écran de
-- création : « Jelvo enverra une notification à la personne assignée ».
create or replace function public.push_tache_assignee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tache    public.tasks%rowtype;
  groupe   text;
  assigneur text;
begin
  -- S'assigner soi-même n'a pas à se notifier.
  if new.user_id = auth.uid() then
    return new;
  end if;

  select * into tache from public.tasks t where t.id = new.task_id;
  if tache.id is null or tache.deleted_at is not null then
    return new;
  end if;

  select g.name into groupe from public.groups g where g.id = tache.group_id;
  select public.nom_affiche(auth.uid()) into assigneur;

  perform public.empiler_push(
    new.user_id,
    'task_assigned',
    coalesce(groupe, 'Personnel'),
    -- Sans assigneur identifiable — une écriture hors session —, on n'invente
    -- pas de sujet à la phrase.
    case when assigneur is null
         then 'Nouvelle tâche : ' || tache.title
         else assigneur || ' vous a confié : ' || tache.title
    end,
    '/taches/' || new.task_id::text
  );

  return new;
exception
  when others then
    raise warning 'push_tache_assignee : %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_push_tache_assignee on public.task_assignees;
create trigger trg_push_tache_assignee
  after insert on public.task_assignees
  for each row execute function public.push_tache_assignee();


-- 5.4 Réponse à un événement ----------------------------------------------
-- Vers l'**organisateur** : c'est lui que la réponse intéresse, et lui seul.
create or replace function public.push_reponse_evenement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  evenement public.events%rowtype;
  groupe    text;
  qui       text;
  mot       text;
begin
  if new.response is not distinct from old.response then
    return new;
  end if;

  select * into evenement from public.events e where e.id = new.event_id;
  if evenement.id is null or evenement.owner_id = new.user_id then
    return new;
  end if;

  qui := coalesce(public.nom_affiche(new.user_id), 'Quelqu''un');

  mot := case new.response
           when 'yes'   then 'vient'
           when 'no'    then 'ne vient pas'
           when 'maybe' then 'hésite'
           else 'a répondu'
         end;

  select g.name into groupe from public.groups g where g.id = evenement.group_id;

  perform public.empiler_push(
    evenement.owner_id,
    'event_response',
    coalesce(groupe, 'Personnel'),
    -- Le titre ne nomme plus l'événement : le corps doit le faire.
    evenement.title || ' — ' || qui || ' ' || mot,
    '/evenements/' || new.event_id::text
  );

  return new;
exception
  when others then
    raise warning 'push_reponse_evenement : %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_push_reponse_evenement on public.event_participants;
create trigger trg_push_reponse_evenement
  after update on public.event_participants
  for each row execute function public.push_reponse_evenement();


-- 5.4bis Invitation à un événement -----------------------------------------
--
-- **Ce cas n'envoyait rien**, et c'était un trou et non un choix. Deux
-- raisons cumulées : `push_invitation` écarte tout ce qui n'est pas
-- `type = 'group'`, et convier quelqu'un passe par une insertion dans
-- `event_participants`, qui n'avait de déclencheur que sur `update`. On était
-- donc prévenu qu'un autre avait répondu, mais jamais qu'on était invité.
--
-- Un événement de groupe convie par défaut tous ses membres actifs : la
-- création d'un événement dans un groupe de huit envoie donc sept
-- notifications. C'est voulu — c'est exactement l'information attendue.
create or replace function public.push_invitation_evenement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  evenement public.events%rowtype;
  groupe    text;
  emetteur  text;
begin
  -- L'organisateur s'inscrit lui-même en créant l'événement.
  if new.user_id = auth.uid() then
    return new;
  end if;

  select * into evenement from public.events e where e.id = new.event_id;
  if evenement.id is null or evenement.deleted_at is not null then
    return new;
  end if;

  if new.user_id = evenement.owner_id then
    return new;
  end if;

  select g.name into groupe from public.groups g where g.id = evenement.group_id;
  emetteur := coalesce(public.nom_affiche(auth.uid()),
                       public.nom_affiche(evenement.owner_id));

  perform public.empiler_push(
    new.user_id,
    'event_invitation',
    coalesce(groupe, 'Personnel'),
    case when emetteur is null
         then 'Vous êtes convié à ' || evenement.title
         else emetteur || ' vous convie à ' || evenement.title
    end,
    '/evenements/' || new.event_id::text
  );

  return new;
exception
  when others then
    raise warning 'push_invitation_evenement : %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_push_invitation_evenement on public.event_participants;
create trigger trg_push_invitation_evenement
  after insert on public.event_participants
  for each row execute function public.push_invitation_evenement();


-- 5.5 Changement de date ---------------------------------------------------
create or replace function public.push_date_changee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  participant record;
  groupe      text;
begin
  if new.starts_at is not distinct from old.starts_at then
    return new;
  end if;

  select g.name into groupe from public.groups g where g.id = new.group_id;

  for participant in
    select ep.user_id
      from public.event_participants ep
     where ep.event_id = new.id
       and ep.user_id <> new.owner_id
  loop
    perform public.empiler_push(
      participant.user_id,
      'event_changed',
      coalesce(groupe, 'Personnel'),
      new.title || ' déplacé au '
        || to_char(new.starts_at, 'DD/MM à HH24:MI'),
      '/evenements/' || new.id::text
    );
  end loop;

  return new;
exception
  when others then
    raise warning 'push_date_changee : %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_push_date_changee on public.events;
create trigger trg_push_date_changee
  after update on public.events
  for each row execute function public.push_date_changee();


-- ---------------------------------------------------------------------------
-- 6. Vidange de la file, pour la fonction Edge
-- ---------------------------------------------------------------------------
-- Ces deux fonctions ne sont **pas** accordées à `authenticated` : elles
-- lisent les abonnements de tout le monde. Seul le rôle `service_role`, dont
-- la clé ne quitte jamais le serveur, peut les appeler.

create or replace function public.push_a_envoyer(p_limite integer default 50)
returns table (
  id       uuid,
  user_id  uuid,
  type     text,
  title    text,
  body     text,
  url      text,
  token    text,
  platform text,
  p256dh   text,
  auth_key text
)
language sql
security definer
set search_path = public
as $$
  select o.id, o.user_id, o.type, o.title, o.body, o.url,
         t.token, t.platform, t.p256dh, t.auth_key
    from public.push_outbox o
    join public.push_tokens t on t.user_id = o.user_id
   where o.sent_at is null
     and o.attempts < 3
   order by o.created_at
   limit least(coalesce(p_limite, 50), 500);
$$;

revoke all on function public.push_a_envoyer(integer) from public, authenticated;
grant execute on function public.push_a_envoyer(integer) to service_role;

-- Marque une ligne comme traitée. `p_erreur` non nul incrémente les tentatives
-- au lieu de clore : trois échecs et la ligne est abandonnée, plutôt que
-- réessayée indéfiniment.
create or replace function public.marquer_push_traite(
  p_id uuid,
  p_erreur text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_erreur is null then
    update public.push_outbox set sent_at = now() where id = p_id;
  else
    update public.push_outbox
       set attempts = attempts + 1, last_error = left(p_erreur, 500)
     where id = p_id;
  end if;
end;
$$;

revoke all on function public.marquer_push_traite(uuid, text)
  from public, authenticated;
grant execute on function public.marquer_push_traite(uuid, text) to service_role;

-- Un endpoint mort répond 404 ou 410 : il faut le retirer, sans quoi chaque
-- envoi le retentera. C'est le cas courant sur iOS — retirer l'icône de
-- l'écran d'accueil détruit l'abonnement sans prévenir personne.
create or replace function public.purger_push(p_token text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  retires integer;
begin
  delete from public.push_tokens where token = p_token;
  get diagnostics retires = row_count;
  return retires;
end;
$$;

revoke all on function public.purger_push(text) from public, authenticated;
grant execute on function public.purger_push(text) to service_role;
