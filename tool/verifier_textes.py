#!/usr/bin/env python3
"""Interdit les textes affichés écrits en dur dans `lib/`.

POURQUOI UN SCRIPT ET PAS UNE RÈGLE D'ANALYSE

`flutter analyze` ne sait pas voir ceci : il n'existe aucun lint standard
« cette chaîne finit à l'écran ». Les paquets qui le proposent
(`flutter_lints` n'en a pas, `intl_lint` n'existe pas) demanderaient une
dépendance d'analyse et une configuration propre. Un script de cent lignes
qui tourne dans la même chaîne fait le travail, et surtout **il dit pourquoi**
dans son message d'erreur.

CE QU'IL CHERCHE, ET POURQUOI C'EST DÉFINI AINSI

Non pas « une chaîne qui ressemble à du français » — ce critère-là attrape les
noms de colonnes SQL (`anniversaire_jour`), les clés de stockage
(`jelvo-apparence`) et les mots du contrat d'apparence (`clair`, `sombre`,
`systeme`), qui n'ont rien à voir avec l'affichage.

Il cherche **une chaîne en position d'être affichée** : argument d'un `Text`,
d'un `EmojiText`, ou valeur d'un paramètre dont le nom dit qu'il porte du
texte visible (`label`, `title`, `message`, `tooltip`, `hint`, `libelle`,
`titre`, `aide`…). C'est une définition par la *position*, pas par le
contenu — un identifiant placé là serait un défaut de toute façon.

S'y ajoute un second filet, par le contenu cette fois : toute chaîne
**accentuée et porteuse d'un espace** est une phrase française, où qu'elle
soit. C'est ce qui attrape les libellés rendus par un modèle ou un provider,
loin de tout widget — exactement les cas que la position ne voit pas.

L'ÉCHAPPATOIRE EST EXPLICITE, ET SE JUSTIFIE SUR LA LIGNE

Une ligne portant `// texte-en-dur-autorise: <raison>` est ignorée. Il en
reste une poignée, toutes documentées dans CLAUDE.md sous « Ce qui reste en
dur, et pourquoi ». Le marqueur demande une raison écrite : c'est ce qui
distingue une exception d'un oubli.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
LIB = RACINE / 'lib'

MARQUEUR = 'texte-en-dur-autorise'

# Paramètres dont le nom dit que la valeur s'affiche. Ajouter un paramètre de
# ce genre sans l'inscrire ici ouvrirait un trou silencieux, d'où la liste la
# plus large qui reste juste.
PARAMETRES = (
    'label|title|titre|libelle|message|texte|text|tooltip|hint|aide|helper|'
    'error|erreur|placeholder|semanticsLabel|confirmLabel|actionLabel|'
    'description|sousTitre|subtitle|valeur|value|boutonTexte|emptyTitle|'
    'emptyMessage'
)

# Une chaîne précédée de ceci s'affiche.
POSITIONS = re.compile(
    r'(?:\b(?:Text|EmojiText|SelectableText)\s*(?:\.rich\s*)?\(\s*'
    r'|\b(?:' + PARAMETRES + r')\s*:\s*)$',
)

# Contextes où une chaîne qui en a l'air n'est pourtant pas du texte affiché.
HORS_SUJET = re.compile(
    r'(?:DateFormat|NumberFormat|RegExp|fontFamily|fontFamilyFallback'
    r'|Intl\.\w+|\.rpc|\.select|\.from|\.eq|\.order|\.filter'
    r'|channel|setPath|assetPath'
    # Une chaîne **comparée** n'est pas une chaîne affichée :
    # `auth_failure` reconnaît les messages de gotrue et de PostgREST, qui
    # sont en anglais et ne doivent surtout pas être traduits.
    r'|\.contains|\.startsWith|\.endsWith|\.indexOf|==|!=)\s*\(?\s*$'
)

# Deux mots d'au moins deux lettres : c'est une phrase, pas un identifiant.
# Le critère ne peut pas être l'accent — « Connectez-vous pour rejoindre ce
# groupe. » n'en porte aucun, l'apostrophe typographique n'étant pas une
# lettre accentuée. Un tel texte serait resté en dur sans que rien ne le dise.
DEUX_MOTS = re.compile(r'[^\W\d_]{2,}[^\w]+[^\W\d_]{2,}')

ACCENTS = 'àâäéèêëîïôöùûüÿçœæÀÂÄÉÈÊËÎÏÔÖÙÛÜŸÇŒÆ'

# Formes qui ne sont jamais une phrase, quoi qu'elles contiennent.
# `$` et les accolades compris : `'assets/avatars/$id.png'` est un
# chemin, pas une phrase — et il avait bel et bien été migré une fois.
IDENTIFIANT = re.compile(r'^[\w./:+${}#&?=@~%-]*$')
GABARIT_DATE = re.compile(r"^[dMyEHhmsaz'\s:/.,-]+$")


def ouvrir(source: str, i: int) -> tuple[str, int, int]:
    """Délimite la chaîne qui commence en `i`. Rend (délimiteur, début, fin).

    **Une interpolation peut contenir des guillemets** — `'${n > 1 ? 's' : ''}'`
    est une seule chaîne, et un automate qui prend le premier `'` venu pour sa
    fin la coupe en morceaux. Les `${…}` sont donc sautés en comptant les
    accolades, et les chaînes qu'ils contiennent sautées récursivement.
    """
    n = len(source)
    c = source[i]
    triple = source.startswith(c * 3, i)
    delim = c * 3 if triple else c
    j = debut = i + len(delim)
    while j < n:
        if source[j] == '\\':
            j += 2
            continue
        if source.startswith('${', j):
            j += 2
            profondeur = 1
            while j < n and profondeur:
                if source[j] in '\'"':
                    _, _, j = ouvrir(source, j)
                    j += 1
                    continue
                if source[j] == '{':
                    profondeur += 1
                elif source[j] == '}':
                    profondeur -= 1
                j += 1
            continue
        if source.startswith(delim, j):
            break
        j += 1
    return delim, debut, j


def litteraux(source: str):
    """Rend (ligne, texte, contexte_precedent) pour chaque chaîne du fichier.

    Écrit à la main plutôt qu'avec une expression régulière unique : les
    commentaires peuvent contenir des apostrophes — le français en est
    plein — et une regex qui les ignore signale des dizaines de fausses
    pistes. L'automate ci-dessous sait, lui, qu'un `//` dans une chaîne n'ouvre
    pas un commentaire, et qu'une apostrophe dans un commentaire n'ouvre pas
    une chaîne.
    """
    i, n, ligne = 0, len(source), 1
    while i < n:
        c = source[i]
        if c == '\n':
            ligne += 1
            i += 1
        elif source.startswith('//', i):
            j = source.find('\n', i)
            i = n if j == -1 else j
        elif source.startswith('/*', i):
            j = source.find('*/', i + 2)
            fin = n if j == -1 else j + 2
            ligne += source.count('\n', i, fin)
            i = fin
        elif c in '\'"':
            delim, debut, j = ouvrir(source, i)
            texte = source[debut:j]
            avant = source[max(0, i - 80):i]
            yield ligne, texte, avant
            ligne += source.count('\n', i, j)
            i = j + len(delim)
        else:
            i += 1


def est_affiche(texte: str, avant: str) -> bool:
    nu = texte.strip()
    if len(re.findall(r'[^\W\d_]', nu)) < 2:
        return False
    # Pas une seule minuscule : c'est une constante technique — une `rrule`
    # (`FREQ=WEEKLY;INTERVAL=2`), un en-tête, un code. Aucun libellé de Jelvo
    # ne s'écrit ainsi, et celui-là avait bel et bien été migré une fois.
    if not re.search(r'[a-zàâäéèêëîïôöùûüÿçœ]', nu):
        return False
    if IDENTIFIANT.match(nu):
        return False
    if HORS_SUJET.search(avant.rstrip()):
        return False
    if GABARIT_DATE.match(nu):
        return False
    # Une interpolation seule — '$nom' — n'est pas un texte à traduire.
    if re.fullmatch(r'[\s${}\w.()\[\]!?]*', nu) and '$' in nu and ' ' not in nu:
        return False

    par_position = bool(POSITIONS.search(avant))
    phrase = bool(DEUX_MOTS.search(nu)) or (
        any(a in nu for a in ACCENTS) and ' ' in nu
    )
    return par_position or phrase


def main() -> int:
    trouves: list[tuple[str, int, str]] = []
    for fichier in sorted(LIB.rglob('*.dart')):
        if 'l10n' in fichier.parts:
            continue
        source = fichier.read_text(encoding='utf-8')
        lignes = source.splitlines()
        rel = fichier.relative_to(RACINE).as_posix()
        for ligne, texte, avant in litteraux(source):
            if not est_affiche(texte, avant):
                continue
            # Le marqueur vaut pour sa ligne et les six qui la précèdent : une
            # chaîne longue est coupée en plusieurs morceaux, et le marqueur se
            # pose **une fois**, au-dessus de l'instruction — pas sur chacun de
            # ses morceaux, ce qui noierait la raison.
            fenetre = '\n'.join(lignes[max(0, ligne - 7):ligne])
            if MARQUEUR in fenetre:
                continue
            trouves.append((rel, ligne, texte))

    if '--liste' in sys.argv:
        for rel, ligne, texte in trouves:
            print(f'{rel}:{ligne}\t{texte}')
    elif '--par-fichier' in sys.argv:
        compte: dict[str, int] = {}
        for rel, _, _ in trouves:
            compte[rel] = compte.get(rel, 0) + 1
        for rel, n in sorted(compte.items(), key=lambda kv: -kv[1]):
            print(f'{n:4d}  {rel}')

    if not trouves:
        print('Textes : aucun texte affiché écrit en dur dans lib/.')
        return 0

    print()
    print(f'{len(trouves)} texte(s) affiché(s) écrit(s) en dur dans lib/.')
    print()
    print('Tout texte affiché vient de `lib/l10n/app_fr.arb`, et se lit par')
    print('`AppTexts.of(context).<cle>`. Un modèle ou un provider ne choisit')
    print('pas ses mots : il dit ce que la chose est, le widget en tire le')
    print('libellé — même règle que pour les couleurs.')
    print()
    print(f'Exception légitime : `// {MARQUEUR}: <raison>` sur la ligne,')
    print('et la raison écrite dans CLAUDE.md.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
