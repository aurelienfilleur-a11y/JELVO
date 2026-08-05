-- Résolution d'un pseudo en adresse e-mail, pour la connexion par pseudo.
--
-- `profiles` ne stocke pas l'adresse e-mail : elle vit dans `auth.users`, hors
-- de portée du client. Sans cette fonction, seule la connexion par e-mail est
-- possible — l'application affiche alors un message invitant à utiliser
-- l'adresse e-mail.
--
-- `security definer` est nécessaire pour lire `auth.users` ; la fonction ne
-- renvoie qu'une seule adresse, et uniquement pour un pseudo exact.
--
-- À exécuter dans l'éditeur SQL du projet Supabase.

create or replace function public.email_pour_pseudo(pseudo_recherche text)
returns text
language sql
security definer
set search_path = public, auth
stable
as $$
  select u.email
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.pseudo = lower(pseudo_recherche)
  limit 1;
$$;

revoke all on function public.email_pour_pseudo(text) from public;
grant execute on function public.email_pour_pseudo(text) to anon, authenticated;

-- Note : cette fonction permet de savoir si un pseudo existe, ce qui est déjà
-- le cas via la vérification de disponibilité à l'inscription. Elle n'expose
-- l'adresse qu'à qui connaît le pseudo exact ; si ce compromis n'est pas
-- souhaité, supprimez-la et retirez la connexion par pseudo de l'écran.
