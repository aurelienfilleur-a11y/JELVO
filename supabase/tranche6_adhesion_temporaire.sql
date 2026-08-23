-- Tranche 6 — adhésion temporaire à un groupe.
--
-- Le script est idempotent : le rejouer ne casse rien.
--
-- `group_members.expires_at` existe depuis la tranche 2, et **toute lecture
-- filtre déjà les adhésions échues** — en SQL comme côté client. Ce qui
-- manquait, c'est de quoi *poser* un terme, et de quoi en tirer les
-- conséquences le moment venu.
--
--
-- CE QUI SE PASSE TOUT SEUL, ET CE QUI DEMANDE UNE ÉCRITURE
--
-- La distinction commande tout le fichier. À la seconde où `expires_at` est
-- passé :
--
--   * le groupe, ses tâches, ses événements et sa conversation **disparaissent
--     déjà** de l'application de l'intéressé, et il ne reçoit **déjà plus**
--     aucune notification du groupe. Rien à écrire : `est_membre_du_groupe`
--     porte la condition, et les rares endroits qui joignent `group_members`
--     directement la portent aussi ;
--   * en revanche, ce qui a été **écrit** en son nom reste écrit. Une tâche
--     lui reste assignée, une invitation à un événement lui reste attachée,
--     une notification déjà déposée reste dans sa boîte. Ces lignes-là ne
--     s'effacent pas d'elles-mêmes.
--
-- D'où `appliquer_adhesions_echues`, qui ne fait *que* la seconde moitié. Le
-- battement n'est donc pas ce qui fait expirer l'adhésion — elle est déjà
-- expirée — mais ce qui range derrière elle.
--
--
-- DEUX `expires_at` QUI NE PARLENT PAS DE LA MÊME CHOSE
--
-- `invitations.expires_at` et `group_invite_links.expires_at` disent jusqu'à
-- quand **l'invitation** vaut. Le terme de l'adhésion est une autre date, plus
-- lointaine en général, et porte donc un autre nom : `membership_expires_at`.
-- Les confondre donnerait une adhésion qui prend fin le jour où l'invitation
-- cesse d'être acceptable, ce qui n'a aucun sens.


-- ---------------------------------------------------------------------------
-- 1. Le terme voyage avec l'invitation
-- ---------------------------------------------------------------------------
-- Il est choisi par l'invitant, et ne doit pas dépendre du moment où
-- l'invitation est acceptée : une adhésion « jusqu'au 31 août » vaut jusqu'au
-- 31 août, qu'elle soit acceptée le 1er ou le 20.

alter table public.invitations
  add column if not exists membership_expires_at timestamptz;

comment on column public.invitations.membership_expires_at is
  'Terme de l''adhésion proposée ; null = adhésion permanente. À ne pas '
  'confondre avec expires_at, qui est la validité de l''invitation elle-même.';

alter table public.group_invite_links
  add column if not exists membership_expires_at timestamptz;

comment on column public.group_invite_links.membership_expires_at is
  'Terme de l''adhésion accordée par ce lien ; null = adhésion permanente.';

-- La lecture anonyme de `group_invite_links` reste restreinte au couple
-- (token, group_id) par un `grant` de colonnes : la nouvelle colonne n'y est
-- pas ajoutée. Quelqu'un qui n'a pas encore de compte n'a pas à savoir
-- combien de temps durerait son adhésion avant même de l'avoir demandée —
-- l'aperçu le lui dira, par une fonction, une fois le jeton reconnu.


-- ---------------------------------------------------------------------------
-- 2. Inviter avec un terme
-- ---------------------------------------------------------------------------
-- La signature gagne un paramètre. Un `create or replace` n'y suffit pas : il
-- créerait une **surcharge**, et l'appel à deux arguments deviendrait ambigu
-- (42725). L'ancienne version est donc retirée d'abord.

drop function if exists public.inviter_dans_groupe(uuid, uuid);

