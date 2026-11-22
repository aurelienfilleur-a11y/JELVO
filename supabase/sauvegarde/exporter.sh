#!/usr/bin/env bash
#
# Fabrique une sauvegarde complète de la base Jelvo : le dump SQL, les fichiers
# des buckets, et l'inventaire qui servira à juger la restauration.
#
#     supabase/sauvegarde/exporter.sh --sortie /tmp/jelvo.tar
#     supabase/sauvegarde/exporter.sh --sortie /tmp/jelvo.tar --sans-fichiers
#
# Lit `SUPABASE_DB_URL`, et — sauf `--sans-fichiers` — `SUPABASE_URL` et
# `SUPABASE_SERVICE_ROLE_KEY`.
#
#
# IL PRODUIT UN TAR EN CLAIR, ET C'EST VOULU
#
# Le chiffrement est une étape **séparée**, posée par le workflow juste après.
# La raison est la seule qui compte : l'épreuve de restauration doit pouvoir
# lire ce qu'on vient d'écrire, et le workflow ne détient **que** la clé
# publique. Chiffrer ici obligerait soit à mettre la clé privée dans les
# secrets GitHub — ce qui détruirait toute la propriété qu'on cherche —, soit
# à renoncer à éprouver la restauration.
#
# L'ordre du workflow est donc : exporter, éprouver, chiffrer, téléverser. Le
# fichier en clair ne quitte jamais le runner, qui est détruit à la fin du job.
#
#
# DEUX MOITIÉS, ET LA SECONDE N'EST PAS DANS LA BASE
#
# `storage.objects` ne porte que les **chemins** des fichiers ; les octets
# vivent ailleurs. Un dump SQL seul perdrait tous les avatars, toutes les
# photos de couverture et tous les messages vocaux, en ayant l'air d'une
# sauvegarde complète. C'est la demi-vérité la plus coûteuse de l'exercice.

set -euo pipefail

readonly SAUVEGARDE=$(cd "$(dirname "$0")" && pwd)
readonly VERIFICATION=$(dirname "$SAUVEGARDE")/verification

# Le nettoyage de la chaîne de connexion vit dans `verification/connexion.sh`,
# sourcé par `appliquer.sh` et par le workflow des migrations. Une seconde
# implémentation aurait fini par diverger — et c'est écrit en toutes lettres
# dans son en-tête.
# shellcheck source=../verification/connexion.sh
. "$VERIFICATION/connexion.sh"

# Encode un chemin d'objet pour une URL, **segment par segment** : les `/`
# doivent rester des séparateurs de chemin, tout le reste être échappé.
#
# Les noms d'objets de Jelvo sont aujourd'hui sûrs — `<groupe>/<uuid>.<ext>` et
# `<utilisateur>/avatar_<horodatage>.jpg` —, mais `storage.objects.name` est
# écrit par le client : rien n'empêche un nom avec une espace ou un accent
# d'arriver un jour. Un chemin non encodé donnerait alors un 404, et sans
# `--fail` on aurait écrit la page d'erreur dans le fichier.
encoder_chemin() {
  local reste=$1 segment sortie=''
  while [ -n "$reste" ]; do
    segment=${reste%%/*}
    sortie="$sortie/$(printf '%s' "$segment" | jq -sRr @uri)"
    [ "$segment" = "$reste" ] && break
    reste=${reste#*/}
  done
  printf '%s' "${sortie#/}"
}

sortie=''
avec_fichiers=1

while [ $# -gt 0 ]; do
  case $1 in
    --sortie)          sortie=${2:?--sortie demande un chemin}; shift 2 ;;
    --sans-fichiers)   avec_fichiers=0; shift ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

[ -n "$sortie" ] || { echo "--sortie est obligatoire." >&2; exit 2; }

url=$(normaliser_url_connexion "${SUPABASE_DB_URL-}") || exit $?

readonly ATELIER=$(mktemp -d)
trap 'rm -rf "$ATELIER"' EXIT
mkdir -p "$ATELIER/jelvo/fichiers"

# ---------------------------------------------------------------------------
# Le client doit être au moins aussi récent que le serveur
# ---------------------------------------------------------------------------
#
# `pg_dump` **refuse** de tourner contre un serveur plus récent que lui, et
# c'est la raison documentée pour laquelle l'instantané du schéma passe par
# une introspection du catalogue plutôt que par `pg_dump`.
#
# Le piège ici est plus sournois : l'image d'un runner GitHub n'embarque pas
# forcément la même version majeure que le projet Supabase, et elle peut
# changer sous nos pieds à une mise à jour d'image. Le contrôle est donc fait
# **à chaque passage**, contre la version réelle du serveur, et non une fois
# pour toutes en lisant la documentation.
majeure_serveur=$(psql "$url" -At -c 'show server_version_num' | cut -c1-2)
echo "Serveur PostgreSQL : majeure ${majeure_serveur}."

