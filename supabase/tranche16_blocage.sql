-- ===========================================================================
-- Tranche 16 — Bloquer quelqu'un
-- ===========================================================================
--
-- Obligation légale : depuis son profil, pouvoir bloquer quelqu'un. Une
-- personne bloquée ne doit plus pouvoir **m'inviter dans un groupe**,
-- **m'ajouter en contact**, ni **m'assigner de tâche**.
--
-- ---------------------------------------------------------------------------
-- Le principe, et le cas délicat qu'il tranche
-- ---------------------------------------------------------------------------
--
-- **Un blocage arrête un geste qui m'est adressé ; il ne change pas ce qu'un
-- groupe fait par défaut pour tous ses membres.**
--
-- Ce n'est pas une liste de trois exceptions, c'est une règle, et c'est elle
-- qui répond au cas délicat — deux personnes déjà dans le même groupe :
--
-- | Ce que fait le blocage | Pourquoi |
-- | --- | --- |
-- | refuse une invitation de groupe | elle m'est adressée, et je ne l'ai pas demandée |
-- | refuse une demande de contact | idem |
-- | refuse une assignation de tâche | idem |
-- | **ne touche pas la conversation partagée** | elle n'est adressée à personne en particulier, et masquer ses messages la trouerait de réponses à des propos invisibles |
-- | **ne retire personne du groupe** | l'adhésion est l'affaire du groupe et de ses administrateurs, pas d'un réglage personnel |
-- | **ne retire personne d'un événement de groupe** | `creer_evenement` convie **tous** les membres actifs : exclure quelqu'un serait réécrire le groupe depuis un réglage personnel |
--
-- La dernière ligne mérite d'être dite, parce qu'elle paraît incohérente avec
-- la troisième : pourquoi refuser une tâche et pas un événement ? Parce que
-- **l'assignation nomme une personne** — c'est un geste choisi, un par un —
-- alors que l'invitation à un événement de groupe est le défaut pour
-- l'ensemble des membres. Et il n'existe aucun événement **personnel** auquel
-- on puisse convier quelqu'un : un événement sans `group_id` n'est visible
-- que de son propriétaire. L'invitation à un événement n'existe donc que dans
-- un groupe déjà partagé, c'est-à-dire exactement l'espace que le blocage ne
-- réécrit pas.
--
-- Conséquence qu'il faut **dire** à l'écran plutôt que de la laisser
-- découvrir : bloquer quelqu'un avec qui l'on partage un groupe ne le fait pas
-- disparaître de ce groupe. Un blocage qui en promet plus qu'il n'en fait est
-- pire qu'un blocage qui annonce sa limite, et la suite qui a du sens — quitter
-- le groupe — existe déjà.
--
-- ---------------------------------------------------------------------------
-- Le prédicat est symétrique, et c'est un choix
-- ---------------------------------------------------------------------------
--
-- `bloque(a, b)` est vrai dès qu'un blocage existe **dans un sens ou dans
-- l'autre**. Un seul prédicat, donc une seule règle à tenir : avoir bloqué
-- quelqu'un puis lui envoyer une invitation serait incohérent, et deux
-- prédicats auraient fini par diverger — c'est le reproche déjà fait, et
-- retenu, aux deux implémentations de la visibilité des disponibilités.
--
-- ---------------------------------------------------------------------------
-- Trois déclencheurs, et non quatre fonctions réécrites
-- ---------------------------------------------------------------------------
--
-- Les trois gestes passent par des fonctions différentes — `inviter_dans_groupe`
-- pour l'invitation, une insertion directe pour le contact, et **quatre**
-- fonctions pour l'assignation : `creer_tache`, `definir_assignes_tache`,
-- `s_attribuer_tache`, `prendre_tache`. Poser la garde dans chacune, c'est
-- six endroits à tenir d'accord, dont deux vivent dans un fichier **gelé**
-- (`tranche3_taches_et_evenements.sql`) qu'il faudrait recopier en entier.
--
-- La garde est donc posée sur les **tables**, en `before insert` :
--
--   invitations · contacts · task_assignees
--
-- C'est la méthode de la requête A0, appliquée à une interdiction : partir de
-- l'endroit où la donnée atterrit plutôt que de la liste des chemins auxquels
-- on a pensé. **Un septième chemin d'écriture ajouté demain est couvert sans
-- qu'on y pense**, et c'est exactement ce qui manque à une garde recopiée.
--
-- Le déclencheur **lève**, il ne filtre pas. Une ligne silencieusement écartée
-- donnerait une tâche dont l'assigné manque sans que rien ne le dise — le
-- défaut que ce projet appelle « pire qu'une erreur », et qui a coûté la
-- promotion de membre. Le SQLSTATE `JB001` est propre à Jelvo, et
-- `AuthFailure` le traduit : « cette personne ne peut pas être ajoutée ».
--
-- ---------------------------------------------------------------------------
-- Ce que bloquer défait, et ce qu'il laisse
-- ---------------------------------------------------------------------------
--
-- | Défait | Laissé |
-- | --- | --- |
-- | le lien de contact, **dans les deux sens** — avec ses favoris | les messages déjà écrits |
-- | les invitations encore `pending` entre les deux | les tâches **déjà** assignées |
-- | | les adhésions aux groupes |
--
-- Le lien de contact part parce que c'est le minimum de ce que « bloquer »
-- veut dire, et `contact_status` ne connaît pas de valeur `blocked` : c'est la
-- suppression de la ligne qui porte le refus, comme pour une demande déclinée.
--
-- Les assignations déjà posées restent : la consigne dit qu'une personne
-- bloquée ne doit **plus pouvoir** assigner, au futur. Les retirer
-- changerait une tâche du groupe après coup.


