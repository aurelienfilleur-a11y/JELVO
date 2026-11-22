-- Test de fumée — NE PAS EXÉCUTER SUR LE PROJET SUPABASE.
--
-- Ce fichier n'est pas une migration. Il s'exécute sur la base jetable montée
-- par `rejouer.sh`, après les sept fichiers de `supabase/`, et **appelle
-- réellement** chaque fonction de la tranche 3 sous le rôle `authenticated`.
--
-- Pourquoi cela ne fait pas double emploi avec le rejeu. `create function` ne
-- vérifie que la syntaxe du corps d'une fonction plpgsql : les instructions SQL
-- qu'elle contient ne sont préparées qu'au premier appel. Un rejeu vert ne dit
-- donc rien de leur validité de typage.
--
-- Ce n'est pas théorique : `creer_tache` a été livrée avec
--
--     case when assigne = utilisateur then 'accepted' else 'pending' end
--
-- pour une colonne de type `assignee_status`. Deux littéraux sans type dans un
-- `case` se résolvent en `text`, et il n'existe pas de conversion implicite de
-- `text` vers un type énuméré : `42804 column "status" is of type
-- assignee_status but expression is of type text`, à chaque création de tâche.
-- La fonction se créait sans broncher. Seul un appel pouvait le montrer.
--
-- **Règle qui en découle** : toute valeur d'énumération écrite depuis une
-- fonction porte une conversion explicite — `'pending'::assignee_status`,
-- `(case … end)::event_response`. Un littéral seul fonctionne par coercition du
-- littéral non typé vers la colonne, mais dès qu'il entre dans une expression
-- il devient `text` et la coercition ne s'applique plus.
--
-- Rien n'est conservé : le `rollback` final annule le décor comme les appels.

begin;

set local role postgres;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'fumee@exemple.test'),
  ('33333333-3333-3333-3333-333333333333', 'autre@exemple.test');

insert into public.profiles (id, pseudo, first_name, last_name) values
  ('11111111-1111-1111-1111-111111111111', 'moi', 'Camille', 'Rousseau'),
  ('33333333-3333-3333-3333-333333333333', 'lea', 'Léa', 'Marchand');

insert into public.groups (id, name, created_by) values
  ('22222222-2222-2222-2222-222222222222', 'Famille Rousseau',
   '11111111-1111-1111-1111-111111111111');

insert into public.group_members (group_id, user_id, role) values
  ('22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111', 'admin'),
  ('22222222-2222-2222-2222-222222222222',
   '33333333-3333-3333-3333-333333333333', 'member');

-- À partir d'ici, tout se joue sous le rôle et le jeton de l'application.
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $fumee$
declare
  tache      uuid;
  libre      uuid;
  occupee    uuid;
  evenement  uuid;
  article    uuid;
  articles   integer;
  resultat   text;
  creneau    uuid;
  message    uuid;
  message2   uuid;
  vocal      uuid;
  photo2     uuid;
  invit      uuid;
