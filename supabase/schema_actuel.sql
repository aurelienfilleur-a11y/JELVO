-- Schéma réel de la base Jelvo — NE PAS MODIFIER À LA MAIN.
--
-- Généré par supabase/verification/extraire_schema.sql, exécuté par le
-- workflow migrations-supabase.yml après chaque application de migrations.
--
-- Ce fichier n'est pas une migration : on ne l'exécute pas. C'est la
-- **vérité** contre laquelle vérifier une insertion avant de la livrer, au
-- lieu de la deviner. C'est ce qui manquait le jour où invitations.type,
-- colonne obligatoire du schéma initial, a été oubliée par
-- inviter_dans_groupe : 23502, et plusieurs jours de diagnostic.
--
-- Version du serveur : 17.6


-- =========================================================
-- TYPES ÉNUMÉRÉS
-- =========================================================
create type public.assignee_status as enum ('pending', 'accepted', 'declined', 'done');
create type public.availability_kind as enum ('recurring', 'exception');
create type public.availability_status as enum ('available', 'unavailable');
create type public.contact_status as enum ('pending', 'accepted');
create type public.event_response as enum ('pending', 'yes', 'maybe', 'no');
create type public.invitation_status as enum ('pending', 'accepted', 'declined', 'expired');
create type public.invitation_type as enum ('group', 'event', 'task');
create type public.media_type as enum ('image', 'video');
create type public.member_role as enum ('admin', 'member');
create type public.task_priority as enum ('low', 'medium', 'high');


-- =========================================================
-- TABLES ET COLONNES
-- =========================================================

