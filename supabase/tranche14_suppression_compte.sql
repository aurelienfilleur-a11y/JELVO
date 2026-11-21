-- ===========================================================================
-- Tranche 14 — Suppression de compte
-- ===========================================================================
--
-- Obligation légale : une personne doit pouvoir supprimer son compte
-- elle-même, sans écrire à personne. Ce qui l'identifie disparaît ; ses
-- messages restent dans les conversations, signés « Compte supprimé », pour
-- ne pas trouer les échanges des autres.
--
-- ---------------------------------------------------------------------------
-- La forme n'a pas été choisie : le schéma l'impose
-- ---------------------------------------------------------------------------
--
-- `profiles.id` référence `auth.users(id)` **on delete cascade**, et
-- `messages.sender_id` référence `profiles(id)` **sans cascade**. Supprimer
-- la ligne d'authentification entraîne donc la suppression du profil, que
-- PostgreSQL refuse en `23503` tant qu'un seul message subsiste.
--
-- « Ses messages restent » et « sa ligne est supprimée » sont incompatibles
-- par construction, et la voie officielle ne s'en sort pas mieux :
-- `auth.admin.deleteUser` depuis une fonction Edge échouerait sur exactement
-- la même contrainte. La ligne survit donc, et c'est son **contenu** qui est
-- détruit — y compris dans `auth`, où `postgres` a bien `update` et `delete`
-- (vérifié sur le projet, le propriétaire étant `supabase_auth_admin`).
--
-- ---------------------------------------------------------------------------
-- Rien ne cascade, et c'est le piège de cette tranche
-- ---------------------------------------------------------------------------
--
-- Douze tables référencent `profiles(id)` en `on delete cascade`. Il serait
-- facile d'en conclure qu'elles se vident d'elles-mêmes : **elles ne se
-- vident pas**, puisque la ligne `profiles` ne part pas. Tout ce qui doit
-- disparaître est donc supprimé **explicitement** ci-dessous.
--
-- La liste n'a pas été dressée de mémoire. Elle vient du catalogue —
-- `pg_constraint`, toutes les clés étrangères pointant vers `profiles(id)` —
-- et c'est la méthode de la requête A0 : partir de la base et lui confronter
-- le code, plutôt que partir d'une liste de tables auxquelles on a pensé.
-- `verification/fumee.sql` refait cette confrontation à chaque rejeu, de
-- sorte qu'une table ajoutée demain et oubliée ici fasse échouer le rejeu.
--
-- Les dix-huit sites et leur sort :
--
--   supprimés   availabilities · contacts (deux bouts) · event_participants
--               group_members · invitations (deux bouts) · message_reactions
--               message_reads · notification_preferences · notifications
--               push_outbox · push_reminders_sent · push_tokens
--               task_assignees
--   gardés      messages.sender_id — tout l'objet de la règle
--               tasks.created_by · groups.created_by · task_list_items.checked_by
--               events.owner_id, pour un événement **de groupe**
--   à part      events.owner_id d'un rendez-vous **personnel** : supprimé,
--               personne d'autre ne le voit


