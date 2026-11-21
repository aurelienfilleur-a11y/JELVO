-- Tranche 12 — Anniversaires
--
-- Jour et mois sur `profiles`, une lecture réservée aux contacts, et un dépôt
-- quotidien dans la boîte et dans la file d'envoi.
--
-- **Idempotent** : rejoué dès que son empreinte change, comme tous les
-- fichiers de `migrations.txt`.
--
-- ===========================================================================
-- Ce qui a été tranché, et pourquoi
-- ===========================================================================
--
-- **Deux colonnes entières, et non une `date`.** Une `date` exige une année,
-- et toute année sentinelle — 1900, 2000, l'année courante — est une valeur
-- que quelqu'un finira par lire comme une année de naissance, puis par
-- afficher. Deux `smallint` rendent l'absence d'année **structurelle** : il
-- n'y a pas d'année à ignorer, il n'y en a pas du tout. C'est ce que demande
-- la consigne, et c'est la seule forme qui l'empêche de se perdre.
--
-- **Le 29 février n'est pas un cas particulier.** Une seule règle le couvre :
-- le jour fêté est `least(jour, dernier jour du mois)`. Un anniversaire du
-- 29 février tombe donc le **dernier jour de février** — le 29 les années
-- bissextiles, le 28 sinon. Le reporter au 1er mars le ferait changer de
-- mois, et « mon anniversaire est en février » cesserait d'être vrai.
--
-- **La mémoire est la clé primaire de `push_reminders_sent`**, dont le `kind`
-- s'élargit à `birthday`. Pas de table de plus : c'est exactement le même
-- besoin — « ceci a déjà été envoyé pour cette occurrence » — et la
-- contrainte d'unicité le tient sans test préalable, donc sans course entre
-- deux battements. Même principe que les rappels de la tranche 5d.

-- Pas de `begin;` ici : `verification/appliquer.sh` enveloppe déjà chaque
-- fichier dans sa propre transaction, avec l'écriture de l'empreinte. En
-- ouvrir une seconde fermerait la sienne au `commit`, et l'empreinte
-- partirait hors transaction — le fichier serait rejoué sans fin.

-- ---------------------------------------------------------------------------
-- 1. Les deux colonnes
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists anniversaire_jour smallint,
  add column if not exists anniversaire_mois smallint;

comment on column public.profiles.anniversaire_jour is
  'Jour de naissance (1-31), sans année. Null avec anniversaire_mois.';
comment on column public.profiles.anniversaire_mois is
  'Mois de naissance (1-12), sans année. Null avec anniversaire_jour.';

-- Retirée puis reposée : c'est ce qui rend la contrainte rejouable, et ce qui
-- permet de la corriger sur place plutôt que d'empiler un correctif.
alter table public.profiles
  drop constraint if exists profiles_anniversaire_check;

-- Trois règles en une contrainte, parce qu'elles ne se séparent pas :
--   - les deux colonnes sont renseignées ensemble ou pas du tout — une
--     moitié de date ne veut rien dire, et laisserait un affichage à deviner ;
--   - le mois est un mois ;
--   - le jour existe **dans ce mois**, février compris. Le 29 février est
--     accepté : c'est une vraie date de naissance. Le 30 février ne l'est pas.
alter table public.profiles
  add constraint profiles_anniversaire_check check (
    (anniversaire_jour is null) = (anniversaire_mois is null)
    and (anniversaire_mois is null or anniversaire_mois between 1 and 12)
    and (
      anniversaire_jour is null
      or anniversaire_jour between 1 and case anniversaire_mois
           when 2 then 29
           when 4 then 30
           when 6 then 30
           when 9 then 30
           when 11 then 30
           else 31
         end
    )
  );

-- ---------------------------------------------------------------------------
-- 2. Le jour fêté une année donnée
-- ---------------------------------------------------------------------------
-- **Une seule règle, pas un cas particulier du 29 février** : le jour est
-- ramené au dernier jour du mois quand il le dépasse. Elle sert à l'envoi
-- ci-dessous ; le calendrier la rejoue côté client, faute de pouvoir demander
-- une ligne par année à la base. Les deux sont épinglées sur les mêmes cas,
-- ici par `verification/fumee.sql` et là par `test/anniversaires_test.dart`.
--
-- `null` dès qu'une des trois valeurs manque : une personne sans date
-- renseignée ne doit pas produire de date approchée.
create or replace function public.jour_anniversaire(
  p_jour smallint,
  p_mois smallint,
  p_annee integer
)
returns date
language sql
immutable
as $$
  select make_date(
    p_annee,
    p_mois::int,
    least(
      p_jour::int,
      extract(
        day from
        make_date(p_annee, p_mois::int, 1) + interval '1 month' - interval '1 day'
      )::int
    )
  )
  where p_jour is not null and p_mois is not null and p_annee is not null;
$$;

-- ---------------------------------------------------------------------------
-- 3. Les anniversaires de ses contacts
-- ---------------------------------------------------------------------------
-- Réservée aux **contacts acceptés**, dans les deux sens. Un co-membre de
-- groupe qui n'est pas un contact n'y figure pas : c'est la consigne, et c'est
-- plus étroit que `has_social_link`, qui ouvre la lecture du profil.
--
-- `security definer` pour la raison habituelle : rien ne garantit qu'on
-- puisse lire la ligne `profiles` d'un autre, et l'assouplir pour cela serait
-- disproportionné.
--
-- **Une personne sans date ne rend aucune ligne.** L'appelant n'a donc rien à
-- écarter, et le calendrier n'a rien à synthétiser.
create or replace function public.anniversaires_de_mes_contacts()
returns table (
  contact_id uuid,
  pseudo     text,
  first_name text,
  last_name  text,
  avatar_url text,
  jour       smallint,
  mois       smallint
)
language sql
security definer
set search_path = public
as $$
  select p.id,
         p.pseudo,
         p.first_name,
         p.last_name,
         coalesce('preset:' || p.avatar_preset, p.avatar_url),
         p.anniversaire_jour,
         p.anniversaire_mois
  from public.contacts c
  join public.profiles p
    on p.id = case when c.requester_id = auth.uid()
                   then c.addressee_id
                   else c.requester_id
              end
  where c.status = 'accepted'
    and (c.requester_id = auth.uid() or c.addressee_id = auth.uid())
    and p.anniversaire_jour is not null;
