-- Tranche 2 — groupes, contacts et invitations.
--
-- À exécuter dans l'éditeur SQL du projet Supabase, en une seule fois.
-- Le script est idempotent : le rejouer ne casse rien.
--
-- Il apporte :
--   1. les favoris personnels sur `contacts` ;
--   2. la table `group_invite_links` et ses politiques ;
--   3. les fonctions d'appartenance, d'aperçu, d'adhésion et de départ ;
--   4. la recherche de profils par pseudo.


-- ---------------------------------------------------------------------------
-- 1. Favoris personnels
-- ---------------------------------------------------------------------------
-- `contacts` ne porte qu'une ligne par relation : un unique `is_favorite`
-- serait donc partagé par les deux personnes. Chacune épingle désormais de son
-- côté. L'ancienne colonne est laissée en place, mais l'application ne l'écrit
-- ni ne la lit plus.

alter table public.contacts
  add column if not exists favorite_requester boolean not null default false,
  add column if not exists favorite_addressee boolean not null default false;

update public.contacts
set favorite_requester = true,
    favorite_addressee = true
where is_favorite
  and not favorite_requester
  and not favorite_addressee;


-- ---------------------------------------------------------------------------
-- 2. Appartenance à un groupe
-- ---------------------------------------------------------------------------
-- `expires_at` prépare l'adhésion temporaire : un membre invité pour la durée
-- d'un voyage, d'un séjour ou d'un événement. `null` signifie « sans terme »,
-- ce qui est le cas de toutes les lignes existantes. L'interface de réglage
-- viendra plus tard, mais la colonne existe dès maintenant et **toute lecture
-- de `group_members` filtre déjà les adhésions échues**.

alter table public.group_members
  add column if not exists expires_at timestamptz;

create index if not exists group_members_expires_at_idx
  on public.group_members (expires_at)
  where expires_at is not null;

-- Ces deux fonctions sont `security definer` : une politique de `group_members`
-- qui interrogerait `group_members` provoquerait une récursion infinie. Elles
-- servent aussi aux politiques des autres tables, qui restent ainsi lisibles.

create or replace function public.est_membre_du_groupe(
  p_group_id uuid,
  p_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.group_members m
    where m.group_id = p_group_id
      and m.user_id = p_user_id
      and (m.expires_at is null or m.expires_at > now())
  );
$$;

create or replace function public.est_admin_du_groupe(
  p_group_id uuid,
  p_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.group_members m
    where m.group_id = p_group_id
      and m.user_id = p_user_id
      and m.role = 'admin'
      and (m.expires_at is null or m.expires_at > now())
  );
$$;

grant execute on function public.est_membre_du_groupe(uuid, uuid)
  to authenticated;
grant execute on function public.est_admin_du_groupe(uuid, uuid)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Liens d'invitation
-- ---------------------------------------------------------------------------
-- Un lien partageable par SMS, messagerie ou e-mail, destiné à quelqu'un qui
-- n'a pas encore de compte. Le jeton est tiré côté client avec un générateur
-- cryptographique, puis rendu unique par la contrainte ci-dessous.

create table if not exists public.group_invite_links (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups (id) on delete cascade,
  created_by  uuid not null references auth.users (id) on delete cascade,
  token       text not null unique,
  expires_at  timestamptz not null default (now() + interval '30 days'),
  max_uses    integer,
  uses_count  integer not null default 0,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  constraint group_invite_links_max_uses_positif
    check (max_uses is null or max_uses > 0)
);

create index if not exists group_invite_links_group_id_idx
  on public.group_invite_links (group_id);

alter table public.group_invite_links enable row level security;

-- Lecture anonyme : le destinataire d'un lien n'a pas encore de session. Les
-- colonnes visibles sont restreintes par le `grant` plus bas — seul le couple
-- jeton / groupe sort de la table.
drop policy if exists lien_invitation_lecture_publique
  on public.group_invite_links;
create policy lien_invitation_lecture_publique
  on public.group_invite_links
  for select
  to anon
  using (true);

