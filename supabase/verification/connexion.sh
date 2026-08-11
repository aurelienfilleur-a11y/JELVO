#!/usr/bin/env bash
#
# Normalisation et contrôle de la chaîne de connexion PostgreSQL.
#
# À sourcer, jamais à exécuter :
#
#     . "$(dirname "$0")/connexion.sh"
#     url=$(normaliser_url_connexion "$SUPABASE_DB_URL") || exit $?
#
#
# POURQUOI CE FICHIER EXISTE
#
# Un secret GitHub collé depuis un téléphone emporte volontiers un saut de
# ligne final — invisible dans le champ de saisie, et impossible à voir dans
# les journaux puisque la valeur y est masquée. libpq le prend au pied de la
# lettre : le dernier segment du chemin devient le nom de la base, saut de
# ligne compris, et l'on obtient
#
#     FATAL: database "postgres\n" does not exist
#
# message qui désigne la base plutôt que le presse-papiers, et envoie chercher
# le défaut du mauvais côté. Une minute de collage a coûté un aller-retour
# complet.
#
# Le nettoyage vit ici plutôt que dans `appliquer.sh` parce que **deux**
# consommateurs en ont besoin : l'application des migrations et l'extraction du
# schéma. Une seconde implémentation aurait fini par diverger de la première.

# Retire les blancs de début et de fin — espaces, tabulations, retours chariot,
# sauts de ligne. Uniquement aux extrémités : une chaîne de connexion n'a pas
# de blanc interne légitime, mais un mot de passe, lui, pourrait en avoir un.
epurer_extremites() {
  local valeur=$1
  valeur="${valeur#"${valeur%%[![:space:]]*}"}"
  valeur="${valeur%"${valeur##*[![:space:]]}"}"
  printf '%s' "$valeur"
}

# Remplace le mot de passe par des étoiles, pour affichage.
#
# Ne sert qu'au confort de lecture : la vraie protection est le `::add-mask::`
# posé par `normaliser_url_connexion`. Le masque de GitHub porte sur la valeur
# **enregistrée** du secret ; dès qu'on en retire le saut de ligne, la chaîne
# affichée n'est plus celle-là et n'est donc plus masquée d'office.
masquer_mot_de_passe() {
  printf '%s' "$1" | sed -E 's#(://[^:/?#@]+):[^@]*@#\1:***@#'
}

# Épure, contrôle la forme, et renvoie la chaîne utilisable sur la sortie
# standard. Les messages partent sur la sortie d'erreur, pour que
# `url=$(normaliser_url_connexion …)` ne récupère que l'URL.
#
# Codes de retour : 0 correct, 2 absent ou mal formé.
normaliser_url_connexion() {
  local brute=${1-}
  local url
  url=$(epurer_extremites "$brute")

  if [ -z "$url" ]; then
    echo "Le secret SUPABASE_DB_URL est vide ou absent." >&2
    echo "Réglages du dépôt → Secrets and variables → Actions." >&2
    return 2
  fi

  # Signalé et non corrigé en silence : le secret restera fautif au prochain
  # passage, et mieux vaut que son propriétaire le sache.
  if [ "$url" != "$brute" ]; then
    echo "Avertissement : des blancs ont été retirés aux extrémités du" >&2
    echo "secret (${#brute} caractères reçus, ${#url} retenus). Un saut de" >&2
    echo "ligne final est fréquent quand on colle depuis un téléphone." >&2
    echo "La suite fonctionne, mais corriger le secret évitera la question." >&2
  fi

  # Dès maintenant : la valeur épurée diffère du secret enregistré, donc le
  # masque automatique de GitHub ne s'y applique plus.
  if [ "${GITHUB_ACTIONS:-}" = 'true' ]; then
    echo "::add-mask::$url" >&2
  fi

  # `postgres://` est le synonyme historique, accepté par libpq depuis
  # toujours et rendu par certains outils. Le refuser ferait échouer une
  # chaîne parfaitement valide.
  case "$url" in
    postgresql://* | postgres://*) ;;
    *)
      echo "La chaîne de connexion est mal formée : elle doit commencer par" >&2
      echo "« postgresql:// » (ou « postgres:// »)." >&2
      # Ce qui suit ne divulgue rien : soit le préfixe de schéma, qui n'est
      # jamais secret, soit rien du tout quand la chaîne ne ressemble pas à
      # une URL — auquel cas elle pourrait bien être le mot de passe seul.
      if [ "${url%%://*}" != "$url" ]; then
        echo "Schéma trouvé : « ${url%%://*}:// »." >&2
      else
        echo "Aucun « :// » dans la valeur reçue (${#url} caractères)." >&2
        echo "Avez-vous collé la chaîne complète, et non le seul mot de" >&2
        echo "passe ? Supabase la donne dans Project Settings → Database →" >&2
        echo "Connection string." >&2
      fi
      return 2
      ;;
  esac

  printf '%s' "$url"
}
