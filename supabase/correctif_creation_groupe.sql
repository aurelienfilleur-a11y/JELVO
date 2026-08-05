-- Correctif — création de groupe refusée par RLS.
--
-- À exécuter dans l'éditeur SQL du projet Supabase. Idempotent.
--
--
-- LE PROBLÈME
--
-- L'application créait un groupe en deux temps :
--
--   1. insert into groups (…) returning *      ← échouait ici
--   2. insert into group_members (…) role admin
--
-- La politique de lecture de `groups` est :
--
--   groups_select : using (is_group_member(id) and deleted_at is null)
--
-- Or PostgreSQL applique **les politiques SELECT au `returning` d'un insert**
-- (documentation « Row Security Policies » : si la commande porte un
-- `returning`, la ligne insérée doit être visible, sinon la commande échoue).
-- À l'instant de l'étape 1, le créateur n'est pas encore dans `group_members` :
-- `is_group_member(id)` vaut donc faux, la ligne tout juste insérée est
-- invisible, et PostgreSQL lève :
--
--   42501 — new row violates row-level security policy (USING expression)
--           for table "groups"
--
-- que l'application traduit par « Vous n'avez pas les droits nécessaires pour
-- cette action ». L'insertion elle-même passait sans peine : c'est bien la
-- relecture qui échouait.
--
-- Un déclencheur `after insert on groups` qui inscrirait le créateur comme
-- admin **ne suffit pas** à réparer ce cas : les déclencheurs `after row` ne
-- s'exécutent qu'en fin d'instruction, alors que le contrôle de visibilité du
-- `returning` a lieu au moment même de l'insertion. Le groupe n'est donc
-- toujours pas visible quand le contrôle tombe.
--
--
-- LE CORRECTIF
--
-- Une fonction `security definer` qui insère le groupe **et** l'adhésion
-- administrateur dans la même transaction, puis renvoie la ligne. Elle est
-- indifférente à la présence d'un déclencheur : si le créateur a déjà été
-- inscrit, elle se contente de confirmer son rôle.
--
-- Aucune politique n'est assouplie : `groups_select` reste « membre du groupe
-- uniquement ».


create or replace function public.creer_groupe(
  p_name        text,
  p_description text default null,
  p_photo_url   text default null,
  p_is_private  boolean default true
)
returns public.groups
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur uuid := auth.uid();
  nouveau     public.groups%rowtype;
  nom         text := nullif(trim(both ' ' from coalesce(p_name, '')), '');
begin
  if utilisateur is null then
    raise exception 'Session absente' using errcode = '42501';
  end if;

  if nom is null then
    raise exception 'Le nom du groupe est obligatoire' using errcode = '23514';
  end if;

  insert into public.groups (name, description, photo_url, is_private, created_by)
  values (
    nom,
    nullif(trim(both ' ' from coalesce(p_description, '')), ''),
    p_photo_url,
    coalesce(p_is_private, true),
    utilisateur
  )
  returning * into nouveau;

  -- Un déclencheur a pu inscrire le créateur avant nous : on ne suppose ni sa
  -- présence, ni son absence. Pas d'`on conflict`, pour ne dépendre d'aucun
  -- nom de contrainte.
  if exists (
    select 1 from public.group_members m
    where m.group_id = nouveau.id and m.user_id = utilisateur
  ) then
    update public.group_members
    set role = 'admin', expires_at = null
    where group_id = nouveau.id and user_id = utilisateur;
  else
    insert into public.group_members (group_id, user_id, role)
    values (nouveau.id, utilisateur, 'admin');
  end if;

  return nouveau;
end;
$$;

revoke all on function public.creer_groupe(text, text, text, boolean) from public;
grant execute on function public.creer_groupe(text, text, text, boolean)
  to authenticated;


-- ---------------------------------------------------------------------------
-- Adhésions échues et politiques existantes
-- ---------------------------------------------------------------------------
-- `is_group_member` et `is_group_admin` sont vos fonctions ; elles portent vos
-- politiques sur `groups` et `group_members`. Elles ont été écrites avant la
-- colonne `expires_at` de la tranche 2 et ignorent donc le terme d'une
-- adhésion temporaire : un membre expiré continuerait de passer les politiques,
-- alors que l'application, elle, le filtre déjà partout.
--
-- Le bloc ci-dessous les remet d'aplomb. Il est enveloppé dans un `do` avec
-- rattrapage d'erreur : PostgreSQL refuse de renommer un paramètre d'entrée par
-- `create or replace`, et rien ne garantit que le vôtre s'appelle `p_group_id`.
-- En cas d'échec, le script continue et vous affiche quoi corriger à la main —
-- le correctif principal, lui, est déjà appliqué.

do $bloc$
begin
  execute $fn$
    create or replace function public.is_group_member(p_group_id uuid)
    returns boolean
    language sql
    security definer
    set search_path = public
    stable
    as $corps$
      select exists (
        select 1 from public.group_members m
        where m.group_id = p_group_id
          and m.user_id = auth.uid()
          and (m.expires_at is null or m.expires_at > now())
      );
    $corps$;
  $fn$;

  execute $fn$
    create or replace function public.is_group_admin(p_group_id uuid)
    returns boolean
    language sql
    security definer
    set search_path = public
    stable
    as $corps$
      select exists (
        select 1 from public.group_members m
        where m.group_id = p_group_id
          and m.user_id = auth.uid()
          and m.role = 'admin'
          and (m.expires_at is null or m.expires_at > now())
      );
    $corps$;
  $fn$;

  raise notice 'is_group_member et is_group_admin filtrent désormais les adhésions échues.';
exception when others then
  raise notice 'is_group_member / is_group_admin laissées en l''état (%). '
               'Ajoutez-y « and (expires_at is null or expires_at > now()) » '
               'en conservant le nom de paramètre existant.', sqlerrm;
end;
$bloc$;
