-- Tranche 7 — durcissement avant ouverture à de vrais utilisateurs.
--
-- Idempotent : le rejouer ne casse rien.
--
-- Revue des politiques RLS, des privilèges de table, des droits d'exécution
-- des fonctions et des trois buckets de stockage. Tout ce qui suit a été
-- relevé sur `supabase/schema_actuel.sql` — le schéma **réel** —, et non
-- deviné.
--
--
-- LE PRINCIPE QUI GUIDE TOUT LE FICHIER
--
-- L'application n'écrit directement que dans **six** tables : `profiles`,
-- `contacts`, `notifications`, `groups`, `group_invite_links` et — en lecture
-- seule — `group_members`. Tout le reste passe par des fonctions
-- `security definer`, qui contrôlent l'appartenance au groupe avant d'écrire.
--
-- Vérifié en recensant tous les `.from('…')` de `lib/` : c'est le seul point
-- d'entrée PostgREST vers une table. Les politiques d'écriture des autres
-- tables n'ont donc **aucun usage légitime**, et chacune est une porte
-- ouverte qu'aucun code n'emprunte.
--
-- Une fonction `security definer` appartenant à `postgres`, propriétaire des
-- tables, contourne RLS : retirer ces politiques ne gêne donc aucune écriture
-- légitime. C'est déjà ce qui fait marcher `definir_assignes_tache`, qui
-- supprime dans `task_assignees` alors qu'aucune politique DELETE n'y existe.


-- ---------------------------------------------------------------------------
-- 1. `profiles` — le `OR true` ouvrait toute la table
-- ---------------------------------------------------------------------------
-- La politique relevée en production :
--
--     profiles_select : ((id = auth.uid()) OR has_social_link(id) OR true)
--
-- Le troisième terme rend les deux premiers sans effet : **tout le monde,
-- session ou pas, lisait tous les profils** — pseudo, nom, prénom, avatar,
-- bio, centres d'intérêt, fuseau, dernière connexion. C'est une commodité de
-- développement restée en place.
--
-- Rien ne casse en la retirant : membres, contacts et recherche passent tous
-- par des fonctions `security definer`, précisément parce que « rien ne
-- garantit qu'un utilisateur puisse lire la ligne `profiles` d'un autre ».
-- Le seul appel direct qui lisait le profil d'autrui est le contrôle de
-- disponibilité d'un pseudo, remplacé au point 2.

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select
  using (id = auth.uid() or public.has_social_link(id));


-- ---------------------------------------------------------------------------
-- 2. Contrôler un pseudo sans ouvrir la table
-- ---------------------------------------------------------------------------
-- L'inscription vérifie qu'un pseudo est libre. Avec la politique resserrée,
-- la requête directe ne renverrait plus jamais rien : tout pseudo paraîtrait
-- disponible, et l'échec ne surviendrait qu'à l'enregistrement.
--
-- La fonction ne renvoie qu'un **booléen**. Elle ne dit pas à qui appartient
-- le pseudo, et ne peut donc pas servir à dresser un annuaire.

