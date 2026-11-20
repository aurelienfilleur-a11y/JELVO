import 'pont_navigateur_stub.dart'
    if (dart.library.js_interop) 'pont_navigateur_web.dart';

/// Ce que l'application a besoin de dire à la page qui l'héberge.
///
/// **Deux choses lui échappent**, et toutes deux sont décidées par le
/// navigateur avant qu'une ligne de Dart ne tourne : la couleur du bandeau de
/// la barre d'état, et ce qui est affiché tant que Flutter n'a pas démarré.
/// `web/index.html` les règle donc lui-même, depuis le réglage enregistré sur
/// l'appareil. Restent deux choses que la page ne peut pas savoir seule, et
/// qui sont tout l'objet de ce pont : qu'on vient de **changer** d'apparence,
/// et que l'application est **prête à être vue**.
///
/// **La règle d'apparence n'est pas réimplémentée ici** : la page expose
/// `jelvoAppliquerApparence(mot)`, on ne fait que lui passer le mot. Une
/// seconde implémentation en Dart aurait fini par diverger de la première, et
/// l'écart se serait vu en clignotement.
///
/// C'est une **interface**, et non deux fonctions libres, pour la même raison
/// que les dépôts : sans elle, rien ne prouverait que le crochet se déclenche
/// quand on change de réglage, et un crochet muet est le défaut qu'on
/// corrige ailleurs.
abstract interface class PontNavigateur {
  /// `clair`, `sombre` ou `systeme` — le vocabulaire de `ThemeStorage`.
  void appliquerApparence(String mot);

  /// Retire l'écran de lancement.
  ///
  /// Appelé quand le premier écran a **son contenu**, et non à la première
  /// image : la première image, c'est l'accueil encore vide, qui ne ressemble
  /// pas à l'accueil et se lit comme un écran de passage.
  void applicationPrete();
}

/// Le pont de la plateforme : la page sur le web, un talon ailleurs.
PontNavigateur creerPontNavigateur() => creerPont();
