-- ===========================================================================
-- Inventaire canonique d'une base Jelvo
-- ===========================================================================
--
-- Rend une liste de lignes `clé<TAB>valeur`, triée, destinée à être
-- **confrontée par `diff`** entre deux bases : celle qu'on vient de dumper et
-- celle qu'on vient de restaurer.
--
--     psql … -At -f inventaire.sql > avant.txt     # au moment du dump
--     psql … -At -f inventaire.sql > apres.txt     # après restauration
--     diff avant.txt apres.txt
--
--
-- POURQUOI UN DIFF ET NON DES NOMBRES ÉCRITS À LA MAIN
--
-- Un contrôle de restauration qui dirait « il doit y avoir 60 tables et
-- 32 messages » serait faux au premier message envoyé, et quelqu'un
-- finirait par relever le nombre sans se demander pourquoi il a changé. Un
-- chiffre écrit à la main ne proteste jamais quand il devient faux — c'est
-- déjà la règle des contrastes du thème sombre, recalculés plutôt que
-- recopiés.
--
-- Ici les deux côtés du diff sont **générés par le même fichier**. Il n'y a
-- aucune attente à tenir à jour : ce qui est éprouvé, c'est que la
-- restauration rend exactement ce que le dump a emporté.
--
--
-- DEUX NIVEAUX, ET LA DISTINCTION N'EST PAS DU CONFORT
--
-- Les lignes préfixées `jelvo` portent **nos** données et **nos** règles :
-- toute différence y est fatale. Les lignes préfixées `interne` décrivent les
-- objets que Supabase pose dans `auth` et `storage` — ils sont dumpés, mais
-- leur restauration dans un cluster nu peut légitimement diverger (rôles
-- propriétaires absents, extensions non installées). Elles sont affichées,
-- jamais fatales.
--
-- Sans cette séparation, l'épreuve nocturne échouerait chaque nuit pour une
-- raison bénigne — et une alerte qui crie tous les jours ne se lit plus.
-- C'est le même défaut qu'un contrôle rouge en permanence, déjà écarté pour
-- `tool/pieges_migrations.py`.

\pset tuples_only on
\pset format unaligned
\pset fieldsep '\t'
\pset recordsep '\n'

-- ---------------------------------------------------------------------------
-- Les lignes de chaque table, comptées pour de vrai
-- ---------------------------------------------------------------------------
--
-- `query_to_xml` permet de compter toutes les tables en **une** instruction :
-- un `count(*)` par table demanderait une boucle plpgsql, donc une fonction à
-- créer dans la base qu'on inspecte — ce qu'on ne veut surtout pas faire sur
-- une base restaurée qu'on est en train de juger.
--
-- Et c'est un compte exact, pas `reltuples` : celui de `pg_class` est une
-- estimation posée par le dernier `analyze`, qui n'a pas tourné sur une base
-- fraîchement restaurée. Il y vaudrait -1 partout.
select 'jelvo	table	' || n.nspname || '.' || c.relname || '	' ||
       (xpath(
          '/row/c/text()',
          query_to_xml(
            format('select count(*) as c from %I.%I', n.nspname, c.relname),
            false, true, '')
        ))[1]::text
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where c.relkind = 'r'
   and n.nspname = 'public'
 order by 1;

-- `auth.users` est à part, et c'est la ligne la plus importante du fichier :
-- sans elle, personne ne retrouve son compte. Le reste de `auth` est interne
-- à Supabase ; celle-ci est à nous autant qu'à eux.
select 'jelvo	table	auth.users	' || count(*)::text from auth.users;

-- ---------------------------------------------------------------------------
-- Nos fonctions, avec leur signature complète
-- ---------------------------------------------------------------------------
--
-- La signature et non le seul nom : c'est ce qui a coûté plusieurs
-- `drop function` à ce projet, et une fonction restaurée avec une colonne de
-- sortie en moins serait indétectable par son nom seul.
select 'jelvo	fonction	' || p.proname || '(' ||
       pg_get_function_identity_arguments(p.oid) || ') -> ' ||
       pg_get_function_result(p.oid)
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
 order by 1;

-- ---------------------------------------------------------------------------
-- Déclencheurs, politiques, et l'état de RLS
-- ---------------------------------------------------------------------------
select 'jelvo	declencheur	' || c.relname || '.' || t.tgname ||
       '	' || p.proname
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc p on p.oid = t.tgfoid
 where not t.tgisinternal
   and n.nspname = 'public'
 order by 1;

-- `polcmd` est un `"char"`, et `text || "char"` est **ambigu** : PostgreSQL
-- refuse de choisir entre les candidats. Trouvé en exécutant, pas en relisant
-- — `create` ne prouve rien, c'est déjà la règle du test de fumée.
select 'jelvo	politique	' || c.relname || '.' || pol.polname ||
       '	' || pol.polcmd::text
  from pg_policy pol
  join pg_class c on c.oid = pol.polrelid
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
 order by 1;

-- RLS activée mais **sans politique** est précisément la forme de
-- `signalements`, `moderateurs` et `blocages` : la table est fermée, et les
-- fonctions `security definer` en sont la seule porte. Une restauration qui
-- perdrait le `enable row level security` rouvrirait ces trois tables.
select 'jelvo	rls	' || c.relname || '	' || c.relrowsecurity::text
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where c.relkind = 'r' and n.nspname = 'public'
 order by 1;

-- ---------------------------------------------------------------------------
-- Les privilèges, qui sont la vraie barrière
-- ---------------------------------------------------------------------------
--
-- Tout le durcissement de la tranche 7 est fait de `grant` et de `revoke`.
-- Une base restaurée sans eux serait grande ouverte **sans qu'aucune donnée
-- ne manque** : c'est le genre de défaut qu'un contrôle de volumétrie ne
-- verrait jamais.
select 'jelvo	privilege	' || table_schema || '.' || table_name ||
       '	' || grantee || '	' || privilege_type
  from information_schema.table_privileges
 where table_schema in ('public', 'storage')
   and grantee in ('anon', 'authenticated', 'service_role')
 order by 1;

-- Et les droits d'exécution, dont la tranche 7 ferme 106 et rouvre 73.
select 'jelvo	execution	' || p.proname || '	' || r.rolname || '	' ||
       has_function_privilege(r.rolname, p.oid, 'execute')::text
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join (select unnest(array['anon', 'authenticated']) as rolname) r
 where n.nspname = 'public'
   and exists (select 1 from pg_roles where rolname = r.rolname)
 order by 1;

-- ---------------------------------------------------------------------------
-- Les types énumérés, dont les valeurs exactes comptent
-- ---------------------------------------------------------------------------
--
-- `member_role`, `contact_status`, `invitation_type`… — une valeur perdue à la
-- restauration ferait échouer une écriture plusieurs jours plus tard, loin de
-- sa cause.
select 'jelvo	enum	' || t.typname || '	' ||
       string_agg(e.enumlabel, ',' order by e.enumsortorder)
  from pg_type t
  join pg_enum e on e.enumtypid = t.oid
  join pg_namespace n on n.oid = t.typnamespace
 where n.nspname = 'public'
 group by t.typname
 order by 1;

-- ---------------------------------------------------------------------------
-- Ce qui est interne à Supabase : relevé, jamais fatal
-- ---------------------------------------------------------------------------
select 'interne	table	' || n.nspname || '.' || c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where c.relkind = 'r'
   and n.nspname in ('auth', 'storage')
 order by 1;
