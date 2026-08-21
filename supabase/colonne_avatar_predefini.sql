-- Tranche 6 — avatars prédéfinis
--
-- Quatre-vingt-treize illustrations sont embarquées dans l'application
-- (`assets/avatars/`). Le profil retient **l'identifiant du fichier choisi**,
-- pas une image : rien n'est téléversé, rien n'est stocké dans un bucket.
--
--
-- POURQUOI AUCUNE SIGNATURE DE FONCTION NE CHANGE
--
-- Onze fonctions de lecture renvoient déjà un champ `avatar_url` :
-- `mes_contacts`, `membres_du_groupe`, `chercher_profils_par_pseudo`,
-- `mes_invitations`, `messages_du_groupe`, les agrégats JSON de `mes_taches`
-- et `mon_agenda`, et les charges utiles des notifications.
--
-- Changer les colonnes de sortie d'un `returns table` impose un `drop
-- function` — `create or replace` le refuse —, donc onze suppressions et
-- recréations en production, pour un gain nul côté appelant.
--
-- À la place, **l'expression change, pas la déclaration** : ces fonctions
-- renvoient désormais
--
--     coalesce('preset:' || p.avatar_preset, p.avatar_url)
--
-- Le champ `avatar_url` de sortie devient donc « l'avatar à afficher »,
-- quelle qu'en soit la nature. Côté Dart, une seule règle : une valeur qui
-- commence par `preset:` désigne un asset, tout le reste est une URL.
--
-- **La colonne `profiles.avatar_url`, elle, ne contient toujours que des
-- URL.** C'est la distinction à garder en tête : la colonne et le champ de
-- sortie portent le même nom sans avoir tout à fait le même sens.
--
--
-- LE DERNIER CHOISI L'EMPORTE
--
-- Un profil a une photo **ou** un avatar prédéfini, jamais les deux. La règle
-- est tenue par l'écriture, qui pose l'un et vide l'autre dans la **même**
-- instruction — voir `ProfileRepository`. Un déclencheur ferait la même chose
-- de façon moins lisible, et il n'y a qu'un seul écrivain.
--
--
-- CE FICHIER EST IDEMPOTENT — il est rejoué dès que son empreinte change.


-- 1. La colonne ------------------------------------------------------------

alter table public.profiles
  add column if not exists avatar_preset text;

comment on column public.profiles.avatar_preset is
  'Identifiant d''un avatar prédéfini embarqué dans l''application '
  '(ex. « p2_07 »), ou null. Exclusif de avatar_url : le dernier choisi '
  'vide l''autre.';

-- Le format est contraint pour que la valeur ne puisse pas servir à autre
-- chose : elle est concaténée dans une chaîne renvoyée à l'application, et
-- un texte libre y ferait entrer n'importe quoi.
do $$
begin
  alter table public.profiles
    add constraint profiles_avatar_preset_check
    check (avatar_preset is null or avatar_preset ~ '^p[0-9]{1,2}_[0-9]{2}$');
exception
  when duplicate_object then null;
end;
$$;