-- ---------------------------------------------------------------------------
-- 0. La recherche de pseudo écarte les comptes supprimés
-- ---------------------------------------------------------------------------
-- Le pseudo de pierre tombale commence par « supprime. », et une recherche
-- sur ce début sortirait tous les comptes supprimés du service. Il n'y a
-- personne à inviter derrière.
--
-- **Ce filtre a d'abord été posé dans la tranche 2, et cela a cassé la
-- livraison.** Modifier un fichier le fait rejouer, et la tranche 2 n'est
-- **plus rejouable** : la tranche 6 a redéfini `apercu_groupe_par_jeton` avec
-- une colonne de sortie de plus, si bien que le `create or replace` de la
-- tranche 2 tente de revenir en arrière et échoue net —
--
--     ERROR: cannot change return type of existing function
--     HINT:  Use DROP FUNCTION apercu_groupe_par_jeton(text) first.
--
-- Chaque fichier étant appliqué dans sa propre transaction, la tranche 2 est
-- restée intacte ; mais tout ce qui la suit dans le manifeste n'a jamais été
-- appliqué, cette tranche-ci comprise. Le compte avait donc un bouton de
-- suppression et la base n'avait pas la fonction.
--
-- `tool/pieges_migrations.py` liste les trois fichiers gelés. La signature de
-- `chercher_profils_par_pseudo` ne change pas, donc un `create or replace`
-- suffit ici — et ce fichier devient son dernier définisseur, c'est-à-dire
-- son propriétaire.
create or replace function public.chercher_profils_par_pseudo(terme text)
returns table (
  id          uuid,
  pseudo      text,
  first_name  text,
  last_name   text,
  avatar_url  text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.pseudo, p.first_name, p.last_name,
         coalesce('preset:' || p.avatar_preset, p.avatar_url)
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and length(trim(terme)) >= 2
    and p.pseudo like lower(trim(terme)) || '%'
    and p.supprime_le is null
  order by p.pseudo
  limit 20;
$$;

grant execute on function public.chercher_profils_par_pseudo(text)
  to authenticated;


-- ---------------------------------------------------------------------------
-- 1. Les fichiers qu'il faut retirer avant d'appeler la suppression
-- ---------------------------------------------------------------------------
-- **Le stockage ne peut pas être vidé depuis le SQL.** Un `delete` sur
-- `storage.objects` retire la ligne et laisse les octets dans le bucket : le
-- fichier devient introuvable, il n'est pas effacé. Seule l'API Storage
-- supprime l'objet, donc seul le client peut le faire — et il doit le faire
-- **avant** l'anonymisation, après laquelle sa session est révoquée et il n'a
-- plus le droit de toucher à rien.
--
-- Ce que cette fonction rend, c'est la liste de ses messages vocaux.
--
-- **Pourquoi les vocaux seulement.** Un message vocal est sa voix : il
-- l'identifie directement, et ce n'est pas une mémoire partagée. Une photo
-- est le plus souvent photo de quelque chose — un restaurant, une vue —, et
-- l'effacer trouerait l'échange, ce que la règle veut précisément éviter.
-- Limite assumée, parce que rien ne permet de la lever : une photo qui montre
-- son visage reste, aucune lecture de la base ne pouvant le savoir.
create or replace function public.mes_medias_a_effacer()
returns table (chemin text)
language sql
security definer
set search_path = public
stable
as $$
  select m.media_url
    from public.messages m
   where m.sender_id = auth.uid()
     and m.media_kind = 'audio'
     and m.media_url is not null
     and m.deleted_at is null;
$$;

grant execute on function public.mes_medias_a_effacer() to authenticated;


-- ---------------------------------------------------------------------------
-- 2. Supprimer son compte
-- ---------------------------------------------------------------------------
-- `security definer` : la fonction écrit dans quinze tables de `public` dont
-- l'application n'a plus le privilège depuis la tranche 7, et dans `auth`,
-- qui ne lui a jamais été ouvert.
--
-- Elle rend un **mot d'état** et non un booléen, pour la raison déjà apprise
-- avec `promouvoir_membre` : une écriture dont l'effet dépend d'une politique
-- ne se juge pas à l'absence d'erreur.
create or replace function public.supprimer_mon_compte()
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  moi          uuid := auth.uid();
  adhesion     record;
  restants     integer;
  autre_admin  boolean;
  successeur   uuid;
begin
  if moi is null then
    return 'non_connecte';
  end if;

  if not exists (select 1 from public.profiles p where p.id = moi) then
    return 'introuvable';
  end if;

  -- Rejouable sans dégât : un second appel ne refait pas le travail, et ne
  -- renvoie pas d'erreur non plus. Le réseau peut très bien avoir perdu la
  -- réponse du premier.
  if exists (
    select 1 from public.profiles p
     where p.id = moi and p.supprime_le is not null
  ) then
    return 'deja_supprime';
  end if;

  -- 2.1 Les groupes, un par un, avec **exactement** les deux garde-fous de
  --     `quitter_groupe` : plus aucun membre actif referme le groupe, plus
  --     aucun administrateur promeut le plus ancien. Les réécrire autrement
  --     donnerait deux règles pour le même fait, et la seconde finirait par
  --     diverger.
  for adhesion in
    select m.group_id, (m.role = 'admin') as etait_admin
      from public.group_members m
     where m.user_id = moi
       and (m.expires_at is null or m.expires_at > now())
  loop
    delete from public.group_members
     where group_id = adhesion.group_id and user_id = moi;

    select count(*)::integer into restants
      from public.group_members m
     where m.group_id = adhesion.group_id
       and (m.expires_at is null or m.expires_at > now());

    if restants = 0 then
      update public.groups
         set deleted_at = now()
       where id = adhesion.group_id and deleted_at is null;

    elsif adhesion.etait_admin then
      select exists (
        select 1 from public.group_members m
         where m.group_id = adhesion.group_id
           and m.role = 'admin'
           and (m.expires_at is null or m.expires_at > now())
      ) into autre_admin;

      if not autre_admin then
        select m.user_id into successeur
          from public.group_members m
         where m.group_id = adhesion.group_id
           and (m.expires_at is null or m.expires_at > now())
         order by m.joined_at asc
         limit 1;

        update public.group_members
           set role = 'admin'
         where group_id = adhesion.group_id and user_id = successeur;
      end if;
    end if;
  end loop;

  -- Les adhésions **échues** ne passent pas par la boucle — elle ne regarde
  -- que les actives, comme toute lecture de `group_members` — et rien ne les
  -- emporterait sans cela.
  delete from public.group_members where user_id = moi;

  -- 2.2 Ses liens d'invitation sont révoqués. Sans cela, un lien tiré par un
  --     compte supprimé continuerait d'ouvrir le groupe à qui le présente.
  update public.group_invite_links
     set revoked_at = now()
   where created_by = moi and revoked_at is null;

  -- 2.3 Une tâche qui n'avait qu'elle **retourne au groupe**, plutôt que de
  --     rester assignée à personne en se disant prise. `tache_prise` repasse
  --     donc à faux, pour que la carte de la conversation redonne ses
  --     boutons — c'est le drapeau que `se_desister` retire, et le même geste.
  --
  --     Calculé **avant** la suppression des assignations : après, la
  --     condition ne trouverait plus rien.
  update public.messages m
     set tache_prise = false
   where m.tache_prise
     and m.task_id in (
       select a.task_id
         from public.task_assignees a
        where a.user_id = moi
          and not exists (
            select 1 from public.task_assignees b
             where b.task_id = a.task_id and b.user_id <> moi
          )
     );

  -- 2.4 Ses rendez-vous personnels. Un événement **de groupe** reste : le
  --     groupe compte dessus, et aucun transfert de propriété n'est
  --     nécessaire — `modifier_evenement` et `supprimer_evenement` acceptent
  --     déjà un administrateur du groupe autant que l'auteur.
  update public.events
     set deleted_at = now()
   where owner_id = moi and group_id is null and deleted_at is null;

  -- 2.5 Ses messages vocaux deviennent des messages supprimés. Le fichier,
  --     lui, est retiré du bucket par le client avant cet appel.
  --
  --     La forme est dictée par `messages_check`, qui exige un contenu **ou**
  --     un média : vider les deux donnerait un `23514`. C'est exactement ce
  --     que fait déjà `supprimer_message`, et pour la même raison.
  update public.messages
     set deleted_at = now(),
         content = '',
         media_url = null,
         media_kind = null,
         media_duree_s = null
   where sender_id = moi
     and media_kind = 'audio'
     and deleted_at is null;

  -- 2.6 Les notifications **des autres** qui la nomment. Leur `payload`
  --     porte une copie de son nom à côté de son identifiant, et une
  --     notification qui réclame une réponse à propos de quelqu'un qui n'a
  --     plus de compte n'a plus d'objet.
  --
  --     La comparaison part des **valeurs** du `payload`, pas d'une liste de
  --     noms de clés : `inviter_id` ici, `requester_id` là, et demain un
  --     troisième auquel personne n'aurait pensé. C'est la leçon de la
  --     requête A0, appliquée à du JSON.
  delete from public.notifications n
   where exists (
     select 1 from jsonb_each_text(n.payload) kv where kv.value = moi::text
   );

  -- 2.7 Tout ce qui est à elle, et qui ne cascade pas puisque sa ligne reste.
  delete from public.task_assignees          where user_id = moi;
  delete from public.event_participants      where user_id = moi;
  delete from public.message_reactions       where user_id = moi;
  delete from public.message_reads           where user_id = moi;
  delete from public.availabilities          where user_id = moi;
  delete from public.contacts                where requester_id = moi
                                                or addressee_id = moi;
  delete from public.invitations             where invitee_id = moi
                                                or inviter_id = moi;
  delete from public.notification_preferences where user_id = moi;
  delete from public.notifications           where user_id = moi;
  delete from public.push_tokens             where user_id = moi;
  delete from public.push_outbox             where user_id = moi;
  delete from public.push_reminders_sent     where user_id = moi;

  -- 2.8 Le profil devient une pierre tombale.
  --
  --     Le pseudo doit rester unique et respecter
  --     `^[a-z0-9.]{3,20}$` : « supprime. » plus onze caractères
  --     hexadécimaux font exactement vingt. Son vrai pseudo **redevient
  --     libre**, ce qui est voulu — c'est une donnée qui l'identifie, et les
  --     messages sont signés par un libellé, pas par un pseudo, si bien que
  --     personne ne peut en hériter l'apparence.
  --
  --     `first_name` et `last_name` sont `not null` : ils passent à la chaîne
  --     vide, et non à une phrase. **Le libellé affiché vient de l'ARB** —
  --     écrire « Compte supprimé » ici le donnerait en français à un
  --     téléphone allemand.
  update public.profiles
     set pseudo            = 'supprime.' || substr(replace(moi::text, '-', ''), 1, 11),
         first_name        = '',
         last_name         = '',
         avatar_url        = null,
         avatar_preset     = null,
         bio               = null,
         interests         = '{}',
         anniversaire_jour = null,
         anniversaire_mois = null,
         last_seen_at      = null,
         supprime_le       = now()
   where id = moi;

  -- 2.9 L'authentification. L'adresse vit à **trois** endroits, et deux sont
  --     à notre portée : `auth.users.email` et `auth.identities`, qui en
  --     garde une copie dans `identity_data`. Le troisième est le journal
  --     d'audit de gotrue, journal d'exploitation que Supabase fait tourner
  --     sur une fenêtre glissante : il n'est pas réécrit ici, et c'est un
  --     choix consigné dans les limites connues.
  --
  --     L'adresse passe à `null` plutôt qu'à une valeur de remplacement :
  --     elle **redevient disponible**, et la personne peut se réinscrire avec
  --     la même. Un `supprime+…@invalid` l'aurait retenue pour rien.
  delete from auth.identities      where user_id = moi;
  delete from auth.sessions        where user_id = moi;
  delete from auth.mfa_factors     where user_id = moi;
  delete from auth.one_time_tokens where user_id = moi;

  -- **`refresh_tokens.user_id` est un `character varying`**, là où les quatre
  -- autres portent un `uuid` : c'est gotrue qui en décide. Sans la conversion
  -- explicite, PostgreSQL répond « operator does not exist: character varying
  -- = uuid » (`42883`) et la suppression entière échoue.
  delete from auth.refresh_tokens  where user_id = moi::text;

  update auth.users
     set email              = null,
         phone              = null,
         email_change       = null,
         encrypted_password = null,
         raw_user_meta_data = '{}'::jsonb
   where id = moi;

  return 'supprime';
end;
$$;

grant execute on function public.supprimer_mon_compte() to authenticated;