create or replace function public.pseudo_disponible(p_pseudo text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select not exists (
    select 1 from public.profiles p
    where p.pseudo = lower(trim(p_pseudo))
  );
$$;


-- ---------------------------------------------------------------------------
-- 3. Fermer l'écriture directe des tables pilotées par fonction
-- ---------------------------------------------------------------------------
-- Trois trous s'y trouvaient, et les deux premiers suffisaient à entrer dans
-- n'importe quel groupe :
--
--   * `gm_insert with check (user_id = auth.uid())` — **s'inscrire soi-même
--     dans n'importe quel groupe**, avec le rôle de son choix, pour peu qu'on
--     en connaisse l'identifiant. Or les identifiants circulent : dans les
--     liens d'invitation, dans les charges utiles de notification, dans les
--     URL d'écran ;
--   * `inv_insert with check (inviter_id = auth.uid())` — **forger une
--     invitation pour soi-même** vers n'importe quel groupe, puis appeler
--     `accepter_invitation`, qui ne vérifiait pas que l'invitant en était
--     membre ;
--   * les politiques UPDATE sans `with check` : PostgreSQL retombe alors sur
--     l'expression `using`, si bien qu'un message, un événement ou une
--     participation pouvaient être **déplacés vers un autre groupe** tout en
--     restant conformes.
--
-- Le privilège est retiré **avant** la politique : c'est lui la vraie
-- barrière, contrôlée avant même que RLS n'entre en jeu.

do $$
declare
  t text;
  p record;
  tables constant text[] := array[
    'group_members', 'invitations',
    'events', 'event_participants',
    'tasks', 'task_assignees', 'task_list_items',
    'messages', 'message_reactions', 'message_reads',
    'availabilities', 'push_tokens', 'notification_preferences',
    'push_outbox', 'push_reminders_sent'
  ];
begin
  foreach t in array tables loop
    execute format(
      'revoke insert, update, delete, truncate, references, trigger '
      'on public.%I from anon, authenticated', t);

    -- Les politiques d'écriture qui subsistent seraient un piège : sans
    -- usage aujourd'hui, elles rouvriraient le trou le jour où quelqu'un
    -- rendrait le privilège. On les retire aussi.
    for p in
      select policyname
      from pg_policies
      where schemaname = 'public'
        and tablename = t
        and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
        -- `notif_insert_declencheur` ne vise que `postgres` : elle sert aux
        -- déclencheurs, pas au client.
        and not ('postgres' = any(roles))
    loop
      execute format('drop policy if exists %I on public.%I',
                     p.policyname, t);
    end loop;
  end loop;

  raise notice 'Écriture directe fermée sur % tables.', array_length(tables, 1);
end;
$$;

-- `message_reads` et `availabilities` portaient une politique `ALL`, donc
-- aussi la lecture : elle est reposée en SELECT seul.
drop policy if exists reads_select on public.message_reads;
create policy reads_select on public.message_reads
  for select using (user_id = auth.uid());

drop policy if exists av_select on public.availabilities;
create policy av_select on public.availabilities
  for select using (user_id = auth.uid());

drop policy if exists mr_select on public.message_reactions;
create policy mr_select on public.message_reactions
  for select using (
    exists (
      select 1 from public.messages m
      where m.id = message_reactions.message_id
        and public.est_membre_du_groupe(m.group_id, auth.uid())
    )
  );

drop policy if exists tli_select on public.task_list_items;
create policy tli_select on public.task_list_items
  for select using (public.peut_voir_tache(task_id));

drop policy if exists pt_select on public.push_tokens;
create policy pt_select on public.push_tokens
  for select using (user_id = auth.uid());

drop policy if exists np_select on public.notification_preferences;
create policy np_select on public.notification_preferences
  for select to authenticated using (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 4. Les quatre tables encore écrites par le client
-- ---------------------------------------------------------------------------
-- Elles gardent leurs politiques, mais les colonnes modifiables sont bornées
-- par des `grant` de colonnes. Une politique RLS ne sait pas dire « cette
-- ligne, mais pas cette colonne » ; un privilège, si.

-- `contacts` : l'application ne change que le statut et les deux favoris.
-- Sans borne, on pouvait réécrire `requester_id` ou `addressee_id` d'une
-- ligne où l'on figure — donc **fabriquer un lien social avec n'importe
-- qui**, ce que `has_social_link` prend pour argent comptant, et qui ouvre
-- désormais la lecture d'un profil.
revoke update on public.contacts from anon, authenticated;
grant update (status, favorite_requester, favorite_addressee)
  on public.contacts to authenticated;

drop policy if exists contacts_update on public.contacts;
create policy contacts_update on public.contacts
  for update
  using (requester_id = auth.uid() or addressee_id = auth.uid())
  with check (requester_id = auth.uid() or addressee_id = auth.uid());

-- Insérer une demande de contact : en être l'émetteur, et ne pas se prendre
-- soi-même pour destinataire.
drop policy if exists contacts_insert on public.contacts;
create policy contacts_insert on public.contacts
  for insert to authenticated
  with check (requester_id = auth.uid() and addressee_id <> auth.uid());

-- `notifications` : seul `read_at` bouge. Le reste est déposé par des
-- déclencheurs, et n'a pas à être réécrit par son destinataire.
revoke update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- `group_invite_links` : révoquer, et rien d'autre. Sans borne, le compteur
-- d'utilisations pouvait être remis à zéro — un lien épuisé redevenait
-- utilisable — et le terme d'adhésion réécrit après envoi.
revoke update on public.group_invite_links from anon, authenticated;
grant update (revoked_at) on public.group_invite_links to authenticated;

-- `groups` : tout sauf `id` et `created_by`.
revoke update on public.groups from anon, authenticated;
grant update (name, description, photo_url, is_private, deleted_at)
  on public.groups to authenticated;

drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups
  for update to authenticated
  using (public.is_group_admin(id))
  with check (public.is_group_admin(id));

-- `profiles` : on ne touche qu'à sa propre ligne, et `id` reste hors
-- d'atteinte.
revoke update on public.profiles from anon, authenticated;
grant update (pseudo, first_name, last_name, avatar_url, avatar_preset,
              bio, interests, timezone, last_seen_at)
  on public.profiles to authenticated;

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
  for insert to authenticated
  with check (id = auth.uid());


-- ---------------------------------------------------------------------------
-- 5. Les liens d'invitation ne se lisent plus anonymement
-- ---------------------------------------------------------------------------
--     lien_invitation_lecture_publique  SELECT {anon}  using (true)
--
-- Le `grant` de colonnes restreignait la lecture anonyme à `(token,
-- group_id)`, mais **rien ne restreignait les lignes** : une seule requête
-- sans session ramenait *tous* les jetons actifs du service, et chacun ouvre
-- un groupe à qui le présente.
--
-- L'application ne lit jamais cette table sans session : la page publique
-- passe par `apercu_groupe_par_jeton`, qui est `security definer`, exige le
-- jeton exact et ne renvoie qu'un aperçu.

drop policy if exists lien_invitation_lecture_publique on public.group_invite_links;
revoke select on public.group_invite_links from anon;

-- Créer un lien reste ouvert à tout membre ; le révoquer, à son auteur ou à
-- un administrateur. Inchangé, mais reposé pour que la lecture du fichier
-- suffise à connaître l'état.
drop policy if exists lien_invitation_creation on public.group_invite_links;
create policy lien_invitation_creation on public.group_invite_links
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and public.est_membre_du_groupe(group_id, auth.uid())
  );


-- ---------------------------------------------------------------------------
-- 6. `accepter_invitation` vérifie que l'invitant était membre
-- ---------------------------------------------------------------------------
-- Défense en profondeur : le point 3 a fermé l'écriture directe dans
-- `invitations`, mais la fonction ne doit pas dépendre de cette seule
-- barrière. Une invitation dont l'émetteur n'est plus — ou n'a jamais été —
-- membre du groupe n'ouvre rien.

create or replace function public.accepter_invitation(p_invitation_id uuid)
returns text
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  inv public.invitations%rowtype;
begin
  select * into inv
  from public.invitations i
  where i.id = p_invitation_id
    and i.invitee_id = auth.uid()
  for update;

  if not found or inv.status <> 'pending' then
    return 'invalide';
  end if;

  if inv.type <> 'group' or inv.group_id is null then
    return 'invalide';
  end if;

  if not exists (
    select 1 from public.groups g
    where g.id = inv.group_id and g.deleted_at is null
  ) then
    return 'invalide';
  end if;

  -- Le contrôle ajouté par la tranche 7.
  if not public.est_membre_du_groupe(inv.group_id, inv.inviter_id) then
    update public.invitations set status = 'expired' where id = inv.id;
    return 'invalide';
  end if;

  if inv.expires_at is not null and inv.expires_at <= now() then
    update public.invitations set status = 'expired' where id = inv.id;
    return 'expire';
  end if;

  if inv.membership_expires_at is not null
     and inv.membership_expires_at <= now() then
    update public.invitations set status = 'expired' where id = inv.id;
    return 'terme_passe';
  end if;

  if public.est_membre_du_groupe(inv.group_id, auth.uid()) then
    update public.invitations set status = 'accepted' where id = inv.id;
    return 'deja_membre';
  end if;

  delete from public.group_members
  where group_id = inv.group_id and user_id = auth.uid();

  insert into public.group_members (group_id, user_id, role, expires_at)
  values (inv.group_id, auth.uid(), 'member', inv.membership_expires_at);

  update public.invitations set status = 'accepted' where id = inv.id;

  return 'rejoint';
end;
$$;


-- ---------------------------------------------------------------------------
-- 7. Droits d'exécution des fonctions — le trou le plus large
-- ---------------------------------------------------------------------------
-- **PostgreSQL accorde `EXECUTE` à `PUBLIC` par défaut.** Un
-- `grant execute … to service_role` *ajoute* un droit, il n'en retire aucun :
-- les fonctions réservées au rôle de service étaient donc appelables par
-- n'importe quel porteur de la clé publiable, et PostgREST les expose toutes.
--
-- Concrètement, avant ce fichier :
--
--   * `push_a_envoyer(50)` renvoyait les **endpoints et les clés Web Push**
--     des notifications en attente de tout le monde — de quoi leur écrire
--     directement ;
--   * `empiler_push(…)` déposait une notification arbitraire dans la boîte de
--     n'importe qui ;
--   * `empiler_rappels()` et `appliquer_adhesions_echues()` se déclenchaient
--     à la demande.
--
-- On retire donc tout, puis on rouvre exactement la liste que l'application
-- appelle — relevée dans `lib/`, pas devinée. Les fonctions de déclencheur
-- n'y figurent pas : un déclencheur s'exécute sous le propriétaire de la
-- table, jamais sous l'appelant.

do $$
declare
  f record;
  ouvertes constant text[] := array[
    -- Authentification et profil
    'email_pour_pseudo', 'pseudo_disponible',
    -- Groupes, membres, invitations
    'creer_groupe', 'quitter_groupe', 'membres_du_groupe',
    'inviter_dans_groupe', 'accepter_invitation', 'refuser_invitation',
    'mes_invitations', 'invitation_par_id',
    'apercu_groupe_par_jeton', 'rejoindre_groupe_par_jeton',
    'promouvoir_membre', 'retrograder_membre', 'retirer_membre',
    'definir_terme_adhesion',
    -- Contacts et recherche
    'mes_contacts', 'chercher_profils_par_pseudo',
    -- Tâches
    'creer_tache', 'modifier_tache', 'supprimer_tache', 'mes_taches',
    'terminer_tache', 'repondre_tache', 's_attribuer_tache',
    'definir_assignes_tache',
    'articles_de_tache', 'ajouter_article', 'cocher_article',
    'supprimer_article',
    -- Événements
    'creer_evenement', 'modifier_evenement', 'supprimer_evenement',
    'mon_agenda', 'repondre_evenement',
    -- Disponibilités
    'mes_disponibilites', 'definir_disponibilite', 'supprimer_disponibilite',
    'statuts_de_disponibilite',
    -- Chat
    'envoyer_message', 'messages_du_groupe', 'messages_non_lus',
    'marquer_lu', 'reagir_message', 'supprimer_message',
    -- Notifications
    'mes_preferences_notification', 'definir_preference_notification',
    'enregistrer_push', 'oublier_push',
    -- Prédicats évalués **dans** les politiques RLS : ils s'exécutent sous le
    -- rôle appelant, et sans le droit la requête échouerait au lieu de ne
    -- rien renvoyer.
    'est_membre_du_groupe', 'est_admin_du_groupe',
    'is_group_member', 'is_group_admin',
    'has_social_link', 'groupe_du_chemin', 'peut_voir_tache',
    'peut_voir_evenement'
  ];
  service constant text[] := array[
    'push_a_envoyer', 'marquer_push_traite', 'purger_push',
    'empiler_rappels', 'appliquer_adhesions_echues'
  ];
  manquantes text[] := '{}';
  n text;
  retirees integer := 0;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public'
  loop
    execute format('revoke all on function %s from public, anon, authenticated',
                   f.sig);
    retirees := retirees + 1;
  end loop;

  -- `anon` n'en garde que deux : se connecter par pseudo suppose de n'avoir
  -- pas encore de session, et la page publique d'invitation non plus.
  for f in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = any(ouvertes)
  loop
    execute format('grant execute on function %s to authenticated', f.sig);
    if f.proname in ('email_pour_pseudo', 'pseudo_disponible',
                     'apercu_groupe_par_jeton', 'groupe_du_chemin',
                     'is_group_member', 'is_group_admin',
                     'est_membre_du_groupe', 'est_admin_du_groupe',
                     'has_social_link') then
      execute format('grant execute on function %s to anon', f.sig);
    end if;
  end loop;

  for f in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = any(service)
  loop
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;

  -- Une faute de frappe dans la liste ci-dessus fermerait une fonction que
  -- l'application appelle, et le défaut ne se verrait qu'à l'usage. On le dit
  -- tout de suite.
  foreach n in array ouvertes || service loop
    if not exists (
      select 1 from pg_proc p
      join pg_namespace ns on ns.oid = p.pronamespace
      where ns.nspname = 'public' and p.proname = n
    ) then
      manquantes := manquantes || n;
    end if;
  end loop;

  if array_length(manquantes, 1) is not null then
    raise exception
      'Fonctions nommées dans la liste mais absentes de la base : %',
      array_to_string(manquantes, ', ');
  end if;

  raise notice
    'Droits d''exécution : % fonctions fermées, % rouvertes à authenticated.',
    retirees, array_length(ouvertes, 1);
end;
$$;


-- ---------------------------------------------------------------------------
-- 8. Buckets — politiques, poids et types
-- ---------------------------------------------------------------------------
-- `chat-media` était déjà policé par la tranche 5b. `avatars` et
-- `group-photos` ne l'étaient pas : leurs politiques sont restées celles du
-- développement, et le poids comme le type de fichier n'étaient bornés que
-- côté application — c'est-à-dire nulle part, une requête pouvant se passer
-- de l'application.
--
-- **La convention de chemin porte l'autorisation**, comme pour `chat-media` :
--
--     avatars/<user_id>/avatar_<horodatage>.<ext>
--     group-photos/<group_id>/photo_<horodatage>.<ext>
--
-- Le premier segment dit à qui appartient l'objet. `groupe_du_chemin`
-- l'extrait déjà et renvoie `null` hors convention — jamais une exception,
-- qui ferait échouer la requête entière au lieu de refuser l'accès.
--
-- Ces deux buckets restent **publics en lecture** : l'application enregistre
-- l'URL publique dans `profiles.avatar_url` et `groups.photo_url`, et les
-- rendre privés invaliderait toutes les URL déjà stockées. C'est un choix
-- assumé, signalé dans CLAUDE.md, et non un oubli.

do $$
begin
  execute $politique$
    -- avatars : lecture ouverte (bucket public), écriture réservée à son
    -- propre dossier.
    drop policy if exists avatars_lecture on storage.objects;
    create policy avatars_lecture on storage.objects
      for select to anon, authenticated
      using (bucket_id = 'avatars');

    drop policy if exists avatars_depot on storage.objects;
    create policy avatars_depot on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'avatars'
        and (string_to_array(name, '/'))[1] = auth.uid()::text
      );

    drop policy if exists avatars_maj on storage.objects;
    create policy avatars_maj on storage.objects
      for update to authenticated
      using (
        bucket_id = 'avatars'
        and (string_to_array(name, '/'))[1] = auth.uid()::text
      )
      with check (
        bucket_id = 'avatars'
        and (string_to_array(name, '/'))[1] = auth.uid()::text
      );

    drop policy if exists avatars_retrait on storage.objects;
    create policy avatars_retrait on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'avatars'
        and (string_to_array(name, '/'))[1] = auth.uid()::text
      );

    -- group-photos : lecture ouverte (bucket public), écriture réservée aux
    -- **administrateurs** du groupe — c'est déjà qui peut modifier le groupe.
    drop policy if exists group_photos_lecture on storage.objects;
    create policy group_photos_lecture on storage.objects
      for select to anon, authenticated
      using (bucket_id = 'group-photos');

    drop policy if exists group_photos_depot on storage.objects;
    create policy group_photos_depot on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'group-photos'
        and public.est_admin_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      );

    drop policy if exists group_photos_maj on storage.objects;
    create policy group_photos_maj on storage.objects
      for update to authenticated
      using (
        bucket_id = 'group-photos'
        and public.est_admin_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      )
      with check (
        bucket_id = 'group-photos'
        and public.est_admin_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      );

    drop policy if exists group_photos_retrait on storage.objects;
    create policy group_photos_retrait on storage.objects
      for delete to authenticated
      using (
        bucket_id = 'group-photos'
        and public.est_admin_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      );

    -- chat-media : la tranche 5b n'avait pas donné de `with check` à la
    -- politique UPDATE. PostgreSQL retombe alors sur `using`, qui ne regarde
    -- que le propriétaire : un membre pouvait **déplacer son propre média
    -- vers le dossier d'un autre groupe**, et le donner à lire à des gens qui
    -- n'y avaient pas droit.
    drop policy if exists chat_media_maj on storage.objects;
    create policy chat_media_maj on storage.objects
      for update to authenticated
      using (bucket_id = 'chat-media' and owner = auth.uid())
      with check (
        bucket_id = 'chat-media'
        and owner = auth.uid()
        and public.est_membre_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      );
  $politique$;

  raise notice 'Politiques des trois buckets posées.';
