// `widgets.dart` réexporte `characters` : `String.characters` vient de là,
// sans dépendance de plus au pubspec.
import 'package:flutter/widgets.dart';

/// Découpe un texte en suites « emoji » et « pas emoji ».
///
///
/// POURQUOI UN DÉCOUPAGE, ET NON UN SIMPLE REPLI DE POLICE
///
/// `fontFamilyFallback` n'est consulté que pour les caractères que la police
/// **principale** ne couvre pas. Or Inter couvre trente-sept des caractères de
/// Noto Color Emoji, dont le cœur `U+2764`, le panneau `U+26A0`, le soleil
/// `U+2600`, la flèche `U+2B06`, `©`, `‼` et `⁉`. Pour ceux-là, Inter gagne, le
/// repli n'est jamais atteint, et le glyphe sorti est celui d'une police de
/// texte — c'est-à-dire **noir**.
///
/// Le sélecteur de variation `U+FE0F`, qui devrait forcer la présentation
/// emoji, n'y change rien : Inter ne le couvre pas, la résolution de police se
/// fait caractère par caractère, et le cœur a déjà été attribué à Inter quand
/// le sélecteur est examiné. C'est exactement le défaut constaté — « un cœur
/// rouge tapé au clavier iPhone apparaît en cœur noir » — et la raison pour
/// laquelle les emojis de la palette, tous hors du répertoire d'Inter,
/// s'affichaient bien.
///
/// La seule correction fiable est donc de faire de la police d'emojis la
/// police **principale** des suites concernées, ce qui suppose de les
/// reconnaître.
///
///
/// CE QUI EST RECONNU
///
/// Le découpage se fait par **grappe de graphèmes** (`String.characters`), et
/// non par point de code : un drapeau, une famille, un ton de peau ou une
/// séquence à sélecteur de variation sont plusieurs points de code qui doivent
/// rester ensemble, faute de quoi la ligature `GSUB` ne se forme pas et
/// `🇫🇷` sort en deux lettres carrées.
///
/// Une grappe est tenue pour un emoji si :
///
/// 1. elle porte `U+FE0F` — le sélecteur de présentation emoji, que tous les
///    claviers émettent : c'est lui qui distingue `❤️` de `❤` ;
/// 2. elle porte `U+20E3` — l'enceinte des touches, `1️⃣` ;
/// 3. son premier point de code a la propriété Unicode
///    **`Emoji_Presentation=Yes`**, c'est-à-dire qu'il s'affiche en emoji sans
///    qu'on ait à le demander : `😀`, `👍`, les indicateurs régionaux des
///    drapeaux.
///
/// **Le point 3 ne suffisait pas, et le point 1 non plus.** Les deux sont
/// nécessaires : `❤` sans sélecteur a la présentation *texte* selon Unicode, et
/// le cœur noir d'Inter est alors le rendu **juste** ; `⬜` a la présentation
/// emoji sans porter de sélecteur, et Inter le couvre pourtant. Chacune des
/// deux règles rattrape ce que l'autre laisse passer.
///
/// Conséquence voulue : `©` écrit au fil du texte reste du texte, et le chiffre
/// `1` reste un chiffre — seul `1️⃣`, avec son enceinte, devient un emoji.
@immutable
class EmojiRun {
  const EmojiRun(this.text, {required this.isEmoji});

  final String text;
  final bool isEmoji;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmojiRun && other.text == text && other.isEmoji == isEmoji);

  @override
  int get hashCode => Object.hash(text, isEmoji);

  @override
  String toString() => '${isEmoji ? 'emoji' : 'texte'}("$text")';
}

/// Découpe [texte] en suites homogènes, dans l'ordre.
///
/// Un texte sans aucun emoji rend une seule suite : le cas courant ne paie donc
/// qu'un parcours, et l'appelant peut se contenter d'un `Text` ordinaire quand
/// la liste ne contient qu'un élément non-emoji.
List<EmojiRun> decouperEmojis(String texte) {
  if (texte.isEmpty) return const <EmojiRun>[];

  final List<EmojiRun> suites = <EmojiRun>[];
  final StringBuffer courante = StringBuffer();
  bool? typeCourant;

  void fermer(bool? type) {
    if (type == null) return;
    suites.add(EmojiRun(courante.toString(), isEmoji: type));
    courante.clear();
  }

  for (final String grappe in texte.characters) {
    final bool emoji = grappeEstEmoji(grappe);
    if (emoji != typeCourant) {
      fermer(typeCourant);
      typeCourant = emoji;
    }
    courante.write(grappe);
  }
  fermer(typeCourant);
  return suites;
}

