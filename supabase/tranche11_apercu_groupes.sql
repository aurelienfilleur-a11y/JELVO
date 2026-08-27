-- ---------------------------------------------------------------------------
-- Tranche 11 — l'aperçu des membres, pour la liste des groupes
-- ---------------------------------------------------------------------------
-- La maquette de l'onglet Groupes pose une rangée d'avatars sur chaque carte.
-- C'est la seule donnée de cet écran qui manquait, et la façon évidente de
-- l'obtenir était la mauvaise : appeler `membres_du_groupe` par carte, soit
-- **une lecture par groupe** à chaque ouverture de l'onglet.
--
-- `fetchMyGroups` comptait déjà les membres « en une requête plutôt qu'une par
-- carte ». Cette fonction reprend ce compte et lui adjoint les quelques profils
-- que la rangée montre : le nombre de requêtes ne bouge pas, la rangée
-- d'avatars est offerte.
--
-- **Pourquoi une fonction plutôt qu'un embed PostgREST.** Joindre `profiles`
-- depuis `group_members` paraît plus simple, mais rien ne garantit qu'on puisse
-- lire la ligne `profiles` d'un autre : depuis la tranche 7, `profiles_select`
-- vaut `id = auth.uid() or has_social_link(id)`. Un embed renverrait donc des
-- profils **partiellement nuls**, sans erreur — des avatars manquants au
-- hasard, et rien pour le dire. C'est exactement la raison d'être de
-- `membres_du_groupe`, et elle vaut ici aussi.
--
-- Le fichier s'applique **avant** `tranche7_durcissement.sql`, qui doit rester
-- le dernier passage — et le nom entre dans sa liste d'exécution, sans quoi la
-- fonction serait refermée au passage suivant.

drop function if exists public.mes_groupes_apercu();

create or replace function public.mes_groupes_apercu()
returns table (
  group_id       uuid,
  nombre_membres integer,
  membres        jsonb
)
language sql
security definer
set search_path = public
stable
as $$
  with mes_groupes as (
    -- Les groupes dont je suis membre **actif** : un terme d'adhésion échu ne
    -- donne plus accès, et un groupe supprimé n'existe plus. Même filtre que
    -- partout ailleurs depuis la tranche 6.
    select gm.group_id
      from public.group_members gm
      join public.groups g
        on g.id = gm.group_id and g.deleted_at is null
     where gm.user_id = auth.uid()
       and (gm.expires_at is null or gm.expires_at > now())
  ),
  actifs as (
    select
      gm.group_id,
      gm.user_id,
      p.first_name,
      p.last_name,
      p.pseudo,
      coalesce('preset:' || p.avatar_preset, p.avatar_url) as avatar_url,
      -- L'ordre d'affichage : les plus anciens d'abord, `user_id` pour
      -- départager. Sans ordre stable, la rangée changerait de visages d'une
      -- lecture à l'autre sans que rien n'ait bougé.
      row_number() over (
        partition by gm.group_id order by gm.joined_at, gm.user_id
      ) as rang
      from public.group_members gm
      join mes_groupes mg on mg.group_id = gm.group_id
      left join public.profiles p on p.id = gm.user_id
     where gm.expires_at is null or gm.expires_at > now()
  )
  select
    a.group_id,
    count(*)::integer,
    -- Quatre profils au plus : c'est ce que la rangée montre avant de basculer
    -- sur « +N », et le compte total dit déjà le reste. En renvoyer davantage
    -- serait transporter des profils que personne n'affiche.
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id',    a.user_id,
          'first_name', a.first_name,
          'last_name',  a.last_name,
          'pseudo',     a.pseudo,
          'avatar_url', a.avatar_url
        )
        order by a.rang
      ) filter (where a.rang <= 4),
      '[]'::jsonb
    )
    from actifs a
   group by a.group_id;
$$;

revoke all on function public.mes_groupes_apercu() from public;
grant execute on function public.mes_groupes_apercu() to authenticated;

comment on function public.mes_groupes_apercu() is
  'Effectif et aperçu des membres de chacun de mes groupes, en une lecture.';
