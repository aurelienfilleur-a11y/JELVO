-- Diagnostic — création d'une tâche et d'un événement.
--
-- **Ce fichier ne corrige rien et n'écrit rien.** Il rejoue les appels exacts
-- que fait l'application, sous le rôle `authenticated`, dans une transaction
-- annulée à la fin. L'erreur PostgreSQL remonte alors telle quelle dans
-- l'éditeur SQL, avec son SQLSTATE.
--
-- Même modèle que `diagnostic_invitation.sql`, qui avait fini par livrer la
-- vraie cause — `invitations.type`, colonne obligatoire jamais renseignée —
-- après trois correctifs à l'aveugle. La leçon tient en une phrase : demander
-- l'erreur à la base coûte moins cher que la deviner.
--
--
-- MODE D'EMPLOI
--
--   1. Exécutez la PARTIE A telle quelle : elle est en lecture seule et se
--      suffit à elle-même. A0 est la plus importante — elle confronte
--      mécaniquement les insertions du code aux colonnes réelles.
--   2. Retrouvez vos identifiants avec les requêtes de la PARTIE B, reportez-les
--      à la place de MOI et GROUPE, puis exécutez le bloc.
--   3. Transmettez la sortie complète.


-- ===========================================================================
-- PARTIE A — état réel, en lecture seule
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A0. Une insertion oublie-t-elle une colonne obligatoire ?
-- ---------------------------------------------------------------------------
-- C'est la requête qui aurait évité la panne d'`invitations.type`.
--
-- Le sondage employé à l'époque énumérait des noms de colonnes *candidats* :
-- il ne pouvait voir que ce qu'on avait pensé à chercher, et `type` n'était pas
-- dans la liste. Ici, le sens de la comparaison est inversé — c'est le
-- catalogue de PostgreSQL qui énumère, et la liste du code qui est confrontée.
-- Aucune colonne ne peut donc échapper à l'examen.
--
-- La table `attendu` recopie, une ligne par site d'insertion, les colonnes que
-- `tranche3_taches_et_evenements.sql` renseigne réellement. **À tenir à jour**
-- en même temps que les fonctions.
--
-- Toute ligne renvoyée est un défaut : une colonne `not null`, sans valeur par
-- défaut, ni générée ni d'identité, qu'une insertion ne fournit pas. Aucune
-- ligne = rien à signaler.

with attendu(fonction, table_cible, colonnes) as (
  values
    ('creer_tache', 'tasks', array[
      'group_id', 'created_by', 'title', 'description', 'due_at',
      'priority', 'reminder_at', 'rrule']),
    ('creer_tache', 'task_assignees', array['task_id', 'user_id', 'status']),
    ('creer_tache', 'task_list_items', array['task_id', 'label', 'position']),
    ('definir_assignes_tache', 'task_assignees',
      array['task_id', 'user_id', 'status']),
    ('ajouter_article', 'task_list_items',
      array['task_id', 'label', 'position']),
    ('creer_evenement', 'events', array[
      'group_id', 'owner_id', 'title', 'description', 'starts_at', 'ends_at',
      'location', 'rrule', 'image_url', 'reminder_minutes']),
    ('creer_evenement', 'event_participants',
      array['event_id', 'user_id', 'response']),
    ('repondre_evenement', 'event_participants',
      array['event_id', 'user_id', 'response', 'responded_at'])
)
select
  a.fonction,
  a.table_cible,
  c.column_name    as colonne_obligatoire_absente,
  c.udt_name       as type_sql
from attendu a
join information_schema.columns c
  on c.table_schema = 'public'
 and c.table_name   = a.table_cible
where c.is_nullable        = 'NO'
  and c.column_default    is null
  and c.is_generated       = 'NEVER'
  and c.identity_generation is null
  and not (c.column_name = any(a.colonnes))
order by a.table_cible, a.fonction, c.column_name;