begin
  -- Tâches -----------------------------------------------------------------
  tache := (public.creer_tache(
    p_title       => 'Fumée — courses',
    p_group_id    => '22222222-2222-2222-2222-222222222222'::uuid,
    p_description => 'Test de fumée',
    p_due_at      => now() + interval '2 days',
    p_priority    => 'high',
    p_reminder_at => now() + interval '1 day',
    p_rrule       => 'FREQ=WEEKLY',
    p_assignees   => array['11111111-1111-1111-1111-111111111111'::uuid,
                           '33333333-3333-3333-3333-333333333333'::uuid],
    p_items       => array['pain', 'lait']
  )).id;

  perform public.creer_tache(p_title => 'Fumée — tâche personnelle');

  resultat := public.repondre_tache(tache, 'accepted');
  assert resultat = 'accepted', 'repondre_tache : ' || resultat;

  perform public.definir_assignes_tache(
    tache, array['11111111-1111-1111-1111-111111111111'::uuid]);

  perform public.terminer_tache(tache, true);
  perform public.terminer_tache(tache, false);

  -- Liste de courses --------------------------------------------------------
  article := public.ajouter_article(tache, 'beurre');
  perform public.cocher_article(article, true);
  perform public.cocher_article(article, false);

  select count(*) into articles from public.articles_de_tache(tache);
  assert articles = 3, 'articles_de_tache : ' || articles;

  assert public.supprimer_article(article), 'supprimer_article';

  -- Événements --------------------------------------------------------------
  evenement := (public.creer_evenement(
    p_title            => 'Fumée — repas de famille',
    p_starts_at        => now() + interval '3 days',
    p_ends_at          => now() + interval '3 days 2 hours',
    p_group_id         => '22222222-2222-2222-2222-222222222222'::uuid,
    p_description      => 'Test de fumée',
    p_location         => 'Salon',
    p_rrule            => 'FREQ=MONTHLY',
    p_image_url        => 'https://exemple.test/photo.jpg',
    p_reminder_minutes => 30
  )).id;

  perform public.creer_evenement(
    p_title     => 'Fumée — rendez-vous personnel',
    p_starts_at => now() + interval '1 day'
  );

  -- Le déclencheur de la tranche 3b prévient les autres membres conviés, et
  -- seulement eux : l'organisateur n'a pas à être notifié de son propre
  -- événement.
  assert (select count(*) from public.notifications
           where type = 'event_invitation'
             and user_id = '33333333-3333-3333-3333-333333333333'::uuid) = 1,
         'notification d''événement absente';
  assert (select count(*) from public.notifications
           where type = 'event_invitation'
             and user_id = '11111111-1111-1111-1111-111111111111'::uuid) = 0,
         'l''organisateur ne doit pas être notifié';

  resultat := public.repondre_evenement(evenement, 'maybe');
  assert resultat = 'maybe', 'repondre_evenement : ' || resultat;

  -- Répondre referme la notification de l'invitée. C'est bien **elle** qui
  -- répond, pas l'organisateur : le déclencheur ne touche que la ligne de
  -- celui qui a répondu, et l'éprouver sous le mauvais jeton ne prouverait
  -- rien.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  perform public.repondre_evenement(evenement, 'yes');

  assert (select count(*) from public.notifications
           where type = 'event_invitation'
             and user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and read_at is null) = 0,
         'répondre n''a pas refermé la notification';

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  -- Lectures ----------------------------------------------------------------
  assert (select count(*) from public.mes_taches()) = 2, 'mes_taches';
  assert (select count(*) from public.mon_agenda()) = 2, 'mon_agenda';
  assert (select count(*) from public.mes_taches(
            '22222222-2222-2222-2222-222222222222'::uuid)) = 1,
         'mes_taches(groupe)';

  -- Modification (tranche 3b) ------------------------------------------------
  assert (public.modifier_tache(
    p_task_id  => tache,
    p_title    => 'Fumée — courses (modifiée)',
    p_due_at   => now() + interval '5 days',
    p_priority => 'low'
  )).title = 'Fumée — courses (modifiée)', 'modifier_tache';

  assert (public.modifier_evenement(
    p_event_id  => evenement,
    p_title     => 'Fumée — repas (déplacé)',
    p_starts_at => now() + interval '4 days',
    p_ends_at   => now() + interval '4 days 1 hour',
    p_location  => 'Jardin'
  )).location = 'Jardin', 'modifier_evenement';

  -- Prendre et lâcher une tâche libre ---------------------------------------
  libre := (public.creer_tache(
    p_title     => 'Fumée — tâche libre',
    p_group_id  => '22222222-2222-2222-2222-222222222222'::uuid,
    p_assignees => array[]::uuid[]
  )).id;

  resultat := public.s_attribuer_tache(libre, true);
  assert resultat = 'pris', 's_attribuer_tache (prendre) : ' || resultat;

  resultat := public.s_attribuer_tache(libre, true);
  assert resultat = 'deja_pris', 's_attribuer_tache (deux fois) : ' || resultat;

  resultat := public.s_attribuer_tache(libre, false);
  assert resultat = 'lache', 's_attribuer_tache (lâcher) : ' || resultat;

  -- Une tâche déjà assignée à autrui ne se prend pas : s'en emparer
  -- reviendrait à décider pour quelqu'un d'autre.
  occupee := (public.creer_tache(
    p_title     => 'Fumée — tâche de Léa',
    p_group_id  => '22222222-2222-2222-2222-222222222222'::uuid,
    p_assignees => array['33333333-3333-3333-3333-333333333333'::uuid]
  )).id;

  resultat := public.s_attribuer_tache(occupee, true);
  assert resultat = 'deja_assignee',
         's_attribuer_tache (occupée) : ' || resultat;

  -- Administration des membres ----------------------------------------------
  resultat := public.promouvoir_membre(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid);
  assert resultat = 'promu', 'promouvoir_membre : ' || resultat;

  resultat := public.promouvoir_membre(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid);
  assert resultat = 'deja_admin', 'promouvoir_membre (deux fois) : ' || resultat;

  resultat := public.retrograder_membre(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid);
  assert resultat = 'retrograde', 'retrograder_membre : ' || resultat;

  -- Le dernier administrateur ne peut pas être rétrogradé.
  resultat := public.retrograder_membre(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '11111111-1111-1111-1111-111111111111'::uuid);
  assert resultat = 'dernier_admin', 'retrograder (dernier) : ' || resultat;

  resultat := public.retirer_membre(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '11111111-1111-1111-1111-111111111111'::uuid);
  assert resultat = 'soi_meme', 'retirer_membre (soi) : ' || resultat;

  resultat := public.retirer_membre(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid);
  assert resultat = 'retire', 'retirer_membre : ' || resultat;

  -- Suppressions douces -----------------------------------------------------
  assert public.supprimer_tache(tache), 'supprimer_tache';
  assert public.supprimer_tache(libre), 'supprimer_tache (libre)';
  assert public.supprimer_evenement(evenement), 'supprimer_evenement';

  assert public.supprimer_tache(occupee), 'supprimer_tache (occupée)';

  assert (select count(*) from public.mes_taches()) = 1, 'tâche non retirée';
  assert (select count(*) from public.mon_agenda()) = 1, 'événement non retiré';

  -- Disponibilités (tranche 4) ----------------------------------------------
  creneau := (public.definir_disponibilite(
    p_kind => 'recurring', p_weekday => 2,
    p_start => '09:00', p_end => '12:00', p_status => 'available'
  )).id;

  perform public.definir_disponibilite(
    p_kind => 'exception', p_on_date => (now() + interval '3 days')::date,
    p_start => '14:00', p_end => '18:00', p_status => 'unavailable'
  );

  -- Modifier son propre créneau ne le duplique pas.
  perform public.definir_disponibilite(
    p_id => creneau, p_kind => 'recurring', p_weekday => 3,
    p_start => '10:00', p_end => '11:00', p_status => 'unavailable');

  -- Le dimanche vaut **0** dans la base (`extract(dow)`), pas 7 : la
  -- contrainte `availabilities_weekday_check` borne le jour à 0..6. Ce cas est
  -- ici parce qu'il a échappé au décor, qui ne portait pas la contrainte.
  perform public.definir_disponibilite(
    p_kind => 'recurring', p_weekday => 0,
    p_start => '15:00', p_end => '17:00', p_status => 'available');

  assert (select count(*) from public.mes_disponibilites()) = 3,
         'mes_disponibilites';

  -- Les autres ne voient qu'un mot parmi trois, jamais un créneau.
  assert (select statut from public.statuts_de_disponibilite(
            array['33333333-3333-3333-3333-333333333333'::uuid], now())) 
         in ('available', 'unavailable', 'unknown'),
         'statuts_de_disponibilite';

  assert public.supprimer_disponibilite(creneau), 'supprimer_disponibilite';
  assert not public.supprimer_disponibilite(creneau),
         'supprimer deux fois doit renvoyer faux';

  -- **CONTRÔLE NÉGATIF de la tranche 7.** L'insertion directe ci-dessous
  -- fonctionnait, et c'était le trou principal : n'importe qui pouvait
  -- s'inscrire dans n'importe quel groupe, au rôle de son choix, en
  -- connaissant son identifiant — lequel circule dans les liens
  -- d'invitation et les charges utiles de notification.
  begin
    insert into public.group_members (group_id, user_id, role)
    values ('22222222-2222-2222-2222-222222222222',
            '33333333-3333-3333-3333-333333333333', 'admin');
    raise exception
      'un client a pu écrire directement dans group_members';
  exception
    when insufficient_privilege then null;
  end;

  -- Même contrôle sur les fonctions réservées au rôle de service :
  -- `push_a_envoyer` renvoie les endpoints et les clés Web Push de tout le
  -- monde, et `EXECUTE` est accordé à PUBLIC par défaut.
  begin
    perform public.push_a_envoyer(1);
    raise exception 'un client a pu appeler push_a_envoyer';
  exception
    when insufficient_privilege then null;
  end;

  -- Chat (tranche 5a) --------------------------------------------------------
  -- Le bloc « administration » ci-dessus a éprouvé `retirer_membre`, et Léa
  -- n'est donc plus dans le groupe. On l'y remet par le **chemin légitime** —
  -- inviter, puis accepter —, seul chemin qui reste ouvert : sans second
  -- membre, ni l'accusé de lecture ni le compteur de non-lus n'ont de sens à
  -- éprouver.
  perform public.inviter_dans_groupe(
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid);

  select i.id into invit
  from public.invitations i
  where i.invitee_id = '33333333-3333-3333-3333-333333333333'
    and i.group_id = '22222222-2222-2222-2222-222222222222'
    and i.status = 'pending'
  order by i.created_at desc
  limit 1;

  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  assert public.accepter_invitation(invit) = 'rejoint',
         'Léa n''a pas pu revenir dans le groupe par le chemin légitime';
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  message := public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid, 'Bonjour tout le monde');

  -- Un message ne portant qu'un média est légitime : `messages_check` exige un
  -- contenu **ou** une URL, pas les deux.
  message2 := public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid,
    p_media_url => 'chat-media/22222222/photo.jpg', p_media_kind => 'image');

  -- Deux messages **écrits**, et non deux lignes : depuis la tranche 9, les
  -- tâches et les événements du groupe déposent leur carte dans la même
  -- table. Compter les lignes ferait dépendre ce test du nombre d'éléments
  -- créés plus haut.
  assert (select count(*) from public.messages_du_groupe(
            '22222222-2222-2222-2222-222222222222'::uuid)
           where task_id is null and event_id is null) = 2,
         'messages_du_groupe';

  -- Et les cartes, elles, sont bien là — à leur place dans la conversation.
  assert (select count(*) from public.messages_du_groupe(
            '22222222-2222-2222-2222-222222222222'::uuid)
           where task_id is not null) >= 1,
         'aucune carte de tâche déposée dans la conversation';

  -- Message vocal : la valeur `audio` du type et la durée qui l'accompagne.
  vocal := public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid,
    p_media_url => 'chat-media/22222222/vocal.m4a',
    p_media_kind => 'audio', p_media_duree_s => 12);

  assert (select media_kind = 'audio' and media_duree_s = 12
            from public.messages_du_groupe(
              '22222222-2222-2222-2222-222222222222'::uuid)
           where id = vocal),
         'la durée du message vocal ne ressort pas de la lecture';

  -- Contrôle négatif : une durée **passée** avec une photo n'est pas retenue.
  -- La garder laisserait une valeur qu'aucune lecture ne saurait interpréter.
  photo2 := public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid,
    p_media_url => 'chat-media/22222222/autre.jpg',
    p_media_kind => 'image', p_media_duree_s => 99);

  assert (select media_duree_s is null
            from public.messages_du_groupe(
              '22222222-2222-2222-2222-222222222222'::uuid)
           where id = photo2),
         'une durée a été retenue sur un média qui n''est pas sonore';

  -- Et la suppression douce l'efface, comme le reste du média.
  assert public.supprimer_message(vocal), 'supprimer un message vocal';
  assert (select media_duree_s is null and media_url is null
            from public.messages_du_groupe(
              '22222222-2222-2222-2222-222222222222'::uuid)
           where id = vocal),
         'un message vocal supprimé laisse fuiter sa durée';

  -- La clé primaire tient la règle : une seule réaction par personne. Poser un
  -- second emoji remplace le premier, il ne s'y ajoute pas.
  assert public.reagir_message(message, '👍') = '👍', 'reagir_message';
  assert public.reagir_message(message, '🎉') = '🎉', 'remplacer la réaction';
  assert (select count(*) from public.message_reactions
           where message_id = message) = 1,
         'une seule réaction par personne et par message';

  -- Reposer le même emoji le retire.
  assert public.reagir_message(message, '🎉') is null, 'retirer la réaction';
  assert (select count(*) from public.message_reactions
           where message_id = message) = 0, 'réaction non retirée';

  -- « Lu » se déduit de `last_read_at`, seule chose que le schéma stocke.
  -- C'est bien l'autre membre qui lit : l'expéditeur ne se compte jamais.
  assert (select lu_par from public.messages_du_groupe(
            '22222222-2222-2222-2222-222222222222'::uuid)
          where id = message) = 0, 'lu_par avant lecture';

  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  perform public.marquer_lu('22222222-2222-2222-2222-222222222222'::uuid);

  assert (select non_lus from public.messages_non_lus()
           where group_id = '22222222-2222-2222-2222-222222222222'::uuid) = 0,
         'messages_non_lus après lecture';

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  assert (select lu_par from public.messages_du_groupe(
            '22222222-2222-2222-2222-222222222222'::uuid)
          where id = message) = 1, 'lu_par après lecture';

  -- `marquer_lu` ne recule jamais : rouvrir une vieille conversation ne doit
  -- pas « dé-lire » ce qui l'était.
  perform public.marquer_lu('22222222-2222-2222-2222-222222222222'::uuid,
                            now() - interval '1 day');
  assert (select last_read_at from public.message_reads
           where group_id = '22222222-2222-2222-2222-222222222222'::uuid
             and user_id = '11111111-1111-1111-1111-111111111111'::uuid)
         > now() - interval '1 hour',
         'marquer_lu a reculé';

  -- Suppression douce : le booléen fait foi, pas l'absence d'erreur.
  assert public.supprimer_message(message2), 'supprimer_message';
  assert not public.supprimer_message(message2),
         'supprimer deux fois doit renvoyer faux';

  -- Le contenu d'un message supprimé ne doit plus sortir de la base — le
  -- masquer à l'écran seulement le laisserait lisible dans la réponse réseau.
  assert (select content is null and media_url is null and deleted_at is not null
            from public.messages_du_groupe(
              '22222222-2222-2222-2222-222222222222'::uuid)
           where id = message2),
         'un message supprimé laisse fuiter son contenu';

  -- Médias du chat (tranche 5b) ----------------------------------------------
  -- `groupe_du_chemin` porte à elle seule l'autorisation du bucket privé : si
  -- elle levait au lieu de rendre `null`, toute politique qui l'appelle ferait
  -- échouer la requête entière plutôt que de refuser l'accès.
  assert public.groupe_du_chemin(
           '22222222-2222-2222-2222-222222222222/photo.jpg')
         = '22222222-2222-2222-2222-222222222222'::uuid,
         'groupe_du_chemin : chemin conforme';

  assert public.groupe_du_chemin('photo.jpg') is null,
         'un chemin sans dossier doit donner null, pas une erreur';
  assert public.groupe_du_chemin('pas-un-uuid/photo.jpg') is null,
         'un dossier qui n''est pas un UUID doit donner null';
  assert public.groupe_du_chemin('') is null, 'chemin vide';

  -- Contrôle positif et négatif de la règle d'accès elle-même.
  assert public.est_membre_du_groupe(
           public.groupe_du_chemin(
             '22222222-2222-2222-2222-222222222222/photo.jpg'),
           '11111111-1111-1111-1111-111111111111'::uuid),
         'un membre doit pouvoir lire les médias de son groupe';

  assert not public.est_membre_du_groupe(
           public.groupe_du_chemin('44444444-4444-4444-4444-444444444444/x.jpg'),
           '11111111-1111-1111-1111-111111111111'::uuid),
         'un non-membre ne doit pas lire les médias d''un autre groupe';

  assert not public.est_membre_du_groupe(
           public.groupe_du_chemin('hors-convention.jpg'),
           '11111111-1111-1111-1111-111111111111'::uuid),
         'un chemin hors convention ne doit ouvrir aucun accès';

  -- Notifications push (tranche 5c) ------------------------------------------
  -- **Le cas qui justifie tout le reste** : `push_tokens_platform_check`
  -- n'acceptait que `ios` et `android`. Sans l'élargissement de la tranche 5c,
  -- cet appel échouerait en `23514` — exactement le défaut du dimanche, vu
  -- cette fois avant livraison plutôt qu'après.
  assert public.enregistrer_push('endpoint-web-moi', 'web', 'cle', 'secret'),
         'enregistrer_push : plateforme web refusée';

  -- Réenregistrer le même endpoint ne duplique pas : la clé primaire est
  -- (user_id, token), et un abonnement se réenregistre à chaque démarrage.
  assert public.enregistrer_push('endpoint-web-moi', 'web', 'cle2', 'secret2');
  assert (select count(*) from public.push_tokens
           where user_id = '11111111-1111-1111-1111-111111111111'::uuid) = 1,
         'un réenregistrement a dupliqué la ligne';

  -- Tranche 14 : la langue voyage avec l'abonnement, donc par appareil.
  assert public.enregistrer_push('endpoint-web-moi', 'web', 'c', 's', 'de');
  assert (select langue from public.push_tokens
           where token = 'endpoint-web-moi') = 'de',
         'la langue de l''appareil n''a pas été retenue';

  -- **Contrôle négatif** : un client plus ancien, qui ne connaît pas le
  -- paramètre, ne doit pas effacer la langue qu'un client à jour a posée sur
  -- le même appareil. Les trois arguments d'avant suffisent à le rejouer.
  assert public.enregistrer_push('endpoint-web-moi', 'web', 'c', 's');
  assert (select langue from public.push_tokens
           where token = 'endpoint-web-moi') = 'de',
         'un client sans langue a effacé celle de l''appareil';

  -- Les neuf types sont proposés, tous activés par défaut : le modèle est un
  -- opt-out, personne n'a de ligne au départ et tout arrive.
  --
  -- **Deux assertions, et elles ne font pas double emploi.** La première est
  -- un nombre écrit à la main : il oblige à passer ici en ajoutant un type,
  -- ce qui est le seul moment où l'on se demande dans quelle famille il va
  -- et quel onglet comptera sa pastille. La seconde nomme le dernier arrivé,
  -- parce qu'un compte juste ne dit pas *lequel* est proposé.
  assert (select count(*) from public.mes_preferences_notification()) = 9,
         'neuf types attendus (le neuvième est birthday, tranche 12)';
  assert exists (select 1 from public.mes_preferences_notification()
                  where type = 'birthday'),
         'le type birthday n''atteint pas l''écran de réglages';
  -- `types_de_notification()` n'est **pas** appelable ici : la tranche 7 ne
  -- la rouvre pas à `authenticated`, et c'est voulu — l'application lit
  -- `mes_preferences_notification`, qui l'appelle sous son propriétaire. Le
  -- bloc de la tranche 12 l'éprouve directement, sous `postgres`.
  assert (select bool_and(enabled) from public.mes_preferences_notification()),
         'tout devrait être activé sans aucune ligne de préférence';

  assert not public.definir_preference_notification('chat_message', false),
         'definir_preference_notification';
  assert (select enabled from public.mes_preferences_notification()
           where type = 'chat_message') = false,
         'la préférence n''a pas été retenue';
  perform public.definir_preference_notification('chat_message', true);

  -- Un type inconnu serait accepté sans effet : il doit être refusé.
  begin
    perform public.definir_preference_notification('type_invente', true);
    raise exception 'un type inconnu aurait dû être refusé';
  exception
    when others then
      if sqlerrm <> 'type_inconnu' then raise; end if;
  end;

  -- Léa s'abonne, puis les six déclencheurs peuvent la viser.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  perform public.enregistrer_push('endpoint-web-lea', 'web', 'k', 's');
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  perform public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid, 'Message qui notifie');

  -- La promesse de l'écran de création de tâche : « Jelvo enverra une
  -- notification à la personne assignée ». Une tâche neuve : celle du début a
  -- été supprimée par le bloc des tâches.
  tache := (public.creer_tache(
    p_title    => 'Fumée — tâche qui notifie',
    p_group_id => '22222222-2222-2222-2222-222222222222'::uuid,
    p_assignees => array['33333333-3333-3333-3333-333333333333'::uuid]
  )).id;

  -- Événement neuf, pour la réponse puis le changement de date.
  evenement := (public.creer_evenement(
    p_title     => 'Fumée — événement qui notifie',
    p_starts_at => now() + interval '6 days',
    p_group_id  => '22222222-2222-2222-2222-222222222222'::uuid
  )).id;

  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  perform public.repondre_evenement(evenement, 'yes');
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  perform public.modifier_evenement(
    p_event_id  => evenement,
    p_title     => 'Fumée — événement qui notifie',
    p_starts_at => now() + interval '7 days');

  -- Une préférence désactivée arrête tout, sans rien casser d'autre.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  perform public.definir_preference_notification('chat_message', false);
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  perform public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid, 'Message qui ne notifie pas');

  raise notice
    'Fumée : les fonctions des tranches 3, 3b, 4, 5a et 5b répondent.';
end;
$fumee$;

-- ---------------------------------------------------------------------------
-- La file d'envoi se vérifie sous `postgres`, pas sous `authenticated`
-- ---------------------------------------------------------------------------
-- `push_outbox` porte une politique SELECT limitée à ses propres lignes : les
-- notifications empilées pour Léa sont **invisibles** à Camille, et compter
-- sous le mauvais jeton donnait zéro alors que les lignes existaient. C'est
-- exactement le piège que ce fichier existe pour attraper.

set local role postgres;

do $file$
declare
  ligne record;
  restants integer;
