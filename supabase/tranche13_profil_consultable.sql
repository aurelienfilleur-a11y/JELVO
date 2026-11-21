-- Tranche 13 — le profil de quelqu'un d'autre
--
-- Jelvo n'avait aucun écran de profil d'autrui : on ne voyait qu'une fiche de
-- contact, et rien du tout d'une personne absente du carnet. Ce fichier
-- apporte la **seule** lecture dont cet écran a besoin.
--
--
-- CE QUI REND CE FICHIER DÉLICAT
--
-- La tranche 7 a resserré `profiles_select` à
--
--   (id = auth.uid()) OR has_social_link(id)
--
-- et ce resserrement **n'est pas touché ici**. C'est volontaire, et c'est le
-- point central : la lecture directe de `profiles` reste fermée aux
-- étrangers, et la seule porte vers un profil d'autrui est cette fonction,
-- qui décide elle-même de ce qu'elle rend.
--
-- La conséquence, qui doit être dite : les cinq champs publics — avatar, nom,
-- pseudo, bio, anniversaire — deviennent lisibles par **tout compte
-- authentifié qui connaît l'identifiant**. C'est la consigne produit (« ce qui
-- est visible par tout le monde »), et `chercher_profils_par_pseudo` permet
-- déjà d'énumérer les comptes par préfixe : ces cinq champs sont donc, en
-- pratique, publics entre porteurs d'un compte. Rien d'autre ne l'est.
--
-- Ce qui reste hors de portée, et par construction plutôt que par omission :
--
--   * **l'adresse e-mail.** Elle vit dans `auth.users`, pas dans `profiles` :
--     cette fonction ne lit pas la table qui la contient. Il n'y a donc pas
--     une colonne à ne pas sélectionner, il n'y a pas de colonne du tout ;
--   * **la disponibilité.** Elle est renvoyée à `null` dès que l'appelant
--     n'est pas un contact accepté. Le filtre est **dans la fonction**, pas
--     dans l'écran : un appel direct à PostgREST avec un identifiant
--     arbitraire obtient le même `null`. C'est la seule façon de tenir
--     « réservé aux contacts » — un écran ne peut rien réserver ;
--   * **les trois statistiques** — groupes, événements, tâches terminées.
--     Elles **ne sont plus calculées du tout**, et c'est un retrait et non un
--     masquage : l'écran ne les montrait à personne, et un compteur que
--     personne ne lit est trois sous-requêtes par ouverture de profil, dont
--     une sur `events` et une sur `tasks` jointe à `task_assignees`.
--
--     Les chiffres gardent tout leur sens sur « Mon profil », où chacun
--     **ouvre la liste qu'il résume** — et c'est précisément ce qui ne se
--     transpose pas ici : les listes de l'application sont celles de
--     l'utilisateur connecté, et « ses groupes » ouvert depuis le profil de
--     quelqu'un d'autre montrerait les siens. Un chiffre qu'on ne peut pas
--     ouvrir n'apprend rien de plus que lui-même.
--
-- La disponibilité **délègue** à `get_availability_status`, du schéma initial,
-- exactement comme `statuts_de_disponibilite` le fait depuis la tranche 4.
-- Réimplémenter sa règle de visibilité donnerait deux endroits où elle peut
-- diverger, et l'un des deux finirait par être le plus permissif. La porte
-- posée ici est **plus étroite** que la sienne — elle exige un contact
-- accepté, là où elle accepte aussi les co-membres de groupe — et c'est
-- l'arbitrage demandé.
--
--
-- LA LIGNE EST LISIBLE PAR LES DEUX PARSEURS QUI EXISTENT DÉJÀ
--
-- Les champs du profil portent les noms de colonnes de `profiles`, et les
-- champs de la relation ceux de `mes_contacts` (`autre_id`, `statut`, `sens`,
-- `favori`, `groupes_communs`). Côté Dart, `Profile.fromMap` et
-- `Contact.fromRow` lisent donc cette même ligne sans une ligne de parsing de
-- plus — et le `Contact` obtenu se donne tel quel à `ContactActions`, qui
-- sait déjà de quel bout de la relation on se trouve.
--
-- `avatar_url` est **composé**, comme dans les onze autres fonctions de
-- lecture : `coalesce('preset:' || avatar_preset, avatar_url)`. La colonne de
-- la table ne contient toujours que des URL ; c'est le champ de sortie du
-- même nom qui devient « l'avatar à afficher ».

