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
    # `name` et `nom` s'affichent **ici** : `AvatarData(name:)` en tire une
    # initiale, `PickablePerson(nom:)` une rangée de prénoms. Le nom paraît
    # trop général pour une liste de positions de texte — éprouvé plutôt que
    # supposé : il ne rapporte que de vraies fuites, « Membre », « Vous »,
    # « Personnel » et « Groupe », et aucun faux positif. Les routes et les
    # fichiers nommés passent par des constantes, jamais par un littéral.
    'emptyMessage|name|nom'
)

# Ce qui peut s'intercaler entre la position et la chaîne.
#
# **Troisième trou du détecteur, et le plus coûteux : la position devait être
# collée à la chaîne.** `EmojiText(message.senderName ?? 'Membre', …)` lui
# échappait, parce que la chaîne n'y est pas le premier jeton — et un mot d'un
# seul tenant passe aussi la règle des deux mots, celle de l'accent exigeant
# une espace. Dix-neuf chaînes françaises atteignaient l'écran dans les quatre
# langues, dont deux pluriels écrits à la main.
#
# Un relais est une suite de jetons qui **passe la main** à la chaîne : un
# repli `??`, une branche de ternaire (`? …` / `: …`), ou le corps d'une
# flèche (`=> …`).
#
# Seule la **virgule** en est exclue, et c'est le bon critère : elle veut dire
# qu'on a changé d'argument, donc que la position ne vaut plus. Les guillemets,
# eux, doivent être admis — `taches > 1 ? 'tâches' : 'tâche'` met une chaîne
# dans le relais de l'autre, et `json['titre'] ?? 'Tâche'` en met une dans un
# indice. Les exclure laissait passer la moitié de chaque ternaire, et tous les
# replis de lecture de JSON.
#
# Écarté sciemment : n'importe quel caractère, virgule comprise. C'est la leçon
# des deux premiers trous — un écartement trop large ne se voit jamais, il rend
# le vert.
RELAIS = r"(?:[^,]*?(?:\?\?|\?|:|=>)\s*)*"

