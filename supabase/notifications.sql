-- Notifications — alimentation automatique et hygiène des compteurs.
--
-- À exécuter dans l'éditeur SQL du projet Supabase, après les scripts de la
-- tranche 2 et le correctif de création de groupe. Idempotent.
--
--
-- CE QUE FAIT CE SCRIPT
--
-- La table `notifications` existe déjà — `id`, `user_id`, `type`, `payload`,
-- `read_at`, `created_at` — avec deux politiques : lecture et mise à jour de
-- ses propres lignes. Il n'y a **pas de politique d'insertion**, et c'est très
-- bien ainsi : personne ne doit pouvoir écrire une notification dans la boîte
-- de quelqu'un d'autre. L'alimentation passe donc par des déclencheurs
-- `security definer`, seuls habilités à écrire.
--
-- Deux événements produisent une notification :
--   • une invitation de groupe reçue      → type `group_invitation`
--   • une demande de contact reçue        → type `contact_request`
--
-- Deux autres la referment, pour que les pastilles ne mentent pas :
--   • l'invitation quitte l'état `pending` → notification marquée lue
--   • la demande de contact est acceptée   → notification marquée lue
--
-- Le `payload` porte de quoi afficher la ligne sans requête supplémentaire :
-- l'écran de notifications ne fait donc qu'une seule lecture.


-- ---------------------------------------------------------------------------
-- 1. Invitation de groupe reçue
-- ---------------------------------------------------------------------------

create or replace function public.notifier_invitation_groupe()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  groupe   public.groups%rowtype;
  emetteur public.profiles%rowtype;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;

  select * into groupe from public.groups g where g.id = new.group_id;
  select * into emetteur from public.profiles p where p.id = new.inviter_id;

  insert into public.notifications (user_id, type, payload)
  values (
    new.invitee_id,
    'group_invitation',
    jsonb_build_object(
      'invitation_id', new.id,
      'group_id',      new.group_id,
      'group_name',    coalesce(groupe.name, 'un groupe'),
      'group_photo',   groupe.photo_url,
      'inviter_id',    new.inviter_id,
      'inviter_name',  coalesce(
        nullif(trim(both ' ' from
          coalesce(emetteur.first_name, '') || ' ' ||
          coalesce(emetteur.last_name, '')), ''),
        emetteur.pseudo,
        'Un membre'
      ),
      'inviter_avatar',
      coalesce('preset:' || emetteur.avatar_preset, emetteur.avatar_url)
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_notifier_invitation_groupe on public.invitations;
create trigger trg_notifier_invitation_groupe
  after insert on public.invitations
  for each row
  execute function public.notifier_invitation_groupe();


-- ---------------------------------------------------------------------------
-- 2. Demande de contact reçue
-- ---------------------------------------------------------------------------

create or replace function public.notifier_demande_contact()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  demandeur public.profiles%rowtype;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;

  select * into demandeur from public.profiles p where p.id = new.requester_id;

  insert into public.notifications (user_id, type, payload)
  values (
    new.addressee_id,
    'contact_request',
    jsonb_build_object(
      'requester_id', new.requester_id,
      'pseudo',       demandeur.pseudo,
      'name',         coalesce(
        nullif(trim(both ' ' from
          coalesce(demandeur.first_name, '') || ' ' ||
          coalesce(demandeur.last_name, '')), ''),
        demandeur.pseudo,
        'Quelqu’un'
      ),
      'avatar_url',
      coalesce('preset:' || demandeur.avatar_preset, demandeur.avatar_url)
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_notifier_demande_contact on public.contacts;
create trigger trg_notifier_demande_contact
  after insert on public.contacts
  for each row
  execute function public.notifier_demande_contact();


-- ---------------------------------------------------------------------------
-- 3. Refermer les notifications traitées
-- ---------------------------------------------------------------------------
-- Sans cela, une invitation acceptée laisserait sa pastille allumée
-- indéfiniment : le compteur d'un onglet doit refléter ce qui reste à faire,
-- pas ce qui est arrivé un jour.

create or replace function public.clore_notification_invitation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  update public.notifications
  set read_at = coalesce(read_at, now())
  where type = 'group_invitation'
    and user_id = new.invitee_id
    and payload ->> 'invitation_id' = new.id::text;

  return new;
end;
$$;

drop trigger if exists trg_clore_notification_invitation on public.invitations;
create trigger trg_clore_notification_invitation
  after update on public.invitations
  for each row
  execute function public.clore_notification_invitation();

create or replace function public.clore_notification_contact()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where type = 'contact_request'
    and user_id = new.addressee_id
    and payload ->> 'requester_id' = new.requester_id::text;

  return new;
end;
$$;

drop trigger if exists trg_clore_notification_contact on public.contacts;
create trigger trg_clore_notification_contact
  after update on public.contacts
  for each row
  when (new.status = 'accepted')
  execute function public.clore_notification_contact();

-- Refuser une demande supprime la ligne `contacts` : la notification
-- correspondante n'a plus d'objet.
create or replace function public.clore_notification_contact_supprime()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where type = 'contact_request'
    and user_id = old.addressee_id
    and payload ->> 'requester_id' = old.requester_id::text;

  return old;
end;
$$;

drop trigger if exists trg_clore_notification_contact_supprime
  on public.contacts;
create trigger trg_clore_notification_contact_supprime
  after delete on public.contacts
  for each row
  execute function public.clore_notification_contact_supprime();


-- ---------------------------------------------------------------------------
-- 4. Index de lecture
-- ---------------------------------------------------------------------------
-- L'écran et les pastilles lisent toujours « mes notifications, les non lues
-- d'abord ». L'index partiel sert le compteur, appelé à chaque changement
-- d'onglet.

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_non_lues_idx
  on public.notifications (user_id)
  where read_at is null;