-- **Le `drop` est nécessaire, et il est la raison de son propre commentaire.**
-- Retirer une colonne de sortie d'un `returns table` est refusé par `create or
-- replace` : PostgreSQL y voit un changement de type de retour. C'est le même
-- prix qu'ont payé `mon_agenda` et `mes_taches` en tranche 6 puis en tranche 8
-- pour en *gagner* une — ici la fonction en perd une, et la règle ne fait pas
-- de différence.
--
-- `if exists` parce que ce fichier est aussi le premier passage sur une base
-- neuve, et `cascade` est volontairement **omis** : rien d'autre en base ne
-- dépend de cette fonction, et un `cascade` qui emporterait silencieusement un
-- objet futur serait pire que l'erreur qui le signale.
drop function if exists public.profil_consultable(uuid);

create or replace function public.profil_consultable(p_user_id uuid)
returns table (
  -- Les cinq champs publics, sous les noms que `Profile.fromMap` attend.
  id                 uuid,
  pseudo             text,
  first_name         text,
  last_name          text,
  avatar_url         text,
  bio                text,
  anniversaire_jour  smallint,
  anniversaire_mois  smallint,

  -- Son propre profil ouvert par ce chemin : l'écran n'offre alors aucune
  -- action de relation, et renvoie vers « Mon profil ».
  cest_moi           boolean,

  -- La relation, sous les noms de `mes_contacts`. `statut` vaut `null`
  -- lorsqu'aucune ligne `contacts` ne lie les deux : c'est ce que l'écran lit
  -- pour proposer « Ajouter en contact ».
  autre_id           uuid,
  statut             text,
  sens               text,
  favori             boolean,

  -- Le compte, pour `Contact.fromRow`, et le détail, pour la carte. Les deux
  -- sortent de la **même** jointure : ils ne peuvent pas se contredire.
  groupes_communs    integer,
  groupes_partages   jsonb,

  -- **Le seul champ réservé aux contacts acceptés** — `null` sinon.
  disponibilite      text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  moi         uuid := auth.uid();
  est_contact boolean;
begin
  -- Un appelant sans session ne lit aucun profil. `anon` n'a de toute façon
  -- pas le droit d'exécution, mais une fonction `security definer` doit poser
  -- sa propre garde plutôt que de s'en remettre au `grant`.
  if moi is null or p_user_id is null then
    return;
  end if;

  select exists (
    select 1
      from public.contacts c
     where c.status = 'accepted'
       and ((c.requester_id = moi and c.addressee_id = p_user_id)
         or (c.requester_id = p_user_id and c.addressee_id = moi))
  ) into est_contact;

  return query
  with commun as (
    -- Les groupes vivants où **les deux** adhésions sont actives. Même règle
    -- qu'au carnet (tranche 10) : une adhésion échue ne compte plus, d'un
    -- côté comme de l'autre — c'est la règle de la tranche 6, et ce fichier
    -- ne fait pas exception.
    select g.id, g.name, g.photo_url
      from public.group_members moi_m
      join public.group_members lui_m on lui_m.group_id = moi_m.group_id
      join public.groups g
        on g.id = moi_m.group_id and g.deleted_at is null
     where moi_m.user_id = moi
       and lui_m.user_id = p_user_id
       and (moi_m.expires_at is null or moi_m.expires_at > now())
       and (lui_m.expires_at is null or lui_m.expires_at > now())
     order by g.name
  ),
  relation as (
    select
      c.status::text as statut,
      case when c.requester_id = moi then 'sortant' else 'entrant' end as sens,
      case when c.requester_id = moi then c.favorite_requester
           else c.favorite_addressee end as favori
      from public.contacts c
     where (c.requester_id = moi and c.addressee_id = p_user_id)
        or (c.requester_id = p_user_id and c.addressee_id = moi)
     limit 1
  )
  select
    p.id,
    p.pseudo,
    p.first_name,
    p.last_name,
    coalesce('preset:' || p.avatar_preset, p.avatar_url),
    p.bio,
    p.anniversaire_jour,
    p.anniversaire_mois,

    (p.id = moi),

    p.id,
    r.statut,
    r.sens,
    coalesce(r.favori, false),

    (select count(*)::integer from commun),
    coalesce(
      (select jsonb_agg(
                jsonb_build_object('id', k.id, 'nom', k.name,
                                   'photo_url', k.photo_url))
         from commun k),
      '[]'::jsonb),

    -- **Le filtre des contacts est ici, et nulle part ailleurs.** Son propre
    -- profil y passe aussi : `cest_moi` ouvre le même champ, puisqu'il est le
    -- sien.
    --
    -- **Appel par noms d'arguments**, comme `statuts_de_disponibilite`. Ce
    -- n'est pas du style : `schema_actuel.sql` donne la signature
    -- `(target uuid, at_ts timestamptz)`, et l'en-tête de la tranche 4 comme
    -- le décor de `verification/` l'ont longtemps écrite dans l'autre sens.
    -- Un appel positionnel dépendrait donc de laquelle des deux a raison ;
    -- nommer les arguments rend la question sans objet.
    case when est_contact or p.id = moi
         then public.get_availability_status(target => p.id, at_ts => now())
    end
    from public.profiles p
    left join relation r on true
   where p.id = p_user_id
     -- Un compte supprimé ne rend **aucune ligne**, exactement comme un
     -- identifiant inconnu — et l'écran sait déjà le dire. C'est la règle de
     -- cette tranche telle qu'elle est écrite plus haut : un profil n'a qu'un
     -- état dégradé, il n'existe pas. Un avatar touché dans une conversation
     -- mène donc à « introuvable », et non à une fiche vide.
     --
     -- Le filtre vit ici, dans le fichier qui possède la fonction : ailleurs,
     -- il se perdrait au premier rejeu de celui-ci.
     and p.supprime_le is null;
end;
$$;

-- `authenticated` seulement. `anon` n'a aucune raison de lire un profil : la
-- page publique d'un lien d'invitation passe par `apercu_groupe_par_jeton`,
-- qui exige le jeton exact.
grant execute on function public.profil_consultable(uuid) to authenticated;
