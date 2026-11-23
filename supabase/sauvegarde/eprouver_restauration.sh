#!/usr/bin/env bash
#
# Restaure une sauvegarde Jelvo dans un cluster PostgreSQL **jetable**, et
# confronte ce qu'elle rend à l'inventaire relevé au moment du dump.
#
#     supabase/sauvegarde/eprouver_restauration.sh /tmp/jelvo.tar
#     supabase/sauvegarde/eprouver_restauration.sh jelvo-20261122.tar.age --cle ~/.jelvo-sauvegarde.key
#
# Rien n'est écrit en dehors d'un répertoire temporaire, et aucune base réelle
# n'est touchée. Le script est sans effet : on peut le lancer autant de fois
# qu'on veut, sur n'importe quelle sauvegarde.
#
#
# POURQUOI CE SCRIPT EST LE CŒUR DU DISPOSITIF
#
# « Une sauvegarde qu'on ne sait pas restaurer ne sert à rien » — et une
# procédure écrite ne prouve rien. Le seul contrôle qui vaille est d'avoir
# restauré.
#
# Il est donc lancé **chaque nuit** par le workflow, sur la sauvegarde qui
# vient d'être produite et avant qu'elle ne soit téléversée. S'il échoue,
# l'export est déclaré en échec et l'alerte part — même si `pg_dump` a rendu 0.
#
#
# UN SEUL SCRIPT POUR DEUX USAGES, ET CE N'EST PAS UNE ÉCONOMIE
#
# C'est aussi celui qu'on lance à la main pour juger une sauvegarde déjà
# téléversée, en lui donnant la clé privée. Deux implémentations — l'une pour
# l'épreuve automatique, l'autre pour la vérification humaine — auraient fini
# par diverger, et c'est la seconde qui aurait été fausse le jour où on en a
# besoin.
#
# Ce que l'épreuve nocturne ne peut **pas** prouver : que le fichier chiffré
# est déchiffrable par votre clé. Le workflow ne détient que la clé publique,
# ce qui est toute la propriété qu'on cherche. Ce contrôle-là est à faire une
# fois à la main, avec `--cle` — voir `RESTAURER.md`.

set -euo pipefail

readonly SAUVEGARDE=$(cd "$(dirname "$0")" && pwd)

# `initdb` refuse de s'exécuter en root, et c'est heureux — même garde que
# `verification/rejouer.sh`.
if [ "$(id -u)" -eq 0 ]; then
  echo "À lancer sous un compte non privilégié (par exemple : su postgres)." >&2
  exit 2
fi

archive=${1:?Usage: eprouver_restauration.sh <sauvegarde.tar[.age]> [--cle <identité>]}
shift
cle=''
while [ $# -gt 0 ]; do
  case $1 in
    --cle) cle=${2:?--cle demande un fichier d identite}; shift 2 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

[ -f "$archive" ] || { echo "Introuvable : $archive" >&2; exit 2; }

readonly PORT=${PGPORT_JELVO_SAUVEGARDE:-55433}
readonly ATELIER=$(mktemp -d)
readonly CLUSTER="$ATELIER/cluster"
trap 'pg_ctl -D "$CLUSTER" stop -m immediate >/dev/null 2>&1 || true
      rm -rf "$ATELIER"' EXIT

echec=0
signaler() { printf 'ÉCHEC  %s\n' "$1" >&2; echec=1; }
constater() { printf 'OK     %s\n' "$1"; }

# ---------------------------------------------------------------------------
# Déchiffrer, s'il y a lieu
# ---------------------------------------------------------------------------
tar_clair="$archive"
case "$archive" in
  *.age)
    [ -n "$cle" ] || {
      echo "Cette sauvegarde est chiffrée : donnez la clé privée par --cle." >&2
      echo "Elle n'est ni dans le dépôt ni dans les secrets GitHub, par" >&2
      echo "construction — voir RESTAURER.md." >&2
      exit 2
    }
    tar_clair="$ATELIER/clair.tar"
    age --decrypt --identity "$cle" --output "$tar_clair" "$archive"
    constater "déchiffrement"
    ;;
esac

tar -C "$ATELIER" -xf "$tar_clair"
readonly CONTENU="$ATELIER/jelvo"
[ -f "$CONTENU/base.dump" ] || { echo "Archive sans base.dump." >&2; exit 2; }

# ---------------------------------------------------------------------------
# Les empreintes, avant tout le reste
# ---------------------------------------------------------------------------
#
# C'est ce qui distingue « la sauvegarde est mauvaise » de « le téléchargement
# s'est interrompu ». Sans ce contrôle, un fichier tronqué ferait échouer
# `pg_restore` avec un message sur le SQL, et on chercherait le défaut du
# mauvais côté — exactement le travers que ce projet paie cher.
if (cd "$CONTENU" && sha256sum --quiet -c EMPREINTES.txt); then
  constater "empreintes ($(wc -l < "$CONTENU/EMPREINTES.txt") fichiers)"
else
  signaler "empreintes : l'archive est abîmée ou tronquée"
  exit 1
fi