-- Lecture complète réservée aux membres du groupe : eux seuls voient qui a
-- créé le lien, combien de fois il a servi et jusqu'à quand il vaut.
drop policy if exists lien_invitation_lecture_membre
  on public.group_invite_links;
create policy lien_invitation_lecture_membre
  on public.group_invite_links
  for select
  to authenticated
  using (public.est_membre_du_groupe(group_id, auth.uid()));

drop policy if exists lien_invitation_creation on public.group_invite_links;
create policy lien_invitation_creation
  on public.group_invite_links
  for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.est_membre_du_groupe(group_id, auth.uid())
  );

-- Révocation : son auteur, ou n'importe quel admin du groupe.
drop policy if exists lien_invitation_revocation on public.group_invite_links;
create policy lien_invitation_revocation
  on public.group_invite_links
  for update
  to authenticated
  using (
    created_by = auth.uid()
    or public.est_admin_du_groupe(group_id, auth.uid())
  )
  with check (
    created_by = auth.uid()
    or public.est_admin_du_groupe(group_id, auth.uid())
  );

revoke all on public.group_invite_links from anon, authenticated;
grant select (token, group_id) on public.group_invite_links to anon;
grant select, insert, update on public.group_invite_links to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Aperçu public d'un lien
-- ---------------------------------------------------------------------------
-- La page `/rejoindre/<jeton>` doit présenter le groupe à quelqu'un qui n'a pas
-- de session : `groups` lui est fermée. Cette fonction n'expose que ce qui est
-- nécessaire à l'aperçu, et jamais la liste des membres.
--
-- `statut` vaut : valide, invalide, expire, revoque, epuise.

