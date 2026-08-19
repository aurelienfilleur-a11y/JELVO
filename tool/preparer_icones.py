#!/usr/bin/env python3
"""Découpe les sept icônes de l'application dans le logo fourni.

    python3 tool/preparer_icones.py

**Ce script ne dessine rien.** Le logo est un fichier fourni — `tool/logo/
jelvo-icone-source.png`, monogramme `jv` blanc sur fond indigo dégradé. Tout
ce qui suit est du recadrage, du recentrage et de la réduction : aucune forme
n'est reconstruite. Un logo redessiné d'après une description est un faux, et
l'erreur a déjà été commise une fois sur ce dépôt.

Deux opérations, et deux seulement :

1. **Recentrage.** Dans le fichier fourni, le monogramme n'est pas au centre
   de la toile. Il est remis d'aplomb par une **translation entière** — aucun
   rééchantillonnage, donc aucun pixel du monogramme n'est modifié — et le
   dégradé est **prolongé** sur la bande ainsi libérée.

2. **Réduction** à chaque taille voulue, plus l'extraction de la silhouette
   pour le badge Android.
"""

from PIL import Image

SOURCE = 'tool/logo/jelvo-icone-source.png'

# Seuil de séparation du monogramme et du fond, en luminance. Le fond indigo
# plafonne autour de 80, le monogramme est à 254 : le seuil est franc, il n'y
# a pas de zone d'incertitude à arbitrer.
SEUIL = 160

# Rampe d'alpha pour la silhouette du badge, qui doit garder l'anticrénelage
# des bords plutôt que de les escalier.
BADGE_BAS, BADGE_HAUT = 120, 200

# Nombre d'échantillons sur lesquels la pente du dégradé est ajustée avant
# d'être prolongée. Voir `_pente` : deux pixels ne suffisent pas.
FENETRE = 64


def boite_du_monogramme(image: Image.Image) -> tuple[int, int, int, int]:
    """Boîte englobante du blanc, bornes incluses."""
    masque = Image.eval(image.convert('L'), lambda v: 255 if v > SEUIL else 0)
    x0, y0, x1, y1 = masque.getbbox()
    return x0, y0, x1 - 1, y1 - 1


def recentrer(image: Image.Image) -> Image.Image:
    """Remet le monogramme au centre des quatre bords.

    La translation est **entière** : les pixels du monogramme sont recopiés
    tels quels, jamais interpolés. Un décalage sous-pixellaire aurait demandé
    un rééchantillonnage, c'est-à-dire une altération du tracé.

    La bande libérée est remplie par **prolongement linéaire** du dégradé, et
    non par recopie du bord : le fond est un dégradé, et dupliquer une colonne
    y laisserait une bande plate visible.
    """
    largeur, hauteur = image.size
    x0, y0, x1, y1 = boite_du_monogramme(image)

    dx = round(((largeur - 1 - x1) - x0) / 2)
    dy = round(((hauteur - 1 - y1) - y0) / 2)
    if dx == 0 and dy == 0:
        return image.copy()

    # Le décalage se fait vers la droite et vers le bas ou l'inverse ; on ne
    # traite ici que le cas rencontré, et on refuse le reste plutôt que de
    # produire un résultat faux en silence.
    if dx < 0 or dy < 0:
        raise SystemExit(
            f'Décalage négatif ({dx}, {dy}) : le prolongement du dégradé n’est '
            'écrit que pour les bandes gauche et haute. À compléter si la '
            'source change.'
        )

    sortie = Image.new('RGB', image.size)
    sortie.paste(image, (dx, dy))
    pixels = sortie.load()

    # Bande gauche : chaque ligne est prolongée depuis la pente ajustée sur
    # ses premières colonnes connues.
    for y in range(dy, hauteur):
        for c in range(3):
            base, pente = _pente(
                [pixels[dx + i, y][c] for i in range(FENETRE)])
            for x in range(dx - 1, -1, -1):
                _poser(pixels, x, y, c, base + pente * (x - dx))

    # Bande haute, sur toute la largeur : les colonnes de gauche viennent
    # d'être remplies, le coin est donc couvert lui aussi.
    for x in range(largeur):
        for c in range(3):
            base, pente = _pente(
                [pixels[x, dy + i][c] for i in range(FENETRE)])
            for y in range(dy - 1, -1, -1):
                _poser(pixels, x, y, c, base + pente * (y - dy))

    return sortie


