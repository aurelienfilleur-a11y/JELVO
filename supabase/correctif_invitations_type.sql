-- Correctif — l'invitation nominative échoue en 23502.
--
-- À exécuter dans l'éditeur SQL du projet Supabase. Idempotent.
--
--
-- LA CAUSE, ENFIN ÉTABLIE
--
--   ERROR: 23502: null value in column "type" of relation "invitations"
--          violates not-null constraint
--   CONTEXT: PL/pgSQL function inviter_dans_groupe(uuid,uuid) line 21
--
-- `invitations` porte une colonne `type` de type `invitation_type`
-- (`group`, `event`, `task`), NOT NULL, venue du schéma initial : une seule
-- table sert les trois sortes d'invitation, discriminées par cette colonne et
-- par celle des trois clés — `group_id`, `event_id`, `task_id` — qui est
-- renseignée.
--
-- `inviter_dans_groupe` ne renseignait pas `type`. L'insertion échouait donc
-- avant même d'atteindre le déclencheur de notification, qui n'était pour rien
-- dans l'affaire. Ni RLS — `postgres` possède les tables et porte `bypassrls`
-- — ni les notifications n'étaient en cause.


-- ---------------------------------------------------------------------------
-- 1. Renseigner `type` à la création d'une invitation
-- ---------------------------------------------------------------------------
-- Le contrôle de doublon est lui aussi restreint au type `group` : rien
-- n'interdit qu'une même personne soit par ailleurs invitée à un événement.

create or replace function public.inviter_dans_groupe(
  p_group_id uuid,
  p_invitee  uuid
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if not public.est_membre_du_groupe(p_group_id, auth.uid()) then
    return 'non_membre';
  end if;

  if public.est_membre_du_groupe(p_group_id, p_invitee) then
    return 'deja_membre';
  end if;

  if exists (
    select 1 from public.invitations i
    where i.group_id = p_group_id
      and i.invitee_id = p_invitee
      and i.type = 'group'
      and i.status = 'pending'
      and i.expires_at > now()
  ) then
    return 'deja_invite';
  end if;

  insert into public.invitations
    (type, group_id, inviter_id, invitee_id, status, expires_at)
  values
    ('group', p_group_id, auth.uid(), p_invitee, 'pending',
     now() + interval '30 days');

  return 'invite';
end;
$$;

grant execute on function public.inviter_dans_groupe(uuid, uuid)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 2. N'accepter comme adhésion que les invitations de groupe
-- ---------------------------------------------------------------------------
-- Sans ce garde-fou, accepter une invitation à un événement tenterait
-- d'insérer une adhésion avec un `group_id` nul. Le défaut est latent
-- aujourd'hui — les invitations d'événement n'existent pas encore — mais il
-- se réveillerait au premier écran de partage d'événement.

create or replace function public.accepter_invitation(p_invitation_id uuid)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  inv public.invitations%rowtype;
begin
  select * into inv
  from public.invitations i
  where i.id = p_invitation_id
    and i.invitee_id = auth.uid()
  for update;

  if not found or inv.status <> 'pending' then
    return 'invalide';
  end if;

  -- Cette fonction ne sait faire adhérer qu'à un groupe.
  if inv.type <> 'group' or inv.group_id is null then
    return 'invalide';
  end if;

  if not exists (
    select 1 from public.groups g
    where g.id = inv.group_id and g.deleted_at is null
  ) then
    return 'invalide';
  end if;

  if inv.expires_at is not null and inv.expires_at <= now() then
    update public.invitations set status = 'expired' where id = inv.id;
    return 'expire';
  end if;

  if public.est_membre_du_groupe(inv.group_id, auth.uid()) then
    update public.invitations set status = 'accepted' where id = inv.id;
    return 'deja_membre';
  end if;

  -- Une adhésion échue laisse sa ligne derrière elle : on la retire avant de
  -- réinsérer, la clé primaire étant le couple groupe / utilisateur.
  delete from public.group_members
  where group_id = inv.group_id and user_id = auth.uid();

  insert into public.group_members (group_id, user_id, role)
  values (inv.group_id, auth.uid(), 'member');

  update public.invitations set status = 'accepted' where id = inv.id;

  return 'rejoint';
end;
$$;

grant execute on function public.accepter_invitation(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Ne lister que les invitations de groupe
-- ---------------------------------------------------------------------------
-- La jointure sur `groups` écartait déjà les autres types, mais par accident
-- plutôt que par intention. L'écran d'invitation ne sait présenter qu'un
-- groupe : autant que la requête le dise.

create or replace function public.mes_invitations()
returns table (
  id              uuid,
  group_id        uuid,
  nom             text,
  description     text,
  photo_url       text,
  nombre_membres  integer,
  membres_apercu  text[],
  emetteur        text,
  emetteur_avatar text,
  statut          text,
  created_at      timestamptz,
  expires_at      timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    i.id, i.group_id, g.name, g.description, g.photo_url,
    (select count(*)::integer from public.group_members m
      where m.group_id = g.id
        and (m.expires_at is null or m.expires_at > now())),
    (select array_agg(prenom order by prenom)
       from (
         select coalesce(pm.first_name, pm.pseudo, 'Membre') as prenom
         from public.group_members m
         join public.profiles pm on pm.id = m.user_id
         where m.group_id = g.id
           and (m.expires_at is null or m.expires_at > now())
         order by m.joined_at
         limit 5
       ) as apercu),
    coalesce(nullif(trim(both ' ' from
      coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
      e.pseudo, 'Un membre'),
    e.avatar_url,
    i.status::text,
    i.created_at,
    i.expires_at
  from public.invitations i
  join public.groups g on g.id = i.group_id and g.deleted_at is null
  left join public.profiles e on e.id = i.inviter_id
  where i.invitee_id = auth.uid()
    and i.type = 'group'
    and i.status = 'pending'
  order by i.created_at desc;
$$;

grant execute on function public.mes_invitations() to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Vérification : reste-t-il une colonne obligatoire non renseignée ?
-- ---------------------------------------------------------------------------
-- Cette panne vient d'une méthode fautive : les colonnes des tables avaient
-- été devinées par sondage de noms candidats, et `type` n'était pas dans la
-- liste. La requête ci-dessous ne devine rien — elle liste les colonnes
-- **obligatoires et sans valeur par défaut** des tables où l'application
-- écrit. Toute colonne qui y apparaît doit figurer dans les `insert`
-- correspondants.

select
  c.table_name,
  c.column_name,
  c.data_type,
  c.udt_name as type_sql
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in (
    'groups', 'group_members', 'contacts', 'invitations',
    'notifications', 'group_invite_links'
  )
  and c.is_nullable = 'NO'
  and c.column_default is null
order by c.table_name, c.ordinal_position;

-- Contraintes des mêmes tables : une contrainte `check` ou une clé étrangère
-- ignorée produirait le même genre de panne.
select
  rel.relname as table_name,
  con.conname as contrainte,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname in (
    'groups', 'group_members', 'contacts', 'invitations',
    'notifications', 'group_invite_links'
  )
  and con.contype in ('c', 'f')
order by rel.relname, con.conname;

-- Valeurs de chaque type énuméré utilisé par l'application.
select t.typname as enumeration, string_agg(e.enumlabel, ', '
         order by e.enumsortorder) as valeurs
from pg_type t
join pg_enum e on e.enumtypid = t.oid
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
group by t.typname
order by t.typname;
