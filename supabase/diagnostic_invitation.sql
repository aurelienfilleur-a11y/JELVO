-- Diagnostic — pourquoi l'invitation nominative échoue.
--
-- **Ce fichier ne corrige rien.** Il rejoue l'appel exact que fait
-- l'application, sous le même rôle, dans une transaction annulée à la fin.
-- L'erreur PostgreSQL remonte alors telle quelle dans l'éditeur SQL, avec son
-- SQLSTATE — ce que trois correctifs à l'aveugle n'ont pas permis d'obtenir.
--
-- Rien n'est écrit : le `rollback` final annule tout, y compris l'invitation
-- de test et la notification éventuelle.
--
--
-- MODE D'EMPLOI
--
--   1. Exécutez la PARTIE A telle quelle : elle décrit l'état réel.
--   2. Renseignez les trois identifiants dans la PARTIE B, puis exécutez-la.
--   3. Transmettez la sortie complète.


-- ===========================================================================
-- PARTIE A — état réel, en lecture seule
-- ===========================================================================

-- A1. Qui possède les tables, et la sécurité y est-elle forcée ?
--
-- `security definer` ne contourne pas RLS : il change seulement le rôle sous
-- lequel la fonction s'exécute. RLS n'est contournée que si ce rôle possède la
-- table (et que `force row level security` n'est pas activé) ou porte
-- l'attribut `bypassrls`. C'est le point que l'état fourni ne dit pas encore.
select
  c.relname                        as table_name,
  pg_get_userbyid(c.relowner)      as proprietaire,
  c.relrowsecurity                 as rls_activee,
  c.relforcerowsecurity            as rls_forcee
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('notifications', 'invitations', 'group_members')
order by c.relname;

-- A2. Qui possède les fonctions, et ce rôle contourne-t-il RLS ?
--
-- Si `proprietaire` diffère du propriétaire de `notifications` en A1, et que
-- `bypassrls` vaut false, alors le déclencheur est bel et bien soumis à RLS —
-- et l'absence de politique INSERT devient la cause.
select
  p.proname                        as fonction,
  pg_get_userbyid(p.proowner)      as proprietaire,
  r.rolbypassrls                   as bypassrls,
  r.rolsuper                       as superuser,
  p.prosecdef                      as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_roles r on r.oid = p.proowner
where n.nspname = 'public'
  and p.proname in (
    'notifier_invitation_groupe',
    'clore_notification_invitation',
    'inviter_dans_groupe'
  )
order by p.proname;

-- A3. Privilèges de table sur `notifications`.
--
-- Une politique RLS ne sert à rien sans le `grant` correspondant : sans
-- privilège INSERT, l'erreur est « permission denied for table », pas un refus
-- de politique.
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'notifications'
order by grantee, privilege_type;

-- A4. Politiques réellement présentes sur `notifications`.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'notifications'
order by policyname;

-- A5. Contraintes de `notifications` — une liste fermée sur `type` ou une clé
-- étrangère inattendue expliqueraient un 23514 ou un 23503.
select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.notifications'::regclass
order by conname;

-- A6. Colonnes de `notifications` : type, obligation, valeur par défaut.
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'notifications'
order by ordinal_position;


-- ===========================================================================
-- PARTIE B — reproduction de l'appel, sous le rôle de l'application
-- ===========================================================================
--
-- Remplacez les trois valeurs ci-dessous, puis exécutez le bloc entier.
--
--   INVITEUR  : votre identifiant utilisateur (celui qui invite)
--   GROUPE    : un groupe dont l'inviteur est membre
--   INVITE    : l'identifiant de la personne à inviter
--
-- Pour les retrouver :
--   select id, email from auth.users;
--   select id, name from public.groups where deleted_at is null;

begin;

-- PostgREST exécute les requêtes sous le rôle `authenticated`, avec le jeton
-- dans `request.jwt.claims`. On reproduit exactement ce contexte : sans cela,
-- l'appel tournerait sous le propriétaire et ne prouverait rien.
set local role authenticated;
set local request.jwt.claims = '{"sub":"INVITEUR","role":"authenticated"}';

select public.inviter_dans_groupe(
  'GROUPE'::uuid,
  'INVITE'::uuid
) as resultat;

-- Ce qui aurait été écrit, si l'appel a abouti.
select id, group_id, inviter_id, invitee_id, status
from public.invitations
order by created_at desc
limit 3;

select id, user_id, type, payload
from public.notifications
order by created_at desc
limit 3;

rollback;

-- Si l'appel échoue, l'éditeur SQL affiche l'erreur complète — SQLSTATE,
-- message, détail, indice. C'est cette sortie qui désigne la cause.
--
-- Lecture rapide des cas :
--   42501 « permission denied for table notifications » → privilège manquant
--   42501 « new row violates row-level security policy » → politique manquante
--   23514 « violates check constraint »                 → liste fermée sur type
--   23502 « null value in column ... violates not-null» → valeur par défaut
--   23503 « violates foreign key constraint »           → cible de user_id
--   42P01 / 42883 « does not exist »                    → objet non déployé
