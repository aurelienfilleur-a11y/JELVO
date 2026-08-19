-- Tranche 5d — envoi des rappels
--
-- `tasks.reminder_at` et `events.reminder_minutes` sont enregistrés depuis la
-- tranche 3, et **rien ne les lit**. Ce fichier ferme cet écart : il empile
-- dans `push_outbox` les rappels dont l'heure est venue.
--
--
-- UN SEUL BATTEMENT, ET IL EST À L'EXTÉRIEUR
--
-- Rien n'invoquait la fonction Edge `envoyer-push` : la file se remplissait
-- depuis la tranche 5c, et personne ne la vidait. Une base ne se réveille pas
-- toute seule — il faut quelque chose de périodique, et ce quelque chose vit
-- hors du SQL.
--
-- Le choix retenu est **une seule chose à planifier** : la fonction Edge
-- appelle `empiler_rappels()` puis vide la file, à chaque passage. Deux
-- planifications distinctes — l'une en `pg_cron` pour les rappels, l'autre
-- pour l'envoi — auraient donné deux cadences à garder d'accord, et un
-- rappel empilé une minute après le dernier envoi serait resté en attente.
--
-- L'alternative était `pg_cron` + `pg_net` appelant la fonction Edge depuis
-- la base. Elle a été écartée pour une raison précise : elle impose de ranger
-- une clé `service_role` **dans la base**, en clair ou dans Vault, pour
-- signer l'appel. La clé n'a rien à faire là ; elle vit déjà du bon côté,
-- dans les secrets de la fonction.
--
-- Conséquence assumée, et c'est le seul prérequis manuel de cette tranche :
-- **planifier `envoyer-push` toutes les minutes** depuis le tableau de bord
-- Supabase (Integrations → Cron → nouvelle tâche de type « Edge Function »).
-- Tant que ce n'est pas fait, les rappels ne sont pas « en retard » : ils ne
-- sont pas empilés du tout.
--
--
-- CE FICHIER EST IDEMPOTENT
--
-- Il est rejoué dès que son empreinte change, comme tous les autres.


-- 1. Ce qui a déjà été rappelé ---------------------------------------------
--
-- Sans mémoire, un battement à la minute renverrait le même rappel à chaque
-- passage tant que la fenêtre le couvre.
--
-- **La clé primaire porte la règle**, plutôt qu'un contrôle dans la fonction :
-- une occurrence donnée d'un élément donné n'est rappelée qu'une fois à une
-- personne donnée, et c'est la base qui le tient. Même raison que pour
-- `message_reactions` : un test préalable se double d'une course, une clé
-- primaire non.
--
-- `occurrence` est dans la clé, et pas seulement `source_id` : un élément
-- récurrent doit être rappelé à **chacune** de ses occurrences.

create table if not exists public.push_reminders_sent (
  kind       text not null check (kind in ('task', 'event')),
  source_id  uuid not null,
  occurrence timestamptz not null,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  sent_at    timestamptz not null default now(),
  primary key (kind, source_id, occurrence, user_id)
);

create index if not exists push_reminders_sent_age
  on public.push_reminders_sent (sent_at);

-- Aucune politique : cette table est de la plomberie, personne n'a à la lire.
-- Les fonctions `security definer` ci-dessous appartiennent au propriétaire de
-- la table et ne sont donc pas soumises à RLS.
alter table public.push_reminders_sent enable row level security;


-- 2. Prochaine occurrence d'une règle de récurrence -------------------------
--
-- L'application n'écrit que cinq `rrule`, prises dans une liste fermée
-- (`RecurrenceRule` côté Dart) : `FREQ=DAILY`, `FREQ=WEEKLY`,
-- `FREQ=WEEKLY;INTERVAL=2`, `FREQ=MONTHLY`, `FREQ=YEARLY`.
--
-- **Une règle non reconnue renvoie `null`**, et l'élément n'est pas rappelé.
-- C'est délibéré : deviner l'intention d'une `rrule` écrite ailleurs — avec
-- `COUNT`, `UNTIL`, `BYDAY` — donnerait des rappels à des heures fausses, ce
-- qui est pire que pas de rappel du tout.
--
-- La fonction est `stable` et non `immutable` : ajouter un mois à un
-- `timestamptz` dépend du fuseau de la session.
create or replace function public.prochaine_occurrence(
  p_base timestamptz,
  p_rrule text,
  p_apres timestamptz
)
returns timestamptz
language plpgsql
stable
set search_path = public
as $$
declare
  frequence text;
  pas       integer;
  unite     text;
  k         integer;
  resultat  timestamptz;
