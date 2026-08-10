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

  raise notice 'Fumée : les 20 fonctions des tranches 3 et 3b répondent.';
end;
$fumee$;

rollback;
