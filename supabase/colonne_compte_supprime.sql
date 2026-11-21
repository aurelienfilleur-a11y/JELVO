-- Marque d'un compte supprimé — à appliquer **avant** tout le reste.
--
-- `messages_du_groupe` est en `language sql`, dont PostgreSQL valide le corps
-- à la création : elle ne peut pas citer `profiles.supprime_le` avant que la
-- colonne existe. D'où un fichier à part, en tête de `migrations.txt`, pour
-- la même raison que `colonne_avatar_predefini.sql` et
-- `colonne_media_audio.sql`. Un nom de « tranche » aurait suggéré une place
-- chronologique qu'il ne peut pas occuper.
--
-- ===========================================================================
-- Pourquoi un drapeau, et non le nom « Compte supprimé » écrit dans le profil
-- ===========================================================================
--
-- Écrire la phrase dans `first_name` était la voie courte, et elle est
-- fausse : **l'application est en quatre langues**, et un compte supprimé
-- s'afficherait en français sur un téléphone allemand. Un profil ne choisit
-- pas ses mots — c'est la règle du projet, celle des couleurs étendue au
-- vocabulaire : il dit *ce que la chose est*, l'écran en tire le libellé.
--
-- La colonne dit donc *qu'il est supprimé*, et `AppTexts` écrit la phrase.
--
-- ===========================================================================
-- Pourquoi la ligne survit : le schéma l'impose
-- ===========================================================================
--
-- `profiles.id` référence `auth.users(id)` **on delete cascade**, tandis que
-- `messages.sender_id` référence `profiles(id)` **sans cascade**. Supprimer
-- la ligne d'authentification entraîne donc la suppression du profil, que
-- PostgreSQL refuse en `23503` tant qu'un seul message subsiste.
--
-- « Ses messages restent » et « sa ligne est supprimée » sont donc
-- incompatibles par construction. Ce n'est pas un contournement en attendant
-- une fonction Edge : `auth.admin.deleteUser` échouerait sur exactement la
-- même contrainte. La ligne survit, et c'est son **contenu** qui est détruit.
alter table public.profiles
  add column if not exists supprime_le timestamptz;

comment on column public.profiles.supprime_le is
  'Renseignée quand la personne a supprimé son compte. La ligne survit parce '
  'que messages.sender_id la référence sans cascade ; tout ce qui identifie '
  'est vidé. Le libellé affiché vient de l''ARB, pas d''ici.';