/// Vrai si [grappe] — **une** grappe de graphèmes — doit être rendue par la
/// police d'emojis. Voir [EmojiRun] pour les trois règles et leur raison.
bool grappeEstEmoji(String grappe) {
  if (grappe.isEmpty) return false;

  int? premier;
  for (final int point in grappe.runes) {
    premier ??= point;
    // Sélecteur de présentation emoji, et enceinte des touches : les deux
    // disent explicitement « ceci est un emoji », où qu'ils se trouvent dans
    // la grappe — `1️⃣` porte l'enceinte en dernier.
    if (point == 0xFE0F || point == 0x20E3) return true;
  }
  return _presentationEmoji(premier!);
}

/// `Emoji_Presentation=Yes`, relevé sur `emoji-data.txt` de l'UCD.
///
/// Régénérable : les plages viennent de la propriété Unicode, pas d'une
/// intuition. Elles bougent d'une version d'Unicode à l'autre, et un caractère
/// manquant ne casse rien — il retombe sur la règle du sélecteur de variation,
/// que les claviers émettent de toute façon.
bool _presentationEmoji(int point) {
  int bas = 0;
  int haut = _plages.length ~/ 2 - 1;
  while (bas <= haut) {
    final int milieu = (bas + haut) ~/ 2;
    if (point < _plages[milieu * 2]) {
      haut = milieu - 1;
    } else if (point > _plages[milieu * 2 + 1]) {
      bas = milieu + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// Bornes inclusives, deux entiers par plage, triées.
const List<int> _plages = <int>[
  0x0231A,
  0x0231B,
  0x023E9,
  0x023EC,
  0x023F0,
  0x023F0,
  0x023F3,
  0x023F3,
  0x025FD,
  0x025FE,
  0x02614,
  0x02615,
  0x02648,
  0x02653,
  0x0267F,
  0x0267F,
  0x02693,
  0x02693,
  0x026A1,
  0x026A1,
  0x026AA,
  0x026AB,
  0x026BD,
  0x026BE,
  0x026C4,
  0x026C5,
  0x026CE,
  0x026CE,
  0x026D4,
  0x026D4,
  0x026EA,
  0x026EA,
  0x026F2,
  0x026F3,
  0x026F5,
  0x026F5,
  0x026FA,
  0x026FA,
  0x026FD,
  0x026FD,
  0x02705,
  0x02705,
  0x0270A,
  0x0270B,
  0x02728,
  0x02728,
  0x0274C,
  0x0274C,
  0x0274E,
  0x0274E,
  0x02753,
  0x02755,
  0x02757,
  0x02757,
  0x02795,
  0x02797,
  0x027B0,
  0x027B0,
  0x027BF,
  0x027BF,
  0x02B1B,
  0x02B1C,
  0x02B50,
  0x02B50,
  0x02B55,
  0x02B55,
  0x1F004,
  0x1F004,
  0x1F0CF,
  0x1F0CF,
  0x1F18E,
  0x1F18E,
  0x1F191,
  0x1F19A,
  0x1F1E6,
  0x1F1FF,
  0x1F201,
  0x1F201,
  0x1F21A,
  0x1F21A,
  0x1F22F,
  0x1F22F,
  0x1F232,
  0x1F236,
  0x1F238,
  0x1F23A,
  0x1F250,
  0x1F251,
  0x1F300,
  0x1F320,
  0x1F32D,
  0x1F335,
  0x1F337,
  0x1F37C,
  0x1F37E,
  0x1F393,
  0x1F3A0,
  0x1F3CA,
  0x1F3CF,
  0x1F3D3,
  0x1F3E0,
  0x1F3F0,
  0x1F3F4,
  0x1F3F4,
  0x1F3F8,
  0x1F43E,
  0x1F440,
  0x1F440,
  0x1F442,
  0x1F4FC,
  0x1F4FF,
  0x1F53D,
  0x1F54B,
  0x1F54E,
  0x1F550,
  0x1F567,
  0x1F57A,
  0x1F57A,
  0x1F595,
  0x1F596,
  0x1F5A4,
  0x1F5A4,
  0x1F5FB,
  0x1F64F,
  0x1F680,
  0x1F6C5,
  0x1F6CC,
  0x1F6CC,
  0x1F6D0,
  0x1F6D2,
  0x1F6D5,
  0x1F6D8,
  0x1F6DC,
  0x1F6DF,
  0x1F6EB,
  0x1F6EC,
  0x1F6F4,
  0x1F6FC,
  0x1F7E0,
  0x1F7EB,
  0x1F7F0,
  0x1F7F0,
  0x1F90C,
  0x1F93A,
  0x1F93C,
  0x1F945,
  0x1F947,
  0x1F9FF,
  0x1FA70,
  0x1FA7C,
  0x1FA80,
  0x1FA8A,
  0x1FA8E,
  0x1FAC6,
  0x1FAC8,
  0x1FAC8,
  0x1FACD,
  0x1FADC,
  0x1FADF,
  0x1FAEA,
  0x1FAEF,
  0x1FAF8,
];