# Une chaîne précédée de ceci s'affiche.
#
# La troisième forme est une **valeur par défaut** de paramètre
# (`this.createLabel = 'Créer'`), et elle a manqué au premier passage : un
# défaut n'est pas écrit avec deux-points, et `createLabel = 'Créer'` est
# resté en dur jusqu'à la traduction. `(?<![=!<>])` écarte les comparaisons,
# qu'`HORS_SUJET` couvre déjà par ailleurs.
POSITIONS = re.compile(
    r'(?:\b(?:Text|EmojiText|SelectableText)\s*(?:\.rich\s*)?\(\s*'
    r'|\b(?:' + PARAMETRES + r')\s*:\s*'
    r'|\b\w*(?i:' + PARAMETRES + r')\s*(?<![=!<>])=\s*)'
    + RELAIS + r'$',
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

# ---------------------------------------------------------------------------
# Quatrième trou : la méthode `label(AppTexts t)` qui rend du français en dur
# ---------------------------------------------------------------------------
# Les deux règles précédentes — la position, et la phrase accentuée — ne
# voient rien dans ceci :
#
#     String label(AppTexts t) => switch (this) {
#       TaskPriority.low => 'Basse',
#       …
#
# La méthode prend bien la langue, et n'en fait rien. Il n'y a aucune position
# de texte à repérer : la chaîne est le corps d'une branche de `switch`. Les
# sept jours de la semaine, les douze mois, les priorités, les statuts et les
# réponses Oui / Peut-être / Non sont tous dans ce cas — **une soixantaine de
# chaînes, dans des fichiers qu'on croyait traduits.**
#
# La règle qui les attrape est un troisième filet par le contenu : une chaîne
# **faite de mots et de ponctuation seulement**, qui porte une majuscule, un
# accent, ou plusieurs mots. Ce que cela n'attrape pas est dit juste après.
MOTS_SEULEMENT = re.compile(r"^[^\W\d_][\w\s'’\-.,;:!?…«»()]*$")
PASCAL_CASE = re.compile(r'^[A-Z][a-z]+(?:[A-Z][a-z]*)+$')
TOUT_CAPITALES = re.compile(r'^[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜŸÇŒÆ\s]{3,}$')
MAJUSCULE = re.compile(r'^[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜŸÇŒÆ]')


def ressemble_a_un_libelle(nu: str) -> bool:
    """Vrai pour « Basse », « Lundi », « février », « Peut-être ».

    **Faux pour un mot ASCII en minuscules d'un seul tenant**, et c'est
    délibéré : `admin`, `member`, `pending`, `image`, `audio` sont les valeurs
    des types énumérés de la base, et `clair`, `sombre`, `systeme` les trois
    mots du contrat d'apparence. Les unes comme les autres doivent rester en
    dur, et aucun critère de contenu ne les distingue de `mai` ou `avril`.

    La contrepartie est assumée : sur les douze noms de mois, seuls `février`,
    `août` et `décembre` sont signalés. **Trois suffisent** — ils rendent la
    CI rouge, et c'est la liste entière qu'on corrige alors. Un détecteur n'a
    pas à voir chaque occurrence, il a à rendre le défaut visible.
    """
    if len(nu) < 3 or not MOTS_SEULEMENT.match(nu):
        return False
    # `ClientException`, `PushManager`, `NotoColorEmoji` : des identifiants.
    if PASCAL_CASE.match(nu):
        return False
    # `DIAGNOSTIC` : un bandeau de développement, pas une phrase.
    if TOUT_CAPITALES.match(nu):
        return False
    return (
        bool(MAJUSCULE.match(nu))
        or any(a in nu for a in ACCENTS)
        or bool(DEUX_MOTS.search(nu))
    )

# Formes qui ne sont jamais une phrase, quoi qu'elles contiennent.
# `$` et les accolades compris : `'assets/avatars/$id.png'` est un
# chemin, pas une phrase — et il avait bel et bien été migré une fois.
#
# **Un caractère non-lettre est exigé**, et c'est ce qui a manqué au premier
# passage : `^[\w…]*$` acceptait `Accueil` et `Calendrier`, qui sont des
# libellés d'onglet, pas des identifiants. `\w` couvre les lettres accentuées
# en Python, si bien que `Créer` et `Filtres` passaient aussi — et les quatre
# onglets de la barre sont restés en dur tout un chantier de migration.
#
# Un mot de lettres seules retombe donc sur les deux règles qui suivent, où
# seule la **position** peut le signaler : `clair`, `sombre` et `systeme`
# n'apparaissent jamais en position de texte, les trois mots du contrat
# d'apparence restent donc tranquilles.
IDENTIFIANT = re.compile(r'^(?=[\w./:+${}#&?=@~%-]*$).*[\d./:+${}#&?=@~%_]')

# **Cinquième trou : un trait d'union suffisait à faire passer un mot pour un
# identifiant.** `« Peut-être »` entrait dans la classe de caractères, et le
# tiret y comptait comme marque technique : la réponse « peut-être » d'un
# événement est restée en français sans que rien ne le dise.
#
# Le tiret ne vaut donc comme marque technique que si la chaîne est
# **entièrement en minuscules ASCII** : `jelvo-apparence`, `chat-media`,
# `group-photos`, `sb-hôte-auth-token` sont de cette forme, et doivent rester
# en dur. Une majuscule ou un accent, et c'est un mot.
IDENTIFIANT_TIRET = re.compile(r'^[a-z0-9._-]*-[a-z0-9._-]*$')
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
    if IDENTIFIANT.match(nu) or IDENTIFIANT_TIRET.match(nu):
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
    # Le troisième filet, qui ne regarde ni la position ni l'espace : voir
    # `ressemble_a_un_libelle`. C'est lui qui voit les branches de `switch`
    # d'une méthode `label(AppTexts t)`.
    return par_position or phrase or ressemble_a_un_libelle(nu)


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
