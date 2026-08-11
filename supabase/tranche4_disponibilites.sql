-- Tranche 4 — disponibilités.
--
-- Appliqué automatiquement au push sur `main` : voir `supabase/migrations.txt`.
-- Idempotent.
--
--
-- LE SCHÉMA EXISTAIT DÉJÀ, ET IL A ÉTÉ VÉRIFIÉ
--
-- `availabilities` et `get_availability_status` viennent du schéma initial.
-- Rien ici ne les crée ni ne les modifie. Les colonnes ci-dessous ont été
-- **relevées sur le projet**, pas devinées :
--
--   availabilities  id, user_id, weekday, on_date, start_time, end_time,
--                   status, kind, created_at
--
--   availability_status  available | unavailable
--   availability_kind    recurring | exception
--
--   get_availability_status(at_ts, target) → texte
--
-- Deux formes de créneau, distinguées par `kind` :
--   - `recurring` s'appuie sur `weekday` (jour de la semaine) ;
--   - `exception` s'appuie sur `on_date` (une date précise), et prime.
--
--
-- LA RÈGLE DE CONFIDENTIALITÉ EST TENUE PAR LA BASE
--
-- Les autres ne voient jamais que « disponible », « indisponible » ou
-- « inconnu ». Jamais un créneau, jamais une heure, jamais une raison.
--
-- `statuts_de_disponibilite` ci-dessous **délègue** à
-- `get_availability_status` plutôt que de relire `availabilities`. C'est
-- délibéré : réimplémenter la règle de visibilité, ce serait se donner deux
-- endroits où elle peut diverger, et l'un des deux finirait par être le plus
-- permissif. La fonction du schéma initial reste seule juge.


-- ---------------------------------------------------------------------------
-- 1. Lire ses propres créneaux
-- ---------------------------------------------------------------------------
-- Réservé à soi-même : le détail des créneaux n'est visible de personne
-- d'autre, et cette fonction n'accepte donc aucun paramètre d'utilisateur.

create or replace function public.mes_disponibilites()
returns table (
  id         uuid,
  kind       text,
  weekday    integer,
  on_date    date,
  start_time time,
  end_time   time,
  status     text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select a.id, a.kind::text, a.weekday, a.on_date, a.start_time, a.end_time,
         a.status::text, a.created_at
  from public.availabilities a
  where a.user_id = auth.uid()
  -- Les exceptions d'abord : ce sont elles qu'on vient de poser, et elles
  -- priment sur la règle hebdomadaire.
  order by a.kind, a.on_date nulls last, a.weekday nulls last, a.start_time;
$$;

grant execute on function public.mes_disponibilites() to authenticated;


-- ---------------------------------------------------------------------------
-- 2. Poser ou modifier un créneau
-- ---------------------------------------------------------------------------
-- Une seule fonction pour les deux formes : le couple (`kind`, `weekday` ou
-- `on_date`) suffit à les distinguer, et deux fonctions auraient dupliqué les
-- mêmes contrôles.
--
-- Passer [p_id] modifie le créneau existant ; l'omettre en crée un.

create or replace function public.definir_disponibilite(
  p_kind    text,
  p_start   time,
  p_end     time,
  p_status  text default 'available',
  p_weekday integer default null,
  p_on_date date default null,
  p_id      uuid default null
)
returns public.availabilities
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  utilisateur uuid := auth.uid();
  resultat    public.availabilities%rowtype;
begin
  if utilisateur is null then
    raise exception 'Session absente' using errcode = '42501';
  end if;
  if p_kind not in ('recurring', 'exception') then
    raise exception 'Type de créneau inconnu' using errcode = '22P02';
  end if;
  if p_status not in ('available', 'unavailable') then
    raise exception 'Statut inconnu' using errcode = '22P02';
  end if;
  if p_kind = 'recurring' and p_weekday is null then
    raise exception 'Un créneau récurrent demande un jour de la semaine'
      using errcode = '23514';
  end if;
  if p_kind = 'exception' and p_on_date is null then
    raise exception 'Un créneau exceptionnel demande une date'
      using errcode = '23514';
  end if;
  if p_end <= p_start then
    raise exception 'La fin doit suivre le début' using errcode = '23514';
  end if;

  if p_id is null then
    -- Toute valeur d'énumération écrite porte une conversion explicite : un
    -- littéral seul passe, mais dès qu'il entre dans une expression il devient
    -- `text`, et `text` ne se convertit pas implicitement vers un énuméré.
    insert into public.availabilities
      (user_id, kind, weekday, on_date, start_time, end_time, status)
    values (utilisateur, p_kind::availability_kind,
            case when p_kind = 'recurring' then p_weekday end,
            case when p_kind = 'exception' then p_on_date end,
            p_start, p_end, p_status::availability_status)
    returning * into resultat;
  else
    update public.availabilities
    set kind       = p_kind::availability_kind,
        weekday    = case when p_kind = 'recurring' then p_weekday end,
        on_date    = case when p_kind = 'exception' then p_on_date end,
        start_time = p_start,
        end_time   = p_end,
        status     = p_status::availability_status
    where id = p_id
      and user_id = utilisateur
    returning * into resultat;

    if not found then
      raise exception 'Créneau introuvable' using errcode = '42501';
    end if;
  end if;

  return resultat;
end;
$$;

grant execute on function public.definir_disponibilite(
  text, time, time, text, integer, date, uuid
) to authenticated;


-- ---------------------------------------------------------------------------
-- 3. Retirer un créneau
-- ---------------------------------------------------------------------------
-- Passe par une fonction plutôt que par un `delete` direct : sans politique
-- DELETE couvrant le cas, PostgREST ne toucherait aucune ligne et répondrait
-- **200 sans erreur**. C'est ce qui avait fait croire que promouvoir un membre
-- fonctionnait. Le booléen renvoyé dit ce qui s'est réellement passé.

create or replace function public.supprimer_disponibilite(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  delete from public.availabilities
  where id = p_id and user_id = auth.uid();
  return found;
end;
$$;

grant execute on function public.supprimer_disponibilite(uuid)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 4. Statut de plusieurs personnes à un instant donné
-- ---------------------------------------------------------------------------
-- Pour l'écran de création d'événement : on veut le statut de tous les
-- participants pressentis d'un coup, et non une requête par personne.
--
-- **Cette fonction ne lit jamais `availabilities`.** Elle appelle
-- `get_availability_status`, qui porte la règle de visibilité du schéma
-- initial. Tout ce qui ressort d'ici est donc un mot parmi trois.

create or replace function public.statuts_de_disponibilite(
  p_users uuid[],
  p_at    timestamptz
)
returns table (user_id uuid, statut text)
language sql
security definer
set search_path = public
stable
as $$
  select u,
         coalesce(
           public.get_availability_status(at_ts => p_at, target => u),
           'unknown')
  from unnest(coalesce(p_users, array[]::uuid[])) as u;
$$;

grant execute on function public.statuts_de_disponibilite(uuid[], timestamptz)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Vérification du schéma
-- ---------------------------------------------------------------------------
-- Toute colonne obligatoire sans valeur par défaut qui apparaît ici doit
-- figurer dans l'insertion ci-dessus.

select c.table_name, c.column_name, c.udt_name as type_sql
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'availabilities'
  and c.is_nullable = 'NO'
  and c.column_default is null
order by c.ordinal_position;