begin
  assert (select count(*) from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'chat_message') = 1,
         'un nouveau message n''a pas empilé exactement une notification';

  -- L'expéditeur ne se notifie jamais lui-même.
  assert (select count(*) from public.push_outbox
           where user_id = '11111111-1111-1111-1111-111111111111'::uuid
             and type = 'chat_message') = 0,
         'l''expéditeur s''est notifié lui-même';

  assert (select count(*) from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'task_assigned') = 1,
         'assigner une tâche n''a pas notifié la personne';

  -- Le trou de la tranche 5c : convier quelqu'un n'envoyait rien. Un
  -- événement de groupe inscrit ses membres dans `event_participants`, et
  -- cette table n'avait de déclencheur que sur `update`.
  assert (select count(*) from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_invitation') = 1,
         'convier quelqu''un à un événement ne l''a pas notifié';

  -- La règle de formulation : le titre porte le contexte, jamais un mot de
  -- catégorie, et le corps nomme l'élément puisque le titre ne le fait plus.
  assert (select title from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_invitation') = 'Famille Rousseau',
         'le titre devrait porter le nom du groupe';
  assert (select body like '%Fumée — événement qui notifie%'
            from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_invitation'),
         'le corps devrait nommer l''événement';

  -- La réponse va à l'organisateur, le changement de date aux participants.
  assert (select count(*) from public.push_outbox
           where user_id = '11111111-1111-1111-1111-111111111111'::uuid
             and type = 'event_response') = 1,
         'la réponse n''a pas notifié l''organisateur';

  assert (select count(*) from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_changed') = 1,
         'le changement de date n''a pas notifié la participante';

  -- La vidange voit les abonnements, et joint chaque ligne à son endpoint.
  select count(*) into restants from public.push_a_envoyer(100);
  assert restants > 0, 'push_a_envoyer ne renvoie rien';

  select * into ligne from public.push_a_envoyer(1);
  assert ligne.token is not null, 'push_a_envoyer sans endpoint';

  -- Tranche 14 : la vidange rend de quoi **composer** — une clé, des
  -- paramètres et la langue de l'appareil —, et plus seulement du texte. Sans
  -- ces trois colonnes, l'envoyeur retomberait en silence sur le français.
  assert (select count(*) from public.push_a_envoyer(100) l
           where l.cle is not null) > 0,
         'push_a_envoyer ne rend aucune clé de gabarit';
  assert (select count(*) from public.push_a_envoyer(100) l
           where l.langue = 'de') > 0,
         'push_a_envoyer ne rend pas la langue de l''appareil';

  -- La clé et les paramètres disent la même chose que le texte français : le
  -- titre est le groupe, et le corps nomme l'élément.
  assert (select cle from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_invitation') = 'push.invitation.evenement',
         'l''invitation à un événement n''a pas déposé sa clé';
  assert (select params->>'evenement' from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_invitation')
         = 'Fumée — événement qui notifie',
         'les paramètres ne nomment pas l''événement';
  assert (select params->>'titre' from public.push_outbox
           where user_id = '33333333-3333-3333-3333-333333333333'::uuid
             and type = 'event_invitation') = 'Famille Rousseau',
         'les paramètres ne portent pas le nom du groupe';

  perform public.marquer_push_traite(ligne.id);
  assert (select sent_at is not null from public.push_outbox
           where id = ligne.id), 'marquer_push_traite n''a rien clos';

  -- Un échec incrémente au lieu de clore : trois tentatives, puis abandon.
  select id into ligne from public.push_outbox where sent_at is null limit 1;
  perform public.marquer_push_traite(ligne.id, 'endpoint injoignable');
  assert (select attempts = 1 and sent_at is null from public.push_outbox
           where id = ligne.id), 'un échec a été pris pour un succès';

  -- Un endpoint mort se purge : sur iOS, retirer l'icône de l'écran d'accueil
  -- détruit l'abonnement sans que personne n'en soit averti.
  assert public.purger_push('endpoint-web-lea') = 1, 'purger_push';
  assert public.purger_push('endpoint-inexistant') = 0,
         'purger_push a cru retirer une ligne qui n''existait pas';

  raise notice
    'Fumée : les fonctions des tranches 3, 3b, 4, 5a, 5b et 5c répondent.';
end;
$file$;


-- ---------------------------------------------------------------------------
-- Les rappels (tranche 5d), sous `postgres` : `empiler_rappels` est réservée
-- au rôle de service, et écrit dans la boîte de tout le monde.
-- ---------------------------------------------------------------------------

do $rappels$
declare
  camille    uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea        uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  groupe     uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  tache      uuid;
  evenement  uuid;
  serie      uuid;
begin
  -- 1. `prochaine_occurrence` ------------------------------------------------
  -- Sans récurrence, l'occurrence unique ne compte que si elle est devant.
  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', null, '2026-08-03 08:00+00'
         ) = '2026-08-03 09:00+00'::timestamptz,
         'une occurrence à venir doit être proposée';
  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', null, '2026-08-03 10:00+00'
         ) is null,
         'une occurrence passée ne doit pas être proposée';

  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', 'FREQ=DAILY', '2026-08-10 08:00+00'
         ) = '2026-08-10 09:00+00'::timestamptz, 'FREQ=DAILY';

  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', 'FREQ=WEEKLY', '2026-08-04 00:00+00'
         ) = '2026-08-10 09:00+00'::timestamptz, 'FREQ=WEEKLY';

  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', 'FREQ=WEEKLY;INTERVAL=2', '2026-08-04 00:00+00'
         ) = '2026-08-17 09:00+00'::timestamptz, 'FREQ=WEEKLY;INTERVAL=2';

  -- Le 31 n'existe pas tous les mois : l'occurrence retombe sur la fin du
  -- mois, et la suivante repart de la base — elle ne se décale pas de proche
  -- en proche.
  assert public.prochaine_occurrence(
           '2026-01-31 09:00+00', 'FREQ=MONTHLY', '2026-02-15 00:00+00'
         ) = '2026-02-28 09:00+00'::timestamptz, 'FREQ=MONTHLY, mois court';
  assert public.prochaine_occurrence(
           '2026-01-31 09:00+00', 'FREQ=MONTHLY', '2026-03-15 00:00+00'
         ) = '2026-03-31 09:00+00'::timestamptz, 'FREQ=MONTHLY, retour au 31';

  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', 'FREQ=YEARLY', '2027-01-01 00:00+00'
         ) = '2027-08-03 09:00+00'::timestamptz, 'FREQ=YEARLY';

  -- Une règle que l'application n'écrit pas ne se devine pas : mieux vaut ne
  -- pas rappeler que rappeler à la mauvaise heure.
  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', 'FREQ=HOURLY', '2026-08-03 10:00+00'
         ) is null, 'une règle inconnue doit renvoyer null';
  assert public.prochaine_occurrence(
           '2026-08-03 09:00+00', 'FREQ=DAILY;INTERVAL=99999999999',
           '2026-08-04 00:00+00'
         ) is not null, 'un INTERVAL démesuré ne doit pas faire lever';

  -- 2. Le décor : deux abonnements, sans lesquels rien ne s'empile -----------
  -- Celui de Léa vient d'être purgé par le bloc précédent.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  perform public.enregistrer_push('endpoint-rappel-lea', 'web', 'k', 's');
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  perform public.enregistrer_push('endpoint-rappel-camille', 'web', 'k', 's');

  -- 3. Une tâche dont l'heure du rappel vient de passer ----------------------
  insert into public.tasks (group_id, created_by, title, due_at, reminder_at)
  values (groupe, camille, 'Fumée — rappel de tâche',
          now() + interval '1 hour', now() - interval '1 minute')
  returning id into tache;

  insert into public.task_assignees (task_id, user_id, status)
  values (tache, lea, 'pending'::assignee_status);

  assert public.empiler_rappels() >= 1, 'aucun rappel empilé';
  assert (select count(*) from public.push_outbox
           where user_id = lea and type = 'reminder') = 1,
         'la tâche n''a pas rappelé son assignée';

  -- **L'assertion qui justifie `push_reminders_sent`.** Le battement passe
  -- toutes les minutes et la fenêtre regarde dix minutes en arrière : sans
  -- mémoire, le même rappel repartirait à chaque passage.
  perform public.empiler_rappels();
  assert (select count(*) from public.push_outbox
           where user_id = lea and type = 'reminder') = 1,
         'un second passage a renvoyé le même rappel';

  -- 4. Un rendez-vous personnel rappelle son propriétaire --------------------
  insert into public.events (owner_id, title, starts_at, reminder_minutes)
  values (camille, 'Fumée — rappel d''événement',
          now() + interval '30 minutes', 30)
  returning id into evenement;

  perform public.empiler_rappels();
  assert (select count(*) from public.push_outbox
           where user_id = camille and type = 'reminder') = 1,
         'l''événement personnel n''a pas rappelé son propriétaire';

  -- 5. Un élément récurrent vise la **prochaine** occurrence -----------------
  -- Série hebdomadaire commencée il y a trois semaines : c'est l'occurrence
  -- d'aujourd'hui qui doit être rappelée, pas celle du début.
  insert into public.events (owner_id, title, starts_at, rrule, reminder_minutes)
  values (camille, 'Fumée — série hebdomadaire',
          now() - interval '21 days' + interval '30 minutes',
          'FREQ=WEEKLY', 30)
  returning id into serie;

  perform public.empiler_rappels();
  assert (select count(*) from public.push_outbox
           where user_id = camille and type = 'reminder') = 2,
         'la série récurrente n''a pas rappelé son occurrence du jour';
  assert (select occurrence > now() from public.push_reminders_sent
           where source_id = serie),
         'le rappel a visé la première occurrence au lieu de la prochaine';

  -- 6. Qui a refusé n'est pas rappelé ---------------------------------------
  insert into public.tasks (group_id, created_by, title, due_at, reminder_at)
  values (groupe, camille, 'Fumée — tâche refusée',
          now() + interval '2 hours', now() - interval '2 minutes')
  returning id into tache;

  insert into public.task_assignees (task_id, user_id, status)
  values (tache, lea, 'declined'::assignee_status);

  perform public.empiler_rappels();
  assert (select count(*) from public.push_outbox
           where user_id = lea and type = 'reminder') = 1,
         'une assignée qui a refusé a tout de même été rappelée';

  -- Avatars prédéfinis ------------------------------------------------------
  -- La colonne existe, mais ce qui compte est qu'elle **ressorte** par les
  -- fonctions de lecture : leur signature n'ayant pas changé, rien d'autre ne
  -- le prouverait.
  update public.profiles set avatar_preset = 'p2_07' where id = lea;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);

  assert (select avatar_url from public.membres_du_groupe(groupe)
           where user_id = lea) = 'preset:p2_07',
         'membres_du_groupe ne renvoie pas l''avatar prédéfini';

  -- Une photo l'emporte sur le prédéfini seulement si le prédéfini est vidé :
  -- c'est l'écriture qui tient la règle, et la lecture ne fait que préférer
  -- le prédéfini quand il est là.
  update public.profiles
     set avatar_preset = null, avatar_url = 'https://exemple.test/photo.jpg'
   where id = lea;
  assert (select avatar_url from public.membres_du_groupe(groupe)
           where user_id = lea) = 'https://exemple.test/photo.jpg',
         'la photo devrait reprendre la main une fois le prédéfini vidé';

  raise notice 'Fumée : les rappels de la tranche 5d répondent.';
end;
$rappels$;


-- ---------------------------------------------------------------------------
-- Adhésion temporaire (tranche 6).
--
-- Le rôle courant est `postgres` : `appliquer_adhesions_echues` est réservée
-- au rôle de service, et les appels côté application posent leur propre
-- `role authenticated` le temps qu'il faut.
-- ---------------------------------------------------------------------------

do $temporaire$
declare
  camille   uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea       uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  groupe    uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  passager  uuid := '44444444-4444-4444-4444-444444444444'::uuid;
  autre     uuid := '55555555-5555-5555-5555-555555555555'::uuid;
  tache     uuid;
  evenement uuid;
  invit     uuid;
  jeton     text := 'fumee-jeton-temporaire';
