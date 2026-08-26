-- ---------------------------------------------------------------------------
-- Tranche 8 — de quoi rendre les trois écrans d'invitation
-- ---------------------------------------------------------------------------
-- Trois invitations, trois écrans : rejoindre un groupe, venir à un événement,
-- prendre une tâche. Ils partagent un motif — qui invite, ce qu'on lui répond
-- — et manquaient chacun d'une chose que la base savait sans la dire.
--
-- 1. `invitation_par_id` : une invitation nominative **quel que soit son
--    état**. `mes_invitations` ne renvoie que les `pending` sur un groupe
--    vivant ; une invitation déjà acceptée y disparaît, et l'écran ne pouvait
--    dire que « introuvable » — le mot le plus vague pour les quatre cas.
-- 2. `auteur` et `auteur_avatar` sur `mon_agenda` et `mes_taches` : le nom de
--    qui invite. Il était en base, aucune lecture ne le remontait.
-- 3. `task_assigned` dans `notifications` : la tranche 5c envoyait la
--    notification **système**, mais ne déposait aucune ligne dans la boîte.
--    L'écran d'attribution n'avait donc pas d'entrée.
--
-- Idempotent : toute la tranche se rejoue sans effet de bord.
--
-- **Ce fichier s'applique avant `tranche7_durcissement.sql`**, qui referme
-- l'exécution de toute fonction absente de sa liste. Les noms créés ici y sont
-- ajoutés ; le durcissement doit rester le dernier passage.


-- ---------------------------------------------------------------------------
-- 1. Une invitation nominative, dans l'état où elle se trouve
-- ---------------------------------------------------------------------------
-- `statut_ecran` est un **mot d'état**, comme ceux de `quitter_groupe` ou de
-- `definir_terme_adhesion` : c'est lui qui décide du message, et non l'absence
-- de ligne. Une invitation refusée n'est pas une invitation qui n'existe pas,
-- et l'écran doit pouvoir le dire.
--
-- La fonction renvoie **toujours une ligne**, y compris `introuvable` : un
-- appelant qui reçoit zéro ligne ne saurait pas distinguer « rien à cet
-- identifiant » d'une panne de lecture.
--
-- Seul l'invité lit son invitation. Un identifiant deviné par quelqu'un
-- d'autre donne `introuvable`, et non le nom du groupe.