pg_dump_binaire=''
for candidat in "/usr/lib/postgresql/$majeure_serveur/bin/pg_dump" \
                "$(command -v pg_dump || true)"; do
  [ -n "$candidat" ] && [ -x "$candidat" ] || continue
  majeure_client=$("$candidat" --version | grep -oE '[0-9]+' | head -1)
  if [ "$majeure_client" -ge "$majeure_serveur" ]; then
    pg_dump_binaire=$candidat
    break
  fi
done

if [ -z "$pg_dump_binaire" ]; then
  echo "::error title=pg_dump trop ancien::Le serveur est en majeure ${majeure_serveur} et aucun pg_dump d'au moins cette version n'a été trouvé. pg_dump refuse de dumper un serveur plus récent que lui, et un dump partiel serait pire qu'aucun dump. Installez postgresql-client-${majeure_serveur} depuis le dépôt PGDG." >&2
  exit 1
fi
echo "Client : $("$pg_dump_binaire" --version)."

# ---------------------------------------------------------------------------
# Le dump
# ---------------------------------------------------------------------------
#
# Trois choix, et aucun n'est un défaut d'outil :
#
#   --format=custom   permet `pg_restore --list`, la restauration sélective et
#                     la restauration parallèle. Un `.sql` à plat ne permet
#                     aucun des trois, et ne se lit qu'en entier.
#
#   --no-owner        retire les `alter … owner to supabase_admin`. Ces rôles
#                     n'existent pas dans un cluster nu, et la restauration y
#                     échouerait à chaque ligne — donc l'épreuve nocturne ne
#                     prouverait rien. Sur un vrai projet Supabase, la
#                     propriété revient à qui restaure, ce qui est correct.
#
#   les privilèges    sont **gardés**. `--no-privileges` aurait rendu le dump
#                     plus portable et aurait silencieusement effacé tout le
#                     durcissement de la tranche 7 : 112 `grant` à
#                     `authenticated`, et les `revoke` qui ferment
#                     `signalements`. Une base restaurée grande ouverte, sans
#                     qu'aucune donnée ne manque.
#
# Les trois schémas, et pas seulement `public` : `auth` porte les comptes —
# sans lui, personne ne retrouve le sien — et `storage` l'index des fichiers.
"$pg_dump_binaire" "$url" \
  --format=custom \
  --compress=9 \
  --no-owner \
  --schema=public \
  --schema=auth \
  --schema=storage \
  --file="$ATELIER/jelvo/base.dump"

echo "Dump : $(du -h "$ATELIER/jelvo/base.dump" | cut -f1)."

# ---------------------------------------------------------------------------
# L'inventaire, relevé **avant** toute autre chose
# ---------------------------------------------------------------------------
#
# C'est lui que l'épreuve de restauration confrontera, ligne à ligne, à ce que
# rend la base restaurée. Le relever ici et non plus tard n'est pas un détail :
# la base continue de vivre pendant l'export, et un inventaire pris après
# coup décrirait un autre état que celui du dump.
#
# Conséquence assumée : un message envoyé pendant les quelques secondes de
# l'export peut faire diverger d'une ligne. `pg_dump` prend un instantané
# cohérent, donc le dump est juste ; c'est l'inventaire qui serait en avance.
# Il est donc pris au plus près, et le workflow ne tourne qu'une fois par nuit.
# `ON_ERROR_STOP=1` n'est pas du zèle, et son absence a été un vrai défaut :
# sans lui, une erreur au milieu d'`inventaire.sql` fait sauter une section et
# `psql` sort tout de même en 0. L'inventaire était alors **silencieusement
# incomplet des deux côtés**, si bien que le diff tombait juste — un contrôle
# qui passe parce qu'il ne contrôle plus rien.
psql "$url" -At -v ON_ERROR_STOP=1 -f "$SAUVEGARDE/inventaire.sql" \
  | sort > "$ATELIER/jelvo/inventaire.txt"
echo "Inventaire : $(wc -l < "$ATELIER/jelvo/inventaire.txt") lignes relevées."

