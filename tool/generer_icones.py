#!/usr/bin/env python3
"""Fabrique les icônes de l'application à partir du monogramme JV.

    python3 tool/generer_icones.py

Les quatre PNG de `web/icons/` sont **produits**, jamais retouchés à la main :
une icône que personne ne sait régénérer finit par ne plus correspondre au
reste de la charte. Les couleurs viennent de `lib/core/theme` — les changer
ici sans les changer là-bas donnerait deux violets.

Le monogramme est tracé géométriquement plutôt qu'avec une police : aucune
fonte n'est garantie présente sur une machine de compilation, et un tracé
reste net à toutes les tailles.
"""

from PIL import Image, ImageDraw

VIOLET = (0x5B, 0x2E, 0xFF, 255)  # AppColors.primary
BLANC = (0xFF, 0xFF, 0xFF, 255)

# Rapport de suréchantillonnage : on trace huit fois trop grand, puis on
# réduit. C'est ce qui donne les bords lisses — `ImageDraw` ne connaît pas
# l'anticrénelage.
ECHELLE = 8

# Part de la largeur occupée par le monogramme.
#
# Une icône masquable est rognée par le système, parfois en cercle : tout ce
# qui compte doit tenir dans les 80 % centraux. D'où deux cadrages, et non un
# seul redimensionné.
PART_NORMALE = 0.62
PART_MASQUABLE = 0.46


def dessiner(taille: int, part: float) -> Image.Image:
    """Rend le monogramme centré sur fond blanc.

    Le centrage se fait sur **l'encre réellement posée**, relevée après coup,
    et non sur la géométrie prévue : le crochet du J déborde à gauche et les
    extrémités arrondies débordent partout, si bien qu'un cadrage calculé
    d'avance laisse le monogramme visiblement décalé.
    """
    grand = taille * ECHELLE

    # Toile de travail large : on trace sans se soucier du cadrage, on recadre
    # ensuite sur le contenu.
    marge = grand
    calque = Image.new('RGBA', (marge, marge), (0, 0, 0, 0))
    trace = ImageDraw.Draw(calque)

    hauteur = marge * 0.5
    epaisseur = hauteur * 0.19
    rayon = epaisseur / 2
    largeur_lettre = hauteur * 0.62
    ecart = hauteur * 0.12

    haut = (marge - hauteur) / 2
    bas = haut + hauteur
    gauche = (marge - (2 * largeur_lettre + ecart)) / 2

    _lettre_j(trace, gauche, haut, bas, largeur_lettre, epaisseur, rayon)
    _lettre_v(trace, gauche + largeur_lettre + ecart, haut, bas,
              largeur_lettre, epaisseur, rayon)

    encre = calque.crop(calque.getbbox())

    # Mise à l'échelle sur la plus grande dimension, pour que le monogramme
    # tienne dans la part demandée quelle que soit sa forme.
    facteur = (grand * part) / max(encre.size)
    encre = encre.resize(
        (max(1, round(encre.width * facteur)),
         max(1, round(encre.height * facteur))),
        Image.LANCZOS,
    )

    image = Image.new('RGBA', (grand, grand), BLANC)
    image.paste(
        encre,
        ((grand - encre.width) // 2, (grand - encre.height) // 2),
        encre,
    )
    return image.resize((taille, taille), Image.LANCZOS).convert('RGB')


def _lettre_j(trace, gauche, haut, bas, largeur, epaisseur, rayon) -> None:
    """Hampe verticale à droite, crochet vers la gauche en bas."""
    # Rayon de la **ligne médiane** du crochet. `ImageDraw.arc` trace vers
    # l'intérieur de la boîte : sans le demi-épaisseur ajouté ci-dessous,
    # l'épaisseur mange le rayon et le crochet devient un disque plein.
    crochet = (largeur - epaisseur) / 2
    hampe_x = gauche + largeur - rayon
    centre_x = hampe_x - crochet
    centre_y = bas - crochet

    trace.line([(hampe_x, haut + rayon), (hampe_x, centre_y)],
               fill=VIOLET, width=int(epaisseur))
    _point(trace, hampe_x, haut + rayon, rayon)

    externe = crochet + rayon
    trace.arc(
        [centre_x - externe, centre_y - externe,
         centre_x + externe, centre_y + externe],
        start=0, end=180, fill=VIOLET, width=int(epaisseur),
    )
    _point(trace, centre_x - crochet, centre_y, rayon)


def _lettre_v(trace, gauche, haut, bas, largeur, epaisseur, rayon) -> None:
    """Deux diagonales qui se rejoignent en pointe."""
    sommets = [
        (gauche + rayon, haut + rayon),
        (gauche + largeur / 2, bas - rayon),
        (gauche + largeur - rayon, haut + rayon),
    ]
    trace.line(sommets, fill=VIOLET, width=int(epaisseur), joint='curve')
    for x, y in (sommets[0], sommets[2]):
        _point(trace, x, y, rayon)
    _point(trace, *sommets[1], rayon)


def _point(trace, x, y, rayon) -> None:
    """Extrémité arrondie — `ImageDraw.line` ne les pose pas lui-même."""
    trace.ellipse([x - rayon, y - rayon, x + rayon, y + rayon], fill=VIOLET)


def main() -> None:
    sorties = [
        ('web/icons/Icon-192.png', 192, PART_NORMALE),
        ('web/icons/Icon-512.png', 512, PART_NORMALE),
        ('web/icons/Icon-maskable-192.png', 192, PART_MASQUABLE),
        ('web/icons/Icon-maskable-512.png', 512, PART_MASQUABLE),
        # À seize pixels, le monogramme entier n'est plus lisible ; on le
        # laisse déborder un peu plus pour qu'il reste identifiable.
        ('web/favicon.png', 32, 0.80),
    ]
    for chemin, taille, part in sorties:
        dessiner(taille, part).save(chemin, 'PNG', optimize=True)
        print(f'{chemin}  {taille}×{taille}')


if __name__ == '__main__':
    main()