-- availabilities [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   user_id              uuid                         NOT NULL, sans défaut
--   kind                 availability_kind            NOT NULL, sans défaut
--   status               availability_status          NOT NULL, sans défaut
--   weekday              integer                      
--   on_date              date                         
--   start_time           time without time zone       NOT NULL, sans défaut
--   end_time             time without time zone       NOT NULL, sans défaut
--   created_at           timestamp with time zone     NOT NULL, défaut now()

-- contacts [RLS activée]
--   requester_id         uuid                         NOT NULL, sans défaut
--   addressee_id         uuid                         NOT NULL, sans défaut
--   status               contact_status               NOT NULL, défaut 'pending'::contact_status
--   is_favorite          boolean                      NOT NULL, défaut false
--   created_at           timestamp with time zone     NOT NULL, défaut now()
--   favorite_requester   boolean                      NOT NULL, défaut false
--   favorite_addressee   boolean                      NOT NULL, défaut false

-- event_participants [RLS activée]
--   event_id             uuid                         NOT NULL, sans défaut
--   user_id              uuid                         NOT NULL, sans défaut
--   response             event_response               NOT NULL, défaut 'pending'::event_response
--   responded_at         timestamp with time zone     

-- events [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   group_id             uuid                         
--   owner_id             uuid                         NOT NULL, sans défaut
--   title                text                         NOT NULL, sans défaut
--   description          text                         
--   location             text                         
--   image_url            text                         
--   starts_at            timestamp with time zone     NOT NULL, sans défaut
--   ends_at              timestamp with time zone     
--   rrule                text                         
--   reminder_minutes     integer                      
--   created_at           timestamp with time zone     NOT NULL, défaut now()
--   deleted_at           timestamp with time zone     

-- group_invite_links [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   group_id             uuid                         NOT NULL, sans défaut
--   created_by           uuid                         NOT NULL, sans défaut
--   token                text                         NOT NULL, sans défaut
--   expires_at           timestamp with time zone     NOT NULL, défaut (now() + '30 days'::interval)
--   max_uses             integer                      
--   uses_count           integer                      NOT NULL, défaut 0
--   revoked_at           timestamp with time zone     
--   created_at           timestamp with time zone     NOT NULL, défaut now()

-- group_members [RLS activée]
--   group_id             uuid                         NOT NULL, sans défaut
--   user_id              uuid                         NOT NULL, sans défaut
--   role                 member_role                  NOT NULL, défaut 'member'::member_role
--   joined_at            timestamp with time zone     NOT NULL, défaut now()
--   expires_at           timestamp with time zone     

-- groups [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   name                 text                         NOT NULL, sans défaut
--   description          text                         
--   photo_url            text                         
--   is_private           boolean                      NOT NULL, défaut true
--   created_by           uuid                         NOT NULL, sans défaut
--   created_at           timestamp with time zone     NOT NULL, défaut now()
--   deleted_at           timestamp with time zone     

-- invitations [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   type                 invitation_type              NOT NULL, sans défaut
--   group_id             uuid                         
--   event_id             uuid                         
--   task_id              uuid                         
--   inviter_id           uuid                         NOT NULL, sans défaut
--   invitee_id           uuid                         NOT NULL, sans défaut
--   status               invitation_status            NOT NULL, défaut 'pending'::invitation_status
--   created_at           timestamp with time zone     NOT NULL, défaut now()
--   expires_at           timestamp with time zone     NOT NULL, défaut (now() + '30 days'::interval)

-- message_reactions [RLS activée]
--   message_id           uuid                         NOT NULL, sans défaut
--   user_id              uuid                         NOT NULL, sans défaut
--   emoji                text                         NOT NULL, sans défaut

-- message_reads [RLS activée]
--   group_id             uuid                         NOT NULL, sans défaut
--   user_id              uuid                         NOT NULL, sans défaut
--   last_read_at         timestamp with time zone     NOT NULL, défaut now()

-- messages [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   group_id             uuid                         NOT NULL, sans défaut
--   sender_id            uuid                         NOT NULL, sans défaut
--   content              text                         
--   media_url            text                         
--   media_kind           media_type                   
--   created_at           timestamp with time zone     NOT NULL, défaut now()
--   deleted_at           timestamp with time zone     

-- notifications [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   user_id              uuid                         NOT NULL, sans défaut
--   type                 text                         NOT NULL, sans défaut
--   payload              jsonb                        NOT NULL, défaut '{}'::jsonb
--   read_at              timestamp with time zone     
--   created_at           timestamp with time zone     NOT NULL, défaut now()

-- profiles [RLS activée]
--   id                   uuid                         NOT NULL, sans défaut
--   pseudo               text                         NOT NULL, sans défaut
--   first_name           text                         NOT NULL, sans défaut
--   last_name            text                         NOT NULL, sans défaut
--   avatar_url           text                         
--   bio                  text                         
--   interests            text[]                       défaut '{}'::text[]
--   timezone             text                         NOT NULL, défaut 'Europe/Paris'::text
--   last_seen_at         timestamp with time zone     
--   created_at           timestamp with time zone     NOT NULL, défaut now()

-- push_tokens [RLS activée]
--   user_id              uuid                         NOT NULL, sans défaut
--   token                text                         NOT NULL, sans défaut
--   platform             text                         NOT NULL, sans défaut
--   updated_at           timestamp with time zone     NOT NULL, défaut now()

-- task_assignees [RLS activée]
--   task_id              uuid                         NOT NULL, sans défaut
--   user_id              uuid                         NOT NULL, sans défaut
--   status               assignee_status              NOT NULL, défaut 'pending'::assignee_status

-- task_list_items [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   task_id              uuid                         NOT NULL, sans défaut
--   label                text                         NOT NULL, sans défaut
--   position             integer                      NOT NULL, défaut 0
--   checked_by           uuid                         
--   checked_at           timestamp with time zone     
--   created_at           timestamp with time zone     NOT NULL, défaut now()

-- tasks [RLS activée]
--   id                   uuid                         NOT NULL, défaut gen_random_uuid()
--   group_id             uuid                         NOT NULL, sans défaut
--   created_by           uuid                         NOT NULL, sans défaut
--   title                text                         NOT NULL, sans défaut
--   description          text                         
--   due_at               timestamp with time zone     
--   priority             task_priority                NOT NULL, défaut 'medium'::task_priority
--   rrule                text                         
--   reminder_at          timestamp with time zone     
--   has_shopping_list    boolean                      NOT NULL, défaut false
--   completed_at         timestamp with time zone     
--   created_at           timestamp with time zone     NOT NULL, défaut now()
--   deleted_at           timestamp with time zone     


-- =========================================================
-- CONTRAINTES
-- =========================================================
-- availabilities           availabilities_check : CHECK ((end_time > start_time))
-- availabilities           availabilities_check1 : CHECK ((((kind = 'recurring'::availability_kind) AND (weekday IS NOT NULL) AND (on_date IS NULL)) OR ((kind = 'exception'::availability_kind) AND (on_date IS NOT NULL) AND (weekday IS NULL))))
-- availabilities           availabilities_weekday_check : CHECK (((weekday >= 0) AND (weekday <= 6)))
-- availabilities           availabilities_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- availabilities           availabilities_pkey : PRIMARY KEY (id)
-- contacts                 contacts_check : CHECK ((requester_id <> addressee_id))
-- contacts                 contacts_addressee_id_fkey : FOREIGN KEY (addressee_id) REFERENCES profiles(id) ON DELETE CASCADE
-- contacts                 contacts_requester_id_fkey : FOREIGN KEY (requester_id) REFERENCES profiles(id) ON DELETE CASCADE
-- contacts                 contacts_pkey : PRIMARY KEY (requester_id, addressee_id)
-- event_participants       event_participants_event_id_fkey : FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
-- event_participants       event_participants_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- event_participants       event_participants_pkey : PRIMARY KEY (event_id, user_id)
-- events                   events_check : CHECK (((ends_at IS NULL) OR (ends_at > starts_at)))
-- events                   events_description_check : CHECK ((char_length(description) <= 200))
-- events                   events_title_check : CHECK (((char_length(title) >= 1) AND (char_length(title) <= 80)))
-- events                   events_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- events                   events_owner_id_fkey : FOREIGN KEY (owner_id) REFERENCES profiles(id)
-- events                   events_pkey : PRIMARY KEY (id)
-- group_invite_links       group_invite_links_max_uses_positif : CHECK (((max_uses IS NULL) OR (max_uses > 0)))
-- group_invite_links       group_invite_links_created_by_fkey : FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE CASCADE
-- group_invite_links       group_invite_links_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- group_invite_links       group_invite_links_pkey : PRIMARY KEY (id)
-- group_invite_links       group_invite_links_token_key : UNIQUE (token)
-- group_members            group_members_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- group_members            group_members_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- group_members            group_members_pkey : PRIMARY KEY (group_id, user_id)
-- groups                   groups_description_check : CHECK ((char_length(description) <= 120))
-- groups                   groups_name_check : CHECK (((char_length(name) >= 1) AND (char_length(name) <= 50)))
-- groups                   groups_created_by_fkey : FOREIGN KEY (created_by) REFERENCES profiles(id)
-- groups                   groups_pkey : PRIMARY KEY (id)
-- invitations              invitations_check : CHECK ((((type = 'group'::invitation_type) AND (group_id IS NOT NULL)) OR ((type = 'event'::invitation_type) AND (event_id IS NOT NULL)) OR ((type = 'task'::invitation_type) AND (task_id IS NOT NULL))))
-- invitations              invitations_event_id_fkey : FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
-- invitations              invitations_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- invitations              invitations_invitee_id_fkey : FOREIGN KEY (invitee_id) REFERENCES profiles(id)
-- invitations              invitations_inviter_id_fkey : FOREIGN KEY (inviter_id) REFERENCES profiles(id)
-- invitations              invitations_task_id_fkey : FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
-- invitations              invitations_pkey : PRIMARY KEY (id)
-- message_reactions        message_reactions_emoji_check : CHECK ((char_length(emoji) <= 8))
-- message_reactions        message_reactions_message_id_fkey : FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
-- message_reactions        message_reactions_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- message_reactions        message_reactions_pkey : PRIMARY KEY (message_id, user_id)
-- message_reads            message_reads_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- message_reads            message_reads_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- message_reads            message_reads_pkey : PRIMARY KEY (group_id, user_id)
-- messages                 messages_check : CHECK (((content IS NOT NULL) OR (media_url IS NOT NULL)))
-- messages                 messages_content_check : CHECK ((char_length(content) <= 2000))
-- messages                 messages_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- messages                 messages_sender_id_fkey : FOREIGN KEY (sender_id) REFERENCES profiles(id)
-- messages                 messages_pkey : PRIMARY KEY (id)
-- notifications            notifications_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- notifications            notifications_pkey : PRIMARY KEY (id)
-- profiles                 profiles_bio_check : CHECK ((char_length(bio) <= 160))
-- profiles                 profiles_pseudo_check : CHECK ((pseudo ~ '^[a-z0-9.]{3,20}$'::text))
-- profiles                 profiles_id_fkey : FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
-- profiles                 profiles_pkey : PRIMARY KEY (id)
-- profiles                 profiles_pseudo_key : UNIQUE (pseudo)
-- push_tokens              push_tokens_platform_check : CHECK ((platform = ANY (ARRAY['ios'::text, 'android'::text])))
-- push_tokens              push_tokens_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- push_tokens              push_tokens_pkey : PRIMARY KEY (user_id, token)
-- task_assignees           task_assignees_task_id_fkey : FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
-- task_assignees           task_assignees_user_id_fkey : FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
-- task_assignees           task_assignees_pkey : PRIMARY KEY (task_id, user_id)
-- task_list_items          task_list_items_label_check : CHECK (((char_length(label) >= 1) AND (char_length(label) <= 60)))
-- task_list_items          task_list_items_checked_by_fkey : FOREIGN KEY (checked_by) REFERENCES profiles(id)
-- task_list_items          task_list_items_task_id_fkey : FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
-- task_list_items          task_list_items_pkey : PRIMARY KEY (id)
-- tasks                    tasks_description_check : CHECK ((char_length(description) <= 300))
-- tasks                    tasks_title_check : CHECK (((char_length(title) >= 1) AND (char_length(title) <= 80)))
-- tasks                    tasks_created_by_fkey : FOREIGN KEY (created_by) REFERENCES profiles(id)
-- tasks                    tasks_group_id_fkey : FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
-- tasks                    tasks_pkey : PRIMARY KEY (id)


-- =========================================================
-- POLITIQUES RLS
-- =========================================================
-- availabilities           av_all                       ALL    {public}
--   using       : (user_id = auth.uid())
--   with check  : (user_id = auth.uid())
-- contacts                 contacts_delete              DELETE {public}
--   using       : ((requester_id = auth.uid()) OR (addressee_id = auth.uid()))
--   with check  : —
-- contacts                 contacts_insert              INSERT {public}
--   using       : —
--   with check  : (requester_id = auth.uid())
-- contacts                 contacts_select              SELECT {public}
--   using       : ((requester_id = auth.uid()) OR (addressee_id = auth.uid()))
--   with check  : —
-- contacts                 contacts_update              UPDATE {public}
--   using       : ((addressee_id = auth.uid()) OR (requester_id = auth.uid()))
--   with check  : —
-- event_participants       ep_insert                    INSERT {public}
--   using       : —
--   with check  : (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = event_participants.event_id) AND (e.group_id IS NOT NULL) AND is_group_member(e.group_id))))
-- event_participants       ep_select                    SELECT {public}
--   using       : (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = event_participants.event_id) AND ((e.owner_id = auth.uid()) OR ((e.group_id IS NOT NULL) AND is_group_member(e.group_id))))))
--   with check  : —
-- event_participants       ep_update                    UPDATE {public}
--   using       : (user_id = auth.uid())
--   with check  : —
-- events                   events_insert                INSERT {public}
--   using       : —
--   with check  : ((owner_id = auth.uid()) AND ((group_id IS NULL) OR is_group_member(group_id)))
-- events                   events_select                SELECT {public}
--   using       : ((deleted_at IS NULL) AND (((group_id IS NULL) AND (owner_id = auth.uid())) OR ((group_id IS NOT NULL) AND is_group_member(group_id))))
--   with check  : —
-- events                   events_update                UPDATE {public}
--   using       : ((owner_id = auth.uid()) OR ((group_id IS NOT NULL) AND is_group_admin(group_id)))
--   with check  : —
-- group_invite_links       lien_invitation_creation     INSERT {authenticated}
--   using       : —
--   with check  : ((created_by = auth.uid()) AND est_membre_du_groupe(group_id, auth.uid()))
-- group_invite_links       lien_invitation_lecture_membre SELECT {authenticated}
--   using       : est_membre_du_groupe(group_id, auth.uid())
--   with check  : —
-- group_invite_links       lien_invitation_lecture_publique SELECT {anon}
--   using       : true
--   with check  : —
-- group_invite_links       lien_invitation_revocation   UPDATE {authenticated}
--   using       : ((created_by = auth.uid()) OR est_admin_du_groupe(group_id, auth.uid()))
--   with check  : ((created_by = auth.uid()) OR est_admin_du_groupe(group_id, auth.uid()))
-- group_members            gm_delete                    DELETE {public}
--   using       : ((user_id = auth.uid()) OR is_group_admin(group_id))
--   with check  : —
-- group_members            gm_insert                    INSERT {public}
--   using       : —
--   with check  : (user_id = auth.uid())
-- group_members            gm_select                    SELECT {public}
--   using       : is_group_member(group_id)
--   with check  : —
-- group_members            gm_update                    UPDATE {public}
--   using       : is_group_admin(group_id)
--   with check  : —
-- groups                   groups_insert                INSERT {public}
--   using       : —
--   with check  : (created_by = auth.uid())
-- groups                   groups_select                SELECT {public}
--   using       : (is_group_member(id) AND (deleted_at IS NULL))
--   with check  : —
-- groups                   groups_update                UPDATE {public}
--   using       : is_group_admin(id)
--   with check  : —
-- invitations              inv_insert                   INSERT {public}
--   using       : —
--   with check  : (inviter_id = auth.uid())
-- invitations              inv_select                   SELECT {public}
--   using       : ((inviter_id = auth.uid()) OR (invitee_id = auth.uid()))
--   with check  : —
-- invitations              inv_update                   UPDATE {public}
--   using       : (invitee_id = auth.uid())
--   with check  : —
-- message_reactions        mr_all                       ALL    {public}
--   using       : (EXISTS ( SELECT 1
   FROM messages m
  WHERE ((m.id = message_reactions.message_id) AND is_group_member(m.group_id))))
--   with check  : (user_id = auth.uid())
-- message_reads            reads_all                    ALL    {public}
--   using       : (user_id = auth.uid())
--   with check  : (user_id = auth.uid())
-- messages                 msg_insert                   INSERT {public}
--   using       : —
--   with check  : ((sender_id = auth.uid()) AND is_group_member(group_id))
-- messages                 msg_select                   SELECT {public}
--   using       : is_group_member(group_id)
--   with check  : —
-- messages                 msg_update                   UPDATE {public}
--   using       : (sender_id = auth.uid())
--   with check  : —
-- notifications            notif_insert_declencheur     INSERT {postgres}
--   using       : —
--   with check  : true
-- notifications            notif_select                 SELECT {public}
--   using       : (user_id = auth.uid())
--   with check  : —
-- notifications            notif_update                 UPDATE {public}
--   using       : (user_id = auth.uid())
--   with check  : —
-- profiles                 profiles_insert              INSERT {public}
--   using       : —
--   with check  : (id = auth.uid())
-- profiles                 profiles_select              SELECT {public}
--   using       : ((id = auth.uid()) OR has_social_link(id) OR true)
--   with check  : —
-- profiles                 profiles_update              UPDATE {public}
--   using       : (id = auth.uid())
--   with check  : —
-- push_tokens              pt_all                       ALL    {public}
--   using       : (user_id = auth.uid())
--   with check  : (user_id = auth.uid())
-- task_assignees           ta_insert                    INSERT {public}
--   using       : —
--   with check  : (EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_assignees.task_id) AND is_group_member(t.group_id))))
-- task_assignees           ta_select                    SELECT {public}
--   using       : (EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_assignees.task_id) AND is_group_member(t.group_id))))
--   with check  : —
-- task_assignees           ta_update                    UPDATE {public}
--   using       : ((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_assignees.task_id) AND (t.created_by = auth.uid())))))
--   with check  : —
-- task_list_items          tli_all                      ALL    {public}
--   using       : (EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_list_items.task_id) AND is_group_member(t.group_id))))
--   with check  : (EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_list_items.task_id) AND is_group_member(t.group_id))))
-- tasks                    tasks_insert                 INSERT {public}
--   using       : —
--   with check  : ((created_by = auth.uid()) AND is_group_member(group_id))
-- tasks                    tasks_select                 SELECT {public}
--   using       : ((deleted_at IS NULL) AND is_group_member(group_id))
--   with check  : —
-- tasks                    tasks_update                 UPDATE {public}
--   using       : is_group_member(group_id)
--   with check  : —