begin
  insert into auth.users (id, email) values
    (passager, 'passager@exemple.test'),
    (autre,    'autre2@exemple.test');
  insert into public.profiles (id, pseudo, first_name, last_name) values
    (passager, 'passager', 'Noé',  'Berger'),
    (autre,    'autre2',   'Zoé',  'Perrin');

  -- 1. Inviter avec un terme, accepter, et vérifier que le terme a suivi ----
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  assert public.inviter_dans_groupe(
           groupe, passager, now() + interval '7 days') = 'invite',
         'l''invitation à durée n''est pas partie';

  -- Un terme déjà passé donnerait une adhésion morte-née.
  assert public.inviter_dans_groupe(
           groupe, autre, now() - interval '1 day') = 'terme_passe',
         'un terme déjà passé aurait dû être refusé';

  select id into invit from public.invitations
   where invitee_id = passager and group_id = groupe;

  perform set_config('request.jwt.claims',
    '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}',
    true);
  assert public.accepter_invitation(invit) = 'rejoint',
         'l''invitation à durée n''a pas pu être acceptée';
  reset role;

  assert (select expires_at is not null from public.group_members
           where group_id = groupe and user_id = passager),
         'le terme de l''invitation n''a pas été recopié sur l''adhésion';

  -- 2. Le même terme par lien ----------------------------------------------
  insert into public.group_invite_links
    (group_id, created_by, token, membership_expires_at)
  values (groupe, camille, jeton, now() + interval '7 days');

  perform set_config('request.jwt.claims',
    '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}',
    true);
  set local role authenticated;
  assert public.rejoindre_groupe_par_jeton(jeton) = 'rejoint',
         'le lien à durée n''a pas fait adhérer';
  reset role;

  assert (select expires_at is not null from public.group_members
           where group_id = groupe and user_id = autre),
         'le terme du lien n''a pas été recopié sur l''adhésion';

  -- L'aperçu doit annoncer la durée : c'est ce que verra quelqu'un qui n'a
  -- pas encore de compte.
  assert (select membership_expires_at is not null
            from public.apercu_groupe_par_jeton(jeton)),
         'l''aperçu du lien ne dit pas que l''adhésion est temporaire';

  -- 3. Régler le terme d'une adhésion existante -----------------------------
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  assert public.definir_terme_adhesion(
           groupe, lea, now() + interval '30 days') = 'terme_defini',
         'poser un terme sur un membre permanent a échoué';
  assert public.definir_terme_adhesion(
           groupe, lea, null) = 'terme_retire',
         'rendre l''adhésion permanente a échoué';
  assert public.definir_terme_adhesion(groupe, lea, null) = 'inchange',
         'reposer la même valeur devrait être annoncé comme sans effet';
  assert public.definir_terme_adhesion(
           groupe, lea, now() - interval '1 day') = 'terme_passe',
         'écourter jusqu''à une date passée doit être refusé';

  -- **Contrôle négatif du dernier administrateur.** Camille est seule admin :
  -- lui poser un terme programmerait un groupe que personne ne peut plus
  -- administrer.
  assert public.definir_terme_adhesion(
           groupe, camille, now() + interval '3 days') = 'dernier_admin',
         'le dernier administrateur ne doit pas pouvoir devenir temporaire';

  -- Un membre ordinaire ne règle pas les durées.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  assert public.definir_terme_adhesion(
           groupe, passager, null) = 'non_admin',
         'un membre non administrateur a pu régler un terme';
  reset role;

  -- 4. Ce que l'échéance range derrière elle --------------------------------
  insert into public.tasks (group_id, created_by, title)
  values (groupe, camille, 'Fumée — tâche du passager')
  returning id into tache;
  insert into public.task_assignees (task_id, user_id, status)
  values (tache, passager, 'accepted'::assignee_status);

  insert into public.events (group_id, owner_id, title, starts_at)
  values (groupe, passager, 'Fumée — événement du passager',
          now() + interval '2 days')
  returning id into evenement;
  insert into public.event_participants (event_id, user_id, response)
  values (evenement, passager, 'yes'::event_response)
  on conflict do nothing;

  insert into public.notifications (user_id, type, payload)
  values (passager, 'group_invitation',
          jsonb_build_object('group_id', groupe));

  -- L'échéance elle-même : la ligne est antidatée, comme le ferait le temps.
  update public.group_members
     set expires_at = now() - interval '1 minute'
   where group_id = groupe and user_id = passager;

  -- Avant le battement, le groupe a **déjà** disparu pour lui : c'est la
  -- lecture qui filtre, pas le rangement.
  assert not public.est_membre_du_groupe(groupe, passager),
         'une adhésion échue devrait cesser de compter sans attendre';

  assert public.appliquer_adhesions_echues() >= 1,
         'aucune adhésion échue n''a été rangée';

  assert not exists (select 1 from public.task_assignees
                      where task_id = tache and user_id = passager),
         'la tâche est restée assignée à quelqu''un qui n''est plus là';
  assert not exists (select 1 from public.event_participants
                      where event_id = evenement and user_id = passager),
         'il reste convié à un événement du groupe';
  -- Aucune n'est restée ouverte, et non « celle-ci est fermée » : le
  -- déclencheur d'invitation en a déposé une de son côté, et une pastille
  -- allumée sur un groupe qu'on ne peut plus ouvrir est un cul-de-sac quelle
  -- que soit son origine.
  assert not exists (select 1 from public.notifications
                      where user_id = passager
                        and read_at is null
                        and payload ->> 'group_id' = groupe::text),
         'une notification du groupe est restée ouverte';
  assert not exists (select 1 from public.group_members
                      where group_id = groupe and user_id = passager),
         'l''adhésion échue n''a pas été retirée';

  -- L'événement qu'il avait créé **reste**, avec son propriétaire : il a été
  -- organisé pour les autres, et un administrateur peut le supprimer.
  assert (select deleted_at is null and owner_id = passager
            from public.events where id = evenement),
         'l''événement créé par le partant a disparu ou changé de main';

  -- **Contrôle négatif de l'idempotence.** La suppression de la ligne est la
  -- seule mémoire : un second passage ne doit rien retrouver.
  assert public.appliquer_adhesions_echues() = 0,
         'un second passage a retraité la même adhésion';

  -- 5. Un administrateur peut supprimer l'événement du partant --------------
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  assert public.supprimer_evenement(evenement),
         'un administrateur ne peut pas supprimer l''événement du partant';
  reset role;

  raise notice 'Fumée : l''adhésion temporaire de la tranche 6 répond.';
end;
$temporaire$;


-- ---------------------------------------------------------------------------
-- Les trois écrans d'invitation (tranche 8).
--
-- Ce qui est éprouvé ici, ce sont les **états** : un écran qui propose
-- « Rejoindre » sur une invitation déjà refusée est exactement le défaut que
-- la tranche corrige. Chaque état est donc atteint pour de bon, jamais
-- simulé.
-- ---------------------------------------------------------------------------

do $invitations$
declare
  camille  uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea      uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  groupe   uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  invitee  uuid := '66666666-6666-6666-6666-666666666666'::uuid;
  groupe2  uuid;
  invit    uuid;
  tache    uuid;
  evenement uuid;
  etat     text;
begin
  insert into auth.users (id, email) values (invitee, 'invitee@exemple.test');
  insert into public.profiles (id, pseudo, first_name, last_name)
  values (invitee, 'invitee', 'Yanis', 'Colin');

  -- 1. Une invitation en attente se lit, avec tout ce que l'écran affiche ---
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  assert public.inviter_dans_groupe(groupe, invitee) = 'invite',
         'l''invitation n''est pas partie';
  reset role;

  select id into invit from public.invitations
   where invitee_id = invitee and group_id = groupe;

  perform set_config('request.jwt.claims',
    '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}',
    true);
  set local role authenticated;

  select statut_ecran into etat from public.invitation_par_id(invit);
  assert etat = 'valide',
         format('une invitation en attente devrait être valide, reçu %s', etat);

  -- La date de création du groupe et les membres avec leur avatar sont ce
  -- que `mes_invitations` ne savait pas dire.
  assert (select groupe_cree_le is not null
            from public.invitation_par_id(invit)),
         'la date de création du groupe manque';
  assert (select jsonb_array_length(membres) >= 1
            from public.invitation_par_id(invit)),
         'les membres du groupe ne sont pas renvoyés';
  assert (select emetteur is not null from public.invitation_par_id(invit)),
         'le nom de l''émetteur manque';

  -- **Contrôle négatif de la portée.** Un identifiant d'invitation qui n'est
  -- pas la sienne ne doit pas livrer le nom du groupe.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  select statut_ecran into etat from public.invitation_par_id(invit);
  assert etat = 'introuvable',
         'l''invitation d''un autre a été lisible';

  -- 2. Refusée : l'écran doit le dire, pas proposer de rejoindre ------------
  perform set_config('request.jwt.claims',
    '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}',
    true);
  perform public.refuser_invitation(invit);
  select statut_ecran into etat from public.invitation_par_id(invit);
  assert etat = 'refusee',
         format('une invitation refusée devrait se dire refusée, reçu %s',
                etat);

  -- 3. Acceptée --------------------------------------------------------------
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  assert public.inviter_dans_groupe(groupe, invitee) = 'invite',
         'la seconde invitation n''est pas partie';
  select id into invit from public.invitations
   where invitee_id = invitee and group_id = groupe and status = 'pending';

  perform set_config('request.jwt.claims',
    '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}',
    true);
  assert public.accepter_invitation(invit) = 'rejoint',
         'l''invitation n''a pas pu être acceptée';
  select statut_ecran into etat from public.invitation_par_id(invit);
  assert etat = 'acceptee',
         format('une invitation acceptée devrait se dire acceptée, reçu %s',
                etat);

  -- 4. Groupe supprimé -------------------------------------------------------
  reset role;
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  groupe2 := (public.creer_groupe(
    'Fumée — groupe éphémère', null, null, false)).id;
  assert public.inviter_dans_groupe(groupe2, invitee) = 'invite',
         'l''invitation au groupe éphémère n''est pas partie';
  select id into invit from public.invitations
   where invitee_id = invitee and group_id = groupe2;
  reset role;

  update public.groups set deleted_at = now() where id = groupe2;

  perform set_config('request.jwt.claims',
    '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}',
    true);
  set local role authenticated;
  select statut_ecran into etat from public.invitation_par_id(invit);
  assert etat = 'groupe_supprime',
         format('un groupe supprimé devrait être annoncé, reçu %s', etat);

  -- 5. Introuvable renvoie **une** ligne, pas zéro ---------------------------
  -- Un appelant qui reçoit zéro ligne ne distinguerait pas « rien à cet
  -- identifiant » d'une panne de lecture.
  assert (select count(*) from public.invitation_par_id(
            '00000000-0000-0000-0000-0000000000ff'::uuid)) = 1,
         'un identifiant inconnu devrait tout de même rendre une ligne';

  -- 6. Qui invite : le nom, sur l'agenda et sur les tâches -------------------
  reset role;
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  tache := (public.creer_tache(
    p_title     => 'Fumée — tâche confiée',
    p_group_id  => groupe,
    p_assignees => array[lea])).id;
  evenement := (public.creer_evenement(
    p_title     => 'Fumée — événement convié',
    p_starts_at => now() + interval '3 days',
    p_ends_at   => now() + interval '3 days 2 hours',
    p_group_id  => groupe)).id;

  assert (select auteur = 'Camille Rousseau'
            from public.mes_taches() where id = tache),
         'le nom de l''auteur de la tâche manque';
  assert (select auteur = 'Camille Rousseau'
            from public.mon_agenda() where id = evenement),
         'le nom de l''organisateur de l''événement manque';

  -- 7. Une tâche confiée entre dans la boîte --------------------------------
  -- La tranche 5c poussait déjà vers le téléphone ; rien ne se déposait dans
  -- `notifications`, et l'écran d'attribution n'avait pas d'entrée.
  reset role;
  assert exists (select 1 from public.notifications
                  where user_id = lea
                    and type = 'task_assigned'
                    and payload ->> 'task_id' = tache::text
                    and read_at is null),
         'aucune notification d''attribution n''a été déposée';

  -- Y répondre la referme : un compteur doit refléter ce qui reste à faire.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  set local role authenticated;
  assert public.repondre_tache(tache, 'accepted') = 'accepted',
         'la réponse à l''attribution a échoué';
  reset role;

  assert not exists (select 1 from public.notifications
                      where user_id = lea
                        and type = 'task_assigned'
                        and payload ->> 'task_id' = tache::text
                        and read_at is null),
         'la notification d''attribution est restée ouverte après réponse';

  -- 7 bis. Et la réponse remonte à qui a confié la tâche ---------------------
  -- L'aller existait, le retour non : accepter ne prévenait personne.
  assert exists (select 1 from public.notifications
                  where user_id = camille
                    and type = 'task_response'
                    and payload ->> 'task_id' = tache::text
                    and payload ->> 'reponse' = 'accepted'),
         'la réponse n''est pas remontée à qui a confié la tâche';
  assert exists (select 1 from public.push_outbox
                  where user_id = camille and type = 'task_response'),
         'la réponse n''a pas été empilée pour le téléphone';

  -- Le type doit figurer dans le catalogue, sinon il n'est pas désactivable
  -- depuis les réglages — et un envoi qu'on ne peut pas couper est un défaut.
  assert exists (select 1 from public.types_de_notification()
                  where type = 'task_response'),
         'task_response ne figure pas dans les réglages de notification';

  -- **Contrôle négatif de l'auto-attribution.** Se confier une tâche à
  -- soi-même ne doit rien déposer : on sait ce qu'on vient d'écrire.
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  tache := (public.creer_tache(
    p_title     => 'Fumée — tâche pour soi',
    p_group_id  => groupe,
    p_assignees => array[camille])).id;
  reset role;

  assert not exists (select 1 from public.notifications
                      where user_id = camille
                        and type = 'task_assigned'
                        and payload ->> 'task_id' = tache::text),
         's''attribuer une tâche a déposé une notification';

  raise notice 'Fumée : les écrans d''invitation de la tranche 8 répondent.';
end;
$invitations$;

-- ---------------------------------------------------------------------------
-- Les cartes de la conversation (tranche 9).
--
-- Ce qui est éprouvé ici, c'est surtout **la course** : deux personnes qui
-- touchent « Oui » au même instant ne doivent pas prendre la tâche toutes les
-- deux. Le reste — l'état renvoyé par la carte — se lit dans la foulée.
-- ---------------------------------------------------------------------------

do $cartes$
declare
  camille uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea     uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  groupe  uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  tache   uuid;
  evenement uuid;
  carte   jsonb;
