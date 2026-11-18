#!/usr/bin/env bash
#
# Rejoue localement les quatre commandes de `deploy-web.yml`, dans le même
# ordre et avec les mêmes options, et **lit le vrai code de sortie de chacune**.
#
# C'est tout l'objet du script. Le piège a été payé deux fois :
#
#   dart format … | tail -3      → le code de sortie est celui de `tail`
#   flutter analyze | grep -cE … → celui de `grep`, et le motif ne collait pas
#
# Les deux fois, la commande avait échoué, le filtre avait répondu « rien à
# signaler », et la CI a démenti trente secondes plus tard. Un filtre n'est pas
# un verdict : seul `$?` en est un, et il doit être relevé **avant** le tube.
#
# Deux pièges de plus, qui ne se devinent pas :
#
#   - `flutter analyze` sort en échec sur un **avertissement**, pas seulement
#     sur une erreur. Un import mort suffit à mettre l'étape au rouge ;
#   - sans option, il n'écrit pas ses lignes en retrait. Un motif qui attend
#     une indentation (`^ +warning`) ne trouve jamais rien, quelle que soit la
#     gravité — c'est exactement ce qui a laissé passer la PR #66.
#
# Usage : tool/verifier.sh [--sans-build]
#
# `--sans-build` s'arrête après les tests. La compilation web est la plus
# longue des quatre et ne dépend d'aucune des trois autres : la sauter pendant
# qu'on corrige, puis la lancer une fois à la fin, est un compromis utile — et
# le résumé dit alors explicitement qu'elle n'a pas été tentée, plutôt que de
# laisser croire à quatre feux verts.
set -u -o pipefail

racine="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$racine"

sans_build=0
[[ "${1:-}" == "--sans-build" ]] && sans_build=1

# Le nom tel qu'il apparaît dans le workflow, pour que le rapprochement entre
# l'échec local et l'étape rouge de la CI soit immédiat.
etapes=()
codes=()

lancer() {
  local nom="$1"
  shift
  printf '\n\033[1m── %s\033[0m\n' "$nom"
  # Pas de tube, pas de redirection : la sortie va à l'écran telle quelle et
  # `$?` est bien celui de la commande.
  "$@"
  local code=$?
  etapes+=("$nom")
  codes+=("$code")
  return $code
}

lancer 'Installer les dépendances' flutter pub get
lancer 'Vérifier le formatage' dart format --output=none --set-exit-if-changed .
lancer 'Analyser le code' flutter analyze
lancer 'Lancer les tests' flutter test

if ((sans_build)); then
  etapes+=('Compiler la version web')
  codes+=(-1)
else
  # **Sans aucun `--dart-define`**, à la différence du workflow. Ce que cette
  # étape éprouve, c'est que le code compile pour le web ; les valeurs de
  # configuration n'y changent rien, `AppConfig` ayant des défauts. Les
  # recopier ici en ferait une seconde source à tenir d'accord avec le
  # workflow — et c'est toujours la copie oubliée qui ment.
  lancer 'Compiler la version web' \
    flutter build web --release --base-href /JELVO/
fi

printf '\n\033[1m── Résumé\033[0m\n'
echec=0
for i in "${!etapes[@]}"; do
  code="${codes[$i]}"
  if [[ "$code" == "-1" ]]; then
    printf '  \033[33m—\033[0m  %s (non tentée)\n' "${etapes[$i]}"
  elif [[ "$code" == "0" ]]; then
    printf '  \033[32m✓\033[0m  %s\n' "${etapes[$i]}"
  else
    printf '  \033[31m✗\033[0m  %s — code %s\n' "${etapes[$i]}" "$code"
    echec=1
  fi
done

if ((echec)); then
  printf '\n\033[31mLa CI refusera cette version.\033[0m\n'
  exit 1
fi
if ((sans_build)); then
  printf '\n\033[33mLa compilation web n'"'"'a pas été tentée.\033[0m\n'
  exit 0
fi
printf '\n\033[32mLes quatre commandes passent.\033[0m\n'