-- =========================================================
-- FONCTIONS
-- =========================================================
-- accepter_invitation(p_invitation_id uuid) → text   [security definer, postgres]
-- add_creator_as_admin() → trigger   [security definer, postgres]
-- ajouter_article(p_task_id uuid, p_label text) → uuid   [security definer, postgres]
-- apercu_groupe_par_jeton(jeton text) → TABLE(statut text, group_id uuid, nom text, description text, photo_url text, nombre_membres integer)   [security definer, postgres]
-- articles_de_tache(p_task_id uuid) → TABLE(id uuid, label text, "position" integer, checked_at timestamp with time zone, checked_by uuid, coche_par text)   [security definer, postgres]
-- chercher_profils_par_pseudo(terme text) → TABLE(id uuid, pseudo text, first_name text, last_name text, avatar_url text)   [security definer, postgres]
-- clore_notification_contact() → trigger   [security definer, postgres]
-- clore_notification_contact_supprime() → trigger   [security definer, postgres]
-- clore_notification_evenement() → trigger   [security definer, postgres]
-- clore_notification_invitation() → trigger   [security definer, postgres]
-- cocher_article(p_item_id uuid, p_coche boolean DEFAULT true) → timestamp with time zone   [security definer, postgres]
-- creer_evenement(p_title text, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_group_id uuid DEFAULT NULL::uuid, p_description text DEFAULT NULL::text, p_location text DEFAULT NULL::text, p_rrule text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text, p_reminder_minutes integer DEFAULT NULL::integer, p_participants uuid[] DEFAULT NULL::uuid[]) → events   [security definer, postgres]
-- creer_groupe(p_name text, p_description text DEFAULT NULL::text, p_photo_url text DEFAULT NULL::text, p_is_private boolean DEFAULT true) → groups   [security definer, postgres]
-- creer_tache(p_title text, p_group_id uuid DEFAULT NULL::uuid, p_description text DEFAULT NULL::text, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_priority text DEFAULT 'medium'::text, p_reminder_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_rrule text DEFAULT NULL::text, p_assignees uuid[] DEFAULT NULL::uuid[], p_items text[] DEFAULT NULL::text[]) → tasks   [security definer, postgres]
-- definir_assignes_tache(p_task_id uuid, p_assignees uuid[]) → integer   [security definer, postgres]
-- definir_disponibilite(p_kind text, p_start time without time zone, p_end time without time zone, p_status text DEFAULT 'available'::text, p_weekday integer DEFAULT NULL::integer, p_on_date date DEFAULT NULL::date, p_id uuid DEFAULT NULL::uuid) → availabilities   [security definer, postgres]
-- email_pour_pseudo(pseudo_recherche text) → text   [security definer, postgres]
-- est_admin_du_groupe(p_group_id uuid, p_user_id uuid) → boolean   [security definer, postgres]
-- est_membre_du_groupe(p_group_id uuid, p_user_id uuid) → boolean   [security definer, postgres]
-- get_availability_status(target uuid, at_ts timestamp with time zone) → text   [security definer, postgres]
-- has_social_link(other uuid) → boolean   [security definer, postgres]
-- inviter_dans_groupe(p_group_id uuid, p_invitee uuid) → text   [security definer, postgres]
-- is_group_admin(gid uuid) → boolean   [security definer, postgres]
-- is_group_member(gid uuid) → boolean   [security definer, postgres]
-- membres_du_groupe(p_group_id uuid) → TABLE(user_id uuid, role text, joined_at timestamp with time zone, expires_at timestamp with time zone, pseudo text, first_name text, last_name text, avatar_url text)   [security definer, postgres]
-- mes_contacts() → TABLE(autre_id uuid, pseudo text, first_name text, last_name text, avatar_url text, statut text, sens text, favori boolean, created_at timestamp with time zone)   [security definer, postgres]
-- mes_disponibilites() → TABLE(id uuid, kind text, weekday integer, on_date date, start_time time without time zone, end_time time without time zone, status text, created_at timestamp with time zone)   [security definer, postgres]
-- mes_invitations() → TABLE(id uuid, group_id uuid, nom text, description text, photo_url text, nombre_membres integer, membres_apercu text[], emetteur text, emetteur_avatar text, statut text, created_at timestamp with time zone, expires_at timestamp with time zone)   [security definer, postgres]
-- mes_taches(p_group_id uuid DEFAULT NULL::uuid) → TABLE(id uuid, group_id uuid, created_by uuid, title text, description text, due_at timestamp with time zone, priority text, reminder_at timestamp with time zone, rrule text, completed_at timestamp with time zone, created_at timestamp with time zone, mon_statut text, assignes jsonb, articles integer, articles_coches integer)   [security definer, postgres]
-- modifier_evenement(p_event_id uuid, p_title text, p_starts_at timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_description text DEFAULT NULL::text, p_location text DEFAULT NULL::text, p_rrule text DEFAULT NULL::text, p_image_url text DEFAULT NULL::text, p_reminder_minutes integer DEFAULT NULL::integer) → events   [security definer, postgres]
-- modifier_tache(p_task_id uuid, p_title text, p_description text DEFAULT NULL::text, p_due_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_priority text DEFAULT 'medium'::text, p_reminder_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_rrule text DEFAULT NULL::text) → tasks   [security definer, postgres]
-- mon_agenda(p_debut timestamp with time zone DEFAULT NULL::timestamp with time zone, p_fin timestamp with time zone DEFAULT NULL::timestamp with time zone, p_group_id uuid DEFAULT NULL::uuid) → TABLE(id uuid, group_id uuid, owner_id uuid, title text, description text, starts_at timestamp with time zone, ends_at timestamp with time zone, location text, rrule text, image_url text, reminder_minutes integer, ma_reponse text, participants jsonb, nombre_oui integer)   [security definer, postgres]
-- notifier_demande_contact() → trigger   [security definer, postgres]
-- notifier_invitation_evenement() → trigger   [security definer, postgres]
-- notifier_invitation_groupe() → trigger   [security definer, postgres]
-- peut_voir_evenement(p_event_id uuid) → boolean   [security definer, postgres]
-- peut_voir_tache(p_task_id uuid) → boolean   [security definer, postgres]
-- promouvoir_membre(p_group_id uuid, p_user_id uuid) → text   [security definer, postgres]
-- quitter_groupe(p_group_id uuid) → text   [security definer, postgres]
-- refuser_invitation(p_invitation_id uuid) → text   [security definer, postgres]
-- rejoindre_groupe_par_jeton(jeton text) → text   [security definer, postgres]
-- repondre_evenement(p_event_id uuid, p_reponse text) → text   [security definer, postgres]
-- repondre_tache(p_task_id uuid, p_statut text) → text   [security definer, postgres]
-- retirer_membre(p_group_id uuid, p_user_id uuid) → text   [security definer, postgres]
-- retrograder_membre(p_group_id uuid, p_user_id uuid) → text   [security definer, postgres]
-- s_attribuer_tache(p_task_id uuid, p_prendre boolean DEFAULT true) → text   [security definer, postgres]
-- statuts_de_disponibilite(p_users uuid[], p_at timestamp with time zone) → TABLE(user_id uuid, statut text)   [security definer, postgres]
-- supprimer_article(p_item_id uuid) → boolean   [security definer, postgres]
-- supprimer_disponibilite(p_id uuid) → boolean   [security definer, postgres]
-- supprimer_evenement(p_event_id uuid) → boolean   [security definer, postgres]
-- supprimer_tache(p_task_id uuid) → boolean   [security definer, postgres]
-- terminer_tache(p_task_id uuid, p_terminee boolean DEFAULT true) → timestamp with time zone   [security definer, postgres]