exception
  when insufficient_privilege then
    raise warning
      'ATTENTION — politiques de stockage NON posées : privilèges '
      'insuffisants sur storage.objects. Collez le point 8 de '
      'supabase/tranche7_durcissement.sql dans l''éditeur SQL du projet.';
  when undefined_table then
    raise warning
      'ATTENTION — schema storage absent : politiques ignorées. Attendu en '
      'rejeu local, anormal sur le projet Supabase.';
end;
$$;

-- Poids et types acceptés, **côté serveur**. La borne de l'application ne
-- protège que l'application : une requête directe s'en passe.
--
-- 25 Mio pour `chat-media` reprend exactement `AppConfig.chatMediaMaxVideoBytes` ;
-- 2 Mio suffisent pour une photo de profil déjà compressée à la sélection.
do $$
begin
  update storage.buckets
     set file_size_limit = 2 * 1024 * 1024,
         allowed_mime_types = array[
           'image/jpeg', 'image/png', 'image/webp',
           'image/heic', 'image/heif'
         ]
   where id in ('avatars', 'group-photos');

  update storage.buckets
     set file_size_limit = 25 * 1024 * 1024,
         allowed_mime_types = array[
           'image/jpeg', 'image/png', 'image/webp', 'image/gif',
           'image/heic', 'image/heif',
           'video/mp4', 'video/quicktime', 'video/webm'
         ]
   where id = 'chat-media';

  raise notice 'Bornes de poids et de type posées sur les trois buckets.';
exception
  when insufficient_privilege then
    raise warning
      'ATTENTION — bornes des buckets NON posées : privilèges insuffisants '
      'sur storage.buckets. À régler depuis le tableau de bord Supabase, '
      'Storage, chaque bucket, Settings.';
  when undefined_table then
    raise warning 'schema storage absent : bornes des buckets ignorées.';
end;
$$;