create or replace function public.invitation_par_id(p_invitation uuid)
returns table (
  statut_ecran          text,
  id                    uuid,
  group_id              uuid,
  nom                   text,
  description           text,
  photo_url             text,
  nombre_membres        integer,
  membres               jsonb,
  emetteur              text,
  emetteur_avatar       text,
  groupe_cree_le        timestamptz,
  created_at            timestamptz,
  expires_at            timestamptz,
  membership_expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  inv    public.invitations%rowtype;
  groupe public.groups%rowtype;
  etat   text;
begin
  select * into inv
  from public.invitations i
  where i.id = p_invitation
    and i.invitee_id = auth.uid()
    and i.type = 'group';

  if not found then
    return query select 'introuvable'::text, null::uuid, null::uuid,
      null::text, null::text, null::text, 0, '[]'::jsonb, null::text,
      null::text, null::timestamptz, null::timestamptz, null::timestamptz,
      null::timestamptz;
    return;
  end if;

  select * into groupe from public.groups g where g.id = inv.group_id;

  -- L'ordre compte : un groupe supprimé rend la question sans objet, même si
  -- l'invitation est encore `pending`.
  if groupe.id is null or groupe.deleted_at is not null then
    etat := 'groupe_supprime';
  elsif inv.status = 'accepted' then
    etat := 'acceptee';
  elsif inv.status = 'declined' then
    etat := 'refusee';
  elsif inv.status = 'expired'
     or (inv.expires_at is not null and inv.expires_at <= now()) then
    etat := 'expiree';
  elsif public.est_membre_du_groupe(inv.group_id, auth.uid()) then
    -- Rejoint par un lien entre-temps : proposer « Rejoindre » n'aurait rien
    -- à faire.
    etat := 'deja_membre';
  else
    etat := 'valide';
  end if;

  return query
  select
    etat,
    inv.id,
    inv.group_id,
    groupe.name,
    groupe.description,
    groupe.photo_url,
    (select count(*)::integer from public.group_members m
      where m.group_id = groupe.id
        and (m.expires_at is null or m.expires_at > now())),
    -- Le nom **et** l'avatar : la maquette montre des visages, et
    -- `membres_apercu` de `mes_invitations` ne porte que des prénoms.
    coalesce((
      select jsonb_agg(jsonb_build_object('nom', a.prenom,
                                          'avatar_url', a.avatar)
                       order by a.joined_at)
      from (
        select coalesce(pm.first_name, pm.pseudo, 'Membre') as prenom,
               coalesce('preset:' || pm.avatar_preset, pm.avatar_url) as avatar,
               m.joined_at
        from public.group_members m
        join public.profiles pm on pm.id = m.user_id
        where m.group_id = groupe.id
          and (m.expires_at is null or m.expires_at > now())
        order by m.joined_at
        limit 8
      ) as a
    ), '[]'::jsonb),
    coalesce(nullif(trim(both ' ' from
      coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
      e.pseudo, 'Un membre'),
    coalesce('preset:' || e.avatar_preset, e.avatar_url),
    groupe.created_at,
    inv.created_at,
    inv.expires_at,
    inv.membership_expires_at
  from public.profiles e
  where e.id = inv.inviter_id;

  -- L'émetteur peut avoir disparu : la jointure ci-dessus ne rendrait alors
  -- aucune ligne, et l'écran retomberait sur « introuvable » pour une
  -- invitation pourtant valide.
  if not found then
    return query select
      etat, inv.id, inv.group_id, groupe.name, groupe.description,
      groupe.photo_url,
      (select count(*)::integer from public.group_members m
        where m.group_id = groupe.id
          and (m.expires_at is null or m.expires_at > now())),
      '[]'::jsonb, 'Un membre'::text, null::text, groupe.created_at,
      inv.created_at, inv.expires_at, inv.membership_expires_at;
  end if;
end;
$$;

grant execute on function public.invitation_par_id(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 2. Qui invite — sur l'agenda et sur les tâches
-- ---------------------------------------------------------------------------
-- Les deux fonctions renvoyaient `owner_id` et `created_by`, c'est-à-dire un
-- identifiant. L'écran d'invitation, lui, ouvre sur une phrase : « Julie
-- Martin vous convie à… ». Reconstituer ce nom côté client demanderait une
-- lecture de `profiles` que RLS n'autorise pas toujours — c'est la raison
-- même pour laquelle ces lectures sont `security definer`.
--
-- Une colonne de sortie de plus impose un `drop function` : `create or
-- replace` le refuse. Le prix est le même qu'en tranche 6, et le gain aussi —
-- sans le nom, l'en-tête des deux écrans n'existe pas.

drop function if exists public.mon_agenda(timestamptz, timestamptz, uuid);

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
  nombre_oui       integer,
  auteur           text,
  auteur_avatar    text
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
                   coalesce(pr.first_name, '') || ' ' || coalesce(pr.last_name, '')), ''),
                 pr.pseudo, 'Membre'),
               'avatar_url',
               coalesce('preset:' || pr.avatar_preset, pr.avatar_url))
             order by pr.first_name nulls last)
      from public.event_participants p
      left join public.profiles pr on pr.id = p.user_id
      where p.event_id = e.id
    ), '[]'::jsonb),
    (select count(*)::integer from public.event_participants p
      where p.event_id = e.id and p.response = 'yes'),
    public.nom_affiche(e.owner_id),
    (select coalesce('preset:' || pa.avatar_preset, pa.avatar_url)
       from public.profiles pa where pa.id = e.owner_id)
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


drop function if exists public.mes_taches(uuid);

