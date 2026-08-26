-- ---------------------------------------------------------------------------
-- Tranche 10 — les groupes qu'on a en commun
-- ---------------------------------------------------------------------------
-- La maquette du carnet affiche, sur chaque ligne, le nombre de groupes
-- partagés avec la personne. C'est la seule donnée de cet écran qui n'était
-- pas déjà lisible — et elle **se calcule proprement** : `group_members` porte
-- les deux adhésions, il suffit de les croiser.
--
-- Trois filtres, et aucun n'est décoratif :
--
--   - le groupe doit être vivant (`deleted_at is null`) ;
--   - **les deux** adhésions doivent être actives — une adhésion temporaire
--     échue ne compte plus, ni de son côté ni du nôtre. C'est la règle de la
--     tranche 6, et toute lecture de `group_members` la porte ;
--   - le compte reste sous `security definer`, comme le reste de la fonction :
--     lire l'adhésion d'autrui ligne à ligne n'est pas donné par RLS, et c'est
--     exactement pourquoi ces lectures passent par une fonction.
--
-- Une colonne de sortie de plus impose un `drop function` : même arbitrage
-- qu'en tranches 6, 8 et 9. Le fichier s'applique **avant**
-- `tranche7_durcissement.sql`, qui doit rester le dernier passage.
--
-- `mes_contacts` figure déjà dans la liste d'exécution de la tranche 7 : rien
-- à y ajouter cette fois.

drop function if exists public.mes_contacts();

create or replace function public.mes_contacts()
returns table (
  autre_id        uuid,
  pseudo          text,
  first_name      text,
  last_name       text,
  avatar_url      text,
  statut          text,
  sens            text,
  favori          boolean,
  created_at      timestamptz,
  groupes_communs integer
)
language sql
security definer
set search_path = public
stable
as $$
  select
    case when c.requester_id = auth.uid() then c.addressee_id
         else c.requester_id end,
    p.pseudo, p.first_name, p.last_name,
    coalesce('preset:' || p.avatar_preset, p.avatar_url),
    c.status::text,
    case when c.requester_id = auth.uid() then 'sortant' else 'entrant' end,
    case when c.requester_id = auth.uid() then c.favorite_requester
         else c.favorite_addressee end,
    c.created_at,
    (select count(*)::integer
       from public.group_members moi
       join public.group_members lui on lui.group_id = moi.group_id
       join public.groups g
         on g.id = moi.group_id and g.deleted_at is null
      where moi.user_id = auth.uid()
        and lui.user_id = case when c.requester_id = auth.uid()
                               then c.addressee_id else c.requester_id end
        and (moi.expires_at is null or moi.expires_at > now())
        and (lui.expires_at is null or lui.expires_at > now()))
  from public.contacts c
  left join public.profiles p
    on p.id = case when c.requester_id = auth.uid() then c.addressee_id
                   else c.requester_id end
  where auth.uid() in (c.requester_id, c.addressee_id)
  order by p.first_name, p.last_name, p.pseudo;
$$;

grant execute on function public.mes_contacts() to authenticated;
