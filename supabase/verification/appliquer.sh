#!/usr/bin/env bash
#
# Applique les migrations de `supabase/` à une vraie base PostgreSQL.
#
#     SUPABASE_DB_URL='postgresql://…' supabase/verification/appliquer.sh
#
# Lancé par le workflow `migrations-supabase.yml` à chaque push sur `main`.
# Utilisable à la main pour rattraper une base, ou avec `--essai` pour voir ce
# qui serait appliqué sans rien écrire.
#
#
# CE QUI EST APPLIQUÉ, ET DANS QUEL ORDRE
#
# `supabase/migrations.txt`, et rien d'autre. Les scripts de diagnostic et le
# dossier `verification/` en sont absents : ils ne modifient rien, et les
# rejouer serait au mieux inutile.
#
#
# CE QUI EST REJOUÉ
#
# Un fichier est appliqué si son **empreinte** a changé depuis la dernière
# fois, pas seulement s'il est nouveau. Les fichiers de ce dépôt sont
# idempotents — `create or replace`, `if not exists`, `drop trigger if
# exists` — et ils sont corrigés sur place plutôt que par ajout d'un fichier
# de correctif : `tranche3_taches_et_evenements.sql` l'a été deux fois. Une
# table de suivi qui ne retiendrait que le nom laisserait ces corrections sur
# le quai.
#
# Le corollaire est une contrainte réelle : **une migration doit rester
# idempotente**. Un `insert` nu ou un `alter table add column` sans
# `if not exists` casserait au deuxième passage.
#
#
# TRANSACTION
#
# Un fichier est appliqué dans une seule transaction, avec l'écriture de son
# empreinte. Un échec au milieu ne laisse donc ni schéma à moitié modifié, ni
# empreinte mensongère. Cela vaut aussi en mode « transaction » du pooler
# Supabase, où une transaction tient sur une seule connexion.

set -euo pipefail

readonly VERIFICATION=$(cd "$(dirname "$0")" && pwd)
readonly SUPABASE=$(dirname "$VERIFICATION")
readonly MANIFESTE="$SUPABASE/migrations.txt"

# shellcheck source=connexion.sh
. "$VERIFICATION/connexion.sh"

essai=0
[ "${1:-}" = '--essai' ] && essai=1

# Épure les blancs de début et de fin, contrôle la forme, et pose le masque
# GitHub sur la valeur nettoyée. Voir `connexion.sh` : un saut de ligne collé
# depuis un téléphone donnait `FATAL: database "postgres\n" does not exist`,
# message qui désigne la base plutôt que le presse-papiers.
URL=$(normaliser_url_connexion "${SUPABASE_DB_URL:-}") || exit 2
readonly URL

echo "Connexion à $(masquer_mot_de_passe "$URL")"

# `-q` tait les « CREATE FUNCTION » ; les `raise notice` des migrations, eux,
# passent toujours — ce sont eux qui disent ce qui s'est passé.
psql=(psql "$URL" -v ON_ERROR_STOP=1 -q --no-psqlrc)

# La table de suivi vit dans son propre schéma : `public` est exposé par
# PostgREST, et l'historique des migrations n'a rien à faire dans l'API.
"${psql[@]}" <<'SQL'
create schema if not exists jelvo_migrations;
create table if not exists jelvo_migrations.appliquees (
  fichier    text primary key,
  empreinte  text not null,
  applique_a timestamptz not null default now()
);
SQL

fichiers=()
while IFS= read -r ligne; do
  ligne="${ligne%%#*}"
  ligne="$(echo "$ligne" | tr -d '[:space:]')"
  [ -n "$ligne" ] && fichiers+=("$ligne")
done < "$MANIFESTE"

if [ "${#fichiers[@]}" -eq 0 ]; then
  echo "Aucune migration listée dans $MANIFESTE." >&2
  exit 2
fi

appliquees=0
for fichier in "${fichiers[@]}"; do
  chemin="$SUPABASE/$fichier"
  if [ ! -f "$chemin" ]; then
    echo "ÉCHEC $fichier — listé dans migrations.txt mais absent du dépôt" >&2
    exit 1
  fi

  empreinte=$(sha256sum "$chemin" | cut -d' ' -f1)
  # `:'nom'` laisse psql poser les guillemets, ce qui évite d'écrire un
  # `$$…$$` que bash remplacerait d'abord par son propre PID. L'interpolation
  # de variables n'a lieu que sur l'entrée standard, jamais avec `-c`.
  connue=$("${psql[@]}" -At -v f="$fichier" <<'SQL'
select empreinte from jelvo_migrations.appliquees where fichier = :'f';
SQL
  )

  if [ "$connue" = "$empreinte" ]; then
    printf 'DÉJÀ  %s\n' "$fichier"
    continue
  fi

  raison='nouveau'
  [ -n "$connue" ] && raison='contenu modifié'

  if [ "$essai" -eq 1 ]; then
    printf 'À FAIRE %s (%s)\n' "$fichier" "$raison"
    appliquees=$((appliquees + 1))
    continue
  fi

  printf '>>>>> %s (%s)\n' "$fichier" "$raison"
  "${psql[@]}" -v f="$fichier" -v e="$empreinte" <<SQL
begin;
\\i $chemin
insert into jelvo_migrations.appliquees (fichier, empreinte)
values (:'f', :'e')
on conflict (fichier) do update
  set empreinte = excluded.empreinte, applique_a = now();
commit;
SQL
  printf 'OK    %s\n' "$fichier"
  appliquees=$((appliquees + 1))
done

if [ "$appliquees" -eq 0 ]; then
  echo "Rien à appliquer : la base est à jour."
else
  echo "$appliquees fichier(s) traité(s)."
fi