begin
  -- 1. Une tâche de groupe dépose sa carte ----------------------------------
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  -- Liste **vide** et non omise : `creer_tache` interprète `null` comme
  -- « assigne l'auteur », et une liste vide comme « proposée au groupe ».
  -- C'est déjà la distinction que fait le formulaire de création.
  tache := (public.creer_tache(
    p_title     => 'Fumée — acheter du pain',
    p_group_id  => groupe,
    p_assignees => array[]::uuid[])).id;

  assert exists (select 1 from public.messages m
                  where m.task_id = tache and m.group_id = groupe),
         'la tâche n''a pas déposé de carte dans la conversation';

  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.task_id = tache;

  assert carte ->> 'sorte' = 'tache', 'la carte ne se dit pas tâche';
  assert (carte ->> 'supprimee')::boolean is false;
  assert (carte ->> 'prise')::boolean is false,
         'une tâche neuve ne devrait pas être annoncée comme prise';
  assert jsonb_array_length(carte -> 'assignes') = 0,
         'une tâche proposée au groupe ne devrait avoir aucun assigné';

  -- 2. **La course.** Camille prend, Léa arrive juste après ------------------
  assert public.prendre_tache(tache) = 'prise',
         'la première prise a échoué';

  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  assert public.prendre_tache(tache) = 'deja_prise',
         'la tâche a pu être prise deux fois';

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.task_id = tache;
  assert (carte ->> 'prise')::boolean,
         'la carte ne dit pas que la tâche a été prise';
  assert jsonb_array_length(carte -> 'assignes') = 1,
         'la prise n''a pas posé exactement un assigné';

  -- 3. Se désister rouvre la tâche ------------------------------------------
  -- **Contrôle négatif** : quelqu'un qui n'a pas pris la tâche ne s'en
  -- désiste pas.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  assert public.se_desister(tache) = 'non_assigne',
         'un tiers a pu se désister d''une tâche qu''il n''avait pas prise';

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  assert public.se_desister(tache) = 'desiste',
         'le preneur n''a pas pu se désister';

  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.task_id = tache;
  assert (carte ->> 'prise')::boolean is false,
         'la carte reste marquée « prise » après un désistement';
  assert jsonb_array_length(carte -> 'assignes') = 0,
         'le désistement n''a pas retiré l''assignation';

  -- Et elle est reprenable : c'est tout l'objet du désistement.
  assert public.prendre_tache(tache) = 'prise',
         'une tâche rendue n''a pas pu être reprise';

  -- 4. Une tâche **confiée** n'est pas une tâche prise -----------------------
  -- Le drapeau `tache_prise` est ce qui sépare « Thomas a pris la tâche » de
  -- « Tâche attribuée à Thomas » : sans lui, les deux se liraient pareil.
  tache := (public.creer_tache(
    p_title     => 'Fumée — tâche confiée depuis la carte',
    p_group_id  => groupe,
    p_assignees => array[lea])).id;

  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.task_id = tache;
  assert (carte ->> 'prise')::boolean is false,
         'une tâche confiée ne doit pas être annoncée comme prise';
  assert jsonb_array_length(carte -> 'assignes') = 1,
         'la tâche confiée n''a pas son assigné';

  -- Elle se refuse, elle ne se rend pas.
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  assert public.se_desister(tache) = 'non_desistable',
         'une tâche confiée a pu être rendue au lieu d''être refusée';
  assert public.repondre_tache(tache, 'declined') = 'declined',
         'le refus d''une tâche confiée a échoué';

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.task_id = tache;
  assert carte -> 'assignes' -> 0 ->> 'status' = 'declined',
         'la carte ne reflète pas le refus';

  -- 5. Un événement de groupe dépose la sienne, avec son décompte ------------
  evenement := (public.creer_evenement(
    p_title     => 'Fumée — carte d''événement',
    p_starts_at => now() + interval '5 days',
    p_ends_at   => now() + interval '5 days 2 hours',
    p_group_id  => groupe)).id;

  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.event_id = evenement;
  assert carte ->> 'sorte' = 'evenement', 'la carte ne se dit pas événement';

  perform public.repondre_evenement(evenement, 'yes');
  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.event_id = evenement;
  assert (carte ->> 'oui')::integer >= 1,
         'le décompte des oui ne bouge pas';
  assert carte ->> 'ma_reponse' = 'yes',
         'la carte ne rappelle pas sa propre réponse';

  -- 6. Supprimé n'est pas introuvable ---------------------------------------
  -- Une carte morte ne dirait rien ; celle-ci dit ce qui est arrivé.
  assert public.supprimer_evenement(evenement),
         'la suppression de l''événement a échoué';
  select c.carte into carte
    from public.messages_du_groupe(groupe) c where c.event_id = evenement;
  assert (carte ->> 'supprimee')::boolean,
         'la carte d''un événement supprimé ne le dit pas';
  assert carte ->> 'titre' is not null,
         'la carte supprimée a perdu son titre';

  -- 7. Une carte ne pousse pas comme un message -----------------------------
  -- L'élément qu'elle porte a déjà sa propre notification ; sans ce garde-fou
  -- l'assigné en recevrait deux.
  reset role;
  assert not exists (
    select 1 from public.push_outbox o
     where o.type = 'chat_message'
       and o.body like '%acheter du pain%'),
         'une carte a été poussée comme un message de conversation';

  raise notice 'Fumée : les cartes de la tranche 9 répondent.';
end;
$cartes$;

-- ---------------------------------------------------------------------------
-- Le carnet (tranche 10).
--
-- Le nombre de groupes en commun est la seule donnée de l'écran Contacts qui
-- ne se lisait pas déjà. Ce qui est éprouvé ici, c'est qu'il **compte ce qu'il
-- faut** : un groupe vivant, et deux adhésions actives.
-- ---------------------------------------------------------------------------

do $carnet$
declare
  camille uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea     uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  groupe  uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  second  uuid;
  compte  integer;
begin
  set local role postgres;
  insert into public.contacts (requester_id, addressee_id, status)
  values (camille, lea, 'accepted'::contact_status)
  on conflict do nothing;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  select groupes_communs into compte
    from public.mes_contacts() where autre_id = lea;
  assert compte = 1,
         format('un groupe en commun attendu, reçu %s', compte);

  -- Un second groupe partagé compte pour un de plus.
  second := (public.creer_groupe('Fumée — second groupe')).id;
  reset role;
  insert into public.group_members (group_id, user_id, role)
  values (second, lea, 'member') on conflict do nothing;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  select groupes_communs into compte
    from public.mes_contacts() where autre_id = lea;
  assert compte = 2, format('deux groupes attendus, reçu %s', compte);

  -- **Contrôle négatif de l'adhésion échue.** La tranche 6 veut qu'une
  -- adhésion passée cesse de compter partout ; le carnet ne fait pas
  -- exception.
  reset role;
  update public.group_members
     set expires_at = now() - interval '1 minute'
   where group_id = second and user_id = lea;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  select groupes_communs into compte
    from public.mes_contacts() where autre_id = lea;
  assert compte = 1,
         format('une adhésion échue compte encore, reçu %s', compte);

  -- **Contrôle négatif du groupe supprimé.**
  reset role;
  update public.group_members
     set expires_at = null
   where group_id = second and user_id = lea;
  update public.groups set deleted_at = now() where id = second;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  select groupes_communs into compte
    from public.mes_contacts() where autre_id = lea;
  assert compte = 1,
         format('un groupe supprimé compte encore, reçu %s', compte);

  reset role;
  raise notice 'Fumée : le carnet de la tranche 10 répond.';
end;
$carnet$;

-- ---------------------------------------------------------------------------
-- L'aperçu des groupes (tranche 11).
--
-- Ce qui est éprouvé ici : la fonction rend **une ligne par groupe actif**,
-- avec l'effectif juste et au plus quatre profils. Les deux contrôles négatifs
-- portent sur les filtres qui pourraient silencieusement laisser passer un
-- groupe qu'on ne voit plus.
-- ---------------------------------------------------------------------------

do $apercu$
declare
  camille uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea     uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  groupe  uuid := '22222222-2222-2222-2222-222222222222'::uuid;
  attendu integer;
  lignes  integer;
  compte  integer;
  apercu  jsonb;
begin
  set local role postgres;
  -- Le décor a pu changer : les blocs précédents ajoutent des membres. On
  -- remet le groupe et ses adhésions dans un état connu, et on **relit
  -- l'effectif dans la table** plutôt que de le supposer — c'est justement
  -- l'accord entre les deux qu'on éprouve.
  update public.groups set deleted_at = null where id = groupe;
  update public.group_members set expires_at = null where group_id = groupe;

  select count(*) into attendu
    from public.group_members where group_id = groupe;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  select nombre_membres, membres into compte, apercu
    from public.mes_groupes_apercu() where group_id = groupe;

  assert compte = attendu,
         format('effectif %s attendu, reçu %s', attendu, compte);
  -- Quatre profils au plus : au-delà, la rangée bascule sur « +N » et le
  -- reste ne serait transporté pour personne.
  assert jsonb_array_length(apercu) = least(attendu, 4),
         format('%s profils attendus, reçu %s',
                least(attendu, 4), jsonb_array_length(apercu));
  -- Le profil est bien joint : sans lui, la rangée n'aurait aucun nom à
  -- afficher, et c'est tout l'objet de la fonction.
  assert apercu -> 0 ->> 'user_id' is not null,
         'un aperçu sans identifiant de membre';

  -- **Contrôle négatif : une adhésion échue ne compte plus.**
  reset role;
  update public.group_members
     set expires_at = now() - interval '1 day'
   where group_id = groupe and user_id = lea;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  select nombre_membres into compte
    from public.mes_groupes_apercu() where group_id = groupe;
  assert compte = attendu - 1,
         format('une adhésion échue compte encore, reçu %s', compte);

  -- **Contrôle négatif : un groupe supprimé disparaît de l'aperçu.**
  reset role;
  update public.groups set deleted_at = now() where id = groupe;

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  select count(*) into lignes
    from public.mes_groupes_apercu() where group_id = groupe;
  assert lignes = 0,
         format('un groupe supprimé reste dans l''aperçu, reçu %s', lignes);

  -- **Contrôle négatif : ce n'est pas l'aperçu de tout le monde.** Léa vient
  -- de voir son adhésion expirer : elle ne doit plus rien voir de ce groupe.
  reset role;
  update public.groups set deleted_at = null where id = groupe;

  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  set local role authenticated;
  select count(*) into lignes
    from public.mes_groupes_apercu() where group_id = groupe;
  assert lignes = 0,
         format('une adhésion échue donne encore l''aperçu, reçu %s', lignes);

  reset role;
  raise notice 'Fumée : l''aperçu des groupes de la tranche 11 répond.';
end;
$apercu$;

-- ---------------------------------------------------------------------------
-- Les anniversaires (tranche 12).
--
-- Ce qui est éprouvé ici, et que `create function` ne dit pas :
--   - la règle du jour fêté sur une **table de cas**, le 29 février compris,
--     des deux côtés d'une année bissextile ;
--   - la contrainte, par deux contrôles négatifs — une date impossible et une
--     moitié de date ;
--   - la lecture réservée aux **contacts**, et muette sans date ;
--   - le dépôt du jour, et surtout qu'un **second passage ne redépose rien** :
--     le battement tourne chaque minute, et c'est la clé primaire de
--     `push_reminders_sent` qui tient seule cette garantie.
-- ---------------------------------------------------------------------------

do $anniv$
declare
  camille    uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea        uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  -- **Un identifiant à lui**, et non celui du passager de la tranche 6.
  -- Les deux blocs partageaient `4444…` : l'insertion ci-dessous retombait
  -- sur son `on conflict do update`, ne posait que la date, et laissait le
  -- profil de Noé Berger. Les contrôles négatifs tenaient — Noé n'est pas
  -- plus un contact que ne l'aurait été Hugo — mais pour une raison que le
  -- fichier ne disait pas, et un décor qui se trompe de personne finit par
  -- faire passer un test pour la mauvaise raison.
  inconnu    uuid := '12121212-1212-1212-1212-121212121212'::uuid;
  aujourdhui date := (now() at time zone 'Europe/Paris')::date;
  jour       smallint := extract(day from aujourdhui)::smallint;
  mois       smallint := extract(month from aujourdhui)::smallint;
  lignes     integer;
  compte     integer;
  refuse     boolean;