def _pente(echantillons: list[int]) -> tuple[float, float]:
    """Droite des moindres carrés, rendue en (valeur à l'origine, pente).

    **La fenêtre est large exprès.** Prolonger depuis deux pixels voisins
    multiplie leur écart par la distance : le bruit du dégradé, invisible à
    l'échelle du pixel, devenait une bande claire de dix-sept pixels le long
    du bord. L'ajustement sur soixante-quatre échantillons suit la pente sans
    suivre le bruit.
    """
    n = len(echantillons)
    somme_i = n * (n - 1) / 2
    somme_ii = (n - 1) * n * (2 * n - 1) / 6
    somme_v = sum(echantillons)
    somme_iv = sum(i * v for i, v in enumerate(echantillons))

    denominateur = n * somme_ii - somme_i * somme_i
    pente = (n * somme_iv - somme_i * somme_v) / denominateur
    base = (somme_v - pente * somme_i) / n
    return base, pente


def _poser(pixels, x: int, y: int, canal: int, valeur: float) -> None:
    couleur = list(pixels[x, y])
    couleur[canal] = _borne(valeur)
    pixels[x, y] = tuple(couleur)


def _borne(valeur: float) -> int:
    return max(0, min(255, int(round(valeur))))


def silhouette(image: Image.Image, taille: int) -> Image.Image:
    """Le monogramme seul, blanc opaque sur fond transparent.

    Android ne garde que l'alpha du badge et en fait une silhouette : une
    icône en couleur y deviendrait un carré plein.
    """
    luminance = image.convert('L')
    alpha = luminance.point(
        lambda v: _borne((v - BADGE_BAS) * 255 / (BADGE_HAUT - BADGE_BAS))
    )
    badge = Image.new('RGBA', image.size, (255, 255, 255, 0))
    badge.putalpha(alpha)
    return badge.resize((taille, taille), Image.LANCZOS)


def main() -> None:
    source = Image.open(SOURCE).convert('RGB')
    avant = boite_du_monogramme(source)
    maitre = recentrer(source)
    apres = boite_du_monogramme(maitre)

    largeur = maitre.size[0]
    print(f'source  : {SOURCE}  {source.size[0]}×{source.size[1]}')
    print(f'  marges avant  g/d {avant[0]}/{largeur - 1 - avant[2]}'
          f'   h/b {avant[1]}/{largeur - 1 - avant[3]}')
    print(f'  marges après  g/d {apres[0]}/{largeur - 1 - apres[2]}'
          f'   h/b {apres[1]}/{largeur - 1 - apres[3]}')

    # Le monogramme tient déjà dans les 80 % centraux — sa demi-diagonale vaut
    # 381 px pour un rayon sûr de 502 —, si bien que les icônes masquables
    # sont la même image que les autres. C'est une propriété du fichier
    # fourni, vérifiée ci-dessous plutôt que supposée.
    _controler_zone_sure(apres, largeur)

    carres = [
        ('web/icons/Icon-180.png', 180),
        ('web/icons/Icon-192.png', 192),
        ('web/icons/Icon-512.png', 512),
        ('web/icons/Icon-maskable-192.png', 192),
        ('web/icons/Icon-maskable-512.png', 512),
        ('web/favicon.png', 32),
    ]
    for chemin, taille in carres:
        maitre.resize((taille, taille), Image.LANCZOS).save(
            chemin, 'PNG', optimize=True)
        print(f'{chemin}  {taille}×{taille}')

    silhouette(maitre, 96).save(
        'web/icons/Icon-badge-96.png', 'PNG', optimize=True)
    print('web/icons/Icon-badge-96.png  96×96  (silhouette transparente)')


def _controler_zone_sure(boite: tuple[int, int, int, int], côte: int) -> None:
    x0, y0, x1, y1 = boite
    demi_diagonale = (((x1 - x0) / 2) ** 2 + ((y1 - y0) / 2) ** 2) ** 0.5
    rayon_sur = 0.4 * côte
    etat = 'tient' if demi_diagonale <= rayon_sur else 'DÉBORDE'
    print(f'  zone sûre masquable : demi-diagonale {demi_diagonale:.0f} px, '
          f'rayon sûr {rayon_sur:.0f} px — {etat}')
    if demi_diagonale > rayon_sur:
        raise SystemExit(
            'Le monogramme déborde des 80 % centraux : les icônes masquables '
            'demandent une source avec plus de marge.'
        )


if __name__ == '__main__':
    main()
