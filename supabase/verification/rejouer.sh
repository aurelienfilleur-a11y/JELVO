#!/usr/bin/env bash
#
# Rejoue tous les fichiers SQL de `supabase/` sur une base PostgreSQL locale et
# jetable, dans l'ordre d'exécution attendu, et signale le premier échec.
#
# À lancer depuis la racine du dépôt :
#
#     supabase/verification/rejouer.sh
#
# Prérequis : PostgreSQL 15 ou plus (`initdb`, `pg_ctl`, `psql`). La CI ne
# lance pas ce script — la chaîne Flutter ne compile pas le SQL, et une CI
# verte ne dit donc rien de ces fichiers. C'est à faire avant de livrer une
# migration.
#
# Le décor vient de `schema_factice.sql` : lire son en-tête pour savoir ce que
# ce contrôle prouve, et surtout ce qu'il ne prouve pas.

set -euo pipefail

# Sur Debian et Ubuntu, les binaires du serveur ne sont pas dans le PATH.
for bin in /usr/lib/postgresql/*/bin; do
  [ -d "$bin" ] && PATH="$PATH:$bin"
done

# `initdb` refuse de s'exécuter en root, et c'est heureux : un cluster créé en
# root serait inutilisable ensuite.
if [ "$(id -u)" -eq 0 ]; then
  echo "À lancer sous un compte non privilégié (par exemple : su postgres)." >&2
  exit 2
fi

readonly PORT=${PGPORT_JELVO:-55432}
readonly SOCKET=${TMPDIR:-/tmp}
readonly CLUSTER=$(mktemp -d)
readonly VERIFICATION=$(cd "$(dirname "$0")" && pwd)
readonly SUPABASE=$(dirname "$VERIFICATION")

# Ordre d'exécution : `supabase/migrations.txt`, la même liste que celle
# appliquée à la base réelle. Deux listes auraient fini par diverger.
readonly MANIFESTE="$SUPABASE/migrations.txt"
FICHIERS=()
while IFS= read -r ligne; do
  ligne="${ligne%%#*}"
  ligne="$(echo "$ligne" | tr -d '[:space:]')"
  [ -n "$ligne" ] && FICHIERS+=("$ligne")
done < "$MANIFESTE"

arreter() { pg_ctl -D "$CLUSTER" stop -m immediate >/dev/null 2>&1 || true
            rm -rf "$CLUSTER"; }
trap arreter EXIT

initdb -D "$CLUSTER" -U postgres --auth=trust >/dev/null
pg_ctl -D "$CLUSTER" -l "$CLUSTER/log" \
  -o "-k $SOCKET -p $PORT -c listen_addresses=" start >/dev/null

psql="psql -h $SOCKET -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
$psql -c 'create database jelvo_verification' >/dev/null
psql="$psql -d jelvo_verification"

$psql -f "$VERIFICATION/schema_factice.sql"

echec=0
for fichier in "${FICHIERS[@]}"; do
  if $psql -f "$SUPABASE/$fichier" >/dev/null; then
    printf 'OK    %s\n' "$fichier"
  else
    printf 'ÉCHEC %s\n' "$fichier"
    echec=1
    break
  fi
done

# Le rejeu ne prouve que la compilation. Les instructions SQL d'une fonction
# plpgsql ne sont préparées qu'au premier appel : il faut donc appeler.
if [ "$echec" -eq 0 ]; then
  if $psql -f "$VERIFICATION/fumee.sql"; then
    printf 'OK    verification/fumee.sql\n'
  else
    printf 'ÉCHEC verification/fumee.sql\n'
    echec=1
  fi
fi

exit "$echec"