begin
  if p_base is null or p_apres is null then
    return null;
  end if;

  -- Sans récurrence, il n'y a qu'une occurrence : elle compte si elle est
  -- devant nous.
  if p_rrule is null or btrim(p_rrule) = '' then
    return case when p_base >= p_apres then p_base end;
  end if;

  if p_base >= p_apres then
    return p_base;
  end if;

  frequence := upper(coalesce(substring(p_rrule from 'FREQ=([A-Za-z]+)'), ''));

  -- Borné à quatre chiffres : `INTERVAL=99999999999` déborderait l'`integer`
  -- et ferait lever la fonction, alors qu'elle doit se contenter de ne rien
  -- proposer sur une règle qu'elle ne sait pas lire.
  pas := coalesce(
    nullif(substring(p_rrule from 'INTERVAL=([0-9]{1,4})'), '')::integer, 1
  );
  if pas < 1 then
    pas := 1;
  end if;

  -- `k` n'est qu'une estimation : les mois n'ont pas tous la même longueur et
  -- le passage à l'heure d'été décale d'une heure. La correction bornée qui
  -- suit rattrape l'un comme l'autre.
  case frequence
    when 'DAILY' then
      unite := 'days';
      k := ceil(extract(epoch from (p_apres - p_base)) / (86400.0 * pas));
    when 'WEEKLY' then
      unite := 'weeks';
      k := ceil(extract(epoch from (p_apres - p_base)) / (604800.0 * pas));
    when 'MONTHLY' then
      unite := 'months';
      k := ceil(
        ((extract(year from p_apres) - extract(year from p_base)) * 12
         + (extract(month from p_apres) - extract(month from p_base))) / pas
      );
    when 'YEARLY' then
      unite := 'years';
      k := ceil(
        (extract(year from p_apres) - extract(year from p_base)) / pas
      );
    else
      return null;
  end case;

  if k < 0 then
    k := 0;
  end if;

  resultat := p_base + ((k * pas)::text || ' ' || unite)::interval;

  for _essai in 1..24 loop
    exit when resultat >= p_apres;
    k := k + 1;
    resultat := p_base + ((k * pas)::text || ' ' || unite)::interval;
  end loop;

  return case when resultat >= p_apres then resultat end;
end;
$$;