-- ---------------------------------------------------------------------------
-- 1. La table
-- ---------------------------------------------------------------------------
--
-- Pas de colonne `id` : la clé primaire est la paire, comme
-- `message_reactions` et `message_reads`. **C'est elle qui porte la règle** —
-- un blocage par paire —, sans test préalable et donc sans course entre deux
-- appels simultanés.

create table if not exists public.blocages (
  bloqueur_id uuid not null references public.profiles(id) on delete cascade,
  bloque_id   uuid not null references public.profiles(id) on delete cascade,
  cree_le     timestamptz not null default now(),

  primary key (bloqueur_id, bloque_id),
  constraint blocages_pas_soi_meme check (bloqueur_id <> bloque_id)
);

alter table public.blocages enable row level security;

-- Aucune politique, et le privilège retiré : la table est hors de portée de
-- l'API. Les quatre fonctions ci-dessous sont la seule porte — règle de la
-- tranche 7, appliquée dès la création.
revoke all on public.blocages from anon, authenticated;

comment on table public.blocages is
  'Qui a bloqué qui. Aucune politique et aucun privilège : les fonctions sont '
  'la seule porte. Un blocage arrête un geste adressé à quelqu''un ; il ne '
  'change pas ce qu''un groupe fait par défaut pour tous ses membres.';

-- Pour « qui m'a bloqué », qui est la moitié la plus lue par les
-- déclencheurs : la clé primaire ne sert que l'autre sens.
create index if not exists blocages_bloque_idx
  on public.blocages (bloque_id);


-- ---------------------------------------------------------------------------
-- 2. Le prédicat
-- ---------------------------------------------------------------------------
--
-- `stable` : l'existence d'un blocage ne change pas pendant une requête, et
-- le planificateur peut donc n'appeler la fonction qu'une fois.
--
-- **Un paramètre nul rend faux**, et ce n'est pas de la complaisance : les
-- travaux d'entretien — `appliquer_adhesions_echues`, `empiler_rappels` —
-- tournent sans session, `auth.uid()` y vaut `null`, et un prédicat qui
-- lèverait là ferait échouer la vidange de la file.