create or replace function public.mes_taches(p_group_id uuid default null)
returns table (
  id              uuid,
  group_id        uuid,
  created_by      uuid,
  title           text,
  description     text,
  due_at          timestamptz,
  priority        text,
  reminder_at     timestamptz,
  rrule           text,
  completed_at    timestamptz,
  created_at      timestamptz,
  mon_statut      text,
  assignes        jsonb,
  articles        integer,
  articles_coches integer,
  auteur          text,
  auteur_avatar   text
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
                   coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
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
      where i.task_id = t.id and i.checked_at is not null),
    public.nom_affiche(t.created_by),
    (select coalesce('preset:' || pa.avatar_preset, pa.avatar_url)
       from public.profiles pa where pa.id = t.created_by)
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
-- 3. Une tâche confiée entre dans la boîte
-- ---------------------------------------------------------------------------
-- La tranche 5c poussait déjà `task_assigned` vers le téléphone, mais rien ne
-- se déposait dans `notifications`. Conséquence : la seule trace d'une tâche
-- confiée était une notification système, qui disparaît une fois balayée.
-- L'écran d'attribution n'avait aucune entrée dans l'application.
--
-- Même forme que `notifier_invitation_evenement` : `security definer` — la
-- table n'a **aucune politique d'insertion** —, et toute erreur consignée en
-- `warning`. **Une notification est un effet de bord : elle ne doit jamais
-- faire échouer l'écriture qui l'a provoquée.**

create or replace function public.notifier_attribution_tache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tache  public.tasks%rowtype;
  groupe text;
  auteur text;
begin
  -- S'attribuer une tâche soi-même n'a pas à se notifier, et un statut déjà
  -- donné n'est pas une attribution en attente.
  if new.user_id = auth.uid()
     or new.status <> 'pending'::assignee_status then
    return new;
  end if;

  select * into tache from public.tasks t where t.id = new.task_id;
  if not found or tache.deleted_at is not null then
    return new;
  end if;

  select g.name into groupe from public.groups g where g.id = tache.group_id;
  select public.nom_affiche(auth.uid()) into auteur;

  insert into public.notifications (user_id, type, payload)
  values (
    new.user_id,
    'task_assigned',
    jsonb_build_object(
      'task_id',    tache.id,
      'titre',      tache.title,
      'due_at',     tache.due_at,
      'priorite',   tache.priority::text,
      'group_id',   tache.group_id,
      'group_name', groupe,
      'auteur',     auteur
    )
  );

  return new;
exception
  when others then
    raise warning 'Notification d''attribution impossible : % (%)',
      sqlerrm, sqlstate;
    return new;
end;
$$;

drop trigger if exists trg_notifier_attribution_tache on public.task_assignees;

create trigger trg_notifier_attribution_tache
after insert on public.task_assignees
for each row execute function public.notifier_attribution_tache();


-- Répondre referme la notification, comme pour un événement : un compteur
-- doit refléter ce qui reste à faire, pas ce qui est arrivé un jour.
create or replace function public.clore_notification_tache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending'::assignee_status then
    update public.notifications
    set read_at = coalesce(read_at, now())
    where user_id = new.user_id
      and type = 'task_assigned'
      and payload ->> 'task_id' = new.task_id::text
      and read_at is null;
  end if;
  return new;
exception
  when others then
    raise warning 'Clôture de notification de tâche impossible : % (%)',
      sqlerrm, sqlstate;
    return new;
end;
$$;

drop trigger if exists trg_clore_notification_tache on public.task_assignees;

create trigger trg_clore_notification_tache
after update on public.task_assignees
for each row execute function public.clore_notification_tache();


-- Retirer quelqu'un des assignés referme aussi : `definir_assignes_tache`
-- supprime la ligne au lieu de la mettre à jour, et la notification serait
-- restée seule à réclamer une réponse à une tâche qui n'est plus la sienne.
create or replace function public.clore_notification_tache_retiree()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where user_id = old.user_id
    and type = 'task_assigned'
    and payload ->> 'task_id' = old.task_id::text
    and read_at is null;
  return old;
exception
  when others then
    raise warning 'Clôture de notification de tâche impossible : % (%)',
      sqlerrm, sqlstate;
    return old;
end;
$$;

drop trigger if exists trg_clore_notification_tache_retiree
  on public.task_assignees;

create trigger trg_clore_notification_tache_retiree
after delete on public.task_assignees
for each row execute function public.clore_notification_tache_retiree();
