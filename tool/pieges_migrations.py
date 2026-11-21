#!/usr/bin/env python3
"""Quels fichiers de `supabase/migrations.txt` ne sont plus rejouables.

**À lancer avant de modifier un fichier de migration.**

Un fichier est rejoué dès que son empreinte change — c'est ce qui permet de
corriger une migration sur place. Mais certains fichiers ne *peuvent plus*
l'être : si une tranche ultérieure a redéfini une de leurs fonctions avec une
signature différente, précédée d'un `drop function`, alors le `create or
replace` du fichier antérieur tente de revenir en arrière, et PostgreSQL
refuse net :

    ERROR:  cannot change return type of existing function
    HINT:  Use DROP FUNCTION apercu_groupe_par_jeton(text) first.

Chaque fichier étant appliqué dans sa propre transaction, celui-là reste
intact — mais **tout ce qui le suit dans le manifeste n'est jamais appliqué**.
Le cas s'est produit le 21 novembre 2026 : un filtre d'une ligne ajouté à la
tranche 2 a empêché la tranche 14 d'atteindre la base, et l'application s'est
retrouvée avec un bouton de suppression de compte que la base ne servait pas.

Pour changer une fonction d'un fichier gelé, la redéfinir dans un fichier
**postérieur** : le propriétaire d'une fonction est le dernier fichier qui la
crée, pas le premier.

On part du code et non d'une liste de fichiers auxquels on a pensé : c'est la
méthode de la requête A0, appliquée au manifeste.
"""

from __future__ import annotations

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent / "supabase"

CREATE = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)\s*\(",
    re.IGNORECASE,
)
DROP = re.compile(
    r"drop\s+function\s+if\s+exists\s+(?:public\.)?(\w+)\s*\(", re.IGNORECASE
)


def main() -> int:
    manifeste = RACINE / "migrations.txt"
    ordre = [
        ligne.strip()
        for ligne in manifeste.read_text(encoding="utf-8").splitlines()
        if ligne.strip() and not ligne.lstrip().startswith("#")
    ]

    # nom de fonction → [(fichier, le fichier porte-t-il son `drop` ?)]
    definit: dict[str, list[tuple[str, bool]]] = {}
    for fichier in ordre:
        chemin = RACINE / fichier
        if not chemin.exists():
            print(f"!! {fichier} est dans le manifeste et n'existe pas")
            return 2
        source = chemin.read_text(encoding="utf-8")
        drops = {m.group(1).lower() for m in DROP.finditer(source)}
        for m in CREATE.finditer(source):
            nom = m.group(1).lower()
            definit.setdefault(nom, []).append((fichier, nom in drops))

    # Un fichier est gelé par une fonction dont un définisseur **postérieur**
    # porte un `drop` — signe que la signature a changé — alors que lui n'en a
    # pas. Sans `drop` nulle part, seul le corps a changé : c'est rejouable, et
    # le signaler serait du bruit.
    geles: dict[str, list[str]] = {}
    for nom, sites in definit.items():
        if len(sites) < 2:
            continue
        drop_plus_tard = [
            indice for indice, (_, a_drop) in enumerate(sites) if a_drop
        ]
        if not drop_plus_tard:
            continue
        dernier_drop = max(drop_plus_tard)
        for fichier, a_drop in sites[:dernier_drop]:
            if not a_drop:
                geles.setdefault(fichier, []).append(nom)

    if not geles:
        print("Migrations : aucun fichier gelé, tous rejouables.")
        return 0

    print("Fichiers **gelés** — les modifier casse la livraison :\n")
    for fichier in ordre:
        if fichier not in geles:
            continue
        fonctions = ", ".join(sorted(set(geles[fichier])))
        print(f"  {fichier}")
        print(f"      reprise(s) plus tard avec une autre signature : {fonctions}")
    print(
        "\nPour changer une de ces fonctions, la redéfinir dans un fichier "
        "postérieur.\nLe propriétaire d'une fonction est le **dernier** "
        "fichier qui la crée."
    )
    # Code de sortie 0 : c'est un relevé, pas un verdict. Ces fichiers sont
    # gelés par construction, et le rester est l'état normal — faire échouer
    # la CI là-dessus la rendrait rouge en permanence.
    return 0


if __name__ == "__main__":
    sys.exit(main())
