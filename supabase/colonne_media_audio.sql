-- Messages vocaux — la valeur `audio` et la durée du média.
--
-- Deux écritures du schéma initial, et rien d'autre. Elles sont ici plutôt
-- que dans une « tranche » parce qu'elles doivent précéder `tranche5a_chat`,
-- qui déclare les fonctions du chat : `messages_du_groupe` renvoie désormais
-- la durée, et un `returns table` citant une colonne absente ne se crée pas.
-- C'est la même raison qui met `colonne_avatar_predefini.sql` en tête du
-- manifeste.
--
--
-- POURQUOI UNE COLONNE, ET NON LE FICHIER LUI-MÊME
--
-- La durée d'un message vocal se lit dans le fichier — mais la lire imposerait
-- de le **télécharger** pour l'afficher, c'est-à-dire une URL signée et un
-- aller-retour réseau par bulle, avant même que quiconque appuie sur « lire ».
-- La durée est connue de celui qui enregistre, au dixième de seconde près :
-- elle voyage avec le message.
--
-- Elle est nullable, et le reste : une photo et une vidéo n'en ont pas.
--
--
-- POURQUOI `alter type` PASSE DANS UNE TRANSACTION
--
-- `appliquer.sh` applique chaque fichier dans une seule transaction. Depuis
-- PostgreSQL 12, `alter type … add value` y est accepté ; ce qui reste
-- interdit, c'est d'**employer** la nouvelle valeur avant la validation.
-- Ce fichier ne fait que l'ajouter — aucun `insert`, aucune conversion. Les
-- fonctions qui la manipuleront vivent dans des fichiers appliqués ensuite,
-- donc dans d'autres transactions.

alter type public.media_type add value if not exists 'audio';

-- Secondes entières : afficher « 12 s » ou « 1:07 » ne demande pas mieux, et
-- une valeur au centième donnerait un compteur qui danse à la lecture.
alter table public.messages
  add column if not exists media_duree_s integer;

comment on column public.messages.media_duree_s is
  'Durée d''un média sonore, en secondes. Nulle pour une photo ou une vidéo.';
