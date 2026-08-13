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

  -- Chat (tranche 5a) --------------------------------------------------------
  -- Le bloc « administration » ci-dessus a éprouvé `retirer_membre`, et Léa
  -- n'est donc plus dans le groupe. On l'y remet : sans second membre, ni
  -- l'accusé de lecture ni le compteur de non-lus n'ont de sens à éprouver.
  insert into public.group_members (group_id, user_id, role)
  values ('22222222-2222-2222-2222-222222222222',
          '33333333-3333-3333-3333-333333333333', 'member')
  on conflict do nothing;

  message := public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid, 'Bonjour tout le monde');

  -- Un message ne portant qu'un média est légitime : `messages_check` exige un
  -- contenu **ou** une URL, pas les deux.
  message2 := public.envoyer_message(
    '22222222-2222-2222-2222-222222222222'::uuid,
    p_media_url => 'chat-media/22222222/photo.jpg', p_media_kind => 'image');

  assert (select count(*) from public.messages_du_groupe(
            '22222222-2222-2222-2222-222222222222'::uuid)) = 2,
         'messages_du_groupe';

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

  -- Les six types sont proposés, tous activés par défaut : le modèle est un
  -- opt-out, personne n'a de ligne au départ et tout arrive.
  assert (select count(*) from public.mes_preferences_notification()) = 6,
         'mes_preferences_notification';
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

rollback;