-- 3. Empiler les rappels dus ------------------------------------------------
--
-- Appelée à chaque passage de la fonction Edge. Elle regarde en arrière sur
-- `p_fenetre` plutôt qu'à l'instant présent : un battement manqué — un
-- redéploiement, une minute sautée — ne doit pas faire disparaître un rappel.
-- Le double envoi qu'une fenêtre large rendrait possible est écarté par la
-- clé primaire de `push_reminders_sent`, pas par la précision de la fenêtre.
--
-- Renvoie le nombre de notifications réellement empilées — celles qu'une
-- préférence ou une absence d'abonnement a écartées n'y sont pas comptées.
create or replace function public.empiler_rappels(
  p_fenetre interval default '10 minutes'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  maintenant  timestamptz := now();
  depuis      timestamptz := now() - p_fenetre;
  empiles     integer := 0;
  ligne       record;
  destinataire record;
  occurrence  timestamptz;
  rappel      timestamptz;
  avance      interval;
  corps       text;
begin
  -- 3.1 Tâches -------------------------------------------------------------
  for ligne in
    select t.id, t.title, t.group_id, t.created_by,
           t.due_at, t.reminder_at, t.rrule, g.name as groupe
      from public.tasks t
      left join public.groups g on g.id = t.group_id
     where t.deleted_at is null
       and t.completed_at is null
       and t.reminder_at is not null
  loop
    -- L'avance est ce que la personne a choisi : l'écart entre l'échéance et
    -- le rappel de la **première** occurrence. On la reporte telle quelle sur
    -- les suivantes.
    avance := coalesce(ligne.due_at - ligne.reminder_at, interval '0');

    if ligne.rrule is null or ligne.due_at is null then
      occurrence := coalesce(ligne.due_at, ligne.reminder_at);
      rappel := ligne.reminder_at;
    else
      occurrence := public.prochaine_occurrence(
        ligne.due_at, ligne.rrule, depuis + avance
      );
      rappel := occurrence - avance;
    end if;

    continue when rappel is null or rappel < depuis or rappel > maintenant;

    -- Même règle qu'en tranche 5c : le titre porte le contexte, le corps
    -- dit quoi. Le groupe quitte donc le corps pour devenir le titre.
    corps := 'Rappel — ' || ligne.title;

    for destinataire in
      -- Les assignés, sauf ceux qui ont refusé. À défaut d'assigné, celui qui
      -- l'a créée : une tâche personnelle n'a personne d'autre à prévenir.
      select a.user_id
        from public.task_assignees a
       where a.task_id = ligne.id
         and a.status <> 'declined'::assignee_status
      union
      select ligne.created_by
       where ligne.created_by is not null
         and not exists (
           select 1 from public.task_assignees a2 where a2.task_id = ligne.id
         )
    loop
      insert into public.push_reminders_sent (kind, source_id, occurrence, user_id)
      values ('task', ligne.id, occurrence, destinataire.user_id)
      on conflict do nothing;

      continue when not found;

      if public.empiler_push(
        destinataire.user_id,
        'reminder',
        coalesce(ligne.groupe, 'Personnel'),
        corps,
        '/taches/' || ligne.id::text
      ) then
        empiles := empiles + 1;
      end if;
    end loop;
  end loop;

  -- 3.2 Événements ---------------------------------------------------------
  for ligne in
    select e.id, e.title, e.group_id, e.owner_id,
           e.starts_at, e.rrule, e.reminder_minutes, g.name as groupe
      from public.events e
      left join public.groups g on g.id = e.group_id
     where e.deleted_at is null
       and e.reminder_minutes is not null
       and e.reminder_minutes > 0
       and e.starts_at is not null
  loop
    avance := (ligne.reminder_minutes::text || ' minutes')::interval;

    if ligne.rrule is null then
      occurrence := ligne.starts_at;
    else
      occurrence := public.prochaine_occurrence(
        ligne.starts_at, ligne.rrule, depuis + avance
      );
    end if;

    continue when occurrence is null;
    rappel := occurrence - avance;
    continue when rappel < depuis or rappel > maintenant;

    -- L'heure est rendue en Europe/Paris : l'application est en français et
    -- n'a qu'une locale. Le schéma ne porte aucun fuseau par événement, donc
    -- il n'y a rien de plus juste à faire ici.
    corps := 'Rappel — ' || ligne.title
      || ' à ' || to_char(occurrence at time zone 'Europe/Paris', 'HH24:MI');

    for destinataire in
      -- Qui a dit non n'a pas à être rappelé. Un rendez-vous personnel n'a
      -- pas de participant : c'est son propriétaire qu'on prévient.
      select p.user_id
        from public.event_participants p
       where p.event_id = ligne.id
         and p.response <> 'no'::event_response
      union
      select ligne.owner_id
       where ligne.owner_id is not null
         and not exists (
           select 1 from public.event_participants p2 where p2.event_id = ligne.id
         )
    loop
      insert into public.push_reminders_sent (kind, source_id, occurrence, user_id)
      values ('event', ligne.id, occurrence, destinataire.user_id)
      on conflict do nothing;

      continue when not found;

      if public.empiler_push(
        destinataire.user_id,
        'reminder',
        coalesce(ligne.groupe, 'Personnel'),
        corps,
        '/evenements/' || ligne.id::text
      ) then
        empiles := empiles + 1;
      end if;
    end loop;
  end loop;

  -- La mémoire ne sert qu'à ne pas répéter un rappel : passé un trimestre,
  -- elle ne protège plus de rien et n'est plus que du volume.
  delete from public.push_reminders_sent
   where sent_at < now() - interval '90 days';

  return empiles;
exception
  when others then
    -- Même règle que pour les déclencheurs de la tranche 5c : un rappel
    -- manqué est un défaut, un battement qui s'arrête en est un plus grave.
    raise warning 'empiler_rappels : %', sqlerrm;
    return empiles;
end;
$$;

-- Réservée au rôle de service, comme le reste de la chaîne d'envoi : elle
-- écrit dans la boîte de tout le monde.
revoke all on function public.empiler_rappels(interval) from public, authenticated;
grant execute on function public.empiler_rappels(interval) to service_role;

-- `prochaine_occurrence` ne lit rien et ne révèle rien : elle reste ouverte,
-- l'application pourra s'en servir pour afficher la prochaine occurrence.
grant execute on function public.prochaine_occurrence(timestamptz, text, timestamptz)
  to authenticated;
