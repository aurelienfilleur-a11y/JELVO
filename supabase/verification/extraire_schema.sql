-- Extraction du schéma réel — lecture seule.
--
-- Produit `supabase/schema_actuel.sql`, l'instantané que le workflow
-- `migrations-supabase.yml` recommite après chaque application de migrations.
--
-- Pourquoi une introspection du catalogue plutôt que `pg_dump` : `pg_dump`
-- refuse de tourner contre un serveur plus récent que lui, et la version de
-- PostgreSQL de Supabase n'est pas celle du runner GitHub. Une requête, elle,
-- marche quelle que soit la version, et donne exactement ce dont on a besoin
-- — colonnes obligatoires, valeurs d'énumération, politiques RLS — sans les
-- milliers de lignes d'un dump complet.
--
-- La sortie est triée de façon **déterministe** : un instantané qui changerait
-- d'ordre d'une exécution à l'autre produirait un commit à chaque push, et le
-- bruit finirait par masquer les vrais changements.
--
-- À lancer avec `psql -At -f`, sortie redirigée dans le fichier.

\pset footer off

select '-- Schéma réel de la base Jelvo — NE PAS MODIFIER À LA MAIN.'
union all select '--'
union all select '-- Généré par supabase/verification/extraire_schema.sql, exécuté par le'
union all select '-- workflow migrations-supabase.yml après chaque application de migrations.'
union all select '--'
union all select '-- Ce fichier n''est pas une migration : on ne l''exécute pas. C''est la'
union all select '-- **vérité** contre laquelle vérifier une insertion avant de la livrer, au'
union all select '-- lieu de la deviner. C''est ce qui manquait le jour où invitations.type,'
union all select '-- colonne obligatoire du schéma initial, a été oubliée par'
union all select '-- inviter_dans_groupe : 23502, et plusieurs jours de diagnostic.'
union all select '--'
union all select '-- Version du serveur : ' || current_setting('server_version');

-- ---------------------------------------------------------------------------
-- Types énumérés
-- ---------------------------------------------------------------------------
select E'\n\n-- =========================================================\n'
       '-- TYPES ÉNUMÉRÉS\n'
       '-- =========================================================';

select format(
         'create type public.%I as enum (%s);',
         t.typname,
         string_agg(quote_literal(e.enumlabel), ', ' order by e.enumsortorder)
       )
from pg_type t
join pg_enum e on e.enumtypid = t.oid
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
group by t.typname
order by t.typname;

-- ---------------------------------------------------------------------------
-- Tables et colonnes
-- ---------------------------------------------------------------------------
-- `not null` sans valeur par défaut est signalé : c'est la classe d'erreur qui
-- coûte un 23502 quand une insertion l'oublie.
select E'\n\n-- =========================================================\n'
       '-- TABLES ET COLONNES\n'
       '-- =========================================================';

select ligne from (
  select
    c.relname                                            as table_tri,
    0                                                    as rang,
    format(E'\n-- %s%s', c.relname,
           case when c.relrowsecurity then ' [RLS activée]'
                else ' [RLS DÉSACTIVÉE]' end)            as ligne
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'

  union all

  select
    c.relname,
    a.attnum,
    format(
      '--   %-20s %-28s %s',
      a.attname,
      format_type(a.atttypid, a.atttypmod),
      case
        when a.attnotnull and d.adbin is null then 'NOT NULL, sans défaut'
        when a.attnotnull then 'NOT NULL, défaut ' || pg_get_expr(d.adbin, d.adrelid)
        when d.adbin is not null then 'défaut ' || pg_get_expr(d.adbin, d.adrelid)
        else ''
      end
    )
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid
  left join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum
  where n.nspname = 'public'
    and c.relkind = 'r'
    and a.attnum > 0
    and not a.attisdropped
) lignes
order by table_tri, rang;

-- ---------------------------------------------------------------------------
-- Contraintes
-- ---------------------------------------------------------------------------
select E'\n\n-- =========================================================\n'
       '-- CONTRAINTES\n'
       '-- =========================================================';

select format('-- %-24s %s', rel.relname,
              con.conname || ' : ' || pg_get_constraintdef(con.oid))
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace n on n.oid = rel.relnamespace
where n.nspname = 'public'
order by rel.relname, con.contype, con.conname;

-- ---------------------------------------------------------------------------
-- Politiques RLS
-- ---------------------------------------------------------------------------
-- Sans politique, une table dont RLS est activée est **vide** pour
-- l'application. Avec une politique SELECT trop stricte, c'est le `returning`
-- d'une insertion qui échoue en 42501.
select E'\n\n-- =========================================================\n'
       '-- POLITIQUES RLS\n'
       '-- =========================================================';

select format(E'-- %-24s %-28s %-6s %s\n--   using       : %s\n--   with check  : %s',
              tablename, policyname, cmd, roles::text,
              coalesce(qual, '—'), coalesce(with_check, '—'))
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;

-- ---------------------------------------------------------------------------
-- Fonctions
-- ---------------------------------------------------------------------------
-- Signature, mode de sécurité et propriétaire. `security definer` ne contourne
-- pas RLS : il change le rôle d'exécution, et c'est la propriété de la table
-- ou `bypassrls` qui décide. D'où le propriétaire dans la sortie.
select E'\n\n-- =========================================================\n'
       '-- FONCTIONS\n'
       '-- =========================================================';

select format('-- %s(%s) → %s   [%s, %s]',
              p.proname,
              pg_get_function_arguments(p.oid),
              pg_get_function_result(p.oid),
              case when p.prosecdef then 'security definer' else 'security invoker' end,
              pg_get_userbyid(p.proowner))
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
order by p.proname, pg_get_function_arguments(p.oid);

-- ---------------------------------------------------------------------------
-- Déclencheurs
-- ---------------------------------------------------------------------------
select E'\n\n-- =========================================================\n'
       '-- DÉCLENCHEURS\n'
       '-- =========================================================';

select format('-- %-24s %s', rel.relname, pg_get_triggerdef(t.oid))
from pg_trigger t
join pg_class rel on rel.oid = t.tgrelid
join pg_namespace n on n.oid = rel.relnamespace
where n.nspname = 'public'
  and not t.tgisinternal
order by rel.relname, t.tgname;

-- ---------------------------------------------------------------------------
-- Privilèges de table
-- ---------------------------------------------------------------------------
-- Une politique RLS ne sert à rien sans le `grant` correspondant : sans
-- privilège, l'erreur est « permission denied for table », et non un refus de
-- politique. Les deux sont en 42501 et se confondent facilement.
select E'\n\n-- =========================================================\n'
       '-- PRIVILÈGES (anon, authenticated)\n'
       '-- =========================================================';

select format('-- %-24s %-16s %s', table_name, grantee,
              string_agg(privilege_type, ', ' order by privilege_type))
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
group by table_name, grantee
order by table_name, grantee;