create or replace function public.apercu_groupe_par_jeton(jeton text)
returns table (
  statut          text,
  group_id        uuid,
  nom             text,
  description     text,
  photo_url       text,
  nombre_membres  integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  lien   public.group_invite_links%rowtype;
  groupe public.groups%rowtype;
begin
  select * into lien
  from public.group_invite_links l
  where l.token = jeton;

  if not found then
    return query select 'invalide'::text, null::uuid, null::text, null::text,
                        null::text, null::integer;
    return;
  end if;

  select * into groupe
  from public.groups g
  where g.id = lien.group_id
    and g.deleted_at is null;

  if not found then
    return query select 'invalide'::text, null::uuid, null::text, null::text,
                        null::text, null::integer;
    return;
  end if;

  return query
  select
    case
      when lien.revoked_at is not null then 'revoque'
      when lien.expires_at <= now() then 'expire'
      when lien.max_uses is not null and lien.uses_count >= lien.max_uses
        then 'epuise'
      else 'valide'
    end::text,
    groupe.id,
    groupe.name,
    groupe.description,
    groupe.photo_url,
    (
      select count(*)::integer
      from public.group_members m
      where m.group_id = groupe.id
        and (m.expires_at is null or m.expires_at > now())
    );
end;
$$;

grant execute on function public.apercu_groupe_par_jeton(text)
  to anon, authenticated;


-- ---------------------------------------------------------------------------
-- 5. Adhésion par jeton
-- ---------------------------------------------------------------------------
-- `security definer` : l'arrivant n'est pas encore membre, il ne peut donc pas
-- s'insérer lui-même dans `group_members` sous ses propres droits. La fonction
-- valide le jeton et incrémente le compteur dans la même transaction.
--
-- Renvoie : rejoint, deja_membre, invalide, expire, revoque, epuise,
-- non_connecte.

create or replace function public.rejoindre_groupe_par_jeton(jeton text)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur uuid := auth.uid();
  lien        public.group_invite_links%rowtype;
begin
  if utilisateur is null then
    return 'non_connecte';
  end if;

  -- `for update` sérialise deux arrivées simultanées sur le dernier jeton
  -- disponible d'un lien à usage limité.
  select * into lien
  from public.group_invite_links l
  where l.token = jeton
  for update;

  if not found then
    return 'invalide';
  end if;

  if not exists (
    select 1 from public.groups g
    where g.id = lien.group_id and g.deleted_at is null
  ) then
    return 'invalide';
  end if;

  if lien.revoked_at is not null then
    return 'revoque';
  end if;

  if lien.expires_at <= now() then
    return 'expire';
  end if;

  if public.est_membre_du_groupe(lien.group_id, utilisateur) then
    return 'deja_membre';
  end if;

  -- Une adhésion échue laisse sa ligne derrière elle : on la retire avant de
  -- réinsérer, la clé primaire étant le couple groupe / utilisateur.
  delete from public.group_members
  where group_id = lien.group_id and user_id = utilisateur;

  if lien.max_uses is not null and lien.uses_count >= lien.max_uses then
    return 'epuise';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (lien.group_id, utilisateur, 'member');

  update public.group_invite_links
  set uses_count = uses_count + 1
  where id = lien.id;

  return 'rejoint';
end;
$$;

grant execute on function public.rejoindre_groupe_par_jeton(text)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 6. Quitter un groupe
-- ---------------------------------------------------------------------------
-- Trois écritures dépendantes — retrait, promotion éventuelle, suppression
-- éventuelle. Les enchaîner depuis le client laisserait, en cas d'échec au
-- milieu, un groupe sans administrateur. D'où cette transaction unique.
--
-- Renvoie : parti, admin_transmis, groupe_supprime, non_membre.

create or replace function public.quitter_groupe(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur   uuid := auth.uid();
  etait_admin   boolean;
  restants      integer;
  autre_admin   boolean;
  successeur    uuid;
begin
  if utilisateur is null then
    return 'non_membre';
  end if;

  select (m.role = 'admin') into etait_admin
  from public.group_members m
  where m.group_id = p_group_id
    and m.user_id = utilisateur
    and (m.expires_at is null or m.expires_at > now());

  if not found then
    return 'non_membre';
  end if;

  delete from public.group_members
  where group_id = p_group_id and user_id = utilisateur;

  -- Les adhésions échues ne comptent pas : le dernier membre encore actif qui
  -- part referme bien le groupe.
  select count(*)::integer into restants
  from public.group_members m
  where m.group_id = p_group_id
    and (m.expires_at is null or m.expires_at > now());

  -- Dernier membre : le groupe n'a plus de raison d'être.
  if restants = 0 then
    update public.groups
    set deleted_at = now()
    where id = p_group_id and deleted_at is null;
    return 'groupe_supprime';
  end if;

  if not etait_admin then
    return 'parti';
  end if;

  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id
      and m.role = 'admin'
      and (m.expires_at is null or m.expires_at > now())
  ) into autre_admin;

  if autre_admin then
    return 'parti';
  end if;

  -- Plus aucun admin : le plus ancien membre encore actif reprend le rôle.
  select m.user_id into successeur
  from public.group_members m
  where m.group_id = p_group_id
    and (m.expires_at is null or m.expires_at > now())
  order by m.joined_at asc
  limit 1;

  update public.group_members
  set role = 'admin'
  where group_id = p_group_id and user_id = successeur;

  return 'admin_transmis';
end;
$$;

grant execute on function public.quitter_groupe(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 7. Recherche de profils par pseudo
-- ---------------------------------------------------------------------------
-- Passer par une fonction plutôt que d'ouvrir `profiles` en lecture : la
-- recherche fonctionne quelle que soit la politique RLS de la table, sans
-- l'assouplir. Seules les colonnes d'identité en ressortent — ni bio, ni
-- fuseau, ni date de dernière visite.

create or replace function public.chercher_profils_par_pseudo(terme text)
returns table (
  id          uuid,
  pseudo      text,
  first_name  text,
  last_name   text,
  avatar_url  text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.pseudo, p.first_name, p.last_name,
         coalesce('preset:' || p.avatar_preset, p.avatar_url)
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and length(trim(terme)) >= 2
    and p.pseudo like lower(trim(terme)) || '%'
  order by p.pseudo
  limit 20;
$$;

grant execute on function public.chercher_profils_par_pseudo(text)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 8. Membres d'un groupe, avec leur profil
-- ---------------------------------------------------------------------------
-- Même raison que la recherche : rien ne garantit qu'un membre puisse lire la
-- ligne `profiles` d'un autre. La fonction joint les deux tables sous ses
-- propres droits, mais ne répond qu'à un membre du groupe.

create or replace function public.membres_du_groupe(p_group_id uuid)
returns table (
  user_id     uuid,
  role        text,
  joined_at   timestamptz,
  expires_at  timestamptz,
  pseudo      text,
  first_name  text,
  last_name   text,
  avatar_url  text
)
language sql
security definer
set search_path = public
stable
as $$
  select m.user_id, m.role::text, m.joined_at, m.expires_at,
         p.pseudo, p.first_name, p.last_name,
         coalesce('preset:' || p.avatar_preset, p.avatar_url)
  from public.group_members m
  left join public.profiles p on p.id = m.user_id
  where m.group_id = p_group_id
    and (m.expires_at is null or m.expires_at > now())
    and public.est_membre_du_groupe(p_group_id, auth.uid())
  order by m.joined_at;
$$;

grant execute on function public.membres_du_groupe(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 9. Carnet de contacts
-- ---------------------------------------------------------------------------
-- Renvoie les relations de l'utilisateur — acceptées et en attente — avec le
-- profil d'en face et le favori du bon côté. `sens` vaut `sortant` si c'est
-- l'utilisateur qui a demandé, `entrant` sinon : l'écran ne propose d'accepter
-- que les demandes entrantes.

create or replace function public.mes_contacts()
returns table (
  autre_id    uuid,
  pseudo      text,
  first_name  text,
  last_name   text,
  avatar_url  text,
  statut      text,
  sens        text,
  favori      boolean,
  created_at  timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    case when c.requester_id = auth.uid() then c.addressee_id
         else c.requester_id end,
    p.pseudo, p.first_name, p.last_name,
    coalesce('preset:' || p.avatar_preset, p.avatar_url),
    c.status::text,
    case when c.requester_id = auth.uid() then 'sortant' else 'entrant' end,
    case when c.requester_id = auth.uid() then c.favorite_requester
         else c.favorite_addressee end,
    c.created_at
  from public.contacts c
  left join public.profiles p
    on p.id = case when c.requester_id = auth.uid() then c.addressee_id
                   else c.requester_id end
  where auth.uid() in (c.requester_id, c.addressee_id)
  order by p.first_name, p.last_name, p.pseudo;
$$;

grant execute on function public.mes_contacts() to authenticated;


-- ---------------------------------------------------------------------------
-- 10. Invitations nominatives
-- ---------------------------------------------------------------------------
-- L'aperçu réunit le groupe, son émetteur et son effectif : autant de lectures
-- qu'un invité, non membre, n'a pas le droit de faire lui-même.

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
    -- Quelques prénoms suffisent à situer le groupe ; l'invité n'a pas à
    -- connaître la liste complète avant d'avoir accepté.
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
    coalesce('preset:' || e.avatar_preset, e.avatar_url),
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

-- Inviter quelqu'un : réservé aux membres, et sans doublon en attente.
-- Renvoie : invite, deja_membre, deja_invite, non_membre.
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

  -- `type` est obligatoire : une seule table sert les invitations de groupe,
  -- d'événement et de tâche, discriminées par cette colonne.
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

-- Accepter : l'invité n'est pas encore membre, il ne peut donc pas s'insérer
-- lui-même dans `group_members`.
-- Renvoie : rejoint, deja_membre, invalide, expire.
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

create or replace function public.refuser_invitation(p_invitation_id uuid)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  update public.invitations
  set status = 'declined'
  where id = p_invitation_id
    and invitee_id = auth.uid()
    and status = 'pending';

  return case when found then 'refuse' else 'invalide' end;
end;
$$;

grant execute on function public.refuser_invitation(uuid) to authenticated;
