// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppTextsFr extends AppTexts {
  AppTextsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Jelvo';

  @override
  String get navHome => 'Accueil';

  @override
  String get navGroups => 'Groupes';

  @override
  String get navCalendar => 'Calendrier';

  @override
  String get navContacts => 'Contacts';

  @override
  String get createNewGroup => 'Nouveau groupe';

  @override
  String get createNewEvent => 'Nouvel événement';

  @override
  String get createAddContact => 'Ajouter un contact';

  @override
  String get createTitle => 'Créer';

  @override
  String get createQuestion => 'Que voulez-vous créer ?';

  @override
  String get createIntro =>
      'Choisissez un type, puis renseignez l’essentiel. Vous pourrez compléter les détails plus tard.';

  @override
  String get createDetails => 'Détails';

  @override
  String get createGroupField => 'Groupe';

  @override
  String get createPersonalOption => 'Personnel — visible de vous seul';

  @override
  String get createPickDate => 'Choisir la date';

  @override
  String get createDueDate => 'Échéance';

  @override
  String get createTime => 'Heure';

  @override
  String get createMissingDate => 'Choisissez la date de l’événement.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRequiredField => 'Ce champ est obligatoire.';

  @override
  String get commonOptional => 'Optionnel';

  @override
  String get homeSubtitle => 'Voici votre journée en un coup d’œil.';

  @override
  String get homeToday => 'Aujourd’hui';

  @override
  String get homeNoEventTitle => 'Journée libre';

  @override
  String get homeNoEventMessage =>
      'Rien n’est encore planifié pour aujourd’hui.';

  @override
  String get homeSoon => 'À faire bientôt';

  @override
  String get homeNothingUrgent => 'Rien d’urgent';

  @override
  String get homeAllUpToDateTitle => 'Tout est à jour';

  @override
  String get homeAllUpToDateMessage =>
      'Aucune tâche n’arrive à échéance dans les 48 heures.';

  @override
  String get homeMyGroups => 'Mes groupes';

  @override
  String get homeMostActive => 'Les plus actifs en ce moment';

  @override
  String get homeSeeAll => 'Tout voir';

  @override
  String homeEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
      zero: 'Aucun événement',
    );
    return '$_temp0';
  }

  @override
  String homeTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches à échéance proche',
      one: '1 tâche à échéance proche',
      zero: 'Aucune tâche',
    );
    return '$_temp0';
  }

  @override
  String get groupUpcoming => 'À venir';

  @override
  String get groupNothingPlanned => 'Rien de prévu';

  @override
  String get groupNoEventTitle => 'Aucun événement';

  @override
  String get groupNoEventMessage =>
      'Proposez une date au groupe : chacun répondra oui, peut-être ou non.';

  @override
  String get groupProposeDate => 'Proposer une date';

  @override
  String get groupTasksToDo => 'Tâches à faire';

  @override
  String get groupNoTaskTitle => 'Aucune tâche ouverte';

  @override
  String get groupNoTaskMessage =>
      'Répartissez ce qu’il y a à faire : chacun verra sa part.';

  @override
  String get groupAddTask => 'Ajouter une tâche';

  @override
  String get groupAdd => 'Ajouter';

  @override
  String get groupAddToGroup => 'Ajouter au groupe';

  @override
  String groupCreationSheetIntro(String name) {
    return 'Ce que vous créez ici sera partagé avec « $name ».';
  }

  @override
  String get groupMembers => 'Membres';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: 'Aucun membre',
    );
    return '$_temp0';
  }

  @override
  String get taskStatusTodo => 'À faire';

  @override
  String get taskStatusDone => 'Terminée';

  @override
  String get taskStatusOverdue => 'En retard';

  @override
  String get taskPriorityLow => 'Basse';

  @override
  String get taskPriorityMedium => 'Normale';

  @override
  String get taskPriorityHigh => 'Haute';

  @override
  String get taskAssigneePending => 'En attente';

  @override
  String get taskAssigneeAccepted => 'Acceptée';

  @override
  String get taskAssigneeDeclined => 'Refusée';

  @override
  String get taskAccept => 'Accepter';

  @override
  String get taskDecline => 'Refuser';

  @override
  String taskListProgress(int checked, int total) {
    return '$checked sur $total articles';
  }

  @override
  String get eventAnswerYes => 'Oui';

  @override
  String get eventAnswerMaybe => 'Peut-être';

  @override
  String get eventAnswerNo => 'Non';

  @override
  String get eventAnswerPending => 'En attente';

  @override
  String get errorGeneric =>
      'Une erreur est survenue. Réessayez dans un instant.';

  @override
  String get errorNetwork =>
      'Connexion indisponible. Vérifiez votre accès à Internet, puis réessayez.';

  @override
  String get errorForbidden =>
      'Vous n’avez pas les droits nécessaires pour cette action.';

  @override
  String get errorNotSaved =>
      'Les données n’ont pas pu être enregistrées. Réessayez dans un instant.';

  @override
  String get coreAujourdHui => 'Aujourd\'hui';

  @override
  String get coreInstant => 'à l’instant';

  @override
  String coreDateLabelTimeLabel(Object dateLabel, Object timeLabel) {
    return '$dateLabel · $timeLabel';
  }

  @override
  String get coreVoirMembres => 'Voir tous les membres';

  @override
  String get corePersonneNom => 'Personne à ce nom.';

  @override
  String get coreMarquerTacheCommeTerminee => 'Marquer la tâche comme terminée';

  @override
  String authMessageDiagnosticRaw(Object _message, Object raw) {
    return '$_message\n\n[diagnostic] $raw';
  }

  @override
  String get authEnvoiPhotoEchoueReessayez =>
      'L\'envoi de la photo a échoué. Réessayez dans un instant.';

  @override
  String get authIdentifiantsIncorrectsVerifiezSaisie =>
      'Identifiants incorrects. Vérifiez votre saisie, puis réessayez.';

  @override
  String get authAdresseEMailEncore =>
      'Votre adresse e-mail n’est pas encore vérifiée.';

  @override
  String get authAdresseEMailDeja =>
      'Cette adresse e-mail est déjà utilisée. Connectez-vous ou choisissez une autre adresse.';

  @override
  String get authCodeExpireDemandezNouveau =>
      'Ce code a expiré. Demandez-en un nouveau.';

  @override
  String get authCodeIncorrectVerifiezSix =>
      'Code incorrect. Vérifiez les six chiffres reçus par e-mail.';

  @override
  String get authTropTentativesPatientezMinute =>
      'Trop de tentatives. Patientez une minute avant de réessayer.';

  @override
  String get authMotPasseTropFaible =>
      'Ce mot de passe est trop faible. Choisissez-en un plus robuste.';

  @override
  String get authNouveauMotPasseDoit =>
      'Le nouveau mot de passe doit différer de l’ancien.';

  @override
  String get authAucunCompteCorrespondInformations =>
      'Aucun compte ne correspond à ces informations.';

  @override
  String get authSessionExpireReconnectez =>
      'Votre session a expiré. Reconnectez-vous.';

  @override
  String get authConnexionEchoueReessayezInstant =>
      'La connexion a échoué. Réessayez dans un instant.';

  @override
  String get authPseudoVientEtrePris =>
      'Ce pseudo vient d’être pris. Choisissez-en un autre.';

  @override
  String get authFonctionnaliteAttendMiseJour =>
      'Cette fonctionnalité attend une mise à jour de la base. Réessayez plus tard, ou signalez-le si cela persiste.';

  @override
  String get authChoisissezPseudo => 'Choisissez un pseudo.';

  @override
  String authPseudoDoitContenirMoins(Object pseudoMinLength) {
    return 'Le pseudo doit contenir au moins $pseudoMinLength caractères.';
  }

  @override
  String authPseudoDoitDepasserPseudoMaxLength(Object pseudoMaxLength) {
    return 'Le pseudo ne doit pas dépasser $pseudoMaxLength caractères.';
  }

  @override
  String get authUniquementMinusculesChiffresPoints =>
      'Uniquement des minuscules, des chiffres et des points.';

  @override
  String get authRenseignezAdresseEMail => 'Renseignez votre adresse e-mail.';

  @override
  String get authAdresseEMailSemble =>
      'Cette adresse e-mail semble incomplète.';

  @override
  String get authChoisissezMotPasse => 'Choisissez un mot de passe.';

  @override
  String authMoinsPasswordMinLengthCaracteresNecessaires(
    Object passwordMinLength,
  ) {
    return 'Au moins $passwordMinLength caractères sont nécessaires.';
  }

  @override
  String get authAjoutezMoinsMajuscule => 'Ajoutez au moins une majuscule.';

  @override
  String get authAjoutezMoinsChiffre => 'Ajoutez au moins un chiffre.';

  @override
  String get authConnexionPseudoEncoreDisponible =>
      'La connexion par pseudo n’est pas encore disponible. Utilisez votre adresse e-mail.';

  @override
  String get authMotPasseOublie => 'Mot de passe oublié';

  @override
  String get authIndiquezAdresseEMail =>
      'Indiquez votre adresse e-mail : nous vous enverrons un code à six chiffres pour en choisir un nouveau.';

  @override
  String get authAdresseEMail => 'Adresse e-mail';

  @override
  String get authEnvoyerCode => 'Envoyer le code';

  @override
  String get authContentRevoir => 'Content de vous revoir';

  @override
  String get authConnectezRetrouverGroupesAgenda =>
      'Connectez-vous pour retrouver vos groupes et votre agenda.';

  @override
  String get authPseudoAdresseEMail => 'Pseudo ou adresse e-mail';

  @override
  String get authMotPasseOublie2 => 'Mot de passe oublié ?';

  @override
  String get authConnecter => 'Se connecter';

  @override
  String get authEncoreCompte => 'Pas encore de compte ?';

  @override
  String get authInscrire => 'S\'inscrire';

  @override
  String get authSouvenirMoi => 'Se souvenir de moi';

  @override
  String get authResterezConnecteJusquDeconnexion =>
      'Vous resterez connecté jusqu’à la déconnexion.';

  @override
  String get authSerezDeconnecteFermetureApplication =>
      'Vous serez déconnecté à la fermeture de l’application.';

  @override
  String get authJelvoInstalleEcranAccueil =>
      'Jelvo installé sur l’écran d’accueil a sa propre session : s’y connecter est une étape distincte de Safari, même avec cette case cochée.';

  @override
  String get authRenseignezPseudoAdresseE =>
      'Renseignez votre pseudo ou votre adresse e-mail.';

  @override
  String get authRenseignezMotPasse => 'Renseignez votre mot de passe.';

  @override
  String get authNouveauMotPasse => 'Nouveau mot de passe';

  @override
  String get authSaisissezCodeRecuPuis =>
      'Saisissez le code reçu, puis choisissez un nouveau mot de passe.';

  @override
  String authSaisissezCodeEnvoyeEmail(Object email) {
    return 'Saisissez le code envoyé à $email, puis choisissez un nouveau mot de passe.';
  }

  @override
  String get authCodeVerification => 'Code de vérification';

  @override
  String get auth8CaracteresMinimum => '8 caractères minimum';

  @override
  String get authChangerMotPasse => 'Changer le mot de passe';

  @override
  String get authRenvoyerCode => 'Renvoyer le code';

  @override
  String get authEnvoiCours => 'Envoi en cours…';

  @override
  String authNouveauCodePossibleSecondsLeft(Object _secondsLeft) {
    return 'Nouveau code possible dans $_secondsLeft s';
  }

  @override
  String get authSaisissezSixChiffresCode =>
      'Saisissez les six chiffres du code.';

  @override
  String get authMotPasseEteMis => 'Votre mot de passe a été mis à jour.';

  @override
  String get authNouveauCodeVientEtre => 'Un nouveau code vient d’être envoyé.';

  @override
  String get authCreerCompte => 'Créer votre compte';

  @override
  String get authChoisissezPseudoSecurisezCompte =>
      'Choisissez un pseudo et sécurisez votre compte.';

  @override
  String get authEtape12 => 'Étape 1 sur 2';

  @override
  String get authCreantCompteAcceptezRecevoir =>
      'En créant un compte, vous acceptez de recevoir un e-mail de vérification.';

  @override
  String get authAppelezComment => 'Vous vous appelez comment ?';

  @override
  String get authProchesReconnaitrontFacilement =>
      'Vos proches vous reconnaîtront plus facilement.';

  @override
  String get authEtape22 => 'Étape 2 sur 2';

  @override
  String get authCreerCompte2 => 'Créer mon compte';

  @override
  String get authRenseignezPrenom => 'Renseignez votre prénom.';

  @override
  String get authRenseignezNom => 'Renseignez votre nom.';

  @override
  String authCompteCreeMaisProfil(Object warning) {
    return 'Compte créé, mais le profil n’a pas pu être enregistré : $warning';
  }

  @override
  String get authVerifiezEMail => 'Vérifiez votre e-mail';

  @override
  String get authSaisissezCodeSixChiffres =>
      'Saisissez le code à six chiffres que nous venons de vous envoyer.';

  @override
  String get authChoisirPhotoProfil => 'Choisir une photo de profil';

  @override
  String get authOuvertureGalerie => 'Ouverture de la galerie…';

  @override
  String get authRetirerPhoto => 'Retirer la photo';

  @override
  String get authAjouterPhotoFacultatif => 'Ajouter une photo (facultatif)';

  @override
  String get authPhotoPuEtreOuverte =>
      'La photo n\'a pas pu être ouverte. Réessayez.';

  @override
  String get authMotPasse => 'Mot de passe';

  @override
  String get authMotPasse2 => 'Votre mot de passe';

  @override
  String get authAfficherMotPasse => 'Afficher le mot de passe';

  @override
  String get authMasquerMotPasse => 'Masquer le mot de passe';

  @override
  String get authMajuscule => 'Une majuscule';

  @override
  String get authChiffre => 'Un chiffre';

  @override
  String get authPseudoDejaPris => 'Ce pseudo est déjà pris.';

  @override
  String get authPseudoDisponible => 'Ce pseudo est disponible.';

  @override
  String get authCodeVerificationSixChiffres =>
      'Code de vérification à six chiffres';

  @override
  String get availabilityChaqueSemaine => 'Chaque semaine';

  @override
  String get availabilityDatePrecise => 'Une date précise';

  @override
  String get availabilityCreneauPuEtreEnregistre =>
      'Le créneau n’a pas pu être enregistré. Réessayez dans un instant.';

  @override
  String get availabilityDisponibilites => 'Mes disponibilités';

  @override
  String get availabilityNouveauCreneau => 'Nouveau créneau';

  @override
  String get availabilityDisponibilitesIndisponibles =>
      'Disponibilités indisponibles';

  @override
  String get availabilitySemaineType => 'Ma semaine type';

  @override
  String get availabilityCreneauxReviennentChaqueSemaine =>
      'Créneaux qui reviennent chaque semaine';

  @override
  String get availabilityAucunCreneauRecurrentRien =>
      'Aucun créneau récurrent. Sans rien de déclaré, les autres vous voient « Inconnu ».';

  @override
  String get availabilityDatePrecisePrimeSemaine =>
      'Une date précise, qui prime sur la semaine type';

  @override
  String get availabilityAucuneExceptionJourConge =>
      'Aucune exception. Un jour de congé ou un déplacement se pose ici.';

  @override
  String get availabilityAjouterCreneau => 'Ajouter un créneau';

  @override
  String get availabilityContactsMembresGroupesVoient =>
      'Vos contacts et les membres de vos groupes voient seulement « Disponible », « Indisponible » ou « Inconnu ». Jamais vos horaires, jamais la raison.';

  @override
  String get availabilityModifierCreneau => 'Modifier le créneau';

  @override
  String get availabilitySupprimerCreneau => 'Supprimer le créneau';

  @override
  String get availabilityCreneauSupprime => 'Créneau supprimé.';

  @override
  String get availabilityCreneauExisteListeVa =>
      'Ce créneau n’existe plus. La liste va se rafraîchir.';

  @override
  String get availabilityAjouterCreneau2 => 'Ajouter le créneau';

  @override
  String get availabilityChoisissezDateCreneau =>
      'Choisissez la date du créneau.';

  @override
  String get availabilityFinDoitSuivreDebut => 'La fin doit suivre le début.';

  @override
  String get availabilityCreneauModifie => 'Créneau modifié.';

  @override
  String get availabilityCreneauAjoute => 'Créneau ajouté.';

  @override
  String get availabilityDisponible => 'Qui est disponible ?';

  @override
  String get availabilityHeureChoisieVoyezQu =>
      'À l’heure choisie. Vous ne voyez qu’un mot, jamais leurs créneaux.';

  @override
  String get availabilityDisponibilitesIndisponiblesInstant =>
      'Disponibilités indisponibles pour l’instant.';

  @override
  String get calendarJours => 'Tous les jours';

  @override
  String get calendarToutesSemaines => 'Toutes les semaines';

  @override
  String get calendarToutesDeuxSemaines => 'Toutes les deux semaines';

  @override
  String get calendarMois => 'Tous les mois';

  @override
  String get calendarAns => 'Tous les ans';

  @override
  String get calendar10MinutesAvant => '10 minutes avant';

  @override
  String get calendar1HeureAvant => '1 heure avant';

  @override
  String get calendarVeille => 'La veille';

  @override
  String get calendar1SemaineAvant => '1 semaine avant';

  @override
  String calendarMinutesMin(Object minutes) {
    return '$minutes min';
  }

  @override
  String get calendarEvenementPuEtreCree =>
      'L’événement n’a pas pu être créé. Réessayez dans un instant.';

  @override
  String get calendarEvenementPuEtreModifie =>
      'L’événement n’a pas pu être modifié. Réessayez dans un instant.';

  @override
  String get calendarSemainePrecedente => 'Semaine précédente';

  @override
  String get calendarSemaineSuivante => 'Semaine suivante';

  @override
  String get calendarRienFiltres => 'Rien avec ces filtres';

  @override
  String get calendarFiltrePoseJourneeEntiere =>
      'Un filtre est posé : la journée entière porte peut-être autre chose.';

  @override
  String get calendarNiEvenementNiTache =>
      'Ni événement, ni tâche, ni créneau déclaré pour cette journée.';

  @override
  String get calendarCreerEvenement => 'Créer un événement';

  @override
  String get calendarModifierEvenement => 'Modifier l’événement';

  @override
  String get calendarSupprimerEvenement => 'Supprimer l’événement';

  @override
  String get calendarEvenementIntrouvable => 'Événement introuvable';

  @override
  String get calendarEteSupprimeAvezAcces =>
      'Il a été supprimé, ou vous n’y avez plus accès.';

  @override
  String get calendarNonPrecise => 'Non précisé';

  @override
  String get calendarReponse => 'Votre réponse';

  @override
  String get calendarPersonneEncoreEteConvie =>
      'Personne n’a encore été convié.';

  @override
  String get calendarEteSupprimeAvezAcces2 =>
      'Il a été supprimé, ou vous n’y avez plus accès. Il n’y a plus rien à confirmer.';

  @override
  String get calendarRevenirCalendrier => 'Revenir au calendrier';

  @override
  String get calendarMembre => 'Un membre';

  @override
  String get calendarConvieEvenement => 'vous convie à un événement';

  @override
  String get calendarPropos => 'À propos';

  @override
  String get calendarCetEvenementDejaEu => 'Cet événement a déjà eu lieu.';

  @override
  String get calendarSerez => 'Serez-vous là ?';

  @override
  String get calendarVoirDetailEvenement => 'Voir le détail de l’événement';

  @override
  String get calendarCreneauxDeclaresFondJournee =>
      'Les créneaux déclarés, en fond de journée. Ils ne dépendent d’aucun groupe.';

  @override
  String get calendarEvenementTache => 'Un événement, une tâche…';

  @override
  String get calendarDeuxLettresSuffisentChercher =>
      'Deux lettres suffisent à chercher.';

  @override
  String get calendarTitre => 'Titre *';

  @override
  String get calendarExDejeunerChezCamille => 'Ex. : Déjeuner chez Camille';

  @override
  String get calendarExPetitComptoir => 'Ex. : Le Petit Comptoir';

  @override
  String get calendarEffacerLieu => 'Effacer le lieu';

  @override
  String get calendarQuFautSavoirQu =>
      'Ce qu’il faut savoir, ce qu’il faut apporter';

  @override
  String get calendarInviterMembresGroupe => 'Inviter des membres du groupe';

  @override
  String get calendarJelvoPreviendraParticipants =>
      'Jelvo préviendra les participants';

  @override
  String get calendarRendezReguliers => 'Pour les rendez-vous réguliers';

  @override
  String get calendarEnregistrerModifications =>
      'Enregistrer les modifications';

  @override
  String get calendarCreerEvenement2 => 'Créer l’événement';

  @override
  String get calendarDate => 'Date *';

  @override
  String get calendarHeure => 'Heure *';

  @override
  String get calendarMembres => 'Tous les membres';

  @override
  String get calendarSelectionMembresGroupeConvies =>
      'Sans sélection, tous les membres du groupe sont conviés.';

  @override
  String get calendarDonnezTitreEvenement => 'Donnez un titre à l’événement.';

  @override
  String get calendarEvenementEteModifie => 'L’événement a été modifié.';

  @override
  String calendarEvenementTitreEteCree(Object titre) {
    return 'L’événement « $titre » a été créé.';
  }

  @override
  String get calendarQuelGroupe => 'Dans quel groupe ? *';

  @override
  String get calendarSeulVerrez => 'Vous seul le verrez';

  @override
  String get calendarQuelGroupe2 => 'Dans quel groupe ?';

  @override
  String chatMoMo(Object mo) {
    return '$mo Mo';
  }

  @override
  String chatOuiOui(Object oui) {
    return '$oui oui';
  }

  @override
  String chatPeutEtrePeutEtre(Object peutEtre) {
    return '$peutEtre peut-être';
  }

  @override
  String chatNonNon(Object non) {
    return '$non non';
  }

  @override
  String get chatAucuneReponse => 'Aucune réponse';

  @override
  String get chatQuelqu => 'Quelqu’un';

  @override
  String get chatMessagePuEtreEnvoye =>
      'Le message n’a pas pu être envoyé. Réessayez dans un instant.';

  @override
  String get chatConversationIndisponible => 'Conversation indisponible';

  @override
  String get chatRienEncore => 'Rien encore';

  @override
  String get chatLancezConversationPersonneEncore =>
      'Lancez la conversation : personne n’a encore écrit ici.';

  @override
  String chatReagirEmoji(Object emoji) {
    return 'Réagir $emoji';
  }

  @override
  String get chatSupprimerMessage => 'Supprimer le message';

  @override
  String get chatPouvezSupprimerMessages =>
      'Vous ne pouvez supprimer que vos messages';

  @override
  String get chatMessageSupprime => 'Message supprimé.';

  @override
  String get chatMessagePeutEtreSupprime =>
      'Ce message ne peut plus être supprimé.';

  @override
  String get chatNouvelleTache => 'Nouvelle tâche';

  @override
  String get chatCreerTacheFaire => 'Créer une tâche à faire';

  @override
  String get chatPlanifierEvenement => 'Planifier un événement';

  @override
  String get chatPhotoVideo => 'Photo ou vidéo';

  @override
  String get chatEnvoyerMedia => 'Envoyer un média';

  @override
  String get chatRienPrevuInstant => 'Rien de prévu pour l’instant';

  @override
  String get chatPhotoGalerie => 'Photo de la galerie';

  @override
  String get chatPrendrePhoto => 'Prendre une photo';

  @override
  String get chatVideoGalerie => 'Vidéo de la galerie';

  @override
  String get chatMediaPuEtreLu => 'Ce média n’a pas pu être lu. Réessayez.';

  @override
  String get chatNonEnvoyeReessayer => 'Non envoyé — réessayer';

  @override
  String get chatMessageSupprime2 => 'Message supprimé';

  @override
  String get chatTacheEteSupprimee => 'Cette tâche a été supprimée.';

  @override
  String get chatDesister => 'Me désister';

  @override
  String get chatProposeeGroupePersonneEncore =>
      'Proposée au groupe — personne ne l’a encore prise.';

  @override
  String get chatCetEvenementEteSupprime => 'Cet événement a été supprimé.';

  @override
  String get chatTresBienTacheReste =>
      'Très bien — la tâche reste proposée au groupe.';

  @override
  String get chatMicrophoneAccessibleAutorisezReglages =>
      'Le microphone n’est pas accessible. Autorisez-le dans les réglages de votre navigateur, puis rouvrez la conversation.';

  @override
  String get chatAjouterConversation => 'Ajouter à la conversation';

  @override
  String get chatMessage => 'Votre message';

  @override
  String get chatFermerEmojis => 'Fermer les emojis';

  @override
  String get chatEnregistrerMessageVocal => 'Enregistrer un message vocal';

  @override
  String get chatAnnulerEnregistrement => 'Annuler l’enregistrement';

  @override
  String get chatEnregistrement => 'Enregistrement…';

  @override
  String get chatEnvoyerMessageVocal => 'Envoyer le message vocal';

  @override
  String get chatPlusieursPersonnesTrainEcrire =>
      'Plusieurs personnes sont en train d’écrire…';

  @override
  String get chatMettrePause => 'Mettre en pause';

  @override
  String get contactsDemandeEnvoyee => 'Demande envoyée.';

  @override
  String get contactsPersonneFaitDejaPartie =>
      'Cette personne fait déjà partie de vos contacts.';

  @override
  String get contactsDemandeDejaAttente => 'Une demande est déjà en attente.';

  @override
  String get contactsPouvezAjouterMeme =>
      'Vous ne pouvez pas vous ajouter vous-même.';

  @override
  String get contactsQRCode => 'Mon QR code';

  @override
  String get contactsCherchezPseudo => 'Cherchez un pseudo';

  @override
  String get contactsSaisissezMoinsDeuxCaracteres =>
      'Saisissez au moins deux caractères pour trouver quelqu’un, ou scannez son QR code.';

  @override
  String get contactsRechercheIndisponible => 'Recherche indisponible';

  @override
  String get contactsAucunResultat => 'Aucun résultat';

  @override
  String contactsAucunPseudoCommenceTerm(Object term) {
    return 'Aucun pseudo ne commence par « $term ».';
  }

  @override
  String get contactsDejaCarnet => 'Déjà dans le carnet';

  @override
  String get contactsContacts => 'Mes contacts';

  @override
  String get contactsRechercherContact => 'Rechercher un contact';

  @override
  String get contactsDemandesRecues => 'Demandes reçues';

  @override
  String get contactsCarnetIndisponible => 'Carnet indisponible';

  @override
  String get contactsCarnetVide => 'Carnet vide';

  @override
  String get contactsAjoutezProchesLeurPseudo =>
      'Ajoutez vos proches par leur pseudo ou en scannant leur QR code pour planifier ensemble.';

  @override
  String contactsAucunContactCorrespondQuery(Object query) {
    return 'Aucun contact ne correspond à « $query ».';
  }

  @override
  String get contactsDemandeRefusee => 'Demande refusée.';

  @override
  String get contactsFaitesScannerCodeEtre =>
      'Faites scanner ce code pour être ajouté en contact. Il ne contient que votre pseudo — ni adresse e-mail, ni agenda.';

  @override
  String get contactsPartagerPseudo => 'Partager mon pseudo';

  @override
  String get contactsPseudoJelvo => 'Mon pseudo Jelvo';

  @override
  String get contactsScannerQRCode => 'Scanner un QR code';

  @override
  String get contactsScanIndisponibleIci => 'Scan indisponible ici';

  @override
  String get contactsChercherPseudo => 'Chercher par pseudo';

  @override
  String get contactsCameraInaccessible => 'Caméra inaccessible';

  @override
  String get contactsAutorisezAccesCameraScanner =>
      'Autorisez l’accès à la caméra pour scanner un QR code.';

  @override
  String get contactsVisezQRCodeProche =>
      'Visez le QR code d’un proche pour lui envoyer une demande de contact.';

  @override
  String get contactsQRCodeProfilJelvo =>
      'Ce QR code n’est pas un profil Jelvo.';

  @override
  String contactsAucunComptePortePseudo(Object pseudo) {
    return 'Aucun compte ne porte le pseudo @$pseudo.';
  }

  @override
  String get contactsScannerQRCode2 => 'Scanner un QR Code';

  @override
  String get contactsAjouterContactQRCode =>
      'Ajouter un contact avec son QR Code';

  @override
  String get contactsRechercherPseudo => 'Rechercher un pseudo';

  @override
  String get contactsTrouverUtilisateurJelvo => 'Trouver un utilisateur Jelvo';

  @override
  String get contactsInviterAmi => 'Inviter un ami';

  @override
  String get contactsEnvoyerInvitationJelvo => 'Envoyer une invitation Jelvo';

  @override
  String get contactsRejoignezMoiJelvo => 'Rejoignez-moi sur Jelvo';

  @override
  String get contactsRetirerFavoris => 'Retirer des favoris';

  @override
  String get contactsAjouterFavoris => 'Ajouter aux favoris';

  @override
  String get contactsFavorisTeteCarnet =>
      'Les favoris sont en tête de votre carnet';

  @override
  String get contactsRetirerContacts => 'Retirer de mes contacts';

  @override
  String get contactsRelationSupprimeeDeuxCotes =>
      'La relation est supprimée des deux côtés';

  @override
  String get contactsRetirerContact => 'Retirer ce contact';

  @override
  String get contactsGererFavoris => 'Gérer les favoris';

  @override
  String get contactsFavoriPersonnelAutreSait =>
      'Le favori est personnel : l’autre n’en sait rien.';

  @override
  String get contactsAjoutezAbordContactsEpingler =>
      'Ajoutez d’abord des contacts à épingler.';

  @override
  String get contactsEpinglezProchesRetrouverIci =>
      'Épinglez vos proches pour les retrouver ici.';

  @override
  String get contactsScanQRCodeDemande =>
      'Le scan de QR code demande une caméra : il est disponible sur l’application mobile. Ici, cherchez la personne par son pseudo.';

  @override
  String get createCreneauAgendaSeulPartage =>
      'Un créneau dans votre agenda, seul ou partagé';

  @override
  String get createActionFaireEcheanceResponsable =>
      'Une action à faire, avec échéance et responsable';

  @override
  String get createEspacePartageProchesAmis =>
      'Un espace partagé avec vos proches ou vos amis';

  @override
  String get createChoisissezTypeFormulaireOuvre =>
      'Choisissez un type : le formulaire s’ouvre juste en dessous.';

  @override
  String get groupsLienInvitationExisteValable =>
      'Ce lien d’invitation n’existe pas ou n’est plus valable.';

  @override
  String get groupsLienInvitationExpireDemandez =>
      'Ce lien d’invitation a expiré. Demandez-en un nouveau au groupe.';

  @override
  String get groupsLienInvitationEteRevoque =>
      'Ce lien d’invitation a été révoqué par le groupe.';

  @override
  String get groupsLienDejaServiNombre =>
      'Ce lien a déjà servi au nombre de fois prévu.';

  @override
  String get groupsAvezRejointGroupe => 'Vous avez rejoint le groupe.';

  @override
  String get groupsFaitesDejaPartieGroupe =>
      'Vous faites déjà partie de ce groupe.';

  @override
  String get groupsLienInvitationExpire => 'Ce lien d’invitation a expiré.';

  @override
  String get groupsLienInvitationEteRevoque2 =>
      'Ce lien d’invitation a été révoqué.';

  @override
  String get groupsConnectezRejoindreGroupe =>
      'Connectez-vous pour rejoindre ce groupe.';

  @override
  String get groupsAvezQuitteGroupe => 'Vous avez quitté le groupe.';

  @override
  String get groupsAvezQuitteGroupeAncien =>
      'Vous avez quitté le groupe. Le plus ancien membre en devient admin.';

  @override
  String get groupsEtiezDernierMembreGroupe =>
      'Vous étiez le dernier membre : le groupe a été supprimé.';

  @override
  String get groupsFaitesPartieGroupe =>
      'Vous ne faites pas partie de ce groupe.';

  @override
  String groupsNomDesormaisAdministrateur(Object nom) {
    return '$nom est désormais administrateur.';
  }

  @override
  String groupsNomAdministrateur(Object nom) {
    return '$nom n’est plus administrateur.';
  }

  @override
  String groupsNomEteRetireGroupe(Object nom) {
    return '$nom a été retiré du groupe.';
  }

  @override
  String groupsAdhesionNomDesormaisTemporaire(Object nom) {
    return 'L’adhésion de $nom est désormais temporaire.';
  }

  @override
  String groupsNomFaitPartieGroupe(Object nom, Object terme) {
    return '$nom fait partie du groupe jusqu’au $terme.';
  }

  @override
  String groupsAdhesionNomTerme(Object nom) {
    return 'L’adhésion de $nom n’a plus de terme.';
  }

  @override
  String get groupsEtaitDejaCasRien => 'C’était déjà le cas, rien n’a changé.';

  @override
  String get groupsDateDejaPasseeDepart =>
      'Cette date est déjà passée. Pour un départ immédiat, utilisez « Retirer du groupe ».';

  @override
  String groupsNomDejaAdministrateur(Object nom) {
    return '$nom est déjà administrateur.';
  }

  @override
  String get groupsGroupeDoitGarderMoins =>
      'Un groupe doit garder au moins un administrateur. Nommez quelqu’un d’autre avant.';

  @override
  String get groupsSeulAdministrateurGroupePeut =>
      'Seul un administrateur du groupe peut faire cela.';

  @override
  String groupsNomAdministrateur2(Object nom) {
    return '$nom n’est pas administrateur.';
  }

  @override
  String groupsNomFaitPartieGroupe2(Object nom) {
    return '$nom ne fait plus partie du groupe.';
  }

  @override
  String get groupsPartirMemeUtilisezQuitter =>
      'Pour partir vous-même, utilisez « Quitter le groupe ».';

  @override
  String get groupsActionAboutiReessayezInstant =>
      'L’action n’a pas abouti. Réessayez dans un instant.';

  @override
  String get groupsJamaisUtilise => 'Jamais utilisé';

  @override
  String get groupsInvitationDejaAcceptee => 'Invitation déjà acceptée';

  @override
  String get groupsInvitationDejaRefusee => 'Invitation déjà refusée';

  @override
  String get groupsInvitationExpiree => 'Invitation expirée';

  @override
  String get groupsEtesDejaMembre => 'Vous êtes déjà membre';

  @override
  String get groupsGroupeSupprime => 'Groupe supprimé';

  @override
  String get groupsInvitationIntrouvable => 'Invitation introuvable';

  @override
  String get groupsAvezDejaRejointGroupe =>
      'Vous avez déjà rejoint ce groupe. Ouvrez-le pour y retrouver ses événements, ses tâches et sa conversation.';

  @override
  String get groupsAvezDeclineInvitationDemandez =>
      'Vous avez décliné cette invitation. Demandez-en une nouvelle si vous changez d’avis.';

  @override
  String get groupsInvitationPasseDateLimite =>
      'Cette invitation a passé sa date limite. Demandez-en une nouvelle au groupe.';

  @override
  String get groupsFaitesDejaPartieGroupe2 =>
      'Vous faites déjà partie de ce groupe, sans doute par un lien de partage.';

  @override
  String get groupsGroupeInvitaitEteSupprime =>
      'Le groupe qui vous invitait a été supprimé. Il n’y a plus rien à rejoindre.';

  @override
  String get groupsInvitationExisteEtaitDestinee =>
      'Cette invitation n’existe pas, ou elle ne vous était pas destinée.';

  @override
  String get groupsGroupe => 'ce groupe';

  @override
  String get groupsGroupePuEtreCree =>
      'Le groupe n’a pas pu être créé. Réessayez dans un instant.';

  @override
  String get groupsGroupeIndisponible => 'Groupe indisponible';

  @override
  String get groupsGroupeIntrouvable => 'Groupe introuvable';

  @override
  String get groupsGroupeEteSupprimeFaites =>
      'Ce groupe a été supprimé, ou vous n’en faites plus partie.';

  @override
  String get groupsRevenirGroupes => 'Revenir aux groupes';

  @override
  String get groupsInviterQuelqu => 'Inviter quelqu’un';

  @override
  String get groupsPartagerLien => 'Partager un lien';

  @override
  String get groupsModifierGroupe => 'Modifier le groupe';

  @override
  String get groupsQuitterGroupe => 'Quitter le groupe';

  @override
  String get groupsSupprimerGroupe => 'Supprimer le groupe';

  @override
  String get groupsAucunMembreAfficher => 'Aucun membre à afficher';

  @override
  String get groupsListeMembresPuEtre =>
      'La liste des membres n’a pas pu être chargée. Réessayez dans un instant.';

  @override
  String get groupsVoir => 'Voir tout';

  @override
  String get groupsAjouterEvenement => 'Ajouter un événement';

  @override
  String get groupsTachesPrioritaires => 'Tâches prioritaires';

  @override
  String get groupsRetirerMembre => 'Retirer ce membre';

  @override
  String get groupsGroupeEteSupprime => 'Le groupe a été supprimé.';

  @override
  String get groupsDecrivezGroupePhrase => 'Décrivez ce groupe en une phrase.';

  @override
  String get groupsInviterMembre => 'Inviter un membre';

  @override
  String get groupsCherchezPersonnePseudoRecevra =>
      'Cherchez la personne par son pseudo. Elle recevra une invitation à accepter.';

  @override
  String groupsNameRecuInvitation(Object name) {
    return '$name a reçu votre invitation.';
  }

  @override
  String groupsNameFaitDejaPartie(Object name) {
    return '$name fait déjà partie du groupe.';
  }

  @override
  String groupsNameDejaInvitationAttente(Object name) {
    return '$name a déjà une invitation en attente.';
  }

  @override
  String get groupsDateFinChoisieDeja =>
      'La date de fin choisie est déjà passée.';

  @override
  String get groupsSeulAdministrateurPeutFixer =>
      'Seul un administrateur peut fixer une durée d’adhésion.';

  @override
  String get groupsSeulsMembresGroupePeuvent =>
      'Seuls les membres du groupe peuvent inviter.';

  @override
  String get groupsSaisissezMoinsDeuxCaracteres =>
      'Saisissez au moins deux caractères.';

  @override
  String get groupsCreezGroupeInvitezPremiers =>
      'Créez votre groupe et invitez les premiers membres.';

  @override
  String get groupsPhotoGroupe => 'Photo du groupe';

  @override
  String get groupsNomGroupe => 'Nom du groupe *';

  @override
  String get groupsExFamilleRousseau => 'Ex. : Famille Rousseau';

  @override
  String get groupsDescriptionOptionnelle => 'Description (optionnelle)';

  @override
  String get groupsDecrivezBrievementButGroupe =>
      'Décrivez brièvement le but de ce groupe';

  @override
  String get groupsCreerGroupe => 'Créer le groupe';

  @override
  String get groupsDonnezNomGroupe => 'Donnez un nom à votre groupe.';

  @override
  String groupsNomDoitDepasserNameMaxLength(Object _nameMaxLength) {
    return 'Le nom ne doit pas dépasser $_nameMaxLength caractères.';
  }

  @override
  String get groupsGroupeCree1Invitation =>
      'Groupe créé, 1 invitation envoyée.';

  @override
  String groupsGroupeCreeEnvoyeesInvitations(Object envoyees) {
    return 'Groupe créé, $envoyees invitations envoyées.';
  }

  @override
  String get groupsGroupeCreeMaisInvitation =>
      'Groupe créé, mais l’invitation n’a pas pu partir.';

  @override
  String groupsGroupeCreeMaisAucune(Object echecs) {
    return 'Groupe créé, mais aucune des $echecs invitations n’a pu partir.';
  }

  @override
  String groupsGroupeCreeEnvoyeesInvitation(Object envoyees, Object echecs) {
    return 'Groupe créé, $envoyees invitation(s) envoyée(s), $echecs non parties.';
  }

  @override
  String get groupsGroupePrive => 'Groupe privé';

  @override
  String get groupsSeulsMembresInvitesPourront =>
      'Seuls les membres invités pourront le rejoindre et voir son contenu. Tous les groupes Jelvo le sont.';

  @override
  String get groupsRechercherGroupe => 'Rechercher un groupe';

  @override
  String get groupsEffacerRecherche => 'Effacer la recherche';

  @override
  String get groupsGroupesIndisponibles => 'Groupes indisponibles';

  @override
  String get groupsAucunGroupeMoment => 'Aucun groupe pour le moment';

  @override
  String get groupsCreezGroupePartagerAgenda =>
      'Créez un groupe pour partager un agenda et répartir les tâches avec vos proches.';

  @override
  String get groupsCreerGroupe2 => 'Créer un groupe';

  @override
  String get groupsAucunGroupeNom => 'Aucun groupe à ce nom';

  @override
  String groupsAucunGroupesCorrespondTerme(Object terme) {
    return 'Aucun de vos groupes ne correspond à « $terme ».';
  }

  @override
  String get groupsInviteRejoindreGroupe =>
      'On vous a invité à rejoindre un groupe.';

  @override
  String get groupsInvitationsIndisponibles => 'Invitations indisponibles';

  @override
  String get groupsAucuneInvitation => 'Aucune invitation';

  @override
  String get groupsQuandProcheInviteraGroupe =>
      'Quand un proche vous invitera dans un groupe, l’invitation apparaîtra ici.';

  @override
  String get groupsInvitationIndisponible => 'Invitation indisponible';

  @override
  String get groupsInviteRejoindreGroupe2 =>
      'vous invite à rejoindre un groupe';

  @override
  String get groupsCree => 'Créé le';

  @override
  String get groupsDejaGroupe => 'Déjà dans le groupe';

  @override
  String get groupsInvitationRefusee => 'Invitation refusée.';

  @override
  String get groupsOuvrirGroupe => 'Ouvrir le groupe';

  @override
  String get groupsLienInutilisable => 'Lien inutilisable';

  @override
  String get groupsRevenirAccueil => 'Revenir à l\'accueil';

  @override
  String get groupsEtesInviteRejoindreGroupe =>
      'Vous êtes invité à rejoindre ce groupe sur Jelvo.';

  @override
  String get groupsRejoindreGroupe => 'Rejoindre le groupe';

  @override
  String get groupsCreerCompteRejoindre => 'Créer un compte pour rejoindre';

  @override
  String get groupsAiDejaCompte => 'J\'ai déjà un compte';

  @override
  String get groupsGroupeSeraRejointAutomatiquement =>
      'Le groupe sera rejoint automatiquement une fois votre compte créé.';

  @override
  String get groupsCreezIciSeraPartage =>
      'Ce que vous créez ici sera partagé avec le groupe.';

  @override
  String get groupsDateProposerMembres => 'Une date à proposer aux membres';

  @override
  String get groupsQuelqueChoseFaireRepartir =>
      'Quelque chose à faire, à répartir';

  @override
  String get groupsAjouterMembres => 'Ajouter des membres';

  @override
  String get groupsChoisirContacts => 'Choisir dans mes contacts';

  @override
  String get groupsParcourirCarnetJelvo => 'Parcourir mon carnet Jelvo';

  @override
  String get groupsInviterLien => 'Inviter par lien';

  @override
  String get groupsProposeApresCreation => 'Proposé après la création';

  @override
  String get groupsPartagerLienInvitation => 'Partager un lien d’invitation';

  @override
  String get groupsInvitationsPartentCreationGroupe =>
      'Les invitations partent à la création du groupe.';

  @override
  String get groupsAucunContactNom => 'Aucun contact à ce nom.';

  @override
  String get groupsPersonneInviteInstant =>
      'Personne n’est invité pour l’instant.';

  @override
  String get groups1PersonneSeraInvitee => '1 personne sera invitée.';

  @override
  String groupsNombrePersonnesSerontInvitees(Object nombre) {
    return '$nombre personnes seront invitées.';
  }

  @override
  String get groupsRetirer => 'Tout retirer';

  @override
  String get groupsCarnetVideInstantPourrez =>
      'Votre carnet est vide pour l’instant. Vous pourrez inviter depuis l’écran du groupe, par lien de partage ou par pseudo.';

  @override
  String get groupsChoisirPhotoGroupe => 'Choisir une photo de groupe';

  @override
  String get groupsChangerPhoto => 'Changer la photo';

  @override
  String get groupsAjouterPhoto => 'Ajouter une photo';

  @override
  String get groupsTachesNenRetard => 'tâches\nen retard';

  @override
  String get groupsEvenementsNaVenir => 'événements\nà venir';

  @override
  String get groupsAucunLienActifMoment => 'Aucun lien actif pour le moment.';

  @override
  String get groupsDureeAccordeeProchainLien =>
      'Durée accordée par le prochain lien';

  @override
  String get groupsGenererLien => 'Générer un lien';

  @override
  String get groupsGenererAutreLien => 'Générer un autre lien';

  @override
  String get groupsLienCopiePressePapiers =>
      'Lien copié dans le presse-papiers.';

  @override
  String get groupsCopierLien => 'Copier le lien';

  @override
  String get groupsRevoquerLien => 'Révoquer le lien';

  @override
  String get groupsGererMembre => 'Gérer ce membre';

  @override
  String get groupsRetirerRoleAdministrateur =>
      'Retirer le rôle d’administrateur';

  @override
  String get groupsNommerAdministrateur => 'Nommer administrateur';

  @override
  String get groupsModifierDureeAdhesion => 'Modifier la durée de l’adhésion';

  @override
  String get groupsRendreAdhesionTemporaire => 'Rendre l’adhésion temporaire';

  @override
  String get groupsRetirerGroupe => 'Retirer du groupe';

  @override
  String get groupsDureeAdhesion => 'Durée de l’adhésion';

  @override
  String get groupsTerme => 'Sans terme';

  @override
  String get groupsFinAdhesion => 'Fin de l’adhésion';

  @override
  String get groupsNouvelleDuree => 'Nouvelle durée';

  @override
  String get homeBonApresMidi => 'Bon après-midi';

  @override
  String get homeCreezGroupePartagerAgenda =>
      'Créez un groupe pour partager un agenda, des tâches et une conversation.';

  @override
  String homeBasePrenom(Object base, Object prenom) {
    return '$base $prenom';
  }

  @override
  String get homeAgenda => 'Mon agenda';

  @override
  String get homeVoirCalendrier => 'Voir calendrier';

  @override
  String get homeVoirAgenda1 => 'Voir tout mon agenda (1 de plus)';

  @override
  String homeVoirAgendaReste(Object reste) {
    return 'Voir tout mon agenda ($reste de plus)';
  }

  @override
  String get homeTaches => 'Mes tâches';

  @override
  String get homeVoirToutesTaches => 'Voir toutes mes tâches';

  @override
  String get home1Tache => '1 tâche';

  @override
  String get homeSemaine => 'cette semaine';

  @override
  String get homeTraiter => 'à traiter';

  @override
  String get homeAucuneTacheAttendEtre =>
      'Aucune tâche n’attend d’être traitée.';

  @override
  String get homeDejaAgenda => 'Déjà dans votre agenda';

  @override
  String get homeTachesJourFigurentChronologie =>
      'Vos tâches du jour figurent dans la chronologie ci-dessus.';

  @override
  String homeValeurLibelleDetail(Object valeur, Object libelle, Object detail) {
    return '$valeur $libelle, $detail';
  }

  @override
  String homeValeurLibelle(Object valeur, Object libelle) {
    return '$valeur $libelle';
  }

  @override
  String get homeAujourdHui => ', aujourd\'hui';

  @override
  String get homeRienPrevu => ', rien de prévu';

  @override
  String get notificationsGroupe => 'un groupe';

  @override
  String get notificationsContact => 'Un contact';

  @override
  String get notificationsEvenement => 'un événement';

  @override
  String get notificationsTache => 'une tâche';

  @override
  String notificationsInvitationRejoindreGroupName(Object groupName) {
    return 'Invitation à rejoindre $groupName';
  }

  @override
  String get notificationsDemandeContact => 'Demande de contact';

  @override
  String notificationsSenderNameInviteRejoindreGroupName(
    Object senderName,
    Object groupName,
  ) {
    return '$senderName vous invite à rejoindre « $groupName ».';
  }

  @override
  String notificationsSenderNameSouhaiteAjouterContacts(Object senderName) {
    return '$senderName souhaite vous ajouter à ses contacts.';
  }

  @override
  String notificationsSenderNameConfieTache(Object senderName) {
    return '$senderName vous a confié cette tâche.';
  }

  @override
  String notificationsSenderNameAccepteTache(Object senderName) {
    return '$senderName accepte cette tâche.';
  }

  @override
  String notificationsSenderNameDeclineTache(Object senderName) {
    return '$senderName décline cette tâche.';
  }

  @override
  String get notificationsFeteAnniversaireAujourdHui =>
      'fête son anniversaire aujourd’hui.';

  @override
  String get notificationsAvezNouvelleNotification =>
      'Vous avez une nouvelle notification.';

  @override
  String get notificationsVoirDemande => 'Voir la demande';

  @override
  String get notificationsVoirEvenement => 'Voir l’événement';

  @override
  String get notificationsVoirTache => 'Voir la tâche';

  @override
  String get notificationsGroupesDiscussions => 'Groupes et discussions';

  @override
  String get notificationsTachesRappels => 'Tâches et rappels';

  @override
  String get notificationsMarquerCommeLu => 'Tout marquer comme lu';

  @override
  String get notificationsNotificationsIndisponibles =>
      'Notifications indisponibles';

  @override
  String get notificationsAucuneNotification => 'Aucune notification';

  @override
  String get notificationsInvitationsGroupeDemandesContact =>
      'Les invitations à un groupe et les demandes de contact apparaîtront ici.';

  @override
  String get notificationsNotificationsPush => 'Notifications push';

  @override
  String get notificationsInstaller => 'À installer';

  @override
  String get notificationsActiverNotifications => 'Activer les notifications';

  @override
  String get notificationsDesactiverCetAppareil =>
      'Désactiver sur cet appareil';

  @override
  String get notificationsNotificationsActives => 'Notifications actives';

  @override
  String get notificationsNotificationsRefusees => 'Notifications refusées';

  @override
  String get notificationsInstallezJelvoRecevoir =>
      'Installez Jelvo pour les recevoir';

  @override
  String get notificationsNotificationsDesactivees =>
      'Notifications désactivées';

  @override
  String get notificationsNotificationsIndisponiblesIci =>
      'Notifications indisponibles ici';

  @override
  String get notificationsCetAppareilRecevraNotifications =>
      'Cet appareil recevra les notifications que vous laissez cochées que vous laissez cochées dans les paramètres.';

  @override
  String get notificationsAvezRefuseAutorisationApplication =>
      'Vous avez refusé l’autorisation. L’application ne peut plus la redemander : elle se rouvre dans les réglages de votre navigateur, à la ligne « Notifications » du site.';

  @override
  String get notificationsIPhoneIPadNotificationsExistent =>
      'Sur iPhone et iPad, les notifications n’existent que dans Jelvo ajouté à l’écran d’accueil. Dans un onglet Safari, le système ne les propose pas du tout.';

  @override
  String get notificationsNavigateurDemanderaAutorisationPourrez =>
      'Votre navigateur vous demandera l’autorisation. Vous pourrez revenir dessus à tout moment.';

  @override
  String get notificationsVersionApplicationGereNotifications =>
      'Cette version de l’application ne gère pas les notifications système.';

  @override
  String get notificationsAutorisationRefuseeRouvreReglages =>
      'Autorisation refusée. Elle se rouvre dans les réglages de votre navigateur, pas ici.';

  @override
  String get notificationsNotificationsOntPuEtre =>
      'Les notifications n’ont pas pu être activées.';

  @override
  String get notificationsNotificationsDesactiveesCetAppareil =>
      'Notifications désactivées sur cet appareil.';

  @override
  String get notifications1TouchezBoutonPartager =>
      '1. Touchez le bouton Partager de Safari.';

  @override
  String get notifications2ChoisissezEcranAccueil =>
      '2. Choisissez « Sur l’écran d’accueil ».';

  @override
  String get notifications3OuvrezJelvoDepuis =>
      '3. Ouvrez Jelvo depuis l’icône, puis reconnectez-vous.';

  @override
  String get notificationsReconnexionErreurApplicationInstallee =>
      'La reconnexion n’est pas une erreur : l’application installée a son propre stockage, distinct de Safari.';

  @override
  String get onboardingBienvenueJelvo => 'Bienvenue sur Jelvo';

  @override
  String get onboardingAppRassembleGroupesProjets =>
      'L’app qui rassemble vos groupes, vos projets et vos proches.';

  @override
  String get onboardingGroupesMemeEndroit => 'Tous vos groupes au même endroit';

  @override
  String get onboardingOrganisezProjetsActivitesEchanges =>
      'Organisez vos projets, activités et échanges facilement.';

  @override
  String get onboardingAgendaPartageSynchronise =>
      'Un agenda partagé et synchronisé';

  @override
  String get onboardingManquezAucunEvenementImportant =>
      'Ne manquez plus aucun événement important.';

  @override
  String get onboardingTachesClairesEfficaces =>
      'Des tâches claires et efficaces';

  @override
  String get onboardingAttribuezSuivezAccomplissezEnsemble =>
      'Attribuez, suivez et accomplissez ensemble vos objectifs.';

  @override
  String get profileProposJelvo => 'À propos de Jelvo';

  @override
  String get profileJelvoReunitGroupesEvenements =>
      'Jelvo réunit vos groupes, vos événements, vos tâches et vos disponibilités au même endroit — pour la famille, les amis, la colocation.';

  @override
  String get profileBonSavoir => 'Bon à savoir';

  @override
  String get profileJelvoApplicationWebInstallable =>
      'Jelvo est une application web installable. Sur iPhone, les notifications ne fonctionnent qu’une fois l’icône ajoutée à l’écran d’accueil, et l’application installée a sa propre session : il faut s’y reconnecter.';

  @override
  String get profileChoisirAvatar => 'Choisir un avatar';

  @override
  String get profileUtiliserCetAvatar => 'Utiliser cet avatar';

  @override
  String profileAvatarId(Object id) {
    return 'Avatar $id';
  }

  @override
  String get profileChangerMotPasse => 'Changer de mot de passe';

  @override
  String get profileMotPasseChange => 'Mot de passe changé.';

  @override
  String get profileModifierProfil => 'Modifier le profil';

  @override
  String get profileProfilEnregistre => 'Profil enregistré.';

  @override
  String get profileProfil => 'Mon profil';

  @override
  String get profileProfilIndisponible => 'Profil indisponible';

  @override
  String get profileProfilIntrouvable => 'Profil introuvable';

  @override
  String get profileProfilEncoreEteCree =>
      'Votre profil n’a pas encore été créé. Reconnectez-vous pour le finaliser.';

  @override
  String get profileProfilJelvo => 'Mon profil Jelvo';

  @override
  String get profileAutresVoientQuMot =>
      'Les autres n’y voient qu’un mot : disponible, indisponible ou inconnu.';

  @override
  String get profileLectureAboutiReessayezInstant =>
      'La lecture n’a pas abouti. Réessayez dans un instant.';

  @override
  String get profilePersonneCompteJelvo =>
      'Cette personne n’a plus de compte Jelvo.';

  @override
  String get profileAnnulerDemande => 'Annuler la demande';

  @override
  String get profileAjouterContact => 'Ajouter en contact';

  @override
  String get profileRetirerContact => 'Retirer ce contact ?';

  @override
  String get profileActionAbouti => 'L’action n’a pas abouti.';

  @override
  String get profileInformationsPersonnelles => 'Informations personnelles';

  @override
  String get profileDeconnecter => 'Se déconnecter';

  @override
  String get profileDevrezSaisirNouveauIdentifiants =>
      'Vous devrez saisir à nouveau vos identifiants pour revenir.';

  @override
  String get profileJourMoisSeulementJelvo =>
      'Le jour et le mois seulement. Jelvo ne demande pas votre année de naissance.';

  @override
  String get profileContactsVoientPrevenusJour =>
      'Vos contacts le voient, et sont prévenus le jour même.';

  @override
  String get profileAnneesNonBissextilesSera =>
      'Les années non bissextiles, il sera fêté le 28 février, dernier jour du mois.';

  @override
  String get profileSuitReglageTelephone =>
      'Suit le réglage de votre téléphone';

  @override
  String get profileFondBlancTexteSombre => 'Fond blanc, texte sombre';

  @override
  String get profileFondSombreTexteClair => 'Fond sombre, texte clair';

  @override
  String get profileChoixVautCetAppareil =>
      'Ce choix ne vaut que sur cet appareil.';

  @override
  String get profilePhotoProfil => 'Photo de profil';

  @override
  String get profileChoisirPhoto => 'Choisir une photo';

  @override
  String get profileDepuisPhotosAppareil =>
      'Depuis les photos de votre appareil';

  @override
  String get profileChoisirAvatarJelvo => 'Choisir un avatar Jelvo';

  @override
  String get profileQuatreVingtTreizeIllustrations =>
      'Quatre-vingt-treize illustrations au choix';

  @override
  String get profileInitialesPrendrontPlace =>
      'Vos initiales prendront la place';

  @override
  String get profileAjoutezJourMoisAnnee =>
      'Ajoutez le jour et le mois, sans l’année';

  @override
  String get profileAdresseIndisponible => 'Adresse indisponible';

  @override
  String get profileQuelquesMots => 'Quelques mots sur vous';

  @override
  String get profileAjoutezQuelquesMots => 'Ajoutez quelques mots sur vous';

  @override
  String get profileEnregistrerBio => 'Enregistrer la bio';

  @override
  String get profileModifierBio => 'Modifier la bio';

  @override
  String get profileChangerPhoto => 'Changer de photo';

  @override
  String get profileChangerPhotoProfil => 'Changer de photo de profil';

  @override
  String get profileQRCode => 'QR Code';

  @override
  String get profilePartagerProfil => 'Partager profil';

  @override
  String get profileStatistiques => 'Mes statistiques';

  @override
  String get profileTachesTerminees => 'Tâches terminées';

  @override
  String get profile1GroupeCommun => '1 groupe en commun';

  @override
  String get profileOrganisezRienEnsembleInstant =>
      'Vous n’organisez rien ensemble pour l’instant.';

  @override
  String get tasksAvezPrisTache => 'Vous avez pris cette tâche.';

  @override
  String get tasksAvezRenduTacheGroupe =>
      'Vous avez rendu cette tâche au groupe.';

  @override
  String get tasksQuelquVientPrendreAvant =>
      'Quelqu’un vient de la prendre avant vous.';

  @override
  String get tasksTache => 'Cette tâche n’est pas la vôtre.';

  @override
  String get tasksTacheEteConfieeRefusez =>
      'Cette tâche vous a été confiée : refusez-la plutôt que de la rendre.';

  @override
  String get tasksFaitesPartieGroupe =>
      'Vous ne faites plus partie de ce groupe.';

  @override
  String get tasksTachePuEtreCreee =>
      'La tâche n’a pas pu être créée. Réessayez dans un instant.';

  @override
  String get tasksTachePuEtreModifiee =>
      'La tâche n’a pas pu être modifiée. Réessayez dans un instant.';

  @override
  String get tasksTacheConfiee => 'Tâche confiée';

  @override
  String get tasksTacheIntrouvable => 'Tâche introuvable';

  @override
  String get tasksEteSupprimeeAvezAcces =>
      'Elle a été supprimée, ou vous n’y avez plus accès. Il n’y a plus rien à accepter.';

  @override
  String get tasksRevenirAccueil => 'Revenir à l’accueil';

  @override
  String get tasksTacheEteConfiee => 'Cette tâche vous a été confiée';

  @override
  String get tasksConfieTache => 'vous a confié une tâche';

  @override
  String get tasksAssignee => 'Assignée à';

  @override
  String get tasksEcheanceDejaPassee => 'L’échéance est déjà passée.';

  @override
  String get tasksAvezAccepteTache => 'Vous avez accepté cette tâche.';

  @override
  String get tasksAvezDeclineTache => 'Vous avez décliné cette tâche.';

  @override
  String get tasksAvezTerminePart => 'Vous avez terminé votre part.';

  @override
  String get tasksTacheAssignee => 'Cette tâche ne vous est pas assignée.';

  @override
  String get tasksOuvrirTache => 'Ouvrir la tâche';

  @override
  String get tasksTacheAcceptee => 'Tâche acceptée.';

  @override
  String get tasksTacheDeclinee => 'Tâche déclinée.';

  @override
  String get tasksModifierTache => 'Modifier la tâche';

  @override
  String get tasksSupprimerTache => 'Supprimer la tâche';

  @override
  String get tasksEteSupprimeeAvezAcces2 =>
      'Elle a été supprimée, ou vous n’y avez plus accès.';

  @override
  String get tasksPersonneInstantImporteQuel =>
      'Personne pour l’instant. N’importe quel membre du groupe peut s’en charger.';

  @override
  String get tasksRetirer => 'Me retirer';

  @override
  String get tasksJeMCharge => 'Je m’en charge';

  @override
  String get tasksChargezTache => 'Vous vous chargez de cette tâche.';

  @override
  String get tasksChargiezDeja => 'Vous vous en chargiez déjà.';

  @override
  String get tasksChargez => 'Vous ne vous en chargez plus.';

  @override
  String get tasksEtiezAssigneTache =>
      'Vous n’étiez pas assigné à cette tâche.';

  @override
  String get tasksQuelquChargeDejaPassez =>
      'Quelqu’un s’en charge déjà. Passez par « Modifier » pour changer les assignés.';

  @override
  String get tasksRienCocherAjoutezQu =>
      'Rien à cocher. Ajoutez ce qu’il faut prendre : chacun verra ce qui reste.';

  @override
  String get tasksAjouterArticle => 'Ajouter un article';

  @override
  String get tasksAjouterListe => 'Ajouter à la liste';

  @override
  String get tasksRetirerListe => 'Retirer de la liste';

  @override
  String get tasksRouvrirTache => 'Rouvrir la tâche';

  @override
  String get tasksMarquerCommeTerminee => 'Marquer comme terminée';

  @override
  String get tasksTachesIndisponibles => 'Tâches indisponibles';

  @override
  String get tasksAucuneTache => 'Aucune tâche';

  @override
  String get tasksFaitRienEncoreEte =>
      'Tout est fait — ou rien n’a encore été noté.';

  @override
  String get tasksGroupeAucuneTacheInstant =>
      'Ce groupe n’a aucune tâche pour l’instant.';

  @override
  String get tasksAssigner => 'Assigner à';

  @override
  String get tasksMembresGroupeOntEncore =>
      'Les membres du groupe n’ont pas encore été chargés.';

  @override
  String get tasksExAcheterPain => 'Ex. : Acheter le pain';

  @override
  String get tasksJelvoEnverraNotificationPersonne =>
      'Jelvo enverra une notification à la personne assignée';

  @override
  String get tasksTachesRecurrentes => 'Pour les tâches récurrentes';

  @override
  String get tasksCreerTache => 'Créer la tâche';

  @override
  String get tasksProposeeGroupeCarteAffichera =>
      'Proposée à tout le groupe : une carte s’affichera dans la conversation, et le premier qui accepte la prend.';

  @override
  String tasksConfieeListeRecevraNotification(Object liste) {
    return 'Confiée à $liste, qui recevra une notification.';
  }

  @override
  String tasksConfieeListeRecevrontNotification(Object liste) {
    return 'Confiée à $liste, qui recevront une notification.';
  }

  @override
  String get tasksEcheancePrioriteDescription =>
      'Échéance, priorité, description…';

  @override
  String get tasksQuFautSavoirOccuper =>
      'Ce qu’il faut savoir pour s’en occuper';

  @override
  String get tasksDonnezTitreTache => 'Donnez un titre à la tâche.';

  @override
  String get tasksTacheEteModifiee => 'La tâche a été modifiée.';

  @override
  String tasksTacheTitreEteCreee(Object titre) {
    return 'La tâche « $titre » a été créée.';
  }

  @override
  String get routerPageIntrouvable => 'Page introuvable';

  @override
  String routerAucunEcranCorrespondLocation(Object location) {
    return 'Aucun écran ne correspond à « $location ».';
  }

  @override
  String get calendarRecurrenceJamais => 'Jamais';

  @override
  String get calendarRappelAucun => 'Aucun';

  @override
  String get coreDemain => 'Demain';

  @override
  String get coreHier => 'Hier';

  @override
  String coreIlYaMinutes(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String coreIlYaHeures(int heures) {
    return 'il y a $heures h';
  }

  @override
  String coreIlYaJours(int jours) {
    String _temp0 = intl.Intl.pluralLogic(
      jours,
      locale: localeName,
      other: 'il y a $jours jours',
      one: 'il y a $jours jour',
    );
    return '$_temp0';
  }

  @override
  String coreLeDate(String date) {
    return 'le $date';
  }

  @override
  String get createEvenement => 'Événement';

  @override
  String get createTache => 'Tâche';

  @override
  String get createGroupe => 'Groupe';

  @override
  String get profileApparence => 'Apparence';

  @override
  String get profileApparenceAutomatique => 'Automatique';

  @override
  String get profileApparenceClair => 'Clair';

  @override
  String get profileApparenceSombre => 'Sombre';

  @override
  String groupsTachesEnCours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches en cours',
      one: '$count tâche en cours',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementsAVenir(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements à venir',
      one: '$count événement à venir',
    );
    return '$_temp0';
  }

  @override
  String groupsVousAdministrezCeGroupe(String membres) {
    return '$membres · vous administrez ce groupe';
  }

  @override
  String authMoinsCaracteres(int min) {
    return 'Au moins $min caractères';
  }

  @override
  String get homeBonjour => 'Bonjour';

  @override
  String get homeBonsoir => 'Bonsoir';

  @override
  String get calendarPersonnel => 'Personnel';

  @override
  String get calendarJournee => 'Journée';

  @override
  String calendarFeteSonAnniversaire(String nom) {
    return '$nom fête son anniversaire';
  }

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navParametres => 'Paramètres';

  @override
  String get coreStatutInformation => 'Information';

  @override
  String get coreStatutConfirme => 'Confirmé';

  @override
  String get coreStatutEnAttente => 'En attente';

  @override
  String get coreStatutConflit => 'Conflit';

  @override
  String get coreStatutInactif => 'Inactif';

  @override
  String get notificationsActives => 'Actives';

  @override
  String get notificationsNotification => 'Notification';

  @override
  String chatUnePersonneEcrit(String nom) {
    return '$nom est en train d’écrire…';
  }

  @override
  String chatDeuxPersonnesEcrivent(String premier, String second) {
    return '$premier et $second sont en train d’écrire…';
  }

  @override
  String chatAPrisLaTache(String nom) {
    return '$nom a pris la tâche';
  }

  @override
  String chatAAccepteLaTache(String nom) {
    return '$nom a accepté la tâche';
  }

  @override
  String chatARefuseLaTache(String nom) {
    return '$nom a refusé la tâche';
  }

  @override
  String chatATermineLaTache(String nom) {
    return '$nom a terminé la tâche';
  }

  @override
  String chatTacheAttribueeA(String nom) {
    return 'Tâche attribuée à $nom';
  }

  @override
  String groupsInvitationDe(String nom) {
    return 'Invitation de $nom';
  }

  @override
  String get calendarRappel => 'Rappel';

  @override
  String get calendarRepeter => 'Répéter';

  @override
  String groupsMembreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '$count événement',
    );
    return '$_temp0';
  }

  @override
  String groupsTacheOuverteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches ouvertes',
      one: '$count tâche ouverte',
    );
    return '$_temp0';
  }

  @override
  String coreJourEtHeure(String jour, String heures) {
    return '$jour · $heures';
  }

  @override
  String groupsRetraitMembreConfirmation(String nom) {
    return '$nom n’aura plus accès au groupe. Vous pourrez l’inviter à nouveau plus tard.';
  }

  @override
  String groupsQuitterConfirmation(String groupe) {
    return 'Vous ne verrez plus « $groupe ». Si vous en êtes le dernier administrateur, le plus ancien membre prendra le relais.';
  }

  @override
  String groupsSupprimerConfirmation(String groupe) {
    return '« $groupe » disparaîtra pour tous ses membres. Cette action ne peut pas être annulée depuis l’application.';
  }

  @override
  String groupsInvitationRecueJusquAu(String nom, String date) {
    return '$nom a reçu votre invitation, jusqu’au $date.';
  }

  @override
  String get coreRetirer => 'Retirer';

  @override
  String get coreQuitter => 'Quitter';

  @override
  String get coreSupprimer => 'Supprimer';

  @override
  String tasksTacheSupprimee(String titre) {
    return '« $titre » a été supprimée.';
  }

  @override
  String tasksSupprimerConfirmation(String titre) {
    return '« $titre » disparaîtra pour tout le monde. Cette action ne peut pas être annulée depuis l’application.';
  }

  @override
  String coreVous(String nom) {
    return '$nom (vous)';
  }

  @override
  String coreSurTotal(int fait, int total) {
    return '$fait sur $total';
  }

  @override
  String tasksCochePar(String nom) {
    return 'Coché par $nom';
  }

  @override
  String get tasksListe => 'Liste';

  @override
  String get tasksEcheance => 'Échéance';

  @override
  String get tasksAucune => 'Aucune';

  @override
  String calendarEvenementSupprime(String titre) {
    return '« $titre » a été supprimé.';
  }

  @override
  String calendarSupprimerConfirmation(String titre) {
    return '« $titre » disparaîtra pour tous les participants. Cette action ne peut pas être annulée depuis l’application.';
  }

  @override
  String get calendarParticipants => 'Participants';

  @override
  String calendarOuiCount(int count) {
    return '$count oui';
  }

  @override
  String calendarVousAvezRepondu(String reponse) {
    return 'Vous avez répondu : $reponse. Vous pouvez encore changer d’avis.';
  }

  @override
  String calendarReponseEnregistree(String reponse) {
    return 'Réponse enregistrée : $reponse.';
  }

  @override
  String groupsPartagezCeLien(String groupe) {
    return 'Partagez ce lien par SMS, messagerie ou e-mail. La personne pourra créer son compte puis rejoindre « $groupe ».';
  }

  @override
  String groupsRejoinsSurJelvo(String groupe, String url) {
    return 'Rejoins « $groupe » sur Jelvo : $url';
  }

  @override
  String groupsInvitationARejoindre(String groupe) {
    return 'Invitation à rejoindre $groupe';
  }

  @override
  String groupsUtilisationsExpireLe(String utilisations, String date) {
    return '$utilisations · expire le $date';
  }

  @override
  String groupsAdhesionJusquAu(String date) {
    return 'Adhésion jusqu’au $date';
  }

  @override
  String groupsUtilisationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilisations',
      one: '$count utilisation',
    );
    return '$_temp0';
  }

  @override
  String groupsUtilisationSurMax(String utilisations, int max) {
    return '$utilisations sur $max';
  }

  @override
  String contactsGroupeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes',
      one: '$count groupe',
    );
    return '$_temp0';
  }

  @override
  String contactsPersonnesSouhaitentVousAjouter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes souhaitent vous ajouter',
      one: '$count personne souhaite vous ajouter',
    );
    return '$_temp0';
  }

  @override
  String contactsFaitMaintenantPartie(String nom) {
    return '$nom fait maintenant partie de vos contacts.';
  }

  @override
  String contactsAjoutezMoiSurJelvo(String pseudo) {
    return 'Ajoutez-moi sur Jelvo : $pseudo';
  }

  @override
  String contactsNomEtMessage(String nom, String message) {
    return '$nom — $message';
  }

  @override
  String contactsRejoignezMoi(String url) {
    return 'Rejoignez-moi sur Jelvo pour organiser nos sorties : $url';
  }

  @override
  String contactsMonPseudoLigne(String pseudo) {
    return '\nMon pseudo : $pseudo';
  }

  @override
  String contactsRetraitConfirmation(String nom) {
    return '$nom ne fera plus partie de vos contacts, et vous ne ferez plus partie des siens.';
  }

  @override
  String contactsAEteRetire(String nom) {
    return '$nom a été retiré.';
  }

  @override
  String coreParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '$count participant',
    );
    return '$_temp0';
  }

  @override
  String coreMessageNonLuCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '$count message non lu',
    );
    return '$_temp0';
  }

  @override
  String authCodeEnvoyeA(String email) {
    return 'Nous avons envoyé un code à six chiffres à $email.';
  }

  @override
  String authFormatPseudo(int min, int max) {
    return 'Minuscules, chiffres et points, de $min à $max caractères.';
  }

  @override
  String availabilityDateEtPlage(String date, String plage) {
    return '$date · $plage';
  }

  @override
  String availabilityDe(String heure) {
    return 'De $heure';
  }

  @override
  String availabilityA(String heure) {
    return 'À $heure';
  }

  @override
  String calendarPuceEtDate(String date) {
    return ' • $date';
  }

  @override
  String calendarRienNeCorrespond(String terme) {
    return 'Rien ne correspond à « $terme ».';
  }

  @override
  String coreSurTotalTexte(int fait, int total) {
    return '$fait sur $total';
  }

  @override
  String calendarHeuresMinutes(int heures, String minutes) {
    return '$heures h $minutes';
  }

  @override
  String calendarHeures(int heures) {
    return '$heures h';
  }

  @override
  String chatMegaoctets(String taille) {
    return '$taille Mo';
  }

  @override
  String chatKilooctets(int taille) {
    return '$taille ko';
  }

  @override
  String chatJusquAEnvironUneMinute(String taille) {
    return 'Jusqu’à $taille, environ une minute';
  }

  @override
  String chatVideoTropLourde(String taille, String max) {
    return 'Cette vidéo pèse $taille, au-delà des $max acceptés. Filmez plus court, ou envoyez-la autrement.';
  }

  @override
  String chatEcheanceDateHeure(String date, String heure) {
    return 'Échéance $date à $heure';
  }

  @override
  String groupsInvitationEnAttenteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations en attente',
      one: '$count invitation en attente',
    );
    return '$_temp0';
  }

  @override
  String groupsAdhesionTemporaireJusquAu(String date) {
    return 'Adhésion temporaire : jusqu’au $date.';
  }

  @override
  String groupsAdhesionTemporaireVousFerezPartie(String date) {
    return 'Adhésion temporaire : vous ferez partie du groupe jusqu’au $date.';
  }

  @override
  String groupsCreezIciPartageAvec(String groupe) {
    return 'Ce que vous créez ici sera partagé avec « $groupe ».';
  }

  @override
  String groupsJusquAu(String date) {
    return 'Jusqu’au $date';
  }

  @override
  String groupsAdhesionJusquAuPuisDisparait(String date) {
    return 'Adhésion jusqu’au $date, puis le groupe disparaîtra de son application.';
  }

  @override
  String groupsMembreJusquAu(String nom, String date) {
    return '$nom fait partie du groupe jusqu’au $date.';
  }

  @override
  String groupsMembreSansTerme(String nom) {
    return '$nom fait partie du groupe sans terme.';
  }

  @override
  String homeTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches',
      one: '$count tâche',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count événements',
      one: ', $count événement',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count tâches',
      one: ', $count tâche',
    );
    return '$_temp0';
  }

  @override
  String notificationsVousConvie(String nom) {
    return '$nom vous convie.';
  }

  @override
  String notificationsVousConvieAvecGroupe(String nom, String groupe) {
    return '$nom vous convie avec « $groupe ».';
  }

  @override
  String profileVersion(String version) {
    return 'Version $version';
  }

  @override
  String profileRetrouvezMoi(String pseudo, String code) {
    return 'Retrouvez-moi sur Jelvo : $pseudo\n$code';
  }

  @override
  String profileVotrePseudo(String pseudo) {
    return 'Votre pseudo : $pseudo';
  }

  @override
  String profileRetraitCarnetConfirmation(String nom) {
    return '$nom ne figurera plus dans votre carnet. Vos groupes communs ne changent pas.';
  }

  @override
  String profileGroupesCommunsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes en commun',
      one: '$count groupe en commun',
    );
    return '$_temp0';
  }

  @override
  String tasksEcheanceDate(String date) {
    return 'Échéance $date';
  }

  @override
  String coreDateAHeure(String date, String heure) {
    return '$date à $heure';
  }

  @override
  String get tasksTerminees => 'Terminées';

  @override
  String tasksConfieeAuxPersonnes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Confiée à $count personnes, qui recevront une notification.',
      one: 'Confiée à $count personne, qui recevra une notification.',
    );
    return '$_temp0';
  }

  @override
  String coreDeuxNoms(String premier, String second) {
    return '$premier et $second';
  }

  @override
  String coreDeuxNomsEtAutres(String premier, String second, int reste) {
    String _temp0 = intl.Intl.pluralLogic(
      reste,
      locale: localeName,
      other: '$reste autres',
      one: '$reste autre',
    );
    return '$premier, $second et $_temp0';
  }

  @override
  String tasksArticlesCoches(int faits, int total) {
    return '$faits sur $total articles';
  }

  @override
  String tasksPrioriteLabel(String priorite) {
    return '$priorite priorité';
  }

  @override
  String navBadgeNonLus(String destination, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lus',
      one: '$count non lu',
    );
    return '$destination, $_temp0';
  }

  @override
  String get profileLangue => 'Langue';

  @override
  String get profileLangueDuTelephone => 'Celle du téléphone';

  @override
  String get profileLangueDuTelephoneAide =>
      'Suit le réglage de l’appareil, et l’anglais si la langue n’est pas proposée';

  @override
  String get profileLangueFrancais => 'Français';

  @override
  String get profileLangueAllemand => 'Allemand';

  @override
  String get profileLangueAnglais => 'Anglais';

  @override
  String get profileLangueEspagnol => 'Espagnol';

  @override
  String get homeBonWeekEnd => 'Bon week-end';

  @override
  String get coreDebutApresMidi => '12';

  @override
  String get coreDebutSoiree => '18';

  @override
  String get coreDescription => 'Description';

  @override
  String get coreRechercher => 'Rechercher';

  @override
  String get coreProfil => 'Profil';

  @override
  String get coreLieu => 'Lieu';

  @override
  String get coreAnniversaire => 'Anniversaire';

  @override
  String get coreAutre => 'Autre';

  @override
  String get corePrenom => 'Prénom';

  @override
  String get coreNom => 'Nom';

  @override
  String get corePseudo => 'Pseudo';

  @override
  String get coreHintPseudo => 'pseudo';

  @override
  String get coreFiltres => 'Filtres';

  @override
  String get coreRepetition => 'Répétition';

  @override
  String get coreInvitation => 'Invitation';

  @override
  String get coreInvitations => 'Invitations';

  @override
  String get coreChoisir => 'Choisir';

  @override
  String get corePriorite => 'Priorité';

  @override
  String get coreDate => 'Date';

  @override
  String get coreHoraires => 'Horaires';

  @override
  String get coreDisponible => 'Disponible';

  @override
  String get coreTout => 'Tout';

  @override
  String get coreAfficher => 'Afficher';

  @override
  String get coreFin => 'Fin';

  @override
  String get coreVideo => 'Vidéo';

  @override
  String get coreJoindre => 'Joindre';

  @override
  String get coreFilmer => 'Filmer';

  @override
  String get coreScanner => 'Scanner';

  @override
  String get coreResultats => 'Résultats';

  @override
  String get coreEffacer => 'Effacer';

  @override
  String get coreFavoris => 'Favoris';

  @override
  String get coreGerer => 'Gérer';

  @override
  String get coreActions => 'Actions';

  @override
  String get coreDiscussion => 'Discussion';

  @override
  String get coreInviter => 'Inviter';

  @override
  String get coreSuggestions => 'Suggestions';

  @override
  String get corePartager => 'Partager';

  @override
  String get coreAdmin => 'Admin';

  @override
  String get coreCommencer => 'Commencer';

  @override
  String get coreCompte => 'Compte';

  @override
  String get coreDeconnexion => 'Déconnexion';

  @override
  String get coreJour => 'Jour';

  @override
  String get coreMois => 'Mois';

  @override
  String get coreEmail => 'Email';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreModifier => 'Modifier';

  @override
  String get coreContinuer => 'Continuer';

  @override
  String get coreVerifier => 'Vérifier';

  @override
  String get coreExceptions => 'Exceptions';

  @override
  String get coreEvenements => 'Événements';

  @override
  String get coreTaches => 'Tâches';

  @override
  String get coreExemplePrenom => 'Camille';

  @override
  String get coreExempleNom => 'Rousseau';

  @override
  String get corePlusDOptions => 'Plus d’options';

  @override
  String get profileSupprimerCompte => 'Supprimer mon compte';

  @override
  String get profileSuppressionDefinitive =>
      'Cette suppression est définitive : elle ne peut pas être annulée.';

  @override
  String get profileSuppressionCeQuiDisparait => 'Ce qui disparaît';

  @override
  String get profileSuppressionIdentite =>
      'Votre nom, votre pseudo, votre adresse e-mail et votre photo';

  @override
  String get profileSuppressionProfil =>
      'Votre bio, votre anniversaire et vos disponibilités';

  @override
  String get profileSuppressionContacts =>
      'Vos contacts, et vos demandes en attente';

  @override
  String get profileSuppressionGroupes =>
      'Vos adhésions aux groupes. Si vous êtes la seule personne à administrer un groupe, le plus ancien membre prend votre place.';

  @override
  String get profileSuppressionNotifications =>
      'Vos notifications et vos abonnements';

  @override
  String get profileSuppressionVocaux =>
      'Vos messages vocaux, qui portent votre voix';

  @override
  String get profileSuppressionCeQuiReste => 'Ce qui reste';

  @override
  String get profileSuppressionMessages =>
      'Vos messages écrits, signés « Compte supprimé », pour ne pas trouer les échanges des autres';

  @override
  String get profileSuppressionMedias =>
      'Les photos et les vidéos que vous avez partagées';

  @override
  String get profileSuppressionGroupeContenu =>
      'Les tâches et les événements que vous avez créés dans un groupe';

  @override
  String get profileSuppressionReinscription =>
      'Vous pourrez vous réinscrire plus tard avec la même adresse.';

  @override
  String get profileSuppressionMotDePasse => 'Mot de passe';

  @override
  String get profileSuppressionMotDePasseAide =>
      'Pour confirmer que c’est bien vous';

  @override
  String get profileSuppressionConfirmer => 'Supprimer définitivement';

  @override
  String get profileSuppressionMotDePasseIncorrect => 'Mot de passe incorrect.';

  @override
  String get profileSuppressionEchec =>
      'La suppression n’a pas abouti. Votre compte est intact : réessayez dans un instant.';

  @override
  String get profileSuppressionFaite => 'Votre compte a été supprimé.';

  @override
  String get coreCompteSupprime => 'Compte supprimé';

  @override
  String get coreMembre => 'Membre';

  @override
  String get coreEpingle => 'Épinglé';

  @override
  String get coreEpingler => 'Épingler';

  @override
  String get coreRouvrir => 'Rouvrir';

  @override
  String get chatEcouter => 'Écouter';

  @override
  String get tasksAssignes => 'Assignés';

  @override
  String get tasksPersonnelle => 'Personnelle';

  @override
  String chatCompteurTaches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tâches',
      one: 'tâche',
    );
    return '$_temp0';
  }

  @override
  String chatCompteurEvenements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'événements',
      one: 'événement',
    );
    return '$_temp0';
  }

  @override
  String contactsCompteurGroupes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'groupes',
      one: 'groupe',
    );
    return '$_temp0';
  }

  @override
  String get tasksLibre => 'Libre';

  @override
  String get coreIndisponible => 'Indisponible';

  @override
  String get coreInconnu => 'Inconnu';

  @override
  String get coreAutres => 'Autres';

  @override
  String get coreContact => 'Contact';

  @override
  String get coreDateChoisir => 'Date…';

  @override
  String get chatEmojis => 'Emojis';

  @override
  String get chatEnvoyer => 'Envoyer';

  @override
  String get authRetirerAvatar => 'Retirer l’avatar';

  @override
  String get groupsRejoindre => 'Rejoindre';

  @override
  String get notificationsActivees => 'Activées';

  @override
  String get notificationsPartielles => 'Partielles';

  @override
  String get notificationsDesactivees => 'Désactivées';

  @override
  String get notificationsRefusees => 'Refusées';

  @override
  String get notificationsIndisponibles => 'Indisponibles';

  @override
  String get notificationsVoirInvitation => 'Voir l’invitation';
}
