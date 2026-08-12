-- Tranche 5b — médias du chat, bucket privé `chat-media`.
--
-- Appliqué automatiquement au push sur `main` : voir `supabase/migrations.txt`.
-- Idempotent.
--
--
-- LE BUCKET EXISTE DÉJÀ, ET IL EST PRIVÉ — VÉRIFIÉ, PAS SUPPOSÉ
--
-- Sondé avant d'écrire une ligne, par la différence des messages d'erreur du
-- service Storage :
--
--   GET /storage/v1/object/chat-media/sonde.txt   → NoSuchKey    (objet absent)
--   GET /storage/v1/object/nom-invente/sonde.txt  → NoSuchBucket (bucket absent)
--   GET /storage/v1/object/public/chat-media/…    → NoSuchBucket
--
-- Le premier prouve que le bucket existe ; le troisième qu'il n'est pas
-- public, le chemin `public/` ne servant que les buckets publics. Ce fichier
-- ne le crée donc pas, et surtout **ne le rend pas public**.
--
-- `schema_actuel.sql` ne couvre pas le schéma `storage` : c'est pourquoi le
-- sondage était nécessaire. Étendre l'extraction est la suite naturelle.
--
--
-- LA CONVENTION DE CHEMIN PORTE L'AUTORISATION
--
--     chat-media/<group_id>/<uuid>.<ext>
--
-- Le **premier segment est l'identifiant du groupe**, et c'est lui que les
-- politiques lisent. Sans cette convention, une politique devrait retrouver le
-- groupe en interrogeant `messages` — mais l'objet est téléversé *avant* que le
-- message existe, et il n'y aurait donc rien à interroger.


-- ---------------------------------------------------------------------------
-- 1. Extraire le groupe d'un chemin, sans jamais lever
-- ---------------------------------------------------------------------------
-- Une exception levée dans une politique fait échouer la requête entière. Un
-- objet déposé hors convention — chemin sans dossier, dossier qui n'est pas un
-- UUID — doit donc donner `null`, que `est_membre_du_groupe` refusera
-- tranquillement, et non une erreur.

create or replace function public.groupe_du_chemin(p_name text)
returns uuid
language plpgsql
immutable
as $$
begin
  return (string_to_array(p_name, '/'))[1]::uuid;
exception
  when others then
    return null;
end;
$$;

grant execute on function public.groupe_du_chemin(text) to authenticated, anon;


-- ---------------------------------------------------------------------------
-- 2. Politiques du bucket, réservées aux membres du groupe
-- ---------------------------------------------------------------------------
-- `storage.objects` appartient à `supabase_storage_admin`. Le rôle qui applique
-- les migrations peut normalement y créer des politiques ; si ce n'est pas le
-- cas, on **le dit fort** et on laisse le reste s'appliquer. Un échec dur
-- bloquerait toutes les migrations suivantes, alors que le défaut se répare en
-- collant ce bloc dans l'éditeur SQL du projet.

do $$
begin
  execute $politique$
    drop policy if exists chat_media_lecture on storage.objects;
    create policy chat_media_lecture on storage.objects
      for select to authenticated
      using (
        bucket_id = 'chat-media'
        and public.est_membre_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      );

    drop policy if exists chat_media_depot on storage.objects;
    create policy chat_media_depot on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'chat-media'
        and owner = auth.uid()
        and public.est_membre_du_groupe(
              public.groupe_du_chemin(name), auth.uid())
      );

    -- Modifier et retirer : seulement ce qu'on a soi-même déposé. Un membre ne
    -- doit pas pouvoir effacer la photo d'un autre.
    drop policy if exists chat_media_maj on storage.objects;
    create policy chat_media_maj on storage.objects
      for update to authenticated
      using (bucket_id = 'chat-media' and owner = auth.uid());

    drop policy if exists chat_media_retrait on storage.objects;
    create policy chat_media_retrait on storage.objects
      for delete to authenticated
      using (bucket_id = 'chat-media' and owner = auth.uid());
  $politique$;

  raise notice 'Politiques du bucket chat-media posées.';
exception
  when insufficient_privilege then
    raise warning
      'ATTENTION — politiques de chat-media NON posées : privilèges '
      'insuffisants sur storage.objects. Collez la PARTIE 2 de '
      'supabase/tranche5b_medias_chat.sql dans l''éditeur SQL du projet. '
      'Sans elles, aucun média ne sera ni déposé ni lu.';
  when undefined_table then
    raise warning
      'ATTENTION — schema storage absent : politiques de chat-media '
      'ignorées. Attendu en rejeu local, anormal sur le projet Supabase.';
end;
$$;


-- ---------------------------------------------------------------------------
-- 3. Le bucket doit exister
-- ---------------------------------------------------------------------------
-- On ne le crée pas — le créer supposerait de décider s'il est public, et il
-- ne l'est pas. On se contente de le dire si quelqu'un l'a supprimé.

do $$
begin
  if not exists (
    select 1 from storage.buckets where id = 'chat-media'
  ) then
    raise warning
      'ATTENTION — le bucket chat-media est introuvable. Créez-le PRIVÉ '
      'depuis Storage, sans quoi tout envoi de média échouera.';
  end if;
exception
  when undefined_table then
    null; -- Rejeu local : pas de schéma storage, rien à vérifier.
end;
$$;