majeure=$(awk -F'\t' '$1=="serveur_majeure"{print $2}' "$CONTENU/MANIFESTE.txt")
echo "       dump pris le $(awk -F'\t' '$1=="date_utc"{print $2}' "$CONTENU/MANIFESTE.txt")" \
     "sur un serveur majeure ${majeure}"

# ---------------------------------------------------------------------------
# Un cluster de la bonne version majeure
# ---------------------------------------------------------------------------
#
# `pg_restore` d'une version antérieure refuserait l'archive. Le chemin est
# construit depuis le manifeste plutôt que pris dans le PATH : avec plusieurs
# versions installées, `/usr/lib/postgresql/*/bin` ajouté au PATH fait gagner
# **la plus ancienne**, l'ordre du glob étant croissant et le PATH lu de
# gauche à droite. Le défaut serait silencieux jusqu'au premier dump d'une
# majeure plus récente.
readonly BIN="/usr/lib/postgresql/$majeure/bin"
if [ ! -x "$BIN/initdb" ]; then
  echo "::error title=PostgreSQL $majeure absent::La sauvegarde vient d'un serveur majeure $majeure et aucun cluster de cette version n'est installable ici. Installez postgresql-$majeure depuis le dépôt PGDG." >&2
  exit 1
fi
PATH="$BIN:$PATH"

initdb -D "$CLUSTER" -U postgres --auth=trust >/dev/null
pg_ctl -D "$CLUSTER" -l "$CLUSTER/journal" \
  -o "-k $ATELIER -p $PORT -c listen_addresses=" start >/dev/null

psql="psql -h $ATELIER -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
$psql -c 'create database jelvo_restauree' >/dev/null
psql="$psql -d jelvo_restauree"

# Le dump porte son propre `create schema public`, et `initdb` en pose un.
# Sans ce retrait, `pg_restore` sort en 1 à **chaque** passage sur cette seule
# collision — et un code d'échec permanent ne se lit plus, exactement comme un
# contrôle rouge en permanence.
$psql -c 'drop schema if exists public cascade' >/dev/null

# ---------------------------------------------------------------------------
# Les rôles viennent du dump, pas d'une liste
# ---------------------------------------------------------------------------
#
# La version précédente en créait trois — `anon`, `authenticated`,
# `service_role` —, relevés sur `supabase/*.sql`. **C'était la mauvaise
# source** : le dump emporte aussi les schémas `auth` et `storage`, dont les
# ACL citent les rôles que Supabase crée pour lui-même
# (`supabase_auth_admin`, `supabase_storage_admin`…), et qu'un cluster nu ne
# connaît pas.
#
# Le défaut ne s'arrêtait pas à ces rôles-là, et c'est ce qui le rendait
# coûteux : **`pg_dump` émet un lot d'ACL par objet**, si bien qu'un seul
# rôle inconnu fait échouer tout le lot et emporte avec lui les `grant` à
# `anon` et `authenticated` qui s'y trouvaient. Mesuré en production le
# 23 novembre 2026 : 31 lignes de privilèges manquantes sur
# `storage.objects` et `storage.buckets`, et l'épreuve déclarait la
# sauvegarde en échec alors que le dump, lui, était complet et intact.
#
# C'est la méthode de la requête A0 appliquée à une restauration : partir de
# ce que la donnée demande, et non de la liste des noms auxquels on a pensé.
# Un rôle de plus côté Supabase est couvert sans qu'on y pense.
#
# `--schema-only` suffit — les ACL sont dans le schéma — et évite d'écrire
# toutes les données en clair une seconde fois sur le disque du runner.
pg_restore --file="$ATELIER/schema.sql" --schema-only "$CONTENU/base.dump"
grep -oE '(GRANT|REVOKE)[^;]*|OWNER TO [^;]*|GRANTED BY [^;]*' "$ATELIER/schema.sql" \
  | grep -oE '(TO|FROM|OWNER TO|GRANTED BY)[[:space:]]+[^;]*$' \
  | sed -E 's/^(TO|FROM|OWNER TO|GRANTED BY)[[:space:]]+//
             s/[[:space:]]+WITH[[:space:]]+GRANT[[:space:]]+OPTION//' \
  | tr ',' '\n' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//' \
  | grep -vE '^(PUBLIC)?$' \
  | grep -vE '^pg_' | sort -u > "$ATELIER/roles.txt"

# `pg_` est écarté, et ce n'est pas de la précaution : depuis PostgreSQL 15,
# le dump porte « grant … on schema public to pg_database_owner », un rôle
# **intégré** que tout cluster possède et dont le nom est réservé.
# `create role "pg_database_owner"` échoue en `reserved_name`, que le
# `duplicate_object` n'attrape pas — le script mourait là. Trouvé en
# exécutant la chaîne complète, pas en la relisant.

# Une liste vide signifie que l'extraction ne fonctionne plus — un format de
# sortie qui a bougé. Ce n'est pas fatal ici : la restauration échouera au
# premier `grant` et l'inventaire le dira. Mais il faut que le journal
# désigne *cet* endroit, sans quoi on chercherait le défaut dans le dump.
if [ ! -s "$ATELIER/roles.txt" ]; then
  echo "AVERT  aucun rôle relevé dans le dump : l'extraction ne reconnaît plus la sortie de pg_restore" >&2