begin
  set local role postgres;

  -- 1. La règle du jour fêté --------------------------------------------------
  -- Une seule règle : le jour est ramené au dernier jour du mois. Le 29
  -- février n'est donc pas un cas particulier, il en est la **conséquence**.
  assert public.jour_anniversaire(29::smallint, 2::smallint, 2024)
         = date '2024-02-29',
         'le 29 février d''une année bissextile doit tomber le 29';
  assert public.jour_anniversaire(29::smallint, 2::smallint, 2025)
         = date '2025-02-28',
         'le 29 février d''une année ordinaire doit tomber le 28, dernier '
         'jour de février — et non le 1er mars, qui change de mois';
  assert public.jour_anniversaire(31::smallint, 1::smallint, 2025)
         = date '2025-01-31',
         'un 31 dans un mois de 31 jours ne doit pas être ramené';
  assert public.jour_anniversaire(30::smallint, 4::smallint, 2025)
         = date '2025-04-30',
         'un 30 dans un mois de 30 jours ne doit pas être ramené';
  -- Sans date, pas de date approchée.
  assert public.jour_anniversaire(null, null, 2025) is null,
         'une personne sans date ne doit pas produire de jour fêté';

  -- 2. Contrôle négatif : une date impossible est refusée ---------------------
  refuse := false;
  begin
    update public.profiles
       set anniversaire_jour = 30, anniversaire_mois = 2
     where id = camille;
  exception
    when check_violation then refuse := true;
  end;
  assert refuse, 'le 30 février a été accepté : la contrainte ne tient pas';

  -- 3. Contrôle négatif : une moitié de date est refusée ----------------------
  -- Un jour sans mois ne veut rien dire, et laisserait un affichage à deviner.
  refuse := false;
  begin
    update public.profiles
       set anniversaire_jour = 12, anniversaire_mois = null
     where id = camille;
  exception
    when check_violation then refuse := true;
  end;
  assert refuse, 'une moitié de date a été acceptée';

  -- 4. Le décor : Camille fête aujourd'hui, Léa est sa contact ---------------
  update public.profiles
     set anniversaire_jour = jour, anniversaire_mois = mois
   where id = camille;
  -- Léa n'a **pas** de date : c'est le contrôle négatif du cas « personne
  -- sans anniversaire », qui doit rendre zéro ligne et non une ligne vide.
  update public.profiles
     set anniversaire_jour = null, anniversaire_mois = null
   where id = lea;

  -- Quelqu'un qui fête aussi aujourd'hui, mais qui n'est le contact de
  -- personne : le contrôle négatif de la visibilité.
  insert into public.profiles (id, pseudo, first_name, last_name,
                               anniversaire_jour, anniversaire_mois)
  values (inconnu, 'inconnu', 'Hugo', 'Lemoine', jour, mois)
  on conflict (id) do update
    set anniversaire_jour = excluded.anniversaire_jour,
        anniversaire_mois = excluded.anniversaire_mois;

  delete from public.contacts
   where (requester_id = camille and addressee_id = lea)
      or (requester_id = lea and addressee_id = camille);
  insert into public.contacts (requester_id, addressee_id, status)
  values (camille, lea, 'accepted');

  -- 5. La lecture est réservée aux contacts ----------------------------------
  perform set_config('request.jwt.claims',
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}',
    true);
  set local role authenticated;

  select count(*) into lignes
    from public.anniversaires_de_mes_contacts() where contact_id = camille;
  assert lignes = 1,
         format('Léa devrait voir l''anniversaire de sa contact, reçu %s',
                lignes);

  -- **Contrôle négatif : un non-contact n'y figure pas**, quand bien même il
  -- fêterait le même jour. C'est plus étroit que `has_social_link`, qui ouvre
  -- la lecture du profil, et c'est la consigne.
  select count(*) into lignes
    from public.anniversaires_de_mes_contacts() where contact_id = inconnu;
  assert lignes = 0,
         format('un non-contact ressort de la lecture, reçu %s', lignes);

  -- **Contrôle négatif : sans date, aucune ligne.** Camille lit son carnet :
  -- Léa n'a rien renseigné, il ne doit y avoir aucune ligne pour elle.
  reset role;
  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;
  select count(*) into lignes
    from public.anniversaires_de_mes_contacts() where contact_id = lea;
  assert lignes = 0,
         format('une personne sans date rend une ligne, reçu %s', lignes);

  -- 6. Le dépôt du jour ------------------------------------------------------
  -- Sous `postgres` : `push_outbox` ne montre que ses propres lignes, et
  -- compter sous le mauvais jeton donnerait zéro alors qu'elles existent —
  -- le piège déjà rencontré en tranche 5c.
  reset role;
  set local role postgres;

  delete from public.push_reminders_sent where kind = 'birthday';
  delete from public.notifications where type = 'birthday';
  delete from public.push_outbox where type = 'birthday';

  perform public.empiler_anniversaires();

  select count(*) into compte
    from public.notifications
   where user_id = lea and type = 'birthday';
  assert compte = 1,
         format('un anniversaire attendu dans la boîte de Léa, reçu %s',
                compte);
  assert exists (
           select 1 from public.notifications
            where user_id = lea and type = 'birthday'
              and payload ->> 'name' is not null
         ),
         'la notification ne porte pas le nom de la personne qui fête';

  select count(*) into compte
    from public.push_outbox where user_id = lea and type = 'birthday';
  assert compte = 1,
         format('un envoi attendu pour Léa, reçu %s', compte);

  -- **Contrôle négatif : personne ne reçoit l'anniversaire d'un
  -- non-contact.** Hugo fête aujourd'hui et n'a aucun contact.
  select count(*) into compte
    from public.notifications
   where type = 'birthday' and payload ->> 'person_id' = inconnu::text;
  assert compte = 0,
         format('l''anniversaire d''un non-contact a été envoyé, reçu %s',
                compte);

  -- **Le contrôle qui compte : un second passage ne redépose rien.** Le
  -- battement tourne chaque minute ; sans la clé primaire de
  -- `push_reminders_sent`, Léa recevrait 1 440 notifications dans la journée.
  perform public.empiler_anniversaires();
  select count(*) into compte
    from public.notifications where user_id = lea and type = 'birthday';
  assert compte = 1,
         format('un second passage a redéposé l''anniversaire, reçu %s',
                compte);

  -- 7. Le type est réglable --------------------------------------------------
  -- Sans cette ligne, l'envoi existerait sans pouvoir être coupé — et un
  -- envoi qu'on ne peut pas couper est un défaut.
  assert exists (
           select 1 from public.types_de_notification() where type = 'birthday'
         ),
         'le type birthday n''est pas réglable depuis les paramètres';

  reset role;
  raise notice 'Fumée : les anniversaires de la tranche 12 répondent.';
end;
$anniv$;

-- Tranche 13 — le profil consultable de quelqu'un d'autre.
--
-- Ce qui compte ici : que les champs réservés aux contacts soient `null` pour
-- un étranger, et qu'ils le soient **dans la fonction**, pas dans l'écran.
--
-- **Le décor est posé explicitement**, et non hérité de ce que les blocs
-- précédents laissent. La première version s'appuyait sur l'adhésion de Léa
-- que la tranche 12 trouve en place — elle ne l'est plus à ce stade, les
-- blocs 6 à 10 éprouvant précisément les départs, les adhésions échues et la
-- suppression douce d'un groupe. Un décor hérité fait échouer le bloc qui
-- hérite, et c'est le meilleur des cas : il aurait pu le faire **passer**
-- pour la mauvaise raison.
do $profil$
declare
  camille uuid := '11111111-1111-1111-1111-111111111111'::uuid;
  lea     uuid := '33333333-3333-3333-3333-333333333333'::uuid;
  hugo    uuid := '14141414-1414-1414-1414-141414141414'::uuid;
  fantome uuid := '15151515-1515-1515-1515-151515151515'::uuid;
  groupe  uuid := '13131313-1313-1313-1313-131313131313'::uuid;
  ligne   record;
  lignes  integer;
begin
  set local role postgres;

  -- Un étranger : ni contact, ni co-membre. Il porte une date, pour que
  -- l'assertion « l'anniversaire est public » éprouve quelque chose.
  insert into auth.users (id, email) values (hugo, 'hugo@exemple.test')
  on conflict (id) do nothing;
  insert into public.profiles (id, pseudo, first_name, last_name,
                               anniversaire_jour, anniversaire_mois)
  values (hugo, 'hugo', 'Hugo', 'Lemoine', 4::smallint, 7::smallint)
  on conflict (id) do update
    set first_name = excluded.first_name,
        anniversaire_jour = excluded.anniversaire_jour,
        anniversaire_mois = excluded.anniversaire_mois;

  insert into public.groups (id, name, created_by)
  values (groupe, 'Voyage en Corse', camille)
  on conflict (id) do update set deleted_at = null;

  insert into public.group_members (group_id, user_id, role)
  values (groupe, camille, 'admin'), (groupe, lea, 'member')
  on conflict (group_id, user_id) do update set expires_at = null;

  -- Camille et Léa sont contacts acceptées depuis le bloc précédent ; on le
  -- repose pour que ce bloc ne dépende de rien.
  delete from public.contacts
   where camille in (requester_id, addressee_id)
     and (lea in (requester_id, addressee_id)
       or hugo in (requester_id, addressee_id));
  insert into public.contacts (requester_id, addressee_id, status)
  values (camille, lea, 'accepted');

  perform set_config('request.jwt.claims',
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',
    true);
  set local role authenticated;

  -- 1. Une contact : tout est ouvert ------------------------------------------
  select * into ligne from public.profil_consultable(lea);
  assert ligne.id = lea, 'la ligne ne porte pas l''identifiant demandé';
  assert ligne.pseudo = 'lea', 'le pseudo manque';
  assert ligne.first_name = 'Léa', 'le prénom manque';
  assert not ligne.cest_moi, 'le profil d''autrui se croit le sien';
  assert ligne.statut = 'accepted',
         format('relation attendue acceptée, reçue %s', ligne.statut);
  assert ligne.sens = 'sortant',
         'Camille a envoyé la demande : le sens doit être sortant';
  assert ligne.groupes_communs = 1,
         format('un groupe commun attendu, reçu %s', ligne.groupes_communs);
  assert ligne.groupes_partages -> 0 ->> 'nom' = 'Voyage en Corse',
         'le détail des groupes communs ne porte pas le nom du groupe';
  assert ligne.disponibilite is not null,
         'une contact doit voir la disponibilité';

  -- 2. **Les deux contrôles négatifs qui portent la consigne** ----------------
  -- Hugo n'est pas un contact. Ses cinq champs publics sortent — c'est la
  -- consigne —, mais rien de plus. Un appel direct à PostgREST avec son
  -- identifiant obtient donc les mêmes `null` : la réserve est dans la
  -- fonction, et un écran ne peut rien réserver.
  select * into ligne from public.profil_consultable(hugo);
  assert ligne.first_name = 'Hugo',
         'les champs publics d''un étranger doivent sortir';
  assert ligne.anniversaire_mois is not null,
         'l''anniversaire est public : il doit sortir pour un étranger';
  assert ligne.statut is null,
         format('aucune relation attendue, reçue %s', ligne.statut);
  assert ligne.groupes_communs = 0,
         format('aucun groupe commun attendu, reçu %s', ligne.groupes_communs);
  assert ligne.disponibilite is null,
         'la disponibilité d''un non-contact ne doit pas sortir';

  -- 3. Contrôle négatif : être *sollicité* n'est pas être contact -------------
  -- La nuance est la plus facile à manquer : `contacts` porte une ligne dès
  -- la demande, et un `exists` sans `status = 'accepted'` ouvrirait les
  -- disponibilité à qui se contente de demander.
  set local role postgres;
  insert into public.contacts (requester_id, addressee_id, status)
  values (camille, hugo, 'pending');
  set local role authenticated;

  select * into ligne from public.profil_consultable(hugo);
  assert ligne.statut = 'pending',
         format('relation attendue en attente, reçue %s', ligne.statut);
  assert ligne.disponibilite is null,
         'une demande en attente a ouvert la disponibilité';

  -- 4. Contrôle négatif : une adhésion échue ne compte plus -------------------
  -- Même règle qu'au carnet (tranche 10) et que partout depuis la tranche 6.
  set local role postgres;
  update public.group_members set expires_at = now() - interval '1 day'
   where user_id = lea and group_id = groupe;
  set local role authenticated;

  select * into ligne from public.profil_consultable(lea);
  assert ligne.groupes_communs = 0,
         format('une adhésion échue compte encore, reçu %s',
                ligne.groupes_communs);
  assert ligne.groupes_partages = '[]'::jsonb,
         'une adhésion échue figure encore dans le détail';

  set local role postgres;
  update public.group_members set expires_at = null
   where user_id = lea and group_id = groupe;
  set local role authenticated;

  -- 5. Son propre profil ------------------------------------------------------
  select * into ligne from public.profil_consultable(camille);
  assert ligne.cest_moi, 'son propre profil doit se reconnaître';
  assert ligne.disponibilite is not null,
         'sa propre disponibilité doit sortir';

  -- 6. Un identifiant inconnu rend zéro ligne ---------------------------------
  -- Contrairement à `invitation_par_id`, qui rend toujours une ligne avec un
  -- mot d'état : une invitation a quatre états dégradés à distinguer, un
  -- profil n'en a qu'un — il n'existe pas.
  select count(*) into lignes from public.profil_consultable(fantome);
  assert lignes = 0,
         format('un identifiant inconnu doit rendre zéro ligne, reçu %s',
                lignes);

  -- 7. **Contrôle négatif : aucune adresse e-mail ne peut sortir** ------------
  -- Elle vit dans `auth.users`, que cette fonction ne lit pas. Ce contrôle
  -- porte sur la *signature* : il échouerait le jour où quelqu'un ajouterait
  -- une colonne de sortie qui en porte une, ce qu'aucun appel ne révélerait.
  reset role;
  assert pg_get_function_result(
           'public.profil_consultable(uuid)'::regprocedure) not ilike '%mail%',
         'la signature expose une colonne d''adresse e-mail';

  -- 8. **Contrôle négatif du retrait des compteurs** ------------------------
  -- Ils ont quitté la signature, et pas seulement l'écran : trois
  -- sous-requêtes par ouverture de profil, dont une sur `events` et une sur
  -- `tasks` jointe à `task_assignees`, pour un chiffre que personne ne lisait.
  -- Le contrôle porte sur la signature parce qu'un `create or replace` ne
  -- sait pas retirer une colonne de sortie : sans le `drop` du fichier, la
  -- migration échouerait — ou, pire, laisserait l'ancienne en place.
  assert pg_get_function_result(
           'public.profil_consultable(uuid)'::regprocedure)
         not ilike '%statistiques%',
         'la signature porte encore les compteurs retirés';

  raise notice 'Fumée : le profil consultable de la tranche 13 répond.';