$$;

grant execute on function public.anniversaires_de_mes_contacts()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. La mémoire des envois s'élargit
-- ---------------------------------------------------------------------------
-- `kind` ne connaissait que `task` et `event`. L'élargir sans rien retirer,
-- comme la tranche 5c l'a fait pour `push_tokens.platform` et sa valeur
-- `web` : sans cela, le premier dépôt échouerait en `23514`.
alter table public.push_reminders_sent
  drop constraint if exists push_reminders_sent_kind_check;
alter table public.push_reminders_sent
  add constraint push_reminders_sent_kind_check
  check (kind in ('task', 'event', 'birthday'));

-- ---------------------------------------------------------------------------
-- 5. Le dépôt du jour
-- ---------------------------------------------------------------------------
-- Appelée par `envoyer-push`, dans le **même passage** que `empiler_rappels`
-- et `appliquer_adhesions_echues`. Une seconde planification serait une
-- seconde cadence à tenir d'accord — le reproche déjà fait, et retenu, aux
-- rappels puis aux adhésions échues.
--
-- Deux dépôts par destinataire, comme partout ailleurs : une ligne dans
-- `notifications` pour la boîte, et un `empiler_push` pour le téléphone.
--
-- La date du jour est prise en **Europe/Paris**, le fuseau dans lequel les
-- rappels sont déjà rendus. `profiles.timezone` existe mais n'est lu par
-- personne, et le lire ici seulement donnerait deux conventions.
create or replace function public.empiler_anniversaires()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  aujourdhui date := (now() at time zone 'Europe/Paris')::date;
  f record;
  deposes integer := 0;
begin
  for f in
    select p.id as fete_id,
           coalesce(public.nom_affiche(p.id), 'Un contact') as nom,
           coalesce('preset:' || p.avatar_preset, p.avatar_url) as avatar,
           p.anniversaire_jour as jour,
           p.anniversaire_mois as mois,
           case when c.requester_id = p.id then c.addressee_id
                else c.requester_id
           end as destinataire
    from public.profiles p
    join public.contacts c
      on c.status = 'accepted'
     and (c.requester_id = p.id or c.addressee_id = p.id)
    where p.anniversaire_jour is not null
      and public.jour_anniversaire(
            p.anniversaire_jour,
            p.anniversaire_mois,
            extract(year from aujourdhui)::int
          ) = aujourdhui
  loop
    -- **C'est l'insertion qui décide**, et non un test préalable : deux
    -- battements concurrents verraient tous deux « pas encore envoyé ».
    --
    -- Elle est **hors** du bloc protégé ci-dessous, et c'est voulu : une
    -- notification qui échoue reste comptée comme envoyée, donc n'est pas
    -- retentée à la minute suivante. Un anniversaire manqué vaut mieux qu'un
    -- anniversaire annoncé mille quatre cent quarante fois dans la journée.
    insert into public.push_reminders_sent (kind, source_id, occurrence,
                                            user_id)
    values ('birthday', f.fete_id, aujourdhui::timestamptz, f.destinataire)
    on conflict do nothing;
    continue when not found;

    begin
      insert into public.notifications (user_id, type, payload)
      values (
        f.destinataire,
        'birthday',
        jsonb_build_object(
          'person_id',  f.fete_id,
          'name',       f.nom,
          'avatar_url', f.avatar,
          'jour',       f.jour,
          'mois',       f.mois
        )
      );

      -- Titre = le contexte, corps = qui fait quoi. Ici le contexte **est**
      -- la personne : un mot de catégorie — « Anniversaire » — est
      -- précisément ce que la règle de formulation écarte.
      perform public.empiler_push(
        f.destinataire,
        'birthday',
        f.nom,
        'fête son anniversaire aujourd''hui',
        '/calendrier',
        'push.anniversaire',
        -- `titre` porte le **nom de la personne** et non celui d'un groupe :
        -- c'est la seule exception à la règle de formulation, et elle traverse
        -- la traduction sans y changer quoi que ce soit.
        jsonb_build_object('titre', f.nom)
      );

      deposes := deposes + 1;
    exception
      when others then
        -- Une notification est un effet de bord : elle ne doit jamais faire
        -- échouer le passage, ni empêcher les suivantes.
        raise warning 'Anniversaire de % impossible à déposer : % (%)',
          f.fete_id, sqlerrm, sqlstate;
    end;
  end loop;

  return deposes;
end;
$$;

grant execute on function public.empiler_anniversaires() to service_role;

-- `jour_anniversaire` n'est **pas** ouverte aux clients, et n'a pas à l'être :
-- elle n'est appelée que depuis la fonction ci-dessus, qui s'exécute sous son
-- propriétaire. La tranche 7 ne lève que sur un nom de sa liste absent de la
-- base, jamais sur une fonction qui n'y figure pas : celle-ci reste donc
-- fermée, ce qui est le bon défaut.