-- A1. Les valeurs d'énumération écrites par le code existent-elles ?
--
-- Une valeur absente donne un `22P02 invalid input value for enum`, message
-- qui ne dit pas d'où vient la valeur fautive. Autant le vérifier d'avance.
-- Toute ligne dont `refusees_par_la_base` n'est pas vide est un défaut.
with attendu(nom, valeurs) as (
  values
    ('task_priority',   array['low', 'medium', 'high']),
    ('assignee_status', array['pending', 'accepted', 'declined', 'done']),
    ('event_response',  array['yes', 'no', 'maybe', 'pending'])
),
reel as (
  select t.typname::text as nom,
         array_agg(e.enumlabel::text order by e.enumsortorder) as valeurs
  from pg_type t
  join pg_enum e on e.enumtypid = t.oid
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public'
  group by t.typname
)
select
  a.nom,
  a.valeurs                              as ecrites_par_le_code,
  coalesce(r.valeurs, array[]::text[])   as acceptees_par_la_base,
  (select array_agg(v)
     from unnest(a.valeurs) as v
    where not (v = any(coalesce(r.valeurs, array[]::text[]))))
                                         as refusees_par_la_base
from attendu a
left join reel r on r.nom = a.nom
order by a.nom;


-- A2. Colonnes réelles des cinq tables : type, obligation, valeur par défaut.
--
-- La vue exhaustive, à lire quand A0 signale quelque chose.
select
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.udt_name      as type_sql,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('tasks', 'task_assignees', 'task_list_items',
                       'events', 'event_participants')
order by c.table_name, c.ordinal_position;


-- A3. Contraintes : `check`, clés étrangères, unicité, clés primaires.
--
-- Un `check` inconnu du code donne un 23514 ; une clé étrangère non satisfaite,
-- un 23503. Ni l'un ni l'autre n'apparaît dans A0.
select
  rel.relname                       as table_name,
  con.conname                       as contrainte,
  case con.contype
    when 'c' then 'check'
    when 'f' then 'cle_etrangere'
    when 'p' then 'cle_primaire'
    when 'u' then 'unicite'
    else con.contype::text
  end                               as genre,
  pg_get_constraintdef(con.oid)     as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace n on n.oid = rel.relnamespace
where n.nspname = 'public'
  and rel.relname in ('tasks', 'task_assignees', 'task_list_items',
                      'events', 'event_participants')
order by rel.relname, con.contype, con.conname;


-- A4. Les fonctions de la tranche 3 sont-elles déployées, et sous quel rôle ?
--
-- Une fonction absente donne `PGRST202` côté application — « fonction
-- introuvable » —, pas une erreur SQL. `security definer` ne contourne pas
-- RLS : il change le rôle d'exécution. RLS n'est écartée que si ce rôle possède
-- la table ou porte `bypassrls`, d'où les deux dernières colonnes.
select
  p.proname                     as fonction,
  pg_get_userbyid(p.proowner)   as proprietaire,
  p.prosecdef                   as security_definer,
  r.rolbypassrls                as bypassrls,
  r.rolsuper                    as superuser
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_roles r on r.oid = p.proowner
where n.nspname = 'public'
  and p.proname in (
    'creer_tache', 'mes_taches', 'repondre_tache', 'terminer_tache',
    'definir_assignes_tache', 'supprimer_tache',
    'articles_de_tache', 'cocher_article', 'ajouter_article',
    'supprimer_article',
    'creer_evenement', 'mon_agenda', 'repondre_evenement',
    'supprimer_evenement',
    'peut_voir_tache', 'peut_voir_evenement',
    'est_membre_du_groupe', 'est_admin_du_groupe'
  )
order by p.proname;


-- A5. Politiques RLS en place sur les cinq tables.
--
-- Rappel utile à la lecture de la PARTIE B : ni `tasks`, ni `events`, ni
-- `task_assignees`, ni `event_participants` n'ont de politique DELETE, et
-- c'est voulu.
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('tasks', 'task_assignees', 'task_list_items',
                    'events', 'event_participants')
order by tablename, cmd, policyname;


-- A6. Privilèges de table.
--
-- Une politique RLS ne sert à rien sans le `grant` correspondant : sans
-- privilège, l'erreur est « permission denied for table », et non un refus de
-- politique. Les deux se confondent facilement, tous deux étant en 42501.
select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('tasks', 'task_assignees', 'task_list_items',
                     'events', 'event_participants')
  and grantee in ('authenticated', 'anon', 'public')