create or replace function public.bloque(p_un uuid, p_autre uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_un is not null
     and p_autre is not null
     and exists (
       select 1 from public.blocages b
        where (b.bloqueur_id = p_un and b.bloque_id = p_autre)
           or (b.bloqueur_id = p_autre and b.bloque_id = p_un)
     );
$$;

comment on function public.bloque(uuid, uuid) is
  'Vrai si un blocage existe entre ces deux personnes, dans un sens ou dans '
  'l''autre. Un seul prédicat : deux auraient fini par diverger.';


-- ---------------------------------------------------------------------------
-- 3. La garde, posée sur les tables
-- ---------------------------------------------------------------------------
--
-- Le déclencheur compare **l'auteur du geste** — `auth.uid()` — à la personne
-- visée, et non le créateur de l'objet : ce qui est interdit, c'est le geste,
-- pas l'existence de l'objet. C'est pourquoi un tiers peut parfaitement
-- assigner la même tâche aux deux personnes qui se bloquent : il ne s'adresse
-- à aucune des deux *en leur nom*.

create or replace function public.refuser_si_bloque()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  acteur uuid := auth.uid();
  vise   uuid;
begin
  -- La colonne visée diffère d'une table à l'autre, et le nom de la table est
  -- lu sur le déclencheur plutôt que passé en argument.
  --
  -- **Trois instructions et non un `case`**, pour une raison qui ne se devine
  -- pas : une expression plpgsql est compilée **en entier**, si bien qu'un
  -- `case tg_table_name when … then new.invitee_id … end` fait échouer le
  -- déclencheur sur `contacts` avec « record "new" has no field
  -- "invitee_id" » — la branche non prise est compilée quand même. Trois
  -- affectations séparées sont trois instructions, et chacune n'est préparée
  -- qu'au premier passage dans sa branche. Le test de fumée l'a trouvé.
  if tg_table_name = 'invitations' then
    vise := new.invitee_id;
  elsif tg_table_name = 'contacts' then
    vise := new.addressee_id;
  elsif tg_table_name = 'task_assignees' then
    vise := new.user_id;
  end if;

  -- S'assigner à soi-même n'est pas un geste adressé à autrui — et la
  -- contrainte de la table rend `bloque(x, x)` faux de toute façon.
  if acteur is null or vise is null or acteur = vise then
    return new;
  end if;

  if public.bloque(acteur, vise) then
    -- **Lever, et non filtrer.** Une ligne silencieusement écartée donnerait
    -- une tâche dont l'assigné manque sans que rien ne le dise.
    raise exception 'blocage entre % et %', acteur, vise
      using errcode = 'JB001',
            hint = 'un blocage existe entre ces deux personnes';
  end if;

  return new;
end;
$$;

comment on function public.refuser_si_bloque() is
  'Garde `before insert` commune aux trois tables où atterrit un geste '
  'adressé à quelqu''un. Lève en JB001 ; AuthFailure le traduit.';

-- `create trigger` n'accepte pas `if not exists` partout : le `drop` qui
-- précède rend le fichier rejouable, comme pour les politiques.
drop trigger if exists invitations_refus_blocage on public.invitations;
create trigger invitations_refus_blocage
  before insert on public.invitations
  for each row execute function public.refuser_si_bloque();

drop trigger if exists contacts_refus_blocage on public.contacts;
create trigger contacts_refus_blocage
  before insert on public.contacts
  for each row execute function public.refuser_si_bloque();

drop trigger if exists task_assignees_refus_blocage on public.task_assignees;
create trigger task_assignees_refus_blocage
  before insert on public.task_assignees
  for each row execute function public.refuser_si_bloque();


-- ---------------------------------------------------------------------------
-- 4. Bloquer
-- ---------------------------------------------------------------------------
--
-- Un mot d'état, comme partout : « déjà bloqué » n'est pas une panne, et
-- l'écran doit pouvoir le dire plutôt que d'annoncer un second blocage.

create or replace function public.bloquer(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  moi uuid := auth.uid();
begin
  if moi is null then
    return 'non_connecte';
  end if;
  if p_user_id is null then
    return 'introuvable';
  end if;
  if p_user_id = moi then
    return 'soi_meme';
  end if;

  if not exists (
    select 1 from public.profiles p
     where p.id = p_user_id and p.supprime_le is null
  ) then
    return 'introuvable';
  end if;

  insert into public.blocages (bloqueur_id, bloque_id)
  values (moi, p_user_id)
  on conflict (bloqueur_id, bloque_id) do nothing;

  if not found then
    return 'deja_bloque';
  end if;

  -- Le lien de contact part **dans les deux sens**, avec ses favoris : c'est
  -- le minimum de ce que « bloquer » veut dire, et `contact_status` n'a pas
  -- de valeur `blocked` — c'est la suppression qui porte le refus.
  delete from public.contacts c
   where (c.requester_id = moi and c.addressee_id = p_user_id)
      or (c.requester_id = p_user_id and c.addressee_id = moi);

  -- Les invitations encore en attente entre les deux : les laisser
  -- permettrait d'accepter demain une invitation de quelqu'un qu'on bloque
  -- aujourd'hui, ce que le refus d'insertion interdit par ailleurs.
  delete from public.invitations i
   where i.status = 'pending'
     and ((i.inviter_id = moi and i.invitee_id = p_user_id)
       or (i.inviter_id = p_user_id and i.invitee_id = moi));

  return 'bloque';
end;
$$;

comment on function public.bloquer(uuid) is
  'Bloque quelqu''un et défait le lien de contact et les invitations en '
  'attente. Ne touche ni les groupes partagés ni les messages déjà écrits.';


-- ---------------------------------------------------------------------------
-- 5. Débloquer
-- ---------------------------------------------------------------------------
--
-- **Rien n'est rendu.** Le lien de contact et les invitations supprimés ne
-- reviennent pas : il faut se redemander en contact. C'est le même parti que
-- l'adhésion échue et rangée de la tranche 6 — ce qui a été défait ne se
-- reconstitue pas, et prétendre le contraire demanderait de garder une
-- mémoire de ce qu'on a effacé, donc de ne pas l'effacer.

create or replace function public.debloquer(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  moi uuid := auth.uid();
begin
  if moi is null then
    return 'non_connecte';
  end if;

  delete from public.blocages b
   where b.bloqueur_id = moi and b.bloque_id = p_user_id;

  if not found then
    return 'pas_bloque';
  end if;

  return 'debloque';
end;
$$;

comment on function public.debloquer(uuid) is
  'Retire son propre blocage. Ne rend ni le lien de contact ni les '
  'invitations supprimées : il faut se redemander en contact.';


-- ---------------------------------------------------------------------------
-- 6. La liste
-- ---------------------------------------------------------------------------
--
-- **Elle est nécessaire, pas confortable.** `profil_consultable` ne rend plus
-- rien à une personne bloquée ni sur une personne bloquée : sans cette liste,
-- il n'y aurait aucun chemin pour débloquer quelqu'un — on aurait enfermé
-- l'utilisateur dans son propre réglage.
--
-- Le profil est joint ici plutôt que relu côté client, pour la raison
-- habituelle : `profiles_select` vaut `id = auth.uid() or has_social_link(id)`
-- depuis la tranche 7, et bloquer quelqu'un **supprime** le lien de contact
-- qui aurait pu le rendre lisible.

create or replace function public.mes_blocages()
returns table (
  user_id    uuid,
  pseudo     text,
  nom        text,
  avatar_url text,
  cree_le    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select b.bloque_id,
         case when p.supprime_le is null then p.pseudo end,
         public.nom_affiche(b.bloque_id),
         case when p.supprime_le is null
              then coalesce('preset:' || p.avatar_preset, p.avatar_url)
         end,
         b.cree_le
    from public.blocages b
    left join public.profiles p on p.id = b.bloque_id
   where b.bloqueur_id = auth.uid()
   order by b.cree_le desc;
$$;

comment on function public.mes_blocages() is
  'Les personnes que j''ai bloquées. Seule porte vers le déblocage, puisque '
  'leur profil ne se lit plus.';


-- ---------------------------------------------------------------------------
-- 7. Les privilèges
-- ---------------------------------------------------------------------------
-- La tranche 7 referme toute fonction absente de sa liste, et ne se rejoue
-- que si son propre contenu change : les `grant` sont reposés ici.

grant execute on function public.bloque(uuid, uuid) to authenticated;
grant execute on function public.bloquer(uuid) to authenticated;
grant execute on function public.debloquer(uuid) to authenticated;
grant execute on function public.mes_blocages() to authenticated;