end;
$profil$;


-- ===========================================================================
-- Tranche 15 — signaler un abus
-- ===========================================================================
-- Ce qui est éprouvé, et les contrôles négatifs d'abord, parce que ce sont
-- eux qui portent la consigne :
--
-- 1. **Un non-modérateur ne lit rien** — zéro ligne, et non une erreur : un
--    appel direct n'apprend donc pas qu'il y avait quelque chose à voir ;
-- 2. **on ne signale pas un message qu'on ne peut pas voir.** Sans ce refus,
--    la recopie du contexte serait un oracle de lecture sur toutes les
--    conversations du service — c'est le défaut qu'il faut ne pas créer en
--    voulant garder la preuve ;
-- 3. la recopie **survit à la suppression du message**, qui est toute sa
--    raison d'être ;
-- 4. « traité » fait sortir de la file, et rien d'autre ne l'en sort.

do $signalements$
declare
  camille  constant uuid := '11111111-1111-1111-1111-111111111111';
  lea      constant uuid := '33333333-3333-3333-3333-333333333333';
  groupe   constant uuid := '22222222-2222-2222-2222-222222222222';
  etranger constant uuid := '55555555-5555-5555-5555-555555555555';
  ailleurs constant uuid := '66666666-6666-6666-6666-666666666666';
  msg_lea  uuid := gen_random_uuid();
  msg_loin uuid := gen_random_uuid();
  etat     text;
  lignes   bigint;
  dossier  uuid;
  contenu  text;
  efface   boolean;
  nom      text;
begin
  -- Décor : un message de Léa dans le groupe, et un groupe où Camille n'est
  -- pas. Posé sous `postgres`, l'insertion directe dans `messages` étant
  -- fermée au client depuis la tranche 7.
  reset role;

  insert into auth.users (id, email) values (etranger, 'loin@exemple.test')
  on conflict (id) do nothing;
  insert into public.profiles (id, pseudo, first_name, last_name)
  values (etranger, 'loin', 'Inès', 'Khelifi')
  on conflict (id) do nothing;

  insert into public.groups (id, name, created_by)
  values (ailleurs, 'Groupe sans Camille', etranger)
  on conflict (id) do nothing;
  insert into public.group_members (group_id, user_id, role)
  values (ailleurs, etranger, 'admin')
  on conflict do nothing;

  insert into public.messages (id, group_id, sender_id, content)
  values (msg_lea, groupe, lea, 'Texte que Camille signale'),
         (msg_loin, ailleurs, etranger, 'Conversation où Camille n''est pas');

  -- 1. Signaler un message de son groupe -----------------------------------
  set local role authenticated;
  set local request.jwt.claims =
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  select public.signaler('message', msg_lea, 'harcelement', 'Insistant')
    into etat;
  assert etat = 'signale',
         format('signaler un message devait répondre « signale », reçu « %s »',
                etat);

  -- 2. Deux fois le même, non traité : le second n'apprend rien ------------
  select public.signaler('message', msg_lea, 'haine') into etat;
  assert etat = 'deja_signale',
         format('un second signalement devait répondre « deja_signale », '
                'reçu « %s »', etat);

  -- 3. CONTRÔLE NÉGATIF — l'oracle de lecture qu'il ne faut pas créer ------
  --    Camille n'est pas membre d'`ailleurs` : si ce refus tombait, elle
  --    obtiendrait le texte de n'importe quel message du service en le
  --    signalant.
  select public.signaler('message', msg_loin, 'spam') into etat;
  assert etat = 'non_membre',
         format('signaler un message d''un groupe dont on n''est pas membre '
                'devait répondre « non_membre », reçu « %s »', etat);

  -- 4. Un motif que l'énumération ne connaît pas se dit, il ne lève pas ----
  select public.signaler('message', msg_lea, 'pas-un-motif') into etat;
  assert etat = 'motif_inconnu',
         format('un motif inconnu devait répondre « motif_inconnu », '
                'reçu « %s »', etat);

  -- 5. Se signaler soi-même n'encombre pas la file -------------------------
  select public.signaler('profile', camille, 'autre') into etat;
  assert etat = 'soi_meme',
         format('se signaler devait répondre « soi_meme », reçu « %s »', etat);

  -- 6. CONTRÔLE NÉGATIF — un non-modérateur ne lit rien, et ne le sait pas -
  assert not public.est_moderateur(),
         'personne ne doit être modérateur sans avoir été désigné';

  select count(*) into lignes from public.signalements_a_traiter();
  assert lignes = 0,
         format('un non-modérateur devait lire zéro ligne, reçu %s', lignes);

  -- Et il ne peut pas traiter, même en connaissant l'identifiant.
  reset role;
  select s.id into dossier from public.signalements s
   where s.message_id = msg_lea limit 1;
  set local role authenticated;
  set local request.jwt.claims =
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  select public.traiter_signalement(dossier) into etat;
  assert etat = 'non_moderateur',
         format('traiter sans l''être devait répondre « non_moderateur », '
                'reçu « %s »', etat);
  select public.supprimer_message_signale(dossier) into etat;
  assert etat = 'non_moderateur',
         format('supprimer sans l''être devait répondre « non_moderateur », '
                'reçu « %s »', etat);

  -- 6bis. CONTRÔLE NÉGATIF — les deux tables sont hors de portée de l'API --
  --    C'est la demande elle-même : « sans que ce soit contournable ». Une
  --    politique RLS correcte laisserait la table **atteignable**, et une
  --    politique de trop posée à côté la rouvrirait en « ou » — c'est
  --    exactement ce qui est arrivé au stockage. Ici il n'y a pas de
  --    politique à contourner : il n'y a pas de privilège.
  begin
    perform 1 from public.signalements limit 1;
    assert false, 'un compte ne doit pas pouvoir lire la table des '
                  'signalements : seules les fonctions sont la porte';
  exception
    when insufficient_privilege then null;
  end;

  begin
    insert into public.moderateurs (user_id) values (camille);
    assert false, 'un compte ne doit pas pouvoir se désigner modérateur';
  exception
    when insufficient_privilege then null;
  end;

  -- 7. Désignée, elle lit — avec le profil joint ---------------------------
  --    `moderateurs` n'a ni politique ni privilège : seul `postgres` écrit,
  --    donc seul l'éditeur SQL du projet. C'est le contrôle que la
  --    désignation ne se fait pas depuis l'application.
  reset role;
  insert into public.moderateurs (user_id) values (camille)
  on conflict (user_id) do nothing;

  set local role authenticated;
  set local request.jwt.claims =
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  assert public.est_moderateur(), 'la désignation doit se voir';

  select count(*) into lignes from public.signalements_a_traiter();
  assert lignes = 1,
         format('la file devait porter un signalement, reçu %s', lignes);

  select s.contexte ->> 'contenu', s.message_efface, s.vise_nom
    into contenu, efface, nom
    from public.signalements_a_traiter() s limit 1;

  assert contenu = 'Texte que Camille signale',
         format('la recopie devait porter le texte signalé, reçu « %s »',
                coalesce(contenu, '(nul)'));
  assert efface is false,
         'le message n''est pas encore effacé, la file ne doit pas le dire';
  assert nom = 'Léa Marchand',
         format('le nom de la personne visée devait être joint, reçu « %s »',
                coalesce(nom, '(nul)'));

  -- 8. Agir : la suppression douce, puis son idempotence -------------------
  select public.supprimer_message_signale(dossier) into etat;
  assert etat = 'supprime',
         format('la suppression devait répondre « supprime », reçu « %s »',
                etat);
  select public.supprimer_message_signale(dossier) into etat;
  assert etat = 'deja_supprime',
         format('un second appel devait répondre « deja_supprime », '
                'reçu « %s »', etat);

  -- 9. **Toute la raison d'être de la recopie** ----------------------------
  --    Le message est effacé ; le dossier garde ce qui avait été écrit, et
  --    dit que la cible n'existe plus. Sans la recopie, il ne resterait rien
  --    à juger — et c'est son auteur qui aurait effacé la preuve.
  select s.contexte ->> 'contenu', s.message_efface
    into contenu, efface
    from public.signalements_a_traiter() s limit 1;

  assert contenu = 'Texte que Camille signale',
         'la recopie doit survivre à la suppression du message';
  assert efface,
         'la file doit signaler que le message visé a été effacé depuis';

  -- 10. « Traité » fait sortir de la file, et c'est tout ce qui l'en sort --
  select public.traiter_signalement(dossier, 'Message retiré, personne avertie')
    into etat;
  assert etat = 'traite',
         format('le traitement devait répondre « traite », reçu « %s »', etat);

  select count(*) into lignes from public.signalements_a_traiter();
  assert lignes = 0,
         format('un signalement traité ne doit plus revenir, reçu %s', lignes);

  select count(*) into lignes from public.signalements_a_traiter(true);
  assert lignes = 1,
         format('l''onglet des traités devait en porter un, reçu %s', lignes);

  -- Rouvrable : un traitement posé par erreur doit avoir un recours.
  select public.traiter_signalement(dossier, null, false) into etat;
  assert etat = 'rouvert',
         format('la réouverture devait répondre « rouvert », reçu « %s »',
                etat);
  select count(*) into lignes from public.signalements_a_traiter();
  assert lignes = 1,
         format('un signalement rouvert doit revenir, reçu %s', lignes);

  -- La note posée au traitement n'est pas perdue par la réouverture : elle
  -- dit ce qui a été fait, et le geste ne se défait pas.
  select s.note into contenu from public.signalements_a_traiter() s limit 1;
  assert contenu = 'Message retiré, personne avertie',
         format('la note devait survivre à la réouverture, reçu « %s »',
                coalesce(contenu, '(nul)'));

  -- 11. Un profil se signale aussi, et le dossier en garde le pseudo -------
  select public.signaler('profile', lea, 'spam') into etat;
  assert etat = 'signale',
         format('signaler un profil devait répondre « signale », reçu « %s »',
                etat);

  select count(*) into lignes from public.signalements_a_traiter();
  assert lignes = 2,
         format('la file devait porter deux signalements, reçu %s', lignes);

  -- Camille cesse d'être modératrice : le bloc suivant la supprime, et un
  -- décor qui la laisserait modératrice ferait passer la suppression pour
  -- la cause de ce que la désignation explique.
  reset role;
  delete from public.moderateurs where user_id = camille;

  raise notice 'Fumée : les signalements de la tranche 15 répondent.';
end;
$signalements$;


-- ===========================================================================
-- Tranche 14 — suppression de compte
-- ===========================================================================
-- Deux choses sont éprouvées, et la première est la plus utile.
--
-- 1. **Le catalogue est confronté au code.** Toute clé étrangère pointant
--    vers `profiles(id)` doit figurer dans la liste des sorts décidés
--    ci-dessous. Une table ajoutée demain et oubliée dans
--    `tranche14_suppression_compte.sql` fait donc échouer le rejeu, au lieu
--    de laisser une donnée identifiante derrière elle sans que rien ne le
--    dise. C'est la méthode de la requête A0 : partir de la base et lui
--    confronter le code, jamais l'inverse — une liste de tables auxquelles on
--    a pensé ne voit pas celle à laquelle personne n'a pensé.
--
-- 2. Le comportement : ce qui doit partir est parti, ce qui doit rester est
--    resté, et l'adresse e-mail a bien quitté ses **deux** emplacements.

do $suppression$
declare
  camille  constant uuid := '11111111-1111-1111-1111-111111111111';
  lea      constant uuid := '33333333-3333-3333-3333-333333333333';
  groupe   constant uuid := '22222222-2222-2222-2222-222222222222';
  -- Les vingt-deux sites relevés dans le catalogue, et leur sort. Toute entrée
  -- de `pg_constraint` absente d'ici fait échouer le contrôle 1.
  decides  constant text[] := array[
    -- supprimés
    'availabilities.user_id',
    'contacts.requester_id', 'contacts.addressee_id',
    'event_participants.user_id',
    'group_members.user_id',
    'invitations.invitee_id', 'invitations.inviter_id',
    'message_reactions.user_id',
    'message_reads.user_id',
    'notification_preferences.user_id',
    'notifications.user_id',
    'push_outbox.user_id',
    'push_reminders_sent.user_id',
    'push_tokens.user_id',
    'task_assignees.user_id',
    'moderateurs.user_id',
    -- gardés : c'est l'échange des autres
    'messages.sender_id',
    'tasks.created_by',
    'groups.created_by',
    'task_list_items.checked_by',
    -- gardé pour un groupe, supprimé pour un rendez-vous personnel
    'events.owner_id',
    -- gardé : le dossier de modération garderait son sujet
    'signalements.profil_id',
    -- anonymisés : le dossier reste, le lien part
    'signalements.auteur_id', 'signalements.traite_par'
  ];
  oublie   text;
  etat     text;
  ligne    record;
  lignes   bigint;
  profil   public.profiles%rowtype;
  tache_a_elle uuid := gen_random_uuid();
  message_vocal uuid := gen_random_uuid();
  message_texte uuid := gen_random_uuid();
  drapeau  boolean;
  v_pseudo text;
  v_prenom text;
  v_avatar text;