-- =========================================================
-- DÉCLENCHEURS
-- =========================================================
-- contacts                 CREATE TRIGGER trg_clore_notification_contact AFTER UPDATE ON public.contacts FOR EACH ROW WHEN ((new.status = 'accepted'::contact_status)) EXECUTE FUNCTION clore_notification_contact()
-- contacts                 CREATE TRIGGER trg_clore_notification_contact_supprime AFTER DELETE ON public.contacts FOR EACH ROW EXECUTE FUNCTION clore_notification_contact_supprime()
-- contacts                 CREATE TRIGGER trg_notifier_demande_contact AFTER INSERT ON public.contacts FOR EACH ROW EXECUTE FUNCTION notifier_demande_contact()
-- event_participants       CREATE TRIGGER trg_clore_notification_evenement AFTER UPDATE ON public.event_participants FOR EACH ROW EXECUTE FUNCTION clore_notification_evenement()
-- event_participants       CREATE TRIGGER trg_notifier_invitation_evenement AFTER INSERT ON public.event_participants FOR EACH ROW EXECUTE FUNCTION notifier_invitation_evenement()
-- groups                   CREATE TRIGGER trg_group_creator_admin AFTER INSERT ON public.groups FOR EACH ROW EXECUTE FUNCTION add_creator_as_admin()
-- invitations              CREATE TRIGGER trg_clore_notification_invitation AFTER UPDATE ON public.invitations FOR EACH ROW EXECUTE FUNCTION clore_notification_invitation()
-- invitations              CREATE TRIGGER trg_notifier_invitation_groupe AFTER INSERT ON public.invitations FOR EACH ROW EXECUTE FUNCTION notifier_invitation_groupe()


-- =========================================================
-- PRIVILÈGES (anon, authenticated)
-- =========================================================
-- availabilities           anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- availabilities           authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- contacts                 anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- contacts                 authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- event_participants       anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- event_participants       authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- events                   anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- events                   authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- group_invite_links       authenticated    INSERT, SELECT, UPDATE
-- group_members            anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- group_members            authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- groups                   anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- groups                   authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- invitations              anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- invitations              authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- message_reactions        anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- message_reactions        authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- message_reads            anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- message_reads            authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- messages                 anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- messages                 authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- notifications            anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- notifications            authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- profiles                 anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- profiles                 authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- push_tokens              anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- push_tokens              authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- task_assignees           anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- task_assignees           authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- task_list_items          anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- task_list_items          authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- tasks                    anon             DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
-- tasks                    authenticated    DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE
