-- Correctif — l'invitation nominative échoue depuis l'ajout des déclencheurs.
--
-- À exécuter dans l'éditeur SQL du projet Supabase, après `notifications.sql`.
-- Idempotent. **Lisez la sortie « Messages » / « Notices » du SQL editor** :
-- le script s'autodiagnostique et y écrit la cause exacte.
--
--
-- CE QUE DIT LE SYMPTÔME
--
-- L'écran affiche « Les données n'ont pas pu être enregistrées ». Ce message
-- est le cas par défaut de `AuthFailure._fromPostgrest` : il n'apparaît que
-- lorsque le code SQLSTATE n'est **ni 23505, ni 42501**.
--
-- Or un refus RLS est **toujours** 42501, et l'application le traduit alors par
-- « Vous n'avez pas les droits nécessaires pour cette action ». L'hypothèse
-- « `notifications` n'a pas de politique INSERT donc le déclencheur est
-- refusé » ne colle donc pas au message observé : elle produirait l'autre
-- texte. Le déclencheur est bien le coupable — l'invitation passait avant lui —
-- mais il échoue pour une autre raison que RLS.
--
-- Restent, côté `notifications` : une contrainte `check` sur `type` qui
-- refuserait nos valeurs (23514), une colonne `id` ou `created_at` sans valeur
-- par défaut (23502), ou une clé étrangère sur `user_id` pointant ailleurs
-- qu'`auth.users` (23503). Le bloc de diagnostic ci-dessous tranche.
--
--
-- LE PRINCIPE DU CORRECTIF
--
-- Au-delà de la cause : **une notification est un effet de bord, elle ne doit
-- jamais faire échouer l'écriture principale.** Qu'un compteur ne s'allume pas
-- est ennuyeux ; qu'une invitation soit impossible à envoyer est bloquant. Les
-- deux déclencheurs attrapent donc désormais toute erreur, la consignent en
-- `warning`, et laissent passer l'invitation ou la demande de contact.


-- ---------------------------------------------------------------------------
-- 1. Réparations sûres
-- ---------------------------------------------------------------------------
-- Sans valeur par défaut sur `id`, aucune insertion ne peut aboutir. Ces deux
-- instructions ne font rien si la valeur par défaut existe déjà.

alter table public.notifications
  alter column id set default gen_random_uuid();

alter table public.notifications
  alter column created_at set default now();

-- Politique d'insertion réservée au rôle propriétaire, celui sous lequel
-- s'exécutent les déclencheurs `security definer`. Aucun assouplissement pour
-- les clients : `anon` et `authenticated` restent sans droit d'insertion, donc
-- personne ne peut écrire dans la boîte d'un autre. Sans effet si le
-- propriétaire contourne déjà RLS — mais couvre le cas contraire.
do $bloc$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notif_insert_declencheur'
  ) then
    execute format(
      'create policy notif_insert_declencheur on public.notifications '
      'for insert to %I with check (true)',
      current_user
    );
    raise notice 'Politique notif_insert_declencheur créée pour le rôle %.',
      current_user;
  end if;
end;
$bloc$;


-- ---------------------------------------------------------------------------
-- 2. Diagnostic : la vraie erreur, écrite noir sur blanc
-- ---------------------------------------------------------------------------
-- Tente une insertion réelle dans une sous-transaction, puis l'annule. Rien
-- n'est laissé derrière. Le SQLSTATE et le message remontent en `notice`.

do $bloc$
declare
  cobaye  uuid;
  contrainte record;
begin
  select id into cobaye from auth.users limit 1;

  if cobaye is null then
    raise notice 'DIAGNOSTIC : aucun compte dans auth.users, test ignoré.';
  else
    begin
      insert into public.notifications (user_id, type, payload)
      values (cobaye, 'group_invitation', jsonb_build_object('essai', true));
      raise notice 'DIAGNOSTIC : l''insertion d''une notification fonctionne.';
      -- On annule : ce n'est qu'un essai.
      raise exception using errcode = 'P0001', message = '__annulation__';
    exception
      when sqlstate 'P0001' then
        if sqlerrm <> '__annulation__' then
          raise notice 'DIAGNOSTIC : échec — % (%)', sqlerrm, sqlstate;
        end if;
      when others then
        raise notice 'DIAGNOSTIC : échec de l''insertion — SQLSTATE % — %',
          sqlstate, sqlerrm;
    end;
  end if;

  -- Contraintes `check` portant sur `type` : cause la plus probable d'un
  -- 23514. `type` est du texte libre dans notre conception ; une liste fermée
  -- côté base doit soit accueillir nos valeurs, soit disparaître.
  for contrainte in
    select conname, pg_get_constraintdef(oid) as definition
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and contype = 'c'
  loop
    raise notice 'CONTRAINTE CHECK sur notifications : % — %',
      contrainte.conname, contrainte.definition;
    raise notice '  Si elle refuse group_invitation ou contact_request : '
                 'alter table public.notifications drop constraint %I;',
      contrainte.conname;
  end loop;

  -- Cible de la clé étrangère de `user_id` : si elle pointe vers `profiles`,
  -- un invité sans ligne de profil ferait échouer l'insertion en 23503.
  for contrainte in
    select conname, pg_get_constraintdef(oid) as definition
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and contype = 'f'
  loop
    raise notice 'CLÉ ÉTRANGÈRE sur notifications : % — %',
      contrainte.conname, contrainte.definition;
  end loop;
end;
$bloc$;


-- ---------------------------------------------------------------------------
-- 3. Les déclencheurs ne peuvent plus bloquer l'écriture principale
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
      'inviter_avatar', emetteur.avatar_url
    )
  );

  return new;
exception when others then
  -- Une notification est un effet de bord : son échec ne doit pas empêcher
  -- l'invitation d'exister. On consigne et on laisse passer.
  raise warning 'Notification d''invitation non créée : % (%)',
    sqlerrm, sqlstate;
  return new;
end;
$$;

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
      'avatar_url',   demandeur.avatar_url
    )
  );

  return new;
exception when others then
  raise warning 'Notification de demande de contact non créée : % (%)',
    sqlerrm, sqlstate;
  return new;
end;
$$;

-- Même protection sur les déclencheurs qui referment les notifications : le
-- refus d'une invitation ne doit pas échouer parce qu'un `update` sur
-- `notifications` a été refusé.

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
exception when others then
  raise warning 'Notification d''invitation non refermée : % (%)',
    sqlerrm, sqlstate;
  return new;
end;
$$;

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
exception when others then
  raise warning 'Notification de contact non refermée : % (%)', sqlerrm, sqlstate;
  return new;
end;
$$;

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
exception when others then
  raise warning 'Notification de contact non refermée : % (%)', sqlerrm, sqlstate;
  return old;
end;
$$;