# ---------------------------------------------------------------------------
# Les fichiers des buckets
# ---------------------------------------------------------------------------
fichiers_attendus=0
fichiers_obtenus=0

if [ "$avec_fichiers" -eq 1 ]; then
  : "${SUPABASE_URL:?SUPABASE_URL est nécessaire pour les fichiers}"
  : "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY est nécessaire pour les fichiers}"

  # La liste vient de la **base**, pas de l'API Storage : la connexion
  # PostgreSQL est déjà là, et `storage.objects` est la source unique des
  # chemins. Lister par l'API demanderait une requête par dossier et une
  # pagination, pour la même réponse.
  # `ON_ERROR_STOP=1` ici aussi, et pour un défaut plus retors que celui de
  # l'inventaire : une requête en échec laisserait un fichier **vide**,
  # `fichiers_attendus` vaudrait 0, et le contrôle final comparerait 0 à 0 —
  # il passerait. On aurait une sauvegarde sans aucun fichier, déclarée
  # complète.
  psql "$url" -At -v ON_ERROR_STOP=1 -F$'\t' \
    -c "select bucket_id, name from storage.objects
         where name is not null order by bucket_id, name" \
    > "$ATELIER/liste.txt"

  fichiers_attendus=$(wc -l < "$ATELIER/liste.txt")
  echo "Fichiers à récupérer : $fichiers_attendus."

  while IFS=$'\t' read -r bucket chemin; do
    [ -n "$bucket" ] || continue
    cible="$ATELIER/jelvo/fichiers/$bucket/$chemin"
    mkdir -p "$(dirname "$cible")"

    # `--fail` est ce qui fait la différence entre une sauvegarde et un dossier
    # de pages d'erreur : sans lui, curl écrit le corps d'un 404 dans le
    # fichier et sort en 0. On aurait un bucket de fichiers de la bonne taille
    # apparente et du mauvais contenu.
    if curl -fsS --max-time 120 --retry 3 --retry-delay 2 \
         -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
         -o "$cible" \
         "$SUPABASE_URL/storage/v1/object/$bucket/$(encoder_chemin "$chemin")"; then
      fichiers_obtenus=$((fichiers_obtenus + 1))
    else
      echo "::error title=Fichier non récupéré::$bucket/$chemin" >&2
      rm -f "$cible"
    fi
  done < "$ATELIER/liste.txt"

  # Le contrôle qui compte : ce qui a été écrit, confronté à ce que la base
  # annonçait. Un écart fait **échouer l'export** plutôt que de produire une
  # sauvegarde incomplète qui en aurait l'air.
  if [ "$fichiers_obtenus" -ne "$fichiers_attendus" ]; then
    echo "::error title=Sauvegarde incomplète::$fichiers_obtenus fichiers récupérés sur $fichiers_attendus annoncés par storage.objects. Une sauvegarde partielle qui se présente comme complète est pire qu'un échec franc." >&2
    exit 1
  fi
  echo "Fichiers : $fichiers_obtenus récupérés, $(du -sh "$ATELIER/jelvo/fichiers" | cut -f1)."
else
  echo "Fichiers des buckets : écartés (--sans-fichiers)."
fi

# ---------------------------------------------------------------------------
# Le manifeste
# ---------------------------------------------------------------------------
#
# Il permet de juger une sauvegarde **sans la restaurer** : sa date, la version
# du serveur — donc quel `pg_restore` il faudra —, et l'empreinte de chaque
# pièce. C'est aussi ce qui dit, dans six mois, si le fichier qu'on tient est
# complet ou tronqué par un téléversement interrompu.
{
  echo "sauvegarde_jelvo	1"
  echo "date_utc	$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "serveur_version	$(psql "$url" -At -c 'select version()')"
  echo "serveur_majeure	$majeure_serveur"
  echo "pg_dump	$("$pg_dump_binaire" --version)"
  echo "fichiers_attendus	$fichiers_attendus"
  echo "fichiers_obtenus	$fichiers_obtenus"
  echo "commit	${GITHUB_SHA:-local}"
} > "$ATELIER/jelvo/MANIFESTE.txt"

(cd "$ATELIER/jelvo" && find . -type f ! -name EMPREINTES.txt -print0 \
  | sort -z | xargs -0 sha256sum) > "$ATELIER/jelvo/EMPREINTES.txt"

tar -C "$ATELIER" -cf "$sortie" jelvo
echo "Sauvegarde : $sortie ($(du -h "$sortie" | cut -f1))."