fi

releves=0
while IFS= read -r role; do
  # Un nom hors de cette forme n'est pas créé, et le dire vaut mieux que de
  # bâtir une instruction à partir d'une chaîne qu'on n'a pas comprise. La
  # restauration échouera dessus, en le nommant.
  case "$role" in
    [A-Za-z_]*) : ;;
    *) echo "AVERT  rôle ignoré, forme inattendue : $role" >&2; continue ;;
  esac
  case "$role" in
    *[!A-Za-z0-9_]*) echo "AVERT  rôle ignoré, forme inattendue : $role" >&2; continue ;;
  esac
  $psql -c "do \$r\$ begin create role \"$role\" nologin;
              exception when duplicate_object then null; end \$r\$;" >/dev/null
  releves=$((releves + 1))
done < "$ATELIER/roles.txt"
printf '       rôles relevés dans le dump et créés : %s\n' "$releves"

# ---------------------------------------------------------------------------
# La restauration
# ---------------------------------------------------------------------------
#
# `pg_restore` sort en échec sur des erreurs qu'une vraie restauration
# Supabase n'aurait pas — des extensions absentes du cluster nu, par exemple.
# Son journal est donc gardé et résumé, et c'est **l'inventaire** qui tranche,
# pas le code de sortie : le seul verdict qui compte est « les données et les
# règles sont-elles là ».
#
# Le code de sortie n'est pas ignoré pour autant : il est relevé et affiché.
# Un filtre n'est pas un verdict, mais un verdict sans le code de sortie non
# plus.
set +e
# `--no-privileges` est **volontairement absent** : c'est un drapeau, et le
# poser effacerait les `grant` et les `revoke` qui sont toute la sécurité.
pg_restore --dbname=jelvo_restauree --no-owner \
  --host="$ATELIER" --port="$PORT" --username=postgres \
  "$CONTENU/base.dump" > "$ATELIER/restore.journal" 2>&1
code_restore=$?
set -e

avertissements=$(grep -c '^pg_restore: error' "$ATELIER/restore.journal" || true)
printf '       pg_restore : code %s, %s ligne(s) d erreur\n' \
  "$code_restore" "$avertissements"
[ "$avertissements" -gt 0 ] && head -5 "$ATELIER/restore.journal" | sed 's/^/       | /'

# ---------------------------------------------------------------------------
# Le verdict : un diff, pas des nombres écrits à la main
# ---------------------------------------------------------------------------
$psql -At -f "$SAUVEGARDE/inventaire.sql" | sort > "$ATELIER/apres.txt"
sort "$CONTENU/inventaire.txt" > "$ATELIER/avant.txt"

grep '^jelvo	' "$ATELIER/avant.txt" > "$ATELIER/avant.jelvo" || true
grep '^jelvo	' "$ATELIER/apres.txt" > "$ATELIER/apres.jelvo" || true

if diff -u "$ATELIER/avant.jelvo" "$ATELIER/apres.jelvo" > "$ATELIER/diff.jelvo"; then
  constater "inventaire : $(wc -l < "$ATELIER/avant.jelvo") lignes identiques"
else
  signaler "inventaire : la base restaurée ne rend pas ce que le dump a emporté"
  echo "--- ce qui diffère (avant / après) ---" >&2
  sed -n '3,60p' "$ATELIER/diff.jelvo" >&2
fi

# Les objets internes à Supabase sont relevés, jamais fatals — un cluster nu
# n'a ni les extensions ni les rôles de leur plateforme. Les taire aurait été
# pire : c'est en les lisant qu'on verra un jour qu'`auth` a changé de forme.
internes=$(diff <(grep '^interne	' "$ATELIER/avant.txt" || true) \
                <(grep '^interne	' "$ATELIER/apres.txt" || true) | grep -c '^[<>]' || true)
printf '       objets internes à Supabase : %s écart(s), non fatals\n' "$internes"

# ---------------------------------------------------------------------------
# Les fichiers des buckets
# ---------------------------------------------------------------------------
#
# Ils ne se « restaurent » pas dans un cluster : ce sont des octets à
# re-téléverser. Ce qui est éprouvé ici, c'est qu'ils sont **présents et
# intacts** — les empreintes l'ont déjà dit —, et que leur nombre est celui
# que la base annonçait.
attendus=$(awk -F'\t' '$1=="fichiers_attendus"{print $2}' "$CONTENU/MANIFESTE.txt")
presents=$(find "$CONTENU/fichiers" -type f | wc -l)
if [ "$presents" -eq "${attendus:-0}" ]; then
  constater "fichiers des buckets : $presents, intacts"
else
  signaler "fichiers des buckets : $presents présents pour $attendus annoncés"
fi

if [ "$echec" -eq 0 ]; then
  echo
  echo "La sauvegarde est restaurable. Données, privilèges, politiques,"
  echo "déclencheurs et valeurs d'énumération sont ceux du dump."
fi
exit "$echec"