order by table_name, grantee, privilege_type;


-- ===========================================================================
-- PARTIE B — rejeu des appels, sous le rôle de l'application
-- ===========================================================================
--
-- Remplacez les deux valeurs ci-dessous, puis exécutez le bloc entier.
--
--   MOI     : votre identifiant utilisateur
--   GROUPE  : un groupe dont vous êtes membre
--
-- Pour les retrouver :
--
--   select id, email from auth.users order by created_at desc;
--
--   select g.id, g.name, m.role
--   from public.groups g
--   join public.group_members m on m.group_id = g.id
--   where m.user_id = 'MOI'::uuid
--     and g.deleted_at is null
--     and (m.expires_at is null or m.expires_at > now());
--
-- Le second appel vaut vérification à lui seul : s'il ne renvoie aucune ligne,
-- inutile d'aller plus loin — `creer_tache` refusera le groupe avec
-- « Groupe inaccessible » (42501), et ce ne sera pas un défaut du code.

begin;

-- PostgREST exécute les requêtes sous `authenticated`, avec le jeton dans
-- `request.jwt.claims`. On reproduit exactement ce contexte : sans cela,
-- l'appel tournerait sous le propriétaire et ne prouverait rien — c'est
-- précisément ce qui avait fait croire à un problème de RLS lors du
-- diagnostic des invitations.
set local role authenticated;
set local request.jwt.claims = '{"sub":"MOI","role":"authenticated"}';

-- B1. Tâche personnelle : le cas le plus simple, sans groupe ni assigné.
--     S'il échoue, la cause est dans `tasks` seule.
select (public.creer_tache(
  p_title => 'Diagnostic — tâche personnelle'
)).id as tache_personnelle;

-- B2. Tâche de groupe, avec assigné et liste de courses : le chemin complet,
--     `task_assignees` et `task_list_items` compris.
select (public.creer_tache(
  p_title       => 'Diagnostic — tâche de groupe',
  p_group_id    => 'GROUPE'::uuid,
  p_description => 'Créée par le script de diagnostic',
  p_due_at      => now() + interval '2 days',
  p_priority    => 'high',
  p_assignees   => array['MOI'::uuid],
  p_items       => array['pain', 'lait']
)).id as tache_de_groupe;

-- B3. Rendez-vous personnel : `events` seule, sans participant.
select (public.creer_evenement(
  p_title     => 'Diagnostic — rendez-vous personnel',
  p_starts_at => now() + interval '1 day'
)).id as evenement_personnel;

-- B4. Événement de groupe : convie tous les membres actifs, donc écrit aussi
--     dans `event_participants`.
select (public.creer_evenement(
  p_title       => 'Diagnostic — événement de groupe',
  p_starts_at   => now() + interval '3 days',
  p_ends_at     => now() + interval '3 days 2 hours',
  p_group_id    => 'GROUPE'::uuid,
  p_description => 'Créé par le script de diagnostic',
  p_location    => 'Salon'
)).id as evenement_de_groupe;

-- B5. Ce que les fonctions de lecture renvoient de tout cela.
select id, title, group_id, priority, due_at, mon_statut, articles
from public.mes_taches()
order by created_at desc
limit 4;

select id, title, group_id, starts_at, ma_reponse, nombre_oui
from public.mon_agenda()
order by starts_at
limit 4;

rollback;

-- Rien n'a été écrit : le `rollback` annule les quatre créations.
--
-- Si un appel échoue, l'éditeur SQL affiche l'erreur complète — SQLSTATE,
-- message, détail, indice. C'est cette sortie qui désigne la cause.
--
-- Lecture rapide des cas :
--   23502 « null value in column … violates not-null » → voir A0
--   22P02 « invalid input value for enum »             → voir A1
--   23514 « violates check constraint »                → voir A3
--   23503 « violates foreign key constraint »          → voir A3
--   42501 « permission denied for table »              → privilège, voir A6
--   42501 « new row violates row-level security »      → politique, voir A5
--   42501 « Groupe inaccessible »                      → GROUPE mal renseigné
--   42883 / 42P01 « does not exist »                   → tranche 3 non exécutée
