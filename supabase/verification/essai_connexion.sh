#!/usr/bin/env bash
#
# Éprouve `connexion.sh` sans base de données.
#
#     supabase/verification/essai_connexion.sh
#
# Le nettoyage de la chaîne de connexion est du code qui ne s'exécute qu'en
# CI, une fois par livraison, et dont l'échec se lit mal — c'est exactement le
# genre de code qu'on n'éprouve jamais et qui casse au pire moment. Ces cas
# tiennent en quelques secondes et n'ont besoin de rien.

set -uo pipefail

readonly VERIFICATION=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=connexion.sh
. "$VERIFICATION/connexion.sh"

reussites=0
echecs=0

# Attendu : nom du cas, code de retour espéré, sortie espérée, valeur d'entrée.
verifier() {
  local nom=$1 code_attendu=$2 sortie_attendue=$3 entree=$4
  local sortie code
  sortie=$(normaliser_url_connexion "$entree" 2>/dev/null)
  code=$?

  if [ "$code" = "$code_attendu" ] && [ "$sortie" = "$sortie_attendue" ]; then
    printf 'OK    %s\n' "$nom"
    reussites=$((reussites + 1))
  else
    printf 'ÉCHEC %s\n      attendu code=%s sortie=%q\n      obtenu  code=%s sortie=%q\n' \
      "$nom" "$code_attendu" "$sortie_attendue" "$code" "$sortie"
    echecs=$((echecs + 1))
  fi
}

readonly BONNE='postgresql://postgres.abc:motdepasse@aws-0-eu-west-3.pooler.supabase.com:6543/postgres'

verifier 'chaîne déjà propre'            0 "$BONNE" "$BONNE"
# Le cas réel : collage depuis un iPhone. Sans épuration, libpq lisait la base
# « postgres\n » et répondait qu'elle n'existait pas.
verifier 'saut de ligne final'           0 "$BONNE" "$BONNE
"
verifier 'saut de ligne initial et final' 0 "$BONNE" "
$BONNE
"
verifier 'retour chariot Windows'        0 "$BONNE" "$BONNE"$'\r'
verifier 'espaces et tabulation'         0 "$BONNE" "  	$BONNE	  "
verifier 'synonyme postgres://'          0 'postgres://u:p@h:5432/d' 'postgres://u:p@h:5432/d'

verifier 'valeur vide'                   2 '' ''
verifier 'blancs seulement'              2 '' '
 '
verifier 'schéma inattendu'              2 '' 'https://exemple.test/base'
verifier 'mot de passe collé seul'       2 '' 'MonMotDePasse123'

# Le masquage doit retirer le mot de passe, et lui seul.
masquee=$(masquer_mot_de_passe "$BONNE")
if [ "$masquee" = 'postgresql://postgres.abc:***@aws-0-eu-west-3.pooler.supabase.com:6543/postgres' ]; then
  printf 'OK    masquage du mot de passe\n'
  reussites=$((reussites + 1))
else
  printf 'ÉCHEC masquage du mot de passe : %s\n' "$masquee"
  echecs=$((echecs + 1))
fi

# Un mot de passe ne doit jamais atteindre les journaux, même quand la chaîne
# est refusée. On vérifie qu'aucun message ne le contient.
messages=$(normaliser_url_connexion 'MonMotDePasse123' 2>&1 >/dev/null)
if printf '%s' "$messages" | grep -q 'MonMotDePasse123'; then
  printf 'ÉCHEC la valeur refusée fuite dans les messages\n'
  echecs=$((echecs + 1))
else
  printf 'OK    une valeur refusée ne fuite pas\n'
  reussites=$((reussites + 1))
fi

printf '\n%d réussite(s), %d échec(s)\n' "$reussites" "$echecs"
[ "$echecs" -eq 0 ]
