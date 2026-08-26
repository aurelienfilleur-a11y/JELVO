import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/onboarding_storage.dart';
import '../../auth/providers/auth_providers.dart';

/// Vrai si l'écran de bienvenue a déjà été vu.
///
/// Un `Notifier` et non un `FutureProvider`, pour la même raison
/// qu'`authStatusProvider` : la redirection du routeur le lit **de façon
/// synchrone**, et ne peut pas attendre un `AsyncValue`. La valeur vient de
/// [OnboardingStorage], chargé dans `main()` avant `runApp`.
class WelcomeSeen extends Notifier<bool> {
  @override
  bool build() {
    // **Une session ouverte vaut présentation faite.** Sans cela, quelqu'un
    // arrivé par un lien d'invitation — qui n'a jamais vu l'écran — se le
    // verrait proposer le jour où il se déconnecte, longtemps après avoir
    // appris à quoi sert l'application.
    ref.listen<AuthStatus>(authStatusProvider, (_, AuthStatus statut) {
      if (statut == AuthStatus.signedIn) marquerVu();
    });

    final OnboardingStorage stockage = ref.read(onboardingStorageProvider);

    // `listen` ne se déclenche qu'au **changement** : une session restaurée au
    // démarrage ne le réveillerait pas. C'est pourtant le cas le plus courant
    // — quelqu'un qui ouvre l'application en étant déjà connecté.
    if (!stockage.dejaVu &&
        ref.read(authStatusProvider) == AuthStatus.signedIn) {
      stockage.marquerVu();
      return true;
    }
    return stockage.dejaVu;
  }

  /// Retient que l'écran a été vu, et le retire de la navigation.
  ///
  /// L'écriture sur disque n'est pas attendue : l'état passe à `true` tout de
  /// suite, sans quoi la redirection pourrait renvoyer sur l'écran qu'on vient
  /// de quitter. Un échec d'écriture ne coûte qu'un affichage de trop au
  /// lancement suivant — refuser de continuer serait bien pire.
  void marquerVu() {
    if (state) return;
    state = true;
    ref.read(onboardingStorageProvider).marquerVu();
  }
}

final NotifierProvider<WelcomeSeen, bool> welcomeSeenProvider =
    NotifierProvider<WelcomeSeen, bool>(WelcomeSeen.new);