create or replace function public.inviter_dans_groupe(
  p_group_id                uuid,
  p_invitee                 uuid,
  p_membership_expires_at   timestamptz default null
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

  -- Un terme déjà passé donnerait une adhésion morte-née : l'intéressé
  -- accepterait et ne verrait rien. Mieux vaut refuser tout de suite.
  if p_membership_expires_at is not null
     and p_membership_expires_at <= now() then
    return 'terme_passe';
  end if;

  -- Seul un administrateur fixe un terme. N'importe quel membre peut inviter
  -- — c'est la règle d'avant, on n'y touche pas —, mais décider de la durée
  -- d'une adhésion relève de l'administration du groupe.
  if p_membership_expires_at is not null
     and not public.est_admin_du_groupe(p_group_id, auth.uid()) then
    return 'non_admin';
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
    (type, group_id, inviter_id, invitee_id, status, expires_at,
     membership_expires_at)
  values
    ('group', p_group_id, auth.uid(), p_invitee, 'pending',
     now() + interval '30 days', p_membership_expires_at);

  return 'invite';
end;
$$;

grant execute on function
  public.inviter_dans_groupe(uuid, uuid, timestamptz) to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Accepter : le terme est recopié sur l'adhésion
-- ---------------------------------------------------------------------------
-- Reprise intégrale de `correctif_invitations_type.sql`, à une ligne près :
-- `expires_at` de l'adhésion vient de `membership_expires_at` de l'invitation.
-- Un terme déjà passé au moment de l'acceptation est refusé plutôt qu'inséré :
-- accepter pour ne rien voir serait la plus déroutante des issues.

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

  if inv.membership_expires_at is not null
     and inv.membership_expires_at <= now() then
    update public.invitations set status = 'expired' where id = inv.id;
    return 'terme_passe';
  end if;

  if public.est_membre_du_groupe(inv.group_id, auth.uid()) then
    update public.invitations set status = 'accepted' where id = inv.id;
    return 'deja_membre';
  end if;

  -- Une adhésion échue laisse sa ligne derrière elle tant que le battement
  -- n'est pas passé : on la retire avant de réinsérer, la clé primaire étant
  -- le couple groupe / utilisateur.
  delete from public.group_members
  where group_id = inv.group_id and user_id = auth.uid();

  insert into public.group_members (group_id, user_id, role, expires_at)
  values (inv.group_id, auth.uid(), 'member', inv.membership_expires_at);

  update public.invitations set status = 'accepted' where id = inv.id;

  return 'rejoint';
end;
$$;

grant execute on function public.accepter_invitation(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Rejoindre par lien : même règle
-- ---------------------------------------------------------------------------

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

  if lien.membership_expires_at is not null
     and lien.membership_expires_at <= now() then
    return 'terme_passe';
  end if;

  if public.est_membre_du_groupe(lien.group_id, utilisateur) then
    return 'deja_membre';
  end if;

  delete from public.group_members
  where group_id = lien.group_id and user_id = utilisateur;

  if lien.max_uses is not null and lien.uses_count >= lien.max_uses then
    return 'epuise';
  end if;

  insert into public.group_members (group_id, user_id, role, expires_at)
  values (lien.group_id, utilisateur, 'member', lien.membership_expires_at);

  update public.group_invite_links
  set uses_count = uses_count + 1
  where id = lien.id;

  return 'rejoint';
end;
$$;

grant execute on function public.rejoindre_groupe_par_jeton(text)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Régler le terme d'une adhésion existante
-- ---------------------------------------------------------------------------
-- Prolonger, écourter et rendre permanent sont **la même écriture** : poser
-- une date, ou poser `null`. Trois fonctions diraient trois fois la même
-- chose, et la troisième finirait par diverger.
--
-- Renvoie : terme_defini, terme_retire, inchange, non_admin, non_membre,
-- terme_passe, dernier_admin.

create or replace function public.definir_terme_adhesion(
  p_group_id   uuid,
  p_user_id    uuid,
  p_expires_at timestamptz
)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  actuel      timestamptz;
  role_cible  public.member_role;
  admins      integer;
begin
  if not public.est_admin_du_groupe(p_group_id, auth.uid()) then
    return 'non_admin';
  end if;

  select m.expires_at, m.role into actuel, role_cible
  from public.group_members m
  where m.group_id = p_group_id
    and m.user_id = p_user_id
    and (m.expires_at is null or m.expires_at > now());

  if not found then
    return 'non_membre';
  end if;

  -- Écourter jusqu'à une date déjà passée, c'est retirer quelqu'un du groupe
  -- — avec des conséquences que « retirer un membre » annonce, confirmation
  -- comprise, et que ce chemin-ci n'annoncerait pas.
  if p_expires_at is not null and p_expires_at <= now() then
    return 'terme_passe';
  end if;

  -- Un groupe doit garder au moins un administrateur. Poser un terme sur le
  -- dernier, c'est programmer un groupe sans personne pour l'administrer :
  -- même règle que `retrograder_membre` et `retirer_membre`.
  if p_expires_at is not null and role_cible = 'admin'::member_role then
    select count(*)::integer into admins
    from public.group_members m
    where m.group_id = p_group_id
      and m.role = 'admin'::member_role
      and (m.expires_at is null or m.expires_at > now());

    if admins <= 1 then
      return 'dernier_admin';
    end if;
  end if;

  if actuel is not distinct from p_expires_at then
    return 'inchange';
  end if;

  update public.group_members
  set expires_at = p_expires_at
  where group_id = p_group_id and user_id = p_user_id;

  return case when p_expires_at is null then 'terme_retire'
              else 'terme_defini' end;
end;
$$;

grant execute on function
  public.definir_terme_adhesion(uuid, uuid, timestamptz) to authenticated;


-- ---------------------------------------------------------------------------
-- 6. Ranger derrière une adhésion échue
-- ---------------------------------------------------------------------------
-- Appelée à chaque battement par la fonction Edge `envoyer-push`, dans le
-- même passage que `empiler_rappels`. Voir l'en-tête pour ce qu'elle ne fait
-- pas : la disparition du groupe, elle, n'a besoin de personne.
--
-- **La suppression de la ligne est la mémoire.** Une fois retirée de
-- `group_members`, l'adhésion n'est plus sélectionnée : le passage suivant ne
-- la retraite pas. Pas de colonne `traite_le`, pas de table de suivi, et pas
-- de course entre deux battements — c'est le même principe que la clé
-- primaire de `push_reminders_sent`.
--
-- Renvoie le nombre d'adhésions rangées.

create or replace function public.appliquer_adhesions_echues()
returns integer
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  echue      record;
  traitees   integer := 0;
  restants   integer;
  autre_admin boolean;
  successeur uuid;
begin
  for echue in
    select m.group_id, m.user_id, m.role
    from public.group_members m
    where m.expires_at is not null
      and m.expires_at <= now()
    -- `skip locked` : deux battements qui se chevauchent — un redéploiement,
    -- une minute qui déborde — ne doivent pas se disputer les mêmes lignes.
    for update of m skip locked
  loop
    -- 1. Les tâches du groupe qui lui étaient assignées redeviennent libres.
    --    `definir_assignes_tache` est le chemin normal, mais il exige une
    --    session ; ici il n'y en a pas, et c'est le rangement d'une adhésion
    --    qui n'existe plus.
    delete from public.task_assignees a
    using public.tasks t
    where a.task_id = t.id
      and a.user_id = echue.user_id
      and t.group_id = echue.group_id;

    -- 2. Il n'est plus convié aux événements du groupe. Ceux qu'il a **créés**
    --    restent, avec leur `owner_id` : un événement organisé pour huit
    --    personnes ne disparaît pas parce que son auteur est parti, et un
    --    administrateur peut le supprimer — `supprimer_evenement` l'autorise
    --    déjà.
    delete from public.event_participants p
    using public.events e
    where p.event_id = e.id
      and p.user_id = echue.user_id
      and e.group_id = echue.group_id;

    -- 3. Les notifications encore ouvertes qui parlent de ce groupe sont
    --    refermées. Sans cela, la pastille resterait allumée sur une ligne
    --    qui ne mène plus nulle part — le groupe n'est plus ouvrable.
    update public.notifications
    set read_at = now()
    where user_id = echue.user_id
      and read_at is null
      and payload ->> 'group_id' = echue.group_id::text;

    -- 4. La file d'envoi est purgée de ce qui ne lui est plus destiné : une
    --    notification déposée il y a trente secondes ne doit pas arriver
    --    après coup.
    delete from public.push_outbox
    where user_id = echue.user_id
      and sent_at is null
      and url like '/groupes/' || echue.group_id::text || '%';

    -- 5. L'adhésion elle-même.
    delete from public.group_members
    where group_id = echue.group_id and user_id = echue.user_id;

    -- 6. Le groupe ne doit pas se retrouver sans personne, ni sans
    --    administrateur. Mêmes règles que `quitter_groupe`, et pour la même
    --    raison : un groupe sans admin ne peut plus ni inviter, ni se
    --    modifier, ni se supprimer.
    select count(*)::integer into restants
    from public.group_members m
    where m.group_id = echue.group_id
      and (m.expires_at is null or m.expires_at > now());

    if restants = 0 then
      update public.groups
      set deleted_at = now()
      where id = echue.group_id and deleted_at is null;
    elsif echue.role = 'admin'::member_role then
      select exists (
        select 1 from public.group_members m
        where m.group_id = echue.group_id
          and m.role = 'admin'::member_role
          and (m.expires_at is null or m.expires_at > now())
      ) into autre_admin;

      if not autre_admin then
        select m.user_id into successeur
        from public.group_members m
        where m.group_id = echue.group_id
          and (m.expires_at is null or m.expires_at > now())
        order by m.joined_at asc
        limit 1;

        update public.group_members
        set role = 'admin'::member_role
        where group_id = echue.group_id and user_id = successeur;
      end if;
    end if;

    traitees := traitees + 1;
  end loop;

  return traitees;
end;
$$;

-- Personne ne l'appelle depuis l'application : c'est le battement qui la
-- déclenche, sous `service_role`. Aucun `grant` à `authenticated` — un membre
-- n'a pas à provoquer le rangement des adhésions de tout le monde.
grant execute on function public.appliquer_adhesions_echues() to service_role;


-- ---------------------------------------------------------------------------
-- 7. Voir le terme dans l'aperçu d'un lien
-- ---------------------------------------------------------------------------
-- `apercu_groupe_par_jeton` gagne une colonne de sortie, ce qu'un
-- `create or replace` refuse sur un `returns table` : il faut supprimer
-- d'abord. La fonction est appelée **sans session** par la page d'invitation,
-- d'où le `grant` à `anon` comme à `authenticated`.

drop function if exists public.apercu_groupe_par_jeton(text);

create or replace function public.apercu_groupe_par_jeton(jeton text)
returns table (
  statut                 text,
  group_id               uuid,
  nom                    text,
  description            text,
  photo_url              text,
  nombre_membres         integer,
  membership_expires_at  timestamptz
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
                        null::text, null::integer, null::timestamptz;
    return;
  end if;

  select * into groupe
  from public.groups g
  where g.id = lien.group_id and g.deleted_at is null;

  if not found then
    return query select 'invalide'::text, null::uuid, null::text, null::text,
                        null::text, null::integer, null::timestamptz;
    return;
  end if;

  return query
  select case
           when lien.revoked_at is not null then 'revoque'
           when lien.expires_at <= now() then 'expire'
           -- Un lien dont le terme d'adhésion est déjà passé n'ouvre plus
           -- rien : `rejoindre_groupe_par_jeton` le refuse. Il est annoncé
           -- « expiré » plutôt que d'inventer un sixième état pour une
           -- nuance que le destinataire n'a pas à démêler — l'offre a bien
           -- expiré, seule la cause diffère.
           when lien.membership_expires_at is not null
                and lien.membership_expires_at <= now() then 'expire'
           when lien.max_uses is not null
                and lien.uses_count >= lien.max_uses then 'epuise'
           else 'valide'
         end::text,
         groupe.id,
         groupe.name,
         groupe.description,
         groupe.photo_url,
         (select count(*)::integer
            from public.group_members m
           where m.group_id = groupe.id
             and (m.expires_at is null or m.expires_at > now())),
         lien.membership_expires_at;
end;
$$;

grant execute on function public.apercu_groupe_par_jeton(text)
  to anon, authenticated;


-- ---------------------------------------------------------------------------
-- 8. Voir le terme dans une invitation nominative
-- ---------------------------------------------------------------------------
-- Même raison, même contrainte : une colonne de sortie de plus impose un
-- `drop function`. On ne s'en dispense pas — accepter une adhésion sans
-- savoir qu'elle s'arrête dans dix jours serait une mauvaise surprise, et
-- c'est **l'invité** qui la découvrirait.
--
-- Reprise de `correctif_invitations_type.sql`, à la dernière colonne près.

drop function if exists public.mes_invitations();

create or replace function public.mes_invitations()
returns table (
  id                    uuid,
  group_id              uuid,
  nom                   text,
  description           text,
  photo_url             text,
  nombre_membres        integer,
  membres_apercu        text[],
  emetteur              text,
  emetteur_avatar       text,
  statut                text,
  created_at            timestamptz,
  expires_at            timestamptz,
  membership_expires_at timestamptz
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
    coalesce('preset:' || e.avatar_preset, e.avatar_url),
    i.status::text,
    i.created_at,
    i.expires_at,
    i.membership_expires_at
  from public.invitations i
  join public.groups g on g.id = i.group_id and g.deleted_at is null
  left join public.profiles e on e.id = i.inviter_id
  where i.invitee_id = auth.uid()
    and i.type = 'group'
    and i.status = 'pending'
  order by i.created_at desc;
$$;

grant execute on function public.mes_invitations() to authenticated;