begin
  -- 1. Catalogue contre code -------------------------------------------------
  reset role;
  select string_agg(format('%s.%s', c.relname, a.attname), ', ')
    into oublie
    from pg_constraint k
    join pg_class c on c.oid = k.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join unnest(k.conkey) with ordinality as cols(attnum, ord) on true
    join pg_attribute a on a.attrelid = k.conrelid and a.attnum = cols.attnum
   where k.contype = 'f'
     and n.nspname = 'public'
     and k.confrelid = 'public.profiles'::regclass
     and format('%s.%s', c.relname, a.attname) <> all (decides);

  assert oublie is null,
         format('ces colonnes référencent profiles et la suppression de '
                'compte ne dit pas ce qu''elles deviennent : %s', oublie);

  -- 2. Un décor qui touche ce qui doit partir et ce qui doit rester ----------
  -- Reposé explicitement : treize blocs ont précédé, et la promotion du plus
  -- ancien ne se vérifie que si l'on sait qui est là. Camille administratrice,
  -- Léa simple membre, personne d'autre.
  delete from public.group_members
   where group_id = groupe and user_id not in (camille, lea);

  insert into public.group_members (group_id, user_id, role, joined_at)
  values (groupe, camille, 'admin', now() - interval '2 day'),
         (groupe, lea,     'member', now() - interval '1 day')
  on conflict (group_id, user_id) do update
    set role = excluded.role,
        joined_at = excluded.joined_at,
        expires_at = null;

  update public.groups set deleted_at = null where id = groupe;

  insert into public.tasks (id, group_id, created_by, title)
  values (tache_a_elle, groupe, camille, 'Réserver le restaurant');

  insert into public.task_assignees (task_id, user_id, status)
  values (tache_a_elle, camille, 'accepted'::public.assignee_status);

  -- La carte de la conversation se dit prise : elle doit redonner ses boutons.
  insert into public.messages (group_id, sender_id, content, task_id,
                               tache_prise)
  values (groupe, camille, 'Réserver le restaurant', tache_a_elle, true);

  -- Un message vocal : sa voix part, la bulle reste en « message supprimé ».
  insert into public.messages (id, group_id, sender_id, media_url, media_kind,
                               media_duree_s)
  values (message_vocal, groupe, camille,
          groupe::text || '/vocal.m4a', 'audio'::public.media_type, 7);

  -- Un message ordinaire : il doit survivre intact, c'est toute la règle.
  insert into public.messages (id, group_id, sender_id, content)
  values (message_texte, groupe, camille, 'On fait un barbecue ?');

  insert into public.availabilities
    (user_id, kind, status, weekday, start_time, end_time)
  values (camille, 'recurring'::public.availability_kind,
          'available'::public.availability_status, 1, '09:00', '12:00');

  -- `on conflict` : un bloc précédent a déjà lié ces deux-là. Ce qui compte
  -- ici est que la ligne existe avant l'appel, pas qui l'a posée.
  insert into public.contacts (requester_id, addressee_id, status)
  values (camille, lea, 'accepted'::public.contact_status)
  on conflict (requester_id, addressee_id) do nothing;

  insert into public.push_tokens (user_id, token, platform)
  values (camille, 'https://exemple.test/push/camille', 'web');

  -- Une notification **de Léa** qui nomme Camille : elle doit être purgée, et
  -- c'est la valeur du payload qui la désigne, pas le nom de la clé.
  insert into public.notifications (user_id, type, payload)
  values (lea, 'contact_request',
          jsonb_build_object('requester_id', camille::text,
                             'name', 'Camille Rousseau'));

  -- Et une qui ne la nomme pas : elle doit survivre. Sans ce second dépôt, la
  -- purge pourrait vider la boîte de Léa en entier sans que rien ne proteste.
  insert into public.notifications (user_id, type, payload)
  values (lea, 'contact_request',
          jsonb_build_object('requester_id', gen_random_uuid()::text,
                             'name', 'Quelqu''un d''autre'));

  -- 3. L'appel, sous son propre jeton ----------------------------------------
  -- Le jeton est posé **explicitement**. S'en remettre à celui que le bloc
  -- précédent a laissé marcherait par coïncidence, et un jour supprimerait le
  -- compte de quelqu'un d'autre sans que le rejeu y voie rien à redire.
  set local role authenticated;
  set local request.jwt.claims =
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
  select public.supprimer_mon_compte() into etat;
  assert etat = 'supprime',
         format('la suppression devait répondre « supprime », reçu « %s »',
                etat);

  reset role;

  -- 4. Ce qui l'identifie a disparu ------------------------------------------
  select * into profil from public.profiles where id = camille;
  assert profil.supprime_le is not null, 'le compte doit être marqué supprimé';
  assert profil.first_name = '' and profil.last_name = '',
         'le nom doit être vidé';
  assert profil.pseudo = 'supprime.' || substr(replace(camille::text, '-', ''), 1, 11),
         format('pseudo de pierre tombale inattendu : %s', profil.pseudo);
  assert profil.pseudo ~ '^[a-z0-9.]{3,20}$',
         format('le pseudo de pierre tombale viole profiles_pseudo_check : %s',
                profil.pseudo);
  assert profil.bio is null and profil.avatar_url is null
         and profil.avatar_preset is null,
         'bio et avatar doivent être vidés';

  -- L'adresse vit à deux endroits à notre portée. Les deux sont contrôlés :
  -- vider `auth.users` en laissant `auth.identities` n'aurait rien effacé.
  select count(*) into lignes
    from auth.users where id = camille and email is not null;
  assert lignes = 0, 'auth.users garde encore une adresse e-mail';

  select count(*) into lignes from auth.identities where user_id = camille;
  assert lignes = 0, 'auth.identities garde encore une copie de l''adresse';

  select count(*) into lignes
    from auth.refresh_tokens where user_id = camille::text;
  assert lignes = 0, 'les jetons de rafraîchissement n''ont pas été révoqués';

  -- 5. Contrôle négatif : ses messages restent -------------------------------
  select count(*) into lignes
    from public.messages
   where id = message_texte and deleted_at is null
     and content = 'On fait un barbecue ?';
  assert lignes = 1,
         'un message ordinaire ne doit pas disparaître avec le compte';

  -- 6. Son message vocal, lui, est refermé -----------------------------------
  select * into ligne from public.messages where id = message_vocal;
  assert ligne.deleted_at is not null,
         'le message vocal devait devenir un message supprimé';
  assert ligne.media_url is null and ligne.media_duree_s is null,
         'le message vocal garde une référence à son fichier';
  assert ligne.content = '',
         'la suppression douce doit vider le contenu sans le mettre à null : '
         'messages_check exige un contenu ou un média';

  -- 7. La tâche qui n'avait qu'elle retourne au groupe -----------------------
  select count(*) into lignes
    from public.task_assignees where task_id = tache_a_elle;
  assert lignes = 0, 'son assignation devait partir';

  select count(*) into lignes
    from public.messages
   where task_id = tache_a_elle and tache_prise;
  assert lignes = 0,
         'la carte se dit encore prise alors que plus personne ne l''a : '
         'ses boutons ne reviendraient pas';

  select count(*) into lignes
    from public.tasks where id = tache_a_elle and deleted_at is null;
  assert lignes = 1, 'la tâche elle-même ne devait pas être supprimée';

  -- 8. Le reste de ce qui est à elle -----------------------------------------
  select count(*) into lignes from public.availabilities where user_id = camille;
  assert lignes = 0, 'ses disponibilités devaient partir';

  select count(*) into lignes from public.contacts
   where requester_id = camille or addressee_id = camille;
  assert lignes = 0, 'ses contacts devaient partir des deux bouts';

  select count(*) into lignes from public.push_tokens where user_id = camille;
  assert lignes = 0, 'son abonnement push devait partir';

  select count(*) into lignes from public.group_members where user_id = camille;
  assert lignes = 0, 'ses adhésions devaient partir';

  -- 9. La notification **de Léa** qui la nommait -----------------------------
  select count(*) into lignes
    from public.notifications n
   where n.user_id = lea
     and exists (select 1 from jsonb_each_text(n.payload) kv
                  where kv.value = camille::text);
  assert lignes = 0,
         'une notification qui nomme un compte supprimé doit être purgée, '
         'et elle se reconnaît à la valeur de son payload';

  -- Contrôle négatif : la purge ne vide pas la boîte de Léa en entier.
  select count(*) into lignes
    from public.notifications n
   where n.user_id = lea
     and n.payload->>'name' = 'Quelqu''un d''autre';
  assert lignes = 1,
         'la purge a emporté une notification qui ne nommait pas le compte '
         'supprimé';

  -- 10. Le groupe : Léa était simple membre, elle reprend le rôle -----------
  select m.role::text into etat
    from public.group_members m
   where m.group_id = groupe and m.user_id = lea;
  assert etat = 'admin',
         format('plus aucun admin : le plus ancien membre devait être promu, '
                'rôle trouvé « %s »', etat);

  select count(*) into lignes
    from public.groups where id = groupe and deleted_at is null;
  assert lignes = 1,
         'le groupe gardait un membre actif : il ne devait pas être fermé';

  -- 11. Ce que les autres voient d'elle désormais ----------------------------
  -- `nom_affiche` rend `null`, chemin qui existe déjà et que les écrans
  -- savent reformuler sans sujet. Et `profil_consultable` ne rend plus rien.
  assert public.nom_affiche(camille) is null,
         'un compte supprimé ne doit plus avoir de nom à écrire';

  set local role authenticated;
  set local request.jwt.claims =
    '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
  select count(*) into lignes from public.profil_consultable(camille);
  assert lignes = 0,
         'le profil d''un compte supprimé ne doit plus être consultable';

  select count(*) into lignes
    from public.chercher_profils_par_pseudo('supprime');
  assert lignes = 0,
         'un compte supprimé ne doit pas ressortir d''une recherche de pseudo';

  -- 12. La conversation le dit, et par un drapeau ----------------------------
  select count(*) into lignes
    from public.messages_du_groupe(groupe) m where m.id = message_texte;
  assert lignes = 1,
         'la lecture de la conversation ne rend pas le message attendu : '
         'le contrôle du drapeau ne prouverait rien';

  -- Des variables scalaires plutôt qu'un `record` : une variable `record`
  -- garde la structure de son affectation précédente, et l'assertion échoue
  -- alors sur « has no field », ce qui désigne le test et non la fonction.
  select m.supprime, m.pseudo, m.first_name, m.avatar_url
    into drapeau, v_pseudo, v_prenom, v_avatar
    from public.messages_du_groupe(groupe) m where m.id = message_texte;

  assert drapeau, 'la lecture doit signaler un compte supprimé';
  assert v_pseudo is null and v_prenom is null and v_avatar is null,
         'aucune identité ne doit sortir d''un compte supprimé';

  -- 12bis. Le dossier de modération survit, anonymisé --------------------
  --     Deux contrôles, et le premier est un **contrôle négatif** : un
  --     signalement déposé par le compte supprimé ne doit pas partir avec
  --     lui, sinon fermer son compte effacerait le signalement qu'on a
  --     déposé. Le second dit l'autre moitié : le lien, lui, part.
  --
  --     **Sous `postgres`** : `signalements` n'a aucun privilège, et compter
  --     sous le mauvais rôle donnerait « permission denied » là où le défaut
  --     serait dans le test. C'est le même piège que `push_outbox`, dont la
  --     politique SELECT faisait compter zéro alors que les lignes existaient.
  reset role;

  --     Deux lignes, et c'est ce qu'on attend : le bloc de la tranche 15 a
  --     signalé le message de Léa **et** son profil, et un signalement de
  --     message porte aussi l'auteur du message.
  select count(*) into lignes from public.signalements s
   where s.profil_id = lea;
  assert lignes = 2,
         format('les signalements déposés par le compte supprimé devaient '
                'rester, reçu %s ligne(s)', lignes);

  select count(*) into lignes from public.signalements s
   where s.auteur_id = camille or s.traite_par = camille;
  assert lignes = 0,
         format('aucun signalement ne doit encore nommer le compte supprimé, '
                'reçu %s ligne(s)', lignes);

  -- 13. Rejouable : un second appel ne refait pas le travail ----------------
  reset role;
  set local role authenticated;
  set local request.jwt.claims =
    '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
  select public.supprimer_mon_compte() into etat;
  assert etat = 'deja_supprime',
         format('un second appel devait répondre « deja_supprime », reçu « %s »',
                etat);

  raise notice 'Fumée : la suppression de compte de la tranche 14 répond.';
end;
$suppression$;

rollback;
