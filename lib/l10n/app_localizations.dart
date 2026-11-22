import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppTexts
/// returned by `AppTexts.of(context)`.
///
/// Applications need to include `AppTexts.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppTexts.localizationsDelegates,
///   supportedLocales: AppTexts.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppTexts.supportedLocales
/// property.
abstract class AppTexts {
  AppTexts(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppTexts of(BuildContext context) {
    return Localizations.of<AppTexts>(context, AppTexts)!;
  }

  static const LocalizationsDelegate<AppTexts> delegate = _AppTextsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// Nom de l'application
  ///
  /// In fr, this message translates to:
  /// **'Jelvo'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get navGroups;

  /// No description provided for @navCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get navCalendar;

  /// No description provided for @navContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get navContacts;

  /// No description provided for @createNewGroup.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get createNewGroup;

  /// No description provided for @createNewEvent.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel événement'**
  String get createNewEvent;

  /// No description provided for @createAddContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get createAddContact;

  /// No description provided for @createTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get createTitle;

  /// No description provided for @createQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Que voulez-vous créer ?'**
  String get createQuestion;

  /// No description provided for @createIntro.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un type, puis renseignez l’essentiel. Vous pourrez compléter les détails plus tard.'**
  String get createIntro;

  /// No description provided for @createDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get createDetails;

  /// No description provided for @createGroupField.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get createGroupField;

  /// No description provided for @createPersonalOption.
  ///
  /// In fr, this message translates to:
  /// **'Personnel — visible de vous seul'**
  String get createPersonalOption;

  /// No description provided for @createPickDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date'**
  String get createPickDate;

  /// No description provided for @createDueDate.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get createDueDate;

  /// No description provided for @createTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get createTime;

  /// No description provided for @createMissingDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la date de l’événement.'**
  String get createMissingDate;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonRequiredField.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire.'**
  String get commonRequiredField;

  /// No description provided for @commonOptional.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel'**
  String get commonOptional;

  /// No description provided for @homeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voici votre journée en un coup d’œil.'**
  String get homeSubtitle;

  /// No description provided for @homeToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get homeToday;

  /// No description provided for @homeNoEventTitle.
  ///
  /// In fr, this message translates to:
  /// **'Journée libre'**
  String get homeNoEventTitle;

  /// No description provided for @homeNoEventMessage.
  ///
  /// In fr, this message translates to:
  /// **'Rien n’est encore planifié pour aujourd’hui.'**
  String get homeNoEventMessage;

  /// No description provided for @homeSoon.
  ///
  /// In fr, this message translates to:
  /// **'À faire bientôt'**
  String get homeSoon;

  /// No description provided for @homeNothingUrgent.
  ///
  /// In fr, this message translates to:
  /// **'Rien d’urgent'**
  String get homeNothingUrgent;

  /// No description provided for @homeAllUpToDateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tout est à jour'**
  String get homeAllUpToDateTitle;

  /// No description provided for @homeAllUpToDateMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tâche n’arrive à échéance dans les 48 heures.'**
  String get homeAllUpToDateMessage;

  /// No description provided for @homeMyGroups.
  ///
  /// In fr, this message translates to:
  /// **'Mes groupes'**
  String get homeMyGroups;

  /// No description provided for @homeMostActive.
  ///
  /// In fr, this message translates to:
  /// **'Les plus actifs en ce moment'**
  String get homeMostActive;

  /// No description provided for @homeSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get homeSeeAll;

  /// No description provided for @homeEventCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun événement} =1{1 événement} other{{count} événements}}'**
  String homeEventCount(int count);

  /// No description provided for @homeTaskCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune tâche} =1{1 tâche à échéance proche} other{{count} tâches à échéance proche}}'**
  String homeTaskCount(int count);

  /// No description provided for @groupUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get groupUpcoming;

  /// No description provided for @groupNothingPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Rien de prévu'**
  String get groupNothingPlanned;

  /// No description provided for @groupNoEventTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement'**
  String get groupNoEventTitle;

  /// No description provided for @groupNoEventMessage.
  ///
  /// In fr, this message translates to:
  /// **'Proposez une date au groupe : chacun répondra oui, peut-être ou non.'**
  String get groupNoEventMessage;

  /// No description provided for @groupProposeDate.
  ///
  /// In fr, this message translates to:
  /// **'Proposer une date'**
  String get groupProposeDate;

  /// No description provided for @groupTasksToDo.
  ///
  /// In fr, this message translates to:
  /// **'Tâches à faire'**
  String get groupTasksToDo;

  /// No description provided for @groupNoTaskTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tâche ouverte'**
  String get groupNoTaskTitle;

  /// No description provided for @groupNoTaskMessage.
  ///
  /// In fr, this message translates to:
  /// **'Répartissez ce qu’il y a à faire : chacun verra sa part.'**
  String get groupNoTaskMessage;

  /// No description provided for @groupAddTask.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une tâche'**
  String get groupAddTask;

  /// No description provided for @groupAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get groupAdd;

  /// No description provided for @groupAddToGroup.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au groupe'**
  String get groupAddToGroup;

  /// No description provided for @groupCreationSheetIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous créez ici sera partagé avec « {name} ».'**
  String groupCreationSheetIntro(String name);

  /// No description provided for @groupMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get groupMembers;

  /// No description provided for @groupMemberCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun membre} =1{1 membre} other{{count} membres}}'**
  String groupMemberCount(int count);

  /// No description provided for @taskStatusTodo.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get taskStatusTodo;

  /// No description provided for @taskStatusDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get taskStatusDone;

  /// No description provided for @taskStatusOverdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get taskStatusOverdue;

  /// No description provided for @taskPriorityLow.
  ///
  /// In fr, this message translates to:
  /// **'Basse'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In fr, this message translates to:
  /// **'Normale'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In fr, this message translates to:
  /// **'Haute'**
  String get taskPriorityHigh;

  /// No description provided for @taskAssigneePending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get taskAssigneePending;

  /// No description provided for @taskAssigneeAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get taskAssigneeAccepted;

  /// No description provided for @taskAssigneeDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusée'**
  String get taskAssigneeDeclined;

  /// No description provided for @taskAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get taskAccept;

  /// No description provided for @taskDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get taskDecline;

  /// No description provided for @taskListProgress.
  ///
  /// In fr, this message translates to:
  /// **'{checked} sur {total} articles'**
  String taskListProgress(int checked, int total);

  /// No description provided for @eventAnswerYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get eventAnswerYes;

  /// No description provided for @eventAnswerMaybe.
  ///
  /// In fr, this message translates to:
  /// **'Peut-être'**
  String get eventAnswerMaybe;

  /// No description provided for @eventAnswerNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get eventAnswerNo;

  /// No description provided for @eventAnswerPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get eventAnswerPending;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez dans un instant.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion indisponible. Vérifiez votre accès à Internet, puis réessayez.'**
  String get errorNetwork;

  /// No description provided for @errorForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’avez pas les droits nécessaires pour cette action.'**
  String get errorForbidden;

  /// No description provided for @errorNotSaved.
  ///
  /// In fr, this message translates to:
  /// **'Les données n’ont pas pu être enregistrées. Réessayez dans un instant.'**
  String get errorNotSaved;

  /// No description provided for @coreAujourdHui.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get coreAujourdHui;

  /// No description provided for @coreInstant.
  ///
  /// In fr, this message translates to:
  /// **'à l’instant'**
  String get coreInstant;

  /// No description provided for @coreDateLabelTimeLabel.
  ///
  /// In fr, this message translates to:
  /// **'{dateLabel} · {timeLabel}'**
  String coreDateLabelTimeLabel(Object dateLabel, Object timeLabel);

  /// No description provided for @coreVoirMembres.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les membres'**
  String get coreVoirMembres;

  /// No description provided for @corePersonneNom.
  ///
  /// In fr, this message translates to:
  /// **'Personne à ce nom.'**
  String get corePersonneNom;

  /// No description provided for @coreMarquerTacheCommeTerminee.
  ///
  /// In fr, this message translates to:
  /// **'Marquer la tâche comme terminée'**
  String get coreMarquerTacheCommeTerminee;

  /// No description provided for @authMessageDiagnosticRaw.
  ///
  /// In fr, this message translates to:
  /// **'{_message}\n\n[diagnostic] {raw}'**
  String authMessageDiagnosticRaw(Object _message, Object raw);

  /// No description provided for @authEnvoiPhotoEchoueReessayez.
  ///
  /// In fr, this message translates to:
  /// **'L\'envoi de la photo a échoué. Réessayez dans un instant.'**
  String get authEnvoiPhotoEchoueReessayez;

  /// No description provided for @authIdentifiantsIncorrectsVerifiezSaisie.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants incorrects. Vérifiez votre saisie, puis réessayez.'**
  String get authIdentifiantsIncorrectsVerifiezSaisie;

  /// No description provided for @authAdresseEMailEncore.
  ///
  /// In fr, this message translates to:
  /// **'Votre adresse e-mail n’est pas encore vérifiée.'**
  String get authAdresseEMailEncore;

  /// No description provided for @authAdresseEMailDeja.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail est déjà utilisée. Connectez-vous ou choisissez une autre adresse.'**
  String get authAdresseEMailDeja;

  /// No description provided for @authCodeExpireDemandezNouveau.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Demandez-en un nouveau.'**
  String get authCodeExpireDemandezNouveau;

  /// No description provided for @authCodeIncorrectVerifiezSix.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect. Vérifiez les six chiffres reçus par e-mail.'**
  String get authCodeIncorrectVerifiezSix;

  /// No description provided for @authTropTentativesPatientezMinute.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Patientez une minute avant de réessayer.'**
  String get authTropTentativesPatientezMinute;

  /// No description provided for @authMotPasseTropFaible.
  ///
  /// In fr, this message translates to:
  /// **'Ce mot de passe est trop faible. Choisissez-en un plus robuste.'**
  String get authMotPasseTropFaible;

  /// No description provided for @authNouveauMotPasseDoit.
  ///
  /// In fr, this message translates to:
  /// **'Le nouveau mot de passe doit différer de l’ancien.'**
  String get authNouveauMotPasseDoit;

  /// No description provided for @authAucunCompteCorrespondInformations.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte ne correspond à ces informations.'**
  String get authAucunCompteCorrespondInformations;

  /// No description provided for @authSessionExpireReconnectez.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré. Reconnectez-vous.'**
  String get authSessionExpireReconnectez;

  /// No description provided for @authConnexionEchoueReessayezInstant.
  ///
  /// In fr, this message translates to:
  /// **'La connexion a échoué. Réessayez dans un instant.'**
  String get authConnexionEchoueReessayezInstant;

  /// No description provided for @authPseudoVientEtrePris.
  ///
  /// In fr, this message translates to:
  /// **'Ce pseudo vient d’être pris. Choisissez-en un autre.'**
  String get authPseudoVientEtrePris;

  /// No description provided for @authFonctionnaliteAttendMiseJour.
  ///
  /// In fr, this message translates to:
  /// **'Cette fonctionnalité attend une mise à jour de la base. Réessayez plus tard, ou signalez-le si cela persiste.'**
  String get authFonctionnaliteAttendMiseJour;

  /// No description provided for @authChoisissezPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un pseudo.'**
  String get authChoisissezPseudo;

  /// No description provided for @authPseudoDoitContenirMoins.
  ///
  /// In fr, this message translates to:
  /// **'Le pseudo doit contenir au moins {pseudoMinLength} caractères.'**
  String authPseudoDoitContenirMoins(Object pseudoMinLength);

  /// No description provided for @authPseudoDoitDepasserPseudoMaxLength.
  ///
  /// In fr, this message translates to:
  /// **'Le pseudo ne doit pas dépasser {pseudoMaxLength} caractères.'**
  String authPseudoDoitDepasserPseudoMaxLength(Object pseudoMaxLength);

  /// No description provided for @authUniquementMinusculesChiffresPoints.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement des minuscules, des chiffres et des points.'**
  String get authUniquementMinusculesChiffresPoints;

  /// No description provided for @authRenseignezAdresseEMail.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez votre adresse e-mail.'**
  String get authRenseignezAdresseEMail;

  /// No description provided for @authAdresseEMailSemble.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail semble incomplète.'**
  String get authAdresseEMailSemble;

  /// No description provided for @authChoisissezMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un mot de passe.'**
  String get authChoisissezMotPasse;

  /// No description provided for @authMoinsPasswordMinLengthCaracteresNecessaires.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {passwordMinLength} caractères sont nécessaires.'**
  String authMoinsPasswordMinLengthCaracteresNecessaires(
    Object passwordMinLength,
  );

  /// No description provided for @authAjoutezMoinsMajuscule.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une majuscule.'**
  String get authAjoutezMoinsMajuscule;

  /// No description provided for @authAjoutezMoinsChiffre.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins un chiffre.'**
  String get authAjoutezMoinsChiffre;

  /// No description provided for @authConnexionPseudoEncoreDisponible.
  ///
  /// In fr, this message translates to:
  /// **'La connexion par pseudo n’est pas encore disponible. Utilisez votre adresse e-mail.'**
  String get authConnexionPseudoEncoreDisponible;

  /// No description provided for @authMotPasseOublie.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get authMotPasseOublie;

  /// No description provided for @authIndiquezAdresseEMail.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre adresse e-mail : nous vous enverrons un code à six chiffres pour en choisir un nouveau.'**
  String get authIndiquezAdresseEMail;

  /// No description provided for @authAdresseEMail.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get authAdresseEMail;

  /// No description provided for @authEnvoyerCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get authEnvoyerCode;

  /// No description provided for @authContentRevoir.
  ///
  /// In fr, this message translates to:
  /// **'Content de vous revoir'**
  String get authContentRevoir;

  /// No description provided for @authConnectezRetrouverGroupesAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour retrouver vos groupes et votre agenda.'**
  String get authConnectezRetrouverGroupesAgenda;

  /// No description provided for @authPseudoAdresseEMail.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo ou adresse e-mail'**
  String get authPseudoAdresseEMail;

  /// No description provided for @authMotPasseOublie2.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get authMotPasseOublie2;

  /// No description provided for @authConnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authConnecter;

  /// No description provided for @authEncoreCompte.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get authEncoreCompte;

  /// No description provided for @authInscrire.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get authInscrire;

  /// No description provided for @authSouvenirMoi.
  ///
  /// In fr, this message translates to:
  /// **'Se souvenir de moi'**
  String get authSouvenirMoi;

  /// No description provided for @authResterezConnecteJusquDeconnexion.
  ///
  /// In fr, this message translates to:
  /// **'Vous resterez connecté jusqu’à la déconnexion.'**
  String get authResterezConnecteJusquDeconnexion;

  /// No description provided for @authSerezDeconnecteFermetureApplication.
  ///
  /// In fr, this message translates to:
  /// **'Vous serez déconnecté à la fermeture de l’application.'**
  String get authSerezDeconnecteFermetureApplication;

  /// No description provided for @authJelvoInstalleEcranAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Jelvo installé sur l’écran d’accueil a sa propre session : s’y connecter est une étape distincte de Safari, même avec cette case cochée.'**
  String get authJelvoInstalleEcranAccueil;

  /// No description provided for @authRenseignezPseudoAdresseE.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez votre pseudo ou votre adresse e-mail.'**
  String get authRenseignezPseudoAdresseE;

  /// No description provided for @authRenseignezMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez votre mot de passe.'**
  String get authRenseignezMotPasse;

  /// No description provided for @authNouveauMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get authNouveauMotPasse;

  /// No description provided for @authSaisissezCodeRecuPuis.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code reçu, puis choisissez un nouveau mot de passe.'**
  String get authSaisissezCodeRecuPuis;

  /// No description provided for @authSaisissezCodeEnvoyeEmail.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code envoyé à {email}, puis choisissez un nouveau mot de passe.'**
  String authSaisissezCodeEnvoyeEmail(Object email);

  /// No description provided for @authCodeVerification.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification'**
  String get authCodeVerification;

  /// No description provided for @auth8CaracteresMinimum.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères minimum'**
  String get auth8CaracteresMinimum;

  /// No description provided for @authChangerMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get authChangerMotPasse;

  /// No description provided for @authRenvoyerCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get authRenvoyerCode;

  /// No description provided for @authEnvoiCours.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours…'**
  String get authEnvoiCours;

  /// No description provided for @authNouveauCodePossibleSecondsLeft.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code possible dans {_secondsLeft} s'**
  String authNouveauCodePossibleSecondsLeft(Object _secondsLeft);

  /// No description provided for @authSaisissezSixChiffresCode.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez les six chiffres du code.'**
  String get authSaisissezSixChiffresCode;

  /// No description provided for @authMotPasseEteMis.
  ///
  /// In fr, this message translates to:
  /// **'Votre mot de passe a été mis à jour.'**
  String get authMotPasseEteMis;

  /// No description provided for @authNouveauCodeVientEtre.
  ///
  /// In fr, this message translates to:
  /// **'Un nouveau code vient d’être envoyé.'**
  String get authNouveauCodeVientEtre;

  /// No description provided for @authCreerCompte.
  ///
  /// In fr, this message translates to:
  /// **'Créer votre compte'**
  String get authCreerCompte;

  /// No description provided for @authChoisissezPseudoSecurisezCompte.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un pseudo et sécurisez votre compte.'**
  String get authChoisissezPseudoSecurisezCompte;

  /// No description provided for @authEtape12.
  ///
  /// In fr, this message translates to:
  /// **'Étape 1 sur 2'**
  String get authEtape12;

  /// No description provided for @authCreantCompteAcceptezRecevoir.
  ///
  /// In fr, this message translates to:
  /// **'En créant un compte, vous acceptez de recevoir un e-mail de vérification.'**
  String get authCreantCompteAcceptezRecevoir;

  /// No description provided for @authAppelezComment.
  ///
  /// In fr, this message translates to:
  /// **'Vous vous appelez comment ?'**
  String get authAppelezComment;

  /// No description provided for @authProchesReconnaitrontFacilement.
  ///
  /// In fr, this message translates to:
  /// **'Vos proches vous reconnaîtront plus facilement.'**
  String get authProchesReconnaitrontFacilement;

  /// No description provided for @authEtape22.
  ///
  /// In fr, this message translates to:
  /// **'Étape 2 sur 2'**
  String get authEtape22;

  /// No description provided for @authCreerCompte2.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get authCreerCompte2;

  /// No description provided for @authRenseignezPrenom.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez votre prénom.'**
  String get authRenseignezPrenom;

  /// No description provided for @authRenseignezNom.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez votre nom.'**
  String get authRenseignezNom;

  /// No description provided for @authCompteCreeMaisProfil.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé, mais le profil n’a pas pu être enregistré : {warning}'**
  String authCompteCreeMaisProfil(Object warning);

  /// No description provided for @authVerifiezEMail.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre e-mail'**
  String get authVerifiezEMail;

  /// No description provided for @authSaisissezCodeSixChiffres.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code à six chiffres que nous venons de vous envoyer.'**
  String get authSaisissezCodeSixChiffres;

  /// No description provided for @authChoisirPhotoProfil.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo de profil'**
  String get authChoisirPhotoProfil;

  /// No description provided for @authOuvertureGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture de la galerie…'**
  String get authOuvertureGalerie;

  /// No description provided for @authRetirerPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get authRetirerPhoto;

  /// No description provided for @authAjouterPhotoFacultatif.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo (facultatif)'**
  String get authAjouterPhotoFacultatif;

  /// No description provided for @authPhotoPuEtreOuverte.
  ///
  /// In fr, this message translates to:
  /// **'La photo n\'a pas pu être ouverte. Réessayez.'**
  String get authPhotoPuEtreOuverte;

  /// No description provided for @authMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authMotPasse;

  /// No description provided for @authMotPasse2.
  ///
  /// In fr, this message translates to:
  /// **'Votre mot de passe'**
  String get authMotPasse2;

  /// No description provided for @authAfficherMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get authAfficherMotPasse;

  /// No description provided for @authMasquerMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get authMasquerMotPasse;

  /// No description provided for @authMajuscule.
  ///
  /// In fr, this message translates to:
  /// **'Une majuscule'**
  String get authMajuscule;

  /// No description provided for @authChiffre.
  ///
  /// In fr, this message translates to:
  /// **'Un chiffre'**
  String get authChiffre;

  /// No description provided for @authPseudoDejaPris.
  ///
  /// In fr, this message translates to:
  /// **'Ce pseudo est déjà pris.'**
  String get authPseudoDejaPris;

  /// No description provided for @authPseudoDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Ce pseudo est disponible.'**
  String get authPseudoDisponible;

  /// No description provided for @authCodeVerificationSixChiffres.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification à six chiffres'**
  String get authCodeVerificationSixChiffres;

  /// No description provided for @availabilityChaqueSemaine.
  ///
  /// In fr, this message translates to:
  /// **'Chaque semaine'**
  String get availabilityChaqueSemaine;

  /// No description provided for @availabilityDatePrecise.
  ///
  /// In fr, this message translates to:
  /// **'Une date précise'**
  String get availabilityDatePrecise;

  /// No description provided for @availabilityCreneauPuEtreEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Le créneau n’a pas pu être enregistré. Réessayez dans un instant.'**
  String get availabilityCreneauPuEtreEnregistre;

  /// No description provided for @availabilityDisponibilites.
  ///
  /// In fr, this message translates to:
  /// **'Mes disponibilités'**
  String get availabilityDisponibilites;

  /// No description provided for @availabilityNouveauCreneau.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau créneau'**
  String get availabilityNouveauCreneau;

  /// No description provided for @availabilityDisponibilitesIndisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités indisponibles'**
  String get availabilityDisponibilitesIndisponibles;

  /// No description provided for @availabilitySemaineType.
  ///
  /// In fr, this message translates to:
  /// **'Ma semaine type'**
  String get availabilitySemaineType;

  /// No description provided for @availabilityCreneauxReviennentChaqueSemaine.
  ///
  /// In fr, this message translates to:
  /// **'Créneaux qui reviennent chaque semaine'**
  String get availabilityCreneauxReviennentChaqueSemaine;

  /// No description provided for @availabilityAucunCreneauRecurrentRien.
  ///
  /// In fr, this message translates to:
  /// **'Aucun créneau récurrent. Sans rien de déclaré, les autres vous voient « Inconnu ».'**
  String get availabilityAucunCreneauRecurrentRien;

  /// No description provided for @availabilityDatePrecisePrimeSemaine.
  ///
  /// In fr, this message translates to:
  /// **'Une date précise, qui prime sur la semaine type'**
  String get availabilityDatePrecisePrimeSemaine;

  /// No description provided for @availabilityAucuneExceptionJourConge.
  ///
  /// In fr, this message translates to:
  /// **'Aucune exception. Un jour de congé ou un déplacement se pose ici.'**
  String get availabilityAucuneExceptionJourConge;

  /// No description provided for @availabilityAjouterCreneau.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un créneau'**
  String get availabilityAjouterCreneau;

  /// No description provided for @availabilityContactsMembresGroupesVoient.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts et les membres de vos groupes voient seulement « Disponible », « Indisponible » ou « Inconnu ». Jamais vos horaires, jamais la raison.'**
  String get availabilityContactsMembresGroupesVoient;

  /// No description provided for @availabilityModifierCreneau.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le créneau'**
  String get availabilityModifierCreneau;

  /// No description provided for @availabilitySupprimerCreneau.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le créneau'**
  String get availabilitySupprimerCreneau;

  /// No description provided for @availabilityCreneauSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Créneau supprimé.'**
  String get availabilityCreneauSupprime;

  /// No description provided for @availabilityCreneauExisteListeVa.
  ///
  /// In fr, this message translates to:
  /// **'Ce créneau n’existe plus. La liste va se rafraîchir.'**
  String get availabilityCreneauExisteListeVa;

  /// No description provided for @availabilityAjouterCreneau2.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le créneau'**
  String get availabilityAjouterCreneau2;

  /// No description provided for @availabilityChoisissezDateCreneau.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la date du créneau.'**
  String get availabilityChoisissezDateCreneau;

  /// No description provided for @availabilityFinDoitSuivreDebut.
  ///
  /// In fr, this message translates to:
  /// **'La fin doit suivre le début.'**
  String get availabilityFinDoitSuivreDebut;

  /// No description provided for @availabilityCreneauModifie.
  ///
  /// In fr, this message translates to:
  /// **'Créneau modifié.'**
  String get availabilityCreneauModifie;

  /// No description provided for @availabilityCreneauAjoute.
  ///
  /// In fr, this message translates to:
  /// **'Créneau ajouté.'**
  String get availabilityCreneauAjoute;

  /// No description provided for @availabilityDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Qui est disponible ?'**
  String get availabilityDisponible;

  /// No description provided for @availabilityHeureChoisieVoyezQu.
  ///
  /// In fr, this message translates to:
  /// **'À l’heure choisie. Vous ne voyez qu’un mot, jamais leurs créneaux.'**
  String get availabilityHeureChoisieVoyezQu;

  /// No description provided for @availabilityDisponibilitesIndisponiblesInstant.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilités indisponibles pour l’instant.'**
  String get availabilityDisponibilitesIndisponiblesInstant;

  /// No description provided for @calendarJours.
  ///
  /// In fr, this message translates to:
  /// **'Tous les jours'**
  String get calendarJours;

  /// No description provided for @calendarToutesSemaines.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les semaines'**
  String get calendarToutesSemaines;

  /// No description provided for @calendarToutesDeuxSemaines.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les deux semaines'**
  String get calendarToutesDeuxSemaines;

  /// No description provided for @calendarMois.
  ///
  /// In fr, this message translates to:
  /// **'Tous les mois'**
  String get calendarMois;

  /// No description provided for @calendarAns.
  ///
  /// In fr, this message translates to:
  /// **'Tous les ans'**
  String get calendarAns;

  /// No description provided for @calendar10MinutesAvant.
  ///
  /// In fr, this message translates to:
  /// **'10 minutes avant'**
  String get calendar10MinutesAvant;

  /// No description provided for @calendar1HeureAvant.
  ///
  /// In fr, this message translates to:
  /// **'1 heure avant'**
  String get calendar1HeureAvant;

  /// No description provided for @calendarVeille.
  ///
  /// In fr, this message translates to:
  /// **'La veille'**
  String get calendarVeille;

  /// No description provided for @calendar1SemaineAvant.
  ///
  /// In fr, this message translates to:
  /// **'1 semaine avant'**
  String get calendar1SemaineAvant;

  /// No description provided for @calendarMinutesMin.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String calendarMinutesMin(Object minutes);

  /// No description provided for @calendarEvenementPuEtreCree.
  ///
  /// In fr, this message translates to:
  /// **'L’événement n’a pas pu être créé. Réessayez dans un instant.'**
  String get calendarEvenementPuEtreCree;

  /// No description provided for @calendarEvenementPuEtreModifie.
  ///
  /// In fr, this message translates to:
  /// **'L’événement n’a pas pu être modifié. Réessayez dans un instant.'**
  String get calendarEvenementPuEtreModifie;

  /// No description provided for @calendarSemainePrecedente.
  ///
  /// In fr, this message translates to:
  /// **'Semaine précédente'**
  String get calendarSemainePrecedente;

  /// No description provided for @calendarSemaineSuivante.
  ///
  /// In fr, this message translates to:
  /// **'Semaine suivante'**
  String get calendarSemaineSuivante;

  /// No description provided for @calendarRienFiltres.
  ///
  /// In fr, this message translates to:
  /// **'Rien avec ces filtres'**
  String get calendarRienFiltres;

  /// No description provided for @calendarFiltrePoseJourneeEntiere.
  ///
  /// In fr, this message translates to:
  /// **'Un filtre est posé : la journée entière porte peut-être autre chose.'**
  String get calendarFiltrePoseJourneeEntiere;

  /// No description provided for @calendarNiEvenementNiTache.
  ///
  /// In fr, this message translates to:
  /// **'Ni événement, ni tâche, ni créneau déclaré pour cette journée.'**
  String get calendarNiEvenementNiTache;

  /// No description provided for @calendarCreerEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Créer un événement'**
  String get calendarCreerEvenement;

  /// No description provided for @calendarModifierEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l’événement'**
  String get calendarModifierEvenement;

  /// No description provided for @calendarSupprimerEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l’événement'**
  String get calendarSupprimerEvenement;

  /// No description provided for @calendarEvenementIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Événement introuvable'**
  String get calendarEvenementIntrouvable;

  /// No description provided for @calendarEteSupprimeAvezAcces.
  ///
  /// In fr, this message translates to:
  /// **'Il a été supprimé, ou vous n’y avez plus accès.'**
  String get calendarEteSupprimeAvezAcces;

  /// No description provided for @calendarNonPrecise.
  ///
  /// In fr, this message translates to:
  /// **'Non précisé'**
  String get calendarNonPrecise;

  /// No description provided for @calendarReponse.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse'**
  String get calendarReponse;

  /// No description provided for @calendarPersonneEncoreEteConvie.
  ///
  /// In fr, this message translates to:
  /// **'Personne n’a encore été convié.'**
  String get calendarPersonneEncoreEteConvie;

  /// No description provided for @calendarEteSupprimeAvezAcces2.
  ///
  /// In fr, this message translates to:
  /// **'Il a été supprimé, ou vous n’y avez plus accès. Il n’y a plus rien à confirmer.'**
  String get calendarEteSupprimeAvezAcces2;

  /// No description provided for @calendarRevenirCalendrier.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au calendrier'**
  String get calendarRevenirCalendrier;

  /// No description provided for @calendarMembre.
  ///
  /// In fr, this message translates to:
  /// **'Un membre'**
  String get calendarMembre;

  /// No description provided for @calendarConvieEvenement.
  ///
  /// In fr, this message translates to:
  /// **'vous convie à un événement'**
  String get calendarConvieEvenement;

  /// No description provided for @calendarPropos.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get calendarPropos;

  /// No description provided for @calendarCetEvenementDejaEu.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement a déjà eu lieu.'**
  String get calendarCetEvenementDejaEu;

  /// No description provided for @calendarSerez.
  ///
  /// In fr, this message translates to:
  /// **'Serez-vous là ?'**
  String get calendarSerez;

  /// No description provided for @calendarVoirDetailEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Voir le détail de l’événement'**
  String get calendarVoirDetailEvenement;

  /// No description provided for @calendarCreneauxDeclaresFondJournee.
  ///
  /// In fr, this message translates to:
  /// **'Les créneaux déclarés, en fond de journée. Ils ne dépendent d’aucun groupe.'**
  String get calendarCreneauxDeclaresFondJournee;

  /// No description provided for @calendarEvenementTache.
  ///
  /// In fr, this message translates to:
  /// **'Un événement, une tâche…'**
  String get calendarEvenementTache;

  /// No description provided for @calendarDeuxLettresSuffisentChercher.
  ///
  /// In fr, this message translates to:
  /// **'Deux lettres suffisent à chercher.'**
  String get calendarDeuxLettresSuffisentChercher;

  /// No description provided for @calendarTitre.
  ///
  /// In fr, this message translates to:
  /// **'Titre *'**
  String get calendarTitre;

  /// No description provided for @calendarExDejeunerChezCamille.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Déjeuner chez Camille'**
  String get calendarExDejeunerChezCamille;

  /// No description provided for @calendarExPetitComptoir.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Le Petit Comptoir'**
  String get calendarExPetitComptoir;

  /// No description provided for @calendarEffacerLieu.
  ///
  /// In fr, this message translates to:
  /// **'Effacer le lieu'**
  String get calendarEffacerLieu;

  /// No description provided for @calendarQuFautSavoirQu.
  ///
  /// In fr, this message translates to:
  /// **'Ce qu’il faut savoir, ce qu’il faut apporter'**
  String get calendarQuFautSavoirQu;

  /// No description provided for @calendarInviterMembresGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Inviter des membres du groupe'**
  String get calendarInviterMembresGroupe;

  /// No description provided for @calendarJelvoPreviendraParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Jelvo préviendra les participants'**
  String get calendarJelvoPreviendraParticipants;

  /// No description provided for @calendarRendezReguliers.
  ///
  /// In fr, this message translates to:
  /// **'Pour les rendez-vous réguliers'**
  String get calendarRendezReguliers;

  /// No description provided for @calendarEnregistrerModifications.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get calendarEnregistrerModifications;

  /// No description provided for @calendarCreerEvenement2.
  ///
  /// In fr, this message translates to:
  /// **'Créer l’événement'**
  String get calendarCreerEvenement2;

  /// No description provided for @calendarDate.
  ///
  /// In fr, this message translates to:
  /// **'Date *'**
  String get calendarDate;

  /// No description provided for @calendarHeure.
  ///
  /// In fr, this message translates to:
  /// **'Heure *'**
  String get calendarHeure;

  /// No description provided for @calendarMembres.
  ///
  /// In fr, this message translates to:
  /// **'Tous les membres'**
  String get calendarMembres;

  /// No description provided for @calendarSelectionMembresGroupeConvies.
  ///
  /// In fr, this message translates to:
  /// **'Sans sélection, tous les membres du groupe sont conviés.'**
  String get calendarSelectionMembresGroupeConvies;

  /// No description provided for @calendarDonnezTitreEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un titre à l’événement.'**
  String get calendarDonnezTitreEvenement;

  /// No description provided for @calendarEvenementEteModifie.
  ///
  /// In fr, this message translates to:
  /// **'L’événement a été modifié.'**
  String get calendarEvenementEteModifie;

  /// No description provided for @calendarEvenementTitreEteCree.
  ///
  /// In fr, this message translates to:
  /// **'L’événement « {titre} » a été créé.'**
  String calendarEvenementTitreEteCree(Object titre);

  /// No description provided for @calendarQuelGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Dans quel groupe ? *'**
  String get calendarQuelGroupe;

  /// No description provided for @calendarSeulVerrez.
  ///
  /// In fr, this message translates to:
  /// **'Vous seul le verrez'**
  String get calendarSeulVerrez;

  /// No description provided for @calendarQuelGroupe2.
  ///
  /// In fr, this message translates to:
  /// **'Dans quel groupe ?'**
  String get calendarQuelGroupe2;

  /// No description provided for @chatMoMo.
  ///
  /// In fr, this message translates to:
  /// **'{mo} Mo'**
  String chatMoMo(Object mo);

  /// No description provided for @chatOuiOui.
  ///
  /// In fr, this message translates to:
  /// **'{oui} oui'**
  String chatOuiOui(Object oui);

  /// No description provided for @chatPeutEtrePeutEtre.
  ///
  /// In fr, this message translates to:
  /// **'{peutEtre} peut-être'**
  String chatPeutEtrePeutEtre(Object peutEtre);

  /// No description provided for @chatNonNon.
  ///
  /// In fr, this message translates to:
  /// **'{non} non'**
  String chatNonNon(Object non);

  /// No description provided for @chatAucuneReponse.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réponse'**
  String get chatAucuneReponse;

  /// No description provided for @chatQuelqu.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu’un'**
  String get chatQuelqu;

  /// No description provided for @chatMessagePuEtreEnvoye.
  ///
  /// In fr, this message translates to:
  /// **'Le message n’a pas pu être envoyé. Réessayez dans un instant.'**
  String get chatMessagePuEtreEnvoye;

  /// No description provided for @chatConversationIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Conversation indisponible'**
  String get chatConversationIndisponible;

  /// No description provided for @chatRienEncore.
  ///
  /// In fr, this message translates to:
  /// **'Rien encore'**
  String get chatRienEncore;

  /// No description provided for @chatLancezConversationPersonneEncore.
  ///
  /// In fr, this message translates to:
  /// **'Lancez la conversation : personne n’a encore écrit ici.'**
  String get chatLancezConversationPersonneEncore;

  /// No description provided for @chatReagirEmoji.
  ///
  /// In fr, this message translates to:
  /// **'Réagir {emoji}'**
  String chatReagirEmoji(Object emoji);

  /// No description provided for @chatSupprimerMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le message'**
  String get chatSupprimerMessage;

  /// No description provided for @chatPouvezSupprimerMessages.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez supprimer que vos messages'**
  String get chatPouvezSupprimerMessages;

  /// No description provided for @chatMessageSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Message supprimé.'**
  String get chatMessageSupprime;

  /// No description provided for @chatMessagePeutEtreSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Ce message ne peut plus être supprimé.'**
  String get chatMessagePeutEtreSupprime;

  /// No description provided for @chatNouvelleTache.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tâche'**
  String get chatNouvelleTache;

  /// No description provided for @chatCreerTacheFaire.
  ///
  /// In fr, this message translates to:
  /// **'Créer une tâche à faire'**
  String get chatCreerTacheFaire;

  /// No description provided for @chatPlanifierEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Planifier un événement'**
  String get chatPlanifierEvenement;

  /// No description provided for @chatPhotoVideo.
  ///
  /// In fr, this message translates to:
  /// **'Photo ou vidéo'**
  String get chatPhotoVideo;

  /// No description provided for @chatEnvoyerMedia.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un média'**
  String get chatEnvoyerMedia;

  /// No description provided for @chatRienPrevuInstant.
  ///
  /// In fr, this message translates to:
  /// **'Rien de prévu pour l’instant'**
  String get chatRienPrevuInstant;

  /// No description provided for @chatPhotoGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Photo de la galerie'**
  String get chatPhotoGalerie;

  /// No description provided for @chatPrendrePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get chatPrendrePhoto;

  /// No description provided for @chatVideoGalerie.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo de la galerie'**
  String get chatVideoGalerie;

  /// No description provided for @chatMediaPuEtreLu.
  ///
  /// In fr, this message translates to:
  /// **'Ce média n’a pas pu être lu. Réessayez.'**
  String get chatMediaPuEtreLu;

  /// No description provided for @chatNonEnvoyeReessayer.
  ///
  /// In fr, this message translates to:
  /// **'Non envoyé — réessayer'**
  String get chatNonEnvoyeReessayer;

  /// No description provided for @chatMessageSupprime2.
  ///
  /// In fr, this message translates to:
  /// **'Message supprimé'**
  String get chatMessageSupprime2;

  /// No description provided for @chatTacheEteSupprimee.
  ///
  /// In fr, this message translates to:
  /// **'Cette tâche a été supprimée.'**
  String get chatTacheEteSupprimee;

  /// No description provided for @chatDesister.
  ///
  /// In fr, this message translates to:
  /// **'Me désister'**
  String get chatDesister;

  /// No description provided for @chatProposeeGroupePersonneEncore.
  ///
  /// In fr, this message translates to:
  /// **'Proposée au groupe — personne ne l’a encore prise.'**
  String get chatProposeeGroupePersonneEncore;

  /// No description provided for @chatCetEvenementEteSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement a été supprimé.'**
  String get chatCetEvenementEteSupprime;

  /// No description provided for @chatTresBienTacheReste.
  ///
  /// In fr, this message translates to:
  /// **'Très bien — la tâche reste proposée au groupe.'**
  String get chatTresBienTacheReste;

  /// No description provided for @chatMicrophoneAccessibleAutorisezReglages.
  ///
  /// In fr, this message translates to:
  /// **'Le microphone n’est pas accessible. Autorisez-le dans les réglages de votre navigateur, puis rouvrez la conversation.'**
  String get chatMicrophoneAccessibleAutorisezReglages;

  /// No description provided for @chatAjouterConversation.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la conversation'**
  String get chatAjouterConversation;

  /// No description provided for @chatMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre message'**
  String get chatMessage;

  /// No description provided for @chatFermerEmojis.
  ///
  /// In fr, this message translates to:
  /// **'Fermer les emojis'**
  String get chatFermerEmojis;

  /// No description provided for @chatEnregistrerMessageVocal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un message vocal'**
  String get chatEnregistrerMessageVocal;

  /// No description provided for @chatAnnulerEnregistrement.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l’enregistrement'**
  String get chatAnnulerEnregistrement;

  /// No description provided for @chatEnregistrement.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get chatEnregistrement;

  /// No description provided for @chatEnvoyerMessageVocal.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le message vocal'**
  String get chatEnvoyerMessageVocal;

  /// No description provided for @chatPlusieursPersonnesTrainEcrire.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs personnes sont en train d’écrire…'**
  String get chatPlusieursPersonnesTrainEcrire;

  /// No description provided for @chatMettrePause.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get chatMettrePause;

  /// No description provided for @contactsDemandeEnvoyee.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée.'**
  String get contactsDemandeEnvoyee;

  /// No description provided for @contactsPersonneFaitDejaPartie.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne fait déjà partie de vos contacts.'**
  String get contactsPersonneFaitDejaPartie;

  /// No description provided for @contactsDemandeDejaAttente.
  ///
  /// In fr, this message translates to:
  /// **'Une demande est déjà en attente.'**
  String get contactsDemandeDejaAttente;

  /// No description provided for @contactsPouvezAjouterMeme.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas vous ajouter vous-même.'**
  String get contactsPouvezAjouterMeme;

  /// No description provided for @contactsQRCode.
  ///
  /// In fr, this message translates to:
  /// **'Mon QR code'**
  String get contactsQRCode;

  /// No description provided for @contactsCherchezPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Cherchez un pseudo'**
  String get contactsCherchezPseudo;

  /// No description provided for @contactsSaisissezMoinsDeuxCaracteres.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez au moins deux caractères pour trouver quelqu’un, ou scannez son QR code.'**
  String get contactsSaisissezMoinsDeuxCaracteres;

  /// No description provided for @contactsRechercheIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Recherche indisponible'**
  String get contactsRechercheIndisponible;

  /// No description provided for @contactsAucunResultat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get contactsAucunResultat;

  /// No description provided for @contactsAucunPseudoCommenceTerm.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pseudo ne commence par « {term} ».'**
  String contactsAucunPseudoCommenceTerm(Object term);

  /// No description provided for @contactsDejaCarnet.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans le carnet'**
  String get contactsDejaCarnet;

  /// No description provided for @contactsContacts.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get contactsContacts;

  /// No description provided for @contactsRechercherContact.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un contact'**
  String get contactsRechercherContact;

  /// No description provided for @contactsDemandesRecues.
  ///
  /// In fr, this message translates to:
  /// **'Demandes reçues'**
  String get contactsDemandesRecues;

  /// No description provided for @contactsCarnetIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Carnet indisponible'**
  String get contactsCarnetIndisponible;

  /// No description provided for @contactsCarnetVide.
  ///
  /// In fr, this message translates to:
  /// **'Carnet vide'**
  String get contactsCarnetVide;

  /// No description provided for @contactsAjoutezProchesLeurPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos proches par leur pseudo ou en scannant leur QR code pour planifier ensemble.'**
  String get contactsAjoutezProchesLeurPseudo;

  /// No description provided for @contactsAucunContactCorrespondQuery.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact ne correspond à « {query} ».'**
  String contactsAucunContactCorrespondQuery(Object query);

  /// No description provided for @contactsDemandeRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée.'**
  String get contactsDemandeRefusee;

  /// No description provided for @contactsFaitesScannerCodeEtre.
  ///
  /// In fr, this message translates to:
  /// **'Faites scanner ce code pour être ajouté en contact. Il ne contient que votre pseudo — ni adresse e-mail, ni agenda.'**
  String get contactsFaitesScannerCodeEtre;

  /// No description provided for @contactsPartagerPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon pseudo'**
  String get contactsPartagerPseudo;

  /// No description provided for @contactsPseudoJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Mon pseudo Jelvo'**
  String get contactsPseudoJelvo;

  /// No description provided for @contactsScannerQRCode.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un QR code'**
  String get contactsScannerQRCode;

  /// No description provided for @contactsScanIndisponibleIci.
  ///
  /// In fr, this message translates to:
  /// **'Scan indisponible ici'**
  String get contactsScanIndisponibleIci;

  /// No description provided for @contactsChercherPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Chercher par pseudo'**
  String get contactsChercherPseudo;

  /// No description provided for @contactsCameraInaccessible.
  ///
  /// In fr, this message translates to:
  /// **'Caméra inaccessible'**
  String get contactsCameraInaccessible;

  /// No description provided for @contactsAutorisezAccesCameraScanner.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez l’accès à la caméra pour scanner un QR code.'**
  String get contactsAutorisezAccesCameraScanner;

  /// No description provided for @contactsVisezQRCodeProche.
  ///
  /// In fr, this message translates to:
  /// **'Visez le QR code d’un proche pour lui envoyer une demande de contact.'**
  String get contactsVisezQRCodeProche;

  /// No description provided for @contactsQRCodeProfilJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Ce QR code n’est pas un profil Jelvo.'**
  String get contactsQRCodeProfilJelvo;

  /// No description provided for @contactsAucunComptePortePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte ne porte le pseudo @{pseudo}.'**
  String contactsAucunComptePortePseudo(Object pseudo);

  /// No description provided for @contactsScannerQRCode2.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un QR Code'**
  String get contactsScannerQRCode2;

  /// No description provided for @contactsAjouterContactQRCode.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact avec son QR Code'**
  String get contactsAjouterContactQRCode;

  /// No description provided for @contactsRechercherPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pseudo'**
  String get contactsRechercherPseudo;

  /// No description provided for @contactsTrouverUtilisateurJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Trouver un utilisateur Jelvo'**
  String get contactsTrouverUtilisateurJelvo;

  /// No description provided for @contactsInviterAmi.
  ///
  /// In fr, this message translates to:
  /// **'Inviter un ami'**
  String get contactsInviterAmi;

  /// No description provided for @contactsEnvoyerInvitationJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une invitation Jelvo'**
  String get contactsEnvoyerInvitationJelvo;

  /// No description provided for @contactsRejoignezMoiJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez-moi sur Jelvo'**
  String get contactsRejoignezMoiJelvo;

  /// No description provided for @contactsRetirerFavoris.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get contactsRetirerFavoris;

  /// No description provided for @contactsAjouterFavoris.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get contactsAjouterFavoris;

  /// No description provided for @contactsFavorisTeteCarnet.
  ///
  /// In fr, this message translates to:
  /// **'Les favoris sont en tête de votre carnet'**
  String get contactsFavorisTeteCarnet;

  /// No description provided for @contactsRetirerContacts.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de mes contacts'**
  String get contactsRetirerContacts;

  /// No description provided for @contactsRelationSupprimeeDeuxCotes.
  ///
  /// In fr, this message translates to:
  /// **'La relation est supprimée des deux côtés'**
  String get contactsRelationSupprimeeDeuxCotes;

  /// No description provided for @contactsRetirerContact.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce contact'**
  String get contactsRetirerContact;

  /// No description provided for @contactsGererFavoris.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les favoris'**
  String get contactsGererFavoris;

  /// No description provided for @contactsFavoriPersonnelAutreSait.
  ///
  /// In fr, this message translates to:
  /// **'Le favori est personnel : l’autre n’en sait rien.'**
  String get contactsFavoriPersonnelAutreSait;

  /// No description provided for @contactsAjoutezAbordContactsEpingler.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez d’abord des contacts à épingler.'**
  String get contactsAjoutezAbordContactsEpingler;

  /// No description provided for @contactsEpinglezProchesRetrouverIci.
  ///
  /// In fr, this message translates to:
  /// **'Épinglez vos proches pour les retrouver ici.'**
  String get contactsEpinglezProchesRetrouverIci;

  /// No description provided for @contactsScanQRCodeDemande.
  ///
  /// In fr, this message translates to:
  /// **'Le scan de QR code demande une caméra : il est disponible sur l’application mobile. Ici, cherchez la personne par son pseudo.'**
  String get contactsScanQRCodeDemande;

  /// No description provided for @createCreneauAgendaSeulPartage.
  ///
  /// In fr, this message translates to:
  /// **'Un créneau dans votre agenda, seul ou partagé'**
  String get createCreneauAgendaSeulPartage;

  /// No description provided for @createActionFaireEcheanceResponsable.
  ///
  /// In fr, this message translates to:
  /// **'Une action à faire, avec échéance et responsable'**
  String get createActionFaireEcheanceResponsable;

  /// No description provided for @createEspacePartageProchesAmis.
  ///
  /// In fr, this message translates to:
  /// **'Un espace partagé avec vos proches ou vos amis'**
  String get createEspacePartageProchesAmis;

  /// No description provided for @createChoisissezTypeFormulaireOuvre.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un type : le formulaire s’ouvre juste en dessous.'**
  String get createChoisissezTypeFormulaireOuvre;

  /// No description provided for @groupsLienInvitationExisteValable.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d’invitation n’existe pas ou n’est plus valable.'**
  String get groupsLienInvitationExisteValable;

  /// No description provided for @groupsLienInvitationExpireDemandez.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d’invitation a expiré. Demandez-en un nouveau au groupe.'**
  String get groupsLienInvitationExpireDemandez;

  /// No description provided for @groupsLienInvitationEteRevoque.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d’invitation a été révoqué par le groupe.'**
  String get groupsLienInvitationEteRevoque;

  /// No description provided for @groupsLienDejaServiNombre.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien a déjà servi au nombre de fois prévu.'**
  String get groupsLienDejaServiNombre;

  /// No description provided for @groupsAvezRejointGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez rejoint le groupe.'**
  String get groupsAvezRejointGroupe;

  /// No description provided for @groupsFaitesDejaPartieGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous faites déjà partie de ce groupe.'**
  String get groupsFaitesDejaPartieGroupe;

  /// No description provided for @groupsLienInvitationExpire.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d’invitation a expiré.'**
  String get groupsLienInvitationExpire;

  /// No description provided for @groupsLienInvitationEteRevoque2.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien d’invitation a été révoqué.'**
  String get groupsLienInvitationEteRevoque2;

  /// No description provided for @groupsConnectezRejoindreGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour rejoindre ce groupe.'**
  String get groupsConnectezRejoindreGroupe;

  /// No description provided for @groupsAvezQuitteGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le groupe.'**
  String get groupsAvezQuitteGroupe;

  /// No description provided for @groupsAvezQuitteGroupeAncien.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le groupe. Le plus ancien membre en devient admin.'**
  String get groupsAvezQuitteGroupeAncien;

  /// No description provided for @groupsEtiezDernierMembreGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous étiez le dernier membre : le groupe a été supprimé.'**
  String get groupsEtiezDernierMembreGroupe;

  /// No description provided for @groupsFaitesPartieGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne faites pas partie de ce groupe.'**
  String get groupsFaitesPartieGroupe;

  /// No description provided for @groupsNomDesormaisAdministrateur.
  ///
  /// In fr, this message translates to:
  /// **'{nom} est désormais administrateur.'**
  String groupsNomDesormaisAdministrateur(Object nom);

  /// No description provided for @groupsNomAdministrateur.
  ///
  /// In fr, this message translates to:
  /// **'{nom} n’est plus administrateur.'**
  String groupsNomAdministrateur(Object nom);

  /// No description provided for @groupsNomEteRetireGroupe.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a été retiré du groupe.'**
  String groupsNomEteRetireGroupe(Object nom);

  /// No description provided for @groupsAdhesionNomDesormaisTemporaire.
  ///
  /// In fr, this message translates to:
  /// **'L’adhésion de {nom} est désormais temporaire.'**
  String groupsAdhesionNomDesormaisTemporaire(Object nom);

  /// No description provided for @groupsNomFaitPartieGroupe.
  ///
  /// In fr, this message translates to:
  /// **'{nom} fait partie du groupe jusqu’au {terme}.'**
  String groupsNomFaitPartieGroupe(Object nom, Object terme);

  /// No description provided for @groupsAdhesionNomTerme.
  ///
  /// In fr, this message translates to:
  /// **'L’adhésion de {nom} n’a plus de terme.'**
  String groupsAdhesionNomTerme(Object nom);

  /// No description provided for @groupsEtaitDejaCasRien.
  ///
  /// In fr, this message translates to:
  /// **'C’était déjà le cas, rien n’a changé.'**
  String get groupsEtaitDejaCasRien;

  /// No description provided for @groupsDateDejaPasseeDepart.
  ///
  /// In fr, this message translates to:
  /// **'Cette date est déjà passée. Pour un départ immédiat, utilisez « Retirer du groupe ».'**
  String get groupsDateDejaPasseeDepart;

  /// No description provided for @groupsNomDejaAdministrateur.
  ///
  /// In fr, this message translates to:
  /// **'{nom} est déjà administrateur.'**
  String groupsNomDejaAdministrateur(Object nom);

  /// No description provided for @groupsGroupeDoitGarderMoins.
  ///
  /// In fr, this message translates to:
  /// **'Un groupe doit garder au moins un administrateur. Nommez quelqu’un d’autre avant.'**
  String get groupsGroupeDoitGarderMoins;

  /// No description provided for @groupsSeulAdministrateurGroupePeut.
  ///
  /// In fr, this message translates to:
  /// **'Seul un administrateur du groupe peut faire cela.'**
  String get groupsSeulAdministrateurGroupePeut;

  /// No description provided for @groupsNomAdministrateur2.
  ///
  /// In fr, this message translates to:
  /// **'{nom} n’est pas administrateur.'**
  String groupsNomAdministrateur2(Object nom);

  /// No description provided for @groupsNomFaitPartieGroupe2.
  ///
  /// In fr, this message translates to:
  /// **'{nom} ne fait plus partie du groupe.'**
  String groupsNomFaitPartieGroupe2(Object nom);

  /// No description provided for @groupsPartirMemeUtilisezQuitter.
  ///
  /// In fr, this message translates to:
  /// **'Pour partir vous-même, utilisez « Quitter le groupe ».'**
  String get groupsPartirMemeUtilisezQuitter;

  /// No description provided for @groupsActionAboutiReessayezInstant.
  ///
  /// In fr, this message translates to:
  /// **'L’action n’a pas abouti. Réessayez dans un instant.'**
  String get groupsActionAboutiReessayezInstant;

  /// No description provided for @groupsJamaisUtilise.
  ///
  /// In fr, this message translates to:
  /// **'Jamais utilisé'**
  String get groupsJamaisUtilise;

  /// No description provided for @groupsInvitationDejaAcceptee.
  ///
  /// In fr, this message translates to:
  /// **'Invitation déjà acceptée'**
  String get groupsInvitationDejaAcceptee;

  /// No description provided for @groupsInvitationDejaRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Invitation déjà refusée'**
  String get groupsInvitationDejaRefusee;

  /// No description provided for @groupsInvitationExpiree.
  ///
  /// In fr, this message translates to:
  /// **'Invitation expirée'**
  String get groupsInvitationExpiree;

  /// No description provided for @groupsEtesDejaMembre.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes déjà membre'**
  String get groupsEtesDejaMembre;

  /// No description provided for @groupsGroupeSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Groupe supprimé'**
  String get groupsGroupeSupprime;

  /// No description provided for @groupsInvitationIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Invitation introuvable'**
  String get groupsInvitationIntrouvable;

  /// No description provided for @groupsAvezDejaRejointGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà rejoint ce groupe. Ouvrez-le pour y retrouver ses événements, ses tâches et sa conversation.'**
  String get groupsAvezDejaRejointGroupe;

  /// No description provided for @groupsAvezDeclineInvitationDemandez.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez décliné cette invitation. Demandez-en une nouvelle si vous changez d’avis.'**
  String get groupsAvezDeclineInvitationDemandez;

  /// No description provided for @groupsInvitationPasseDateLimite.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation a passé sa date limite. Demandez-en une nouvelle au groupe.'**
  String get groupsInvitationPasseDateLimite;

  /// No description provided for @groupsFaitesDejaPartieGroupe2.
  ///
  /// In fr, this message translates to:
  /// **'Vous faites déjà partie de ce groupe, sans doute par un lien de partage.'**
  String get groupsFaitesDejaPartieGroupe2;

  /// No description provided for @groupsGroupeInvitaitEteSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe qui vous invitait a été supprimé. Il n’y a plus rien à rejoindre.'**
  String get groupsGroupeInvitaitEteSupprime;

  /// No description provided for @groupsInvitationExisteEtaitDestinee.
  ///
  /// In fr, this message translates to:
  /// **'Cette invitation n’existe pas, ou elle ne vous était pas destinée.'**
  String get groupsInvitationExisteEtaitDestinee;

  /// No description provided for @groupsGroupe.
  ///
  /// In fr, this message translates to:
  /// **'ce groupe'**
  String get groupsGroupe;

  /// No description provided for @groupsGroupePuEtreCree.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe n’a pas pu être créé. Réessayez dans un instant.'**
  String get groupsGroupePuEtreCree;

  /// No description provided for @groupsGroupeIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Groupe indisponible'**
  String get groupsGroupeIndisponible;

  /// No description provided for @groupsGroupeIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Groupe introuvable'**
  String get groupsGroupeIntrouvable;

  /// No description provided for @groupsGroupeEteSupprimeFaites.
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe a été supprimé, ou vous n’en faites plus partie.'**
  String get groupsGroupeEteSupprimeFaites;

  /// No description provided for @groupsRevenirGroupes.
  ///
  /// In fr, this message translates to:
  /// **'Revenir aux groupes'**
  String get groupsRevenirGroupes;

  /// No description provided for @groupsInviterQuelqu.
  ///
  /// In fr, this message translates to:
  /// **'Inviter quelqu’un'**
  String get groupsInviterQuelqu;

  /// No description provided for @groupsPartagerLien.
  ///
  /// In fr, this message translates to:
  /// **'Partager un lien'**
  String get groupsPartagerLien;

  /// No description provided for @groupsModifierGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get groupsModifierGroupe;

  /// No description provided for @groupsQuitterGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get groupsQuitterGroupe;

  /// No description provided for @groupsSupprimerGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get groupsSupprimerGroupe;

  /// No description provided for @groupsAucunMembreAfficher.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre à afficher'**
  String get groupsAucunMembreAfficher;

  /// No description provided for @groupsListeMembresPuEtre.
  ///
  /// In fr, this message translates to:
  /// **'La liste des membres n’a pas pu être chargée. Réessayez dans un instant.'**
  String get groupsListeMembresPuEtre;

  /// No description provided for @groupsVoir.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get groupsVoir;

  /// No description provided for @groupsAjouterEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un événement'**
  String get groupsAjouterEvenement;

  /// No description provided for @groupsTachesPrioritaires.
  ///
  /// In fr, this message translates to:
  /// **'Tâches prioritaires'**
  String get groupsTachesPrioritaires;

  /// No description provided for @groupsRetirerMembre.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce membre'**
  String get groupsRetirerMembre;

  /// No description provided for @groupsGroupeEteSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe a été supprimé.'**
  String get groupsGroupeEteSupprime;

  /// No description provided for @groupsDecrivezGroupePhrase.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez ce groupe en une phrase.'**
  String get groupsDecrivezGroupePhrase;

  /// No description provided for @groupsInviterMembre.
  ///
  /// In fr, this message translates to:
  /// **'Inviter un membre'**
  String get groupsInviterMembre;

  /// No description provided for @groupsCherchezPersonnePseudoRecevra.
  ///
  /// In fr, this message translates to:
  /// **'Cherchez la personne par son pseudo. Elle recevra une invitation à accepter.'**
  String get groupsCherchezPersonnePseudoRecevra;

  /// No description provided for @groupsNameRecuInvitation.
  ///
  /// In fr, this message translates to:
  /// **'{name} a reçu votre invitation.'**
  String groupsNameRecuInvitation(Object name);

  /// No description provided for @groupsNameFaitDejaPartie.
  ///
  /// In fr, this message translates to:
  /// **'{name} fait déjà partie du groupe.'**
  String groupsNameFaitDejaPartie(Object name);

  /// No description provided for @groupsNameDejaInvitationAttente.
  ///
  /// In fr, this message translates to:
  /// **'{name} a déjà une invitation en attente.'**
  String groupsNameDejaInvitationAttente(Object name);

  /// No description provided for @groupsDateFinChoisieDeja.
  ///
  /// In fr, this message translates to:
  /// **'La date de fin choisie est déjà passée.'**
  String get groupsDateFinChoisieDeja;

  /// No description provided for @groupsSeulAdministrateurPeutFixer.
  ///
  /// In fr, this message translates to:
  /// **'Seul un administrateur peut fixer une durée d’adhésion.'**
  String get groupsSeulAdministrateurPeutFixer;

  /// No description provided for @groupsSeulsMembresGroupePeuvent.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les membres du groupe peuvent inviter.'**
  String get groupsSeulsMembresGroupePeuvent;

  /// No description provided for @groupsSaisissezMoinsDeuxCaracteres.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez au moins deux caractères.'**
  String get groupsSaisissezMoinsDeuxCaracteres;

  /// No description provided for @groupsCreezGroupeInvitezPremiers.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre groupe et invitez les premiers membres.'**
  String get groupsCreezGroupeInvitezPremiers;

  /// No description provided for @groupsPhotoGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Photo du groupe'**
  String get groupsPhotoGroupe;

  /// No description provided for @groupsNomGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe *'**
  String get groupsNomGroupe;

  /// No description provided for @groupsExFamilleRousseau.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Famille Rousseau'**
  String get groupsExFamilleRousseau;

  /// No description provided for @groupsDescriptionOptionnelle.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnelle)'**
  String get groupsDescriptionOptionnelle;

  /// No description provided for @groupsDecrivezBrievementButGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez brièvement le but de ce groupe'**
  String get groupsDecrivezBrievementButGroupe;

  /// No description provided for @groupsCreerGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Créer le groupe'**
  String get groupsCreerGroupe;

  /// No description provided for @groupsDonnezNomGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un nom à votre groupe.'**
  String get groupsDonnezNomGroupe;

  /// No description provided for @groupsNomDoitDepasserNameMaxLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom ne doit pas dépasser {_nameMaxLength} caractères.'**
  String groupsNomDoitDepasserNameMaxLength(Object _nameMaxLength);

  /// No description provided for @groupsGroupeCree1Invitation.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé, 1 invitation envoyée.'**
  String get groupsGroupeCree1Invitation;

  /// No description provided for @groupsGroupeCreeEnvoyeesInvitations.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé, {envoyees} invitations envoyées.'**
  String groupsGroupeCreeEnvoyeesInvitations(Object envoyees);

  /// No description provided for @groupsGroupeCreeMaisInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé, mais l’invitation n’a pas pu partir.'**
  String get groupsGroupeCreeMaisInvitation;

  /// No description provided for @groupsGroupeCreeMaisAucune.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé, mais aucune des {echecs} invitations n’a pu partir.'**
  String groupsGroupeCreeMaisAucune(Object echecs);

  /// No description provided for @groupsGroupeCreeEnvoyeesInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé, {envoyees} invitation(s) envoyée(s), {echecs} non parties.'**
  String groupsGroupeCreeEnvoyeesInvitation(Object envoyees, Object echecs);

  /// No description provided for @groupsGroupePrive.
  ///
  /// In fr, this message translates to:
  /// **'Groupe privé'**
  String get groupsGroupePrive;

  /// No description provided for @groupsSeulsMembresInvitesPourront.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les membres invités pourront le rejoindre et voir son contenu. Tous les groupes Jelvo le sont.'**
  String get groupsSeulsMembresInvitesPourront;

  /// No description provided for @groupsRechercherGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un groupe'**
  String get groupsRechercherGroupe;

  /// No description provided for @groupsEffacerRecherche.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get groupsEffacerRecherche;

  /// No description provided for @groupsGroupesIndisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Groupes indisponibles'**
  String get groupsGroupesIndisponibles;

  /// No description provided for @groupsAucunGroupeMoment.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe pour le moment'**
  String get groupsAucunGroupeMoment;

  /// No description provided for @groupsCreezGroupePartagerAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Créez un groupe pour partager un agenda et répartir les tâches avec vos proches.'**
  String get groupsCreezGroupePartagerAgenda;

  /// No description provided for @groupsCreerGroupe2.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get groupsCreerGroupe2;

  /// No description provided for @groupsAucunGroupeNom.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe à ce nom'**
  String get groupsAucunGroupeNom;

  /// No description provided for @groupsAucunGroupesCorrespondTerme.
  ///
  /// In fr, this message translates to:
  /// **'Aucun de vos groupes ne correspond à « {terme} ».'**
  String groupsAucunGroupesCorrespondTerme(Object terme);

  /// No description provided for @groupsInviteRejoindreGroupe.
  ///
  /// In fr, this message translates to:
  /// **'On vous a invité à rejoindre un groupe.'**
  String get groupsInviteRejoindreGroupe;

  /// No description provided for @groupsInvitationsIndisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Invitations indisponibles'**
  String get groupsInvitationsIndisponibles;

  /// No description provided for @groupsAucuneInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune invitation'**
  String get groupsAucuneInvitation;

  /// No description provided for @groupsQuandProcheInviteraGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Quand un proche vous invitera dans un groupe, l’invitation apparaîtra ici.'**
  String get groupsQuandProcheInviteraGroupe;

  /// No description provided for @groupsInvitationIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Invitation indisponible'**
  String get groupsInvitationIndisponible;

  /// No description provided for @groupsInviteRejoindreGroupe2.
  ///
  /// In fr, this message translates to:
  /// **'vous invite à rejoindre un groupe'**
  String get groupsInviteRejoindreGroupe2;

  /// No description provided for @groupsCree.
  ///
  /// In fr, this message translates to:
  /// **'Créé le'**
  String get groupsCree;

  /// No description provided for @groupsDejaGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans le groupe'**
  String get groupsDejaGroupe;

  /// No description provided for @groupsInvitationRefusee.
  ///
  /// In fr, this message translates to:
  /// **'Invitation refusée.'**
  String get groupsInvitationRefusee;

  /// No description provided for @groupsOuvrirGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le groupe'**
  String get groupsOuvrirGroupe;

  /// No description provided for @groupsLienInutilisable.
  ///
  /// In fr, this message translates to:
  /// **'Lien inutilisable'**
  String get groupsLienInutilisable;

  /// No description provided for @groupsRevenirAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à l\'accueil'**
  String get groupsRevenirAccueil;

  /// No description provided for @groupsEtesInviteRejoindreGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes invité à rejoindre ce groupe sur Jelvo.'**
  String get groupsEtesInviteRejoindreGroupe;

  /// No description provided for @groupsRejoindreGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre le groupe'**
  String get groupsRejoindreGroupe;

  /// No description provided for @groupsCreerCompteRejoindre.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte pour rejoindre'**
  String get groupsCreerCompteRejoindre;

  /// No description provided for @groupsAiDejaCompte.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get groupsAiDejaCompte;

  /// No description provided for @groupsGroupeSeraRejointAutomatiquement.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe sera rejoint automatiquement une fois votre compte créé.'**
  String get groupsGroupeSeraRejointAutomatiquement;

  /// No description provided for @groupsCreezIciSeraPartage.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous créez ici sera partagé avec le groupe.'**
  String get groupsCreezIciSeraPartage;

  /// No description provided for @groupsDateProposerMembres.
  ///
  /// In fr, this message translates to:
  /// **'Une date à proposer aux membres'**
  String get groupsDateProposerMembres;

  /// No description provided for @groupsQuelqueChoseFaireRepartir.
  ///
  /// In fr, this message translates to:
  /// **'Quelque chose à faire, à répartir'**
  String get groupsQuelqueChoseFaireRepartir;

  /// No description provided for @groupsAjouterMembres.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des membres'**
  String get groupsAjouterMembres;

  /// No description provided for @groupsChoisirContacts.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans mes contacts'**
  String get groupsChoisirContacts;

  /// No description provided for @groupsParcourirCarnetJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir mon carnet Jelvo'**
  String get groupsParcourirCarnetJelvo;

  /// No description provided for @groupsInviterLien.
  ///
  /// In fr, this message translates to:
  /// **'Inviter par lien'**
  String get groupsInviterLien;

  /// No description provided for @groupsProposeApresCreation.
  ///
  /// In fr, this message translates to:
  /// **'Proposé après la création'**
  String get groupsProposeApresCreation;

  /// No description provided for @groupsPartagerLienInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Partager un lien d’invitation'**
  String get groupsPartagerLienInvitation;

  /// No description provided for @groupsInvitationsPartentCreationGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Les invitations partent à la création du groupe.'**
  String get groupsInvitationsPartentCreationGroupe;

  /// No description provided for @groupsAucunContactNom.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact à ce nom.'**
  String get groupsAucunContactNom;

  /// No description provided for @groupsPersonneInviteInstant.
  ///
  /// In fr, this message translates to:
  /// **'Personne n’est invité pour l’instant.'**
  String get groupsPersonneInviteInstant;

  /// No description provided for @groups1PersonneSeraInvitee.
  ///
  /// In fr, this message translates to:
  /// **'1 personne sera invitée.'**
  String get groups1PersonneSeraInvitee;

  /// No description provided for @groupsNombrePersonnesSerontInvitees.
  ///
  /// In fr, this message translates to:
  /// **'{nombre} personnes seront invitées.'**
  String groupsNombrePersonnesSerontInvitees(Object nombre);

  /// No description provided for @groupsRetirer.
  ///
  /// In fr, this message translates to:
  /// **'Tout retirer'**
  String get groupsRetirer;

  /// No description provided for @groupsCarnetVideInstantPourrez.
  ///
  /// In fr, this message translates to:
  /// **'Votre carnet est vide pour l’instant. Vous pourrez inviter depuis l’écran du groupe, par lien de partage ou par pseudo.'**
  String get groupsCarnetVideInstantPourrez;

  /// No description provided for @groupsChoisirPhotoGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo de groupe'**
  String get groupsChoisirPhotoGroupe;

  /// No description provided for @groupsChangerPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Changer la photo'**
  String get groupsChangerPhoto;

  /// No description provided for @groupsAjouterPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get groupsAjouterPhoto;

  /// No description provided for @groupsTachesNenRetard.
  ///
  /// In fr, this message translates to:
  /// **'tâches\nen retard'**
  String get groupsTachesNenRetard;

  /// No description provided for @groupsEvenementsNaVenir.
  ///
  /// In fr, this message translates to:
  /// **'événements\nà venir'**
  String get groupsEvenementsNaVenir;

  /// No description provided for @groupsAucunLienActifMoment.
  ///
  /// In fr, this message translates to:
  /// **'Aucun lien actif pour le moment.'**
  String get groupsAucunLienActifMoment;

  /// No description provided for @groupsDureeAccordeeProchainLien.
  ///
  /// In fr, this message translates to:
  /// **'Durée accordée par le prochain lien'**
  String get groupsDureeAccordeeProchainLien;

  /// No description provided for @groupsGenererLien.
  ///
  /// In fr, this message translates to:
  /// **'Générer un lien'**
  String get groupsGenererLien;

  /// No description provided for @groupsGenererAutreLien.
  ///
  /// In fr, this message translates to:
  /// **'Générer un autre lien'**
  String get groupsGenererAutreLien;

  /// No description provided for @groupsLienCopiePressePapiers.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié dans le presse-papiers.'**
  String get groupsLienCopiePressePapiers;

  /// No description provided for @groupsCopierLien.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get groupsCopierLien;

  /// No description provided for @groupsRevoquerLien.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer le lien'**
  String get groupsRevoquerLien;

  /// No description provided for @groupsGererMembre.
  ///
  /// In fr, this message translates to:
  /// **'Gérer ce membre'**
  String get groupsGererMembre;

  /// No description provided for @groupsRetirerRoleAdministrateur.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le rôle d’administrateur'**
  String get groupsRetirerRoleAdministrateur;

  /// No description provided for @groupsNommerAdministrateur.
  ///
  /// In fr, this message translates to:
  /// **'Nommer administrateur'**
  String get groupsNommerAdministrateur;

  /// No description provided for @groupsModifierDureeAdhesion.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la durée de l’adhésion'**
  String get groupsModifierDureeAdhesion;

  /// No description provided for @groupsRendreAdhesionTemporaire.
  ///
  /// In fr, this message translates to:
  /// **'Rendre l’adhésion temporaire'**
  String get groupsRendreAdhesionTemporaire;

  /// No description provided for @groupsRetirerGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du groupe'**
  String get groupsRetirerGroupe;

  /// No description provided for @groupsDureeAdhesion.
  ///
  /// In fr, this message translates to:
  /// **'Durée de l’adhésion'**
  String get groupsDureeAdhesion;

  /// No description provided for @groupsTerme.
  ///
  /// In fr, this message translates to:
  /// **'Sans terme'**
  String get groupsTerme;

  /// No description provided for @groupsFinAdhesion.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l’adhésion'**
  String get groupsFinAdhesion;

  /// No description provided for @groupsNouvelleDuree.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle durée'**
  String get groupsNouvelleDuree;

  /// No description provided for @homeBonApresMidi.
  ///
  /// In fr, this message translates to:
  /// **'Bon après-midi'**
  String get homeBonApresMidi;

  /// No description provided for @homeCreezGroupePartagerAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Créez un groupe pour partager un agenda, des tâches et une conversation.'**
  String get homeCreezGroupePartagerAgenda;

  /// No description provided for @homeBasePrenom.
  ///
  /// In fr, this message translates to:
  /// **'{base} {prenom}'**
  String homeBasePrenom(Object base, Object prenom);

  /// No description provided for @homeAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Mon agenda'**
  String get homeAgenda;

  /// No description provided for @homeVoirCalendrier.
  ///
  /// In fr, this message translates to:
  /// **'Voir calendrier'**
  String get homeVoirCalendrier;

  /// No description provided for @homeVoirAgenda1.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout mon agenda (1 de plus)'**
  String get homeVoirAgenda1;

  /// No description provided for @homeVoirAgendaReste.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout mon agenda ({reste} de plus)'**
  String homeVoirAgendaReste(Object reste);

  /// No description provided for @homeTaches.
  ///
  /// In fr, this message translates to:
  /// **'Mes tâches'**
  String get homeTaches;

  /// No description provided for @homeVoirToutesTaches.
  ///
  /// In fr, this message translates to:
  /// **'Voir toutes mes tâches'**
  String get homeVoirToutesTaches;

  /// No description provided for @home1Tache.
  ///
  /// In fr, this message translates to:
  /// **'1 tâche'**
  String get home1Tache;

  /// No description provided for @homeSemaine.
  ///
  /// In fr, this message translates to:
  /// **'cette semaine'**
  String get homeSemaine;

  /// No description provided for @homeTraiter.
  ///
  /// In fr, this message translates to:
  /// **'à traiter'**
  String get homeTraiter;

  /// No description provided for @homeAucuneTacheAttendEtre.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tâche n’attend d’être traitée.'**
  String get homeAucuneTacheAttendEtre;

  /// No description provided for @homeDejaAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans votre agenda'**
  String get homeDejaAgenda;

  /// No description provided for @homeTachesJourFigurentChronologie.
  ///
  /// In fr, this message translates to:
  /// **'Vos tâches du jour figurent dans la chronologie ci-dessus.'**
  String get homeTachesJourFigurentChronologie;

  /// No description provided for @homeValeurLibelleDetail.
  ///
  /// In fr, this message translates to:
  /// **'{valeur} {libelle}, {detail}'**
  String homeValeurLibelleDetail(Object valeur, Object libelle, Object detail);

  /// No description provided for @homeValeurLibelle.
  ///
  /// In fr, this message translates to:
  /// **'{valeur} {libelle}'**
  String homeValeurLibelle(Object valeur, Object libelle);

  /// No description provided for @homeAujourdHui.
  ///
  /// In fr, this message translates to:
  /// **', aujourd\'hui'**
  String get homeAujourdHui;

  /// No description provided for @homeRienPrevu.
  ///
  /// In fr, this message translates to:
  /// **', rien de prévu'**
  String get homeRienPrevu;

  /// No description provided for @notificationsGroupe.
  ///
  /// In fr, this message translates to:
  /// **'un groupe'**
  String get notificationsGroupe;

  /// No description provided for @notificationsContact.
  ///
  /// In fr, this message translates to:
  /// **'Un contact'**
  String get notificationsContact;

  /// No description provided for @notificationsEvenement.
  ///
  /// In fr, this message translates to:
  /// **'un événement'**
  String get notificationsEvenement;

  /// No description provided for @notificationsTache.
  ///
  /// In fr, this message translates to:
  /// **'une tâche'**
  String get notificationsTache;

  /// No description provided for @notificationsInvitationRejoindreGroupName.
  ///
  /// In fr, this message translates to:
  /// **'Invitation à rejoindre {groupName}'**
  String notificationsInvitationRejoindreGroupName(Object groupName);

  /// No description provided for @notificationsDemandeContact.
  ///
  /// In fr, this message translates to:
  /// **'Demande de contact'**
  String get notificationsDemandeContact;

  /// No description provided for @notificationsSenderNameInviteRejoindreGroupName.
  ///
  /// In fr, this message translates to:
  /// **'{senderName} vous invite à rejoindre « {groupName} ».'**
  String notificationsSenderNameInviteRejoindreGroupName(
    Object senderName,
    Object groupName,
  );

  /// No description provided for @notificationsSenderNameSouhaiteAjouterContacts.
  ///
  /// In fr, this message translates to:
  /// **'{senderName} souhaite vous ajouter à ses contacts.'**
  String notificationsSenderNameSouhaiteAjouterContacts(Object senderName);

  /// No description provided for @notificationsSenderNameConfieTache.
  ///
  /// In fr, this message translates to:
  /// **'{senderName} vous a confié cette tâche.'**
  String notificationsSenderNameConfieTache(Object senderName);

  /// No description provided for @notificationsSenderNameAccepteTache.
  ///
  /// In fr, this message translates to:
  /// **'{senderName} accepte cette tâche.'**
  String notificationsSenderNameAccepteTache(Object senderName);

  /// No description provided for @notificationsSenderNameDeclineTache.
  ///
  /// In fr, this message translates to:
  /// **'{senderName} décline cette tâche.'**
  String notificationsSenderNameDeclineTache(Object senderName);

  /// No description provided for @notificationsFeteAnniversaireAujourdHui.
  ///
  /// In fr, this message translates to:
  /// **'fête son anniversaire aujourd’hui.'**
  String get notificationsFeteAnniversaireAujourdHui;

  /// No description provided for @notificationsAvezNouvelleNotification.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez une nouvelle notification.'**
  String get notificationsAvezNouvelleNotification;

  /// No description provided for @notificationsVoirDemande.
  ///
  /// In fr, this message translates to:
  /// **'Voir la demande'**
  String get notificationsVoirDemande;

  /// No description provided for @notificationsVoirEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Voir l’événement'**
  String get notificationsVoirEvenement;

  /// No description provided for @notificationsVoirTache.
  ///
  /// In fr, this message translates to:
  /// **'Voir la tâche'**
  String get notificationsVoirTache;

  /// No description provided for @notificationsGroupesDiscussions.
  ///
  /// In fr, this message translates to:
  /// **'Groupes et discussions'**
  String get notificationsGroupesDiscussions;

  /// No description provided for @notificationsTachesRappels.
  ///
  /// In fr, this message translates to:
  /// **'Tâches et rappels'**
  String get notificationsTachesRappels;

  /// No description provided for @notificationsMarquerCommeLu.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get notificationsMarquerCommeLu;

  /// No description provided for @notificationsNotificationsIndisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Notifications indisponibles'**
  String get notificationsNotificationsIndisponibles;

  /// No description provided for @notificationsAucuneNotification.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get notificationsAucuneNotification;

  /// No description provided for @notificationsInvitationsGroupeDemandesContact.
  ///
  /// In fr, this message translates to:
  /// **'Les invitations à un groupe et les demandes de contact apparaîtront ici.'**
  String get notificationsInvitationsGroupeDemandesContact;

  /// No description provided for @notificationsNotificationsPush.
  ///
  /// In fr, this message translates to:
  /// **'Notifications push'**
  String get notificationsNotificationsPush;

  /// No description provided for @notificationsInstaller.
  ///
  /// In fr, this message translates to:
  /// **'À installer'**
  String get notificationsInstaller;

  /// No description provided for @notificationsActiverNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get notificationsActiverNotifications;

  /// No description provided for @notificationsDesactiverCetAppareil.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver sur cet appareil'**
  String get notificationsDesactiverCetAppareil;

  /// No description provided for @notificationsNotificationsActives.
  ///
  /// In fr, this message translates to:
  /// **'Notifications actives'**
  String get notificationsNotificationsActives;

  /// No description provided for @notificationsNotificationsRefusees.
  ///
  /// In fr, this message translates to:
  /// **'Notifications refusées'**
  String get notificationsNotificationsRefusees;

  /// No description provided for @notificationsInstallezJelvoRecevoir.
  ///
  /// In fr, this message translates to:
  /// **'Installez Jelvo pour les recevoir'**
  String get notificationsInstallezJelvoRecevoir;

  /// No description provided for @notificationsNotificationsDesactivees.
  ///
  /// In fr, this message translates to:
  /// **'Notifications désactivées'**
  String get notificationsNotificationsDesactivees;

  /// No description provided for @notificationsNotificationsIndisponiblesIci.
  ///
  /// In fr, this message translates to:
  /// **'Notifications indisponibles ici'**
  String get notificationsNotificationsIndisponiblesIci;

  /// No description provided for @notificationsCetAppareilRecevraNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil recevra les notifications que vous laissez cochées que vous laissez cochées dans les paramètres.'**
  String get notificationsCetAppareilRecevraNotifications;

  /// No description provided for @notificationsAvezRefuseAutorisationApplication.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez refusé l’autorisation. L’application ne peut plus la redemander : elle se rouvre dans les réglages de votre navigateur, à la ligne « Notifications » du site.'**
  String get notificationsAvezRefuseAutorisationApplication;

  /// No description provided for @notificationsIPhoneIPadNotificationsExistent.
  ///
  /// In fr, this message translates to:
  /// **'Sur iPhone et iPad, les notifications n’existent que dans Jelvo ajouté à l’écran d’accueil. Dans un onglet Safari, le système ne les propose pas du tout.'**
  String get notificationsIPhoneIPadNotificationsExistent;

  /// No description provided for @notificationsNavigateurDemanderaAutorisationPourrez.
  ///
  /// In fr, this message translates to:
  /// **'Votre navigateur vous demandera l’autorisation. Vous pourrez revenir dessus à tout moment.'**
  String get notificationsNavigateurDemanderaAutorisationPourrez;

  /// No description provided for @notificationsVersionApplicationGereNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de l’application ne gère pas les notifications système.'**
  String get notificationsVersionApplicationGereNotifications;

  /// No description provided for @notificationsAutorisationRefuseeRouvreReglages.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation refusée. Elle se rouvre dans les réglages de votre navigateur, pas ici.'**
  String get notificationsAutorisationRefuseeRouvreReglages;

  /// No description provided for @notificationsNotificationsOntPuEtre.
  ///
  /// In fr, this message translates to:
  /// **'Les notifications n’ont pas pu être activées.'**
  String get notificationsNotificationsOntPuEtre;

  /// No description provided for @notificationsNotificationsDesactiveesCetAppareil.
  ///
  /// In fr, this message translates to:
  /// **'Notifications désactivées sur cet appareil.'**
  String get notificationsNotificationsDesactiveesCetAppareil;

  /// No description provided for @notifications1TouchezBoutonPartager.
  ///
  /// In fr, this message translates to:
  /// **'1. Touchez le bouton Partager de Safari.'**
  String get notifications1TouchezBoutonPartager;

  /// No description provided for @notifications2ChoisissezEcranAccueil.
  ///
  /// In fr, this message translates to:
  /// **'2. Choisissez « Sur l’écran d’accueil ».'**
  String get notifications2ChoisissezEcranAccueil;

  /// No description provided for @notifications3OuvrezJelvoDepuis.
  ///
  /// In fr, this message translates to:
  /// **'3. Ouvrez Jelvo depuis l’icône, puis reconnectez-vous.'**
  String get notifications3OuvrezJelvoDepuis;

  /// No description provided for @notificationsReconnexionErreurApplicationInstallee.
  ///
  /// In fr, this message translates to:
  /// **'La reconnexion n’est pas une erreur : l’application installée a son propre stockage, distinct de Safari.'**
  String get notificationsReconnexionErreurApplicationInstallee;

  /// No description provided for @onboardingBienvenueJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur Jelvo'**
  String get onboardingBienvenueJelvo;

  /// No description provided for @onboardingAppRassembleGroupesProjets.
  ///
  /// In fr, this message translates to:
  /// **'L’app qui rassemble vos groupes, vos projets et vos proches.'**
  String get onboardingAppRassembleGroupesProjets;

  /// No description provided for @onboardingGroupesMemeEndroit.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos groupes au même endroit'**
  String get onboardingGroupesMemeEndroit;

  /// No description provided for @onboardingOrganisezProjetsActivitesEchanges.
  ///
  /// In fr, this message translates to:
  /// **'Organisez vos projets, activités et échanges facilement.'**
  String get onboardingOrganisezProjetsActivitesEchanges;

  /// No description provided for @onboardingAgendaPartageSynchronise.
  ///
  /// In fr, this message translates to:
  /// **'Un agenda partagé et synchronisé'**
  String get onboardingAgendaPartageSynchronise;

  /// No description provided for @onboardingManquezAucunEvenementImportant.
  ///
  /// In fr, this message translates to:
  /// **'Ne manquez plus aucun événement important.'**
  String get onboardingManquezAucunEvenementImportant;

  /// No description provided for @onboardingTachesClairesEfficaces.
  ///
  /// In fr, this message translates to:
  /// **'Des tâches claires et efficaces'**
  String get onboardingTachesClairesEfficaces;

  /// No description provided for @onboardingAttribuezSuivezAccomplissezEnsemble.
  ///
  /// In fr, this message translates to:
  /// **'Attribuez, suivez et accomplissez ensemble vos objectifs.'**
  String get onboardingAttribuezSuivezAccomplissezEnsemble;

  /// No description provided for @profileProposJelvo.
  ///
  /// In fr, this message translates to:
  /// **'À propos de Jelvo'**
  String get profileProposJelvo;

  /// No description provided for @profileJelvoReunitGroupesEvenements.
  ///
  /// In fr, this message translates to:
  /// **'Jelvo réunit vos groupes, vos événements, vos tâches et vos disponibilités au même endroit — pour la famille, les amis, la colocation.'**
  String get profileJelvoReunitGroupesEvenements;

  /// No description provided for @profileBonSavoir.
  ///
  /// In fr, this message translates to:
  /// **'Bon à savoir'**
  String get profileBonSavoir;

  /// No description provided for @profileJelvoApplicationWebInstallable.
  ///
  /// In fr, this message translates to:
  /// **'Jelvo est une application web installable. Sur iPhone, les notifications ne fonctionnent qu’une fois l’icône ajoutée à l’écran d’accueil, et l’application installée a sa propre session : il faut s’y reconnecter.'**
  String get profileJelvoApplicationWebInstallable;

  /// No description provided for @profileChoisirAvatar.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un avatar'**
  String get profileChoisirAvatar;

  /// No description provided for @profileUtiliserCetAvatar.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser cet avatar'**
  String get profileUtiliserCetAvatar;

  /// No description provided for @profileAvatarId.
  ///
  /// In fr, this message translates to:
  /// **'Avatar {id}'**
  String profileAvatarId(Object id);

  /// No description provided for @profileChangerMotPasse.
  ///
  /// In fr, this message translates to:
  /// **'Changer de mot de passe'**
  String get profileChangerMotPasse;

  /// No description provided for @profileMotPasseChange.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe changé.'**
  String get profileMotPasseChange;

  /// No description provided for @profileModifierProfil.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get profileModifierProfil;

  /// No description provided for @profileProfilEnregistre.
  ///
  /// In fr, this message translates to:
  /// **'Profil enregistré.'**
  String get profileProfilEnregistre;

  /// No description provided for @profileProfil.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get profileProfil;

  /// No description provided for @profileProfilIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Profil indisponible'**
  String get profileProfilIndisponible;

  /// No description provided for @profileProfilIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Profil introuvable'**
  String get profileProfilIntrouvable;

  /// No description provided for @profileProfilEncoreEteCree.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil n’a pas encore été créé. Reconnectez-vous pour le finaliser.'**
  String get profileProfilEncoreEteCree;

  /// No description provided for @profileProfilJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil Jelvo'**
  String get profileProfilJelvo;

  /// No description provided for @profileAutresVoientQuMot.
  ///
  /// In fr, this message translates to:
  /// **'Les autres n’y voient qu’un mot : disponible, indisponible ou inconnu.'**
  String get profileAutresVoientQuMot;

  /// No description provided for @profileLectureAboutiReessayezInstant.
  ///
  /// In fr, this message translates to:
  /// **'La lecture n’a pas abouti. Réessayez dans un instant.'**
  String get profileLectureAboutiReessayezInstant;

  /// No description provided for @profilePersonneCompteJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne n’a plus de compte Jelvo.'**
  String get profilePersonneCompteJelvo;

  /// No description provided for @profileAnnulerDemande.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get profileAnnulerDemande;

  /// No description provided for @profileAjouterContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter en contact'**
  String get profileAjouterContact;

  /// No description provided for @profileRetirerContact.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce contact ?'**
  String get profileRetirerContact;

  /// No description provided for @profileActionAbouti.
  ///
  /// In fr, this message translates to:
  /// **'L’action n’a pas abouti.'**
  String get profileActionAbouti;

  /// No description provided for @profileInformationsPersonnelles.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get profileInformationsPersonnelles;

  /// No description provided for @profileDeconnecter.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get profileDeconnecter;

  /// No description provided for @profileDevrezSaisirNouveauIdentifiants.
  ///
  /// In fr, this message translates to:
  /// **'Vous devrez saisir à nouveau vos identifiants pour revenir.'**
  String get profileDevrezSaisirNouveauIdentifiants;

  /// No description provided for @profileJourMoisSeulementJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Le jour et le mois seulement. Jelvo ne demande pas votre année de naissance.'**
  String get profileJourMoisSeulementJelvo;

  /// No description provided for @profileContactsVoientPrevenusJour.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts le voient, et sont prévenus le jour même.'**
  String get profileContactsVoientPrevenusJour;

  /// No description provided for @profileAnneesNonBissextilesSera.
  ///
  /// In fr, this message translates to:
  /// **'Les années non bissextiles, il sera fêté le 28 février, dernier jour du mois.'**
  String get profileAnneesNonBissextilesSera;

  /// No description provided for @profileSuitReglageTelephone.
  ///
  /// In fr, this message translates to:
  /// **'Suit le réglage de votre téléphone'**
  String get profileSuitReglageTelephone;

  /// No description provided for @profileFondBlancTexteSombre.
  ///
  /// In fr, this message translates to:
  /// **'Fond blanc, texte sombre'**
  String get profileFondBlancTexteSombre;

  /// No description provided for @profileFondSombreTexteClair.
  ///
  /// In fr, this message translates to:
  /// **'Fond sombre, texte clair'**
  String get profileFondSombreTexteClair;

  /// No description provided for @profileChoixVautCetAppareil.
  ///
  /// In fr, this message translates to:
  /// **'Ce choix ne vaut que sur cet appareil.'**
  String get profileChoixVautCetAppareil;

  /// No description provided for @profilePhotoProfil.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get profilePhotoProfil;

  /// No description provided for @profileChoisirPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get profileChoisirPhoto;

  /// No description provided for @profileDepuisPhotosAppareil.
  ///
  /// In fr, this message translates to:
  /// **'Depuis les photos de votre appareil'**
  String get profileDepuisPhotosAppareil;

  /// No description provided for @profileChoisirAvatarJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un avatar Jelvo'**
  String get profileChoisirAvatarJelvo;

  /// No description provided for @profileQuatreVingtTreizeIllustrations.
  ///
  /// In fr, this message translates to:
  /// **'Quatre-vingt-treize illustrations au choix'**
  String get profileQuatreVingtTreizeIllustrations;

  /// No description provided for @profileInitialesPrendrontPlace.
  ///
  /// In fr, this message translates to:
  /// **'Vos initiales prendront la place'**
  String get profileInitialesPrendrontPlace;

  /// No description provided for @profileAjoutezJourMoisAnnee.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez le jour et le mois, sans l’année'**
  String get profileAjoutezJourMoisAnnee;

  /// No description provided for @profileAdresseIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Adresse indisponible'**
  String get profileAdresseIndisponible;

  /// No description provided for @profileQuelquesMots.
  ///
  /// In fr, this message translates to:
  /// **'Quelques mots sur vous'**
  String get profileQuelquesMots;

  /// No description provided for @profileAjoutezQuelquesMots.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez quelques mots sur vous'**
  String get profileAjoutezQuelquesMots;

  /// No description provided for @profileEnregistrerBio.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la bio'**
  String get profileEnregistrerBio;

  /// No description provided for @profileModifierBio.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la bio'**
  String get profileModifierBio;

  /// No description provided for @profileChangerPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Changer de photo'**
  String get profileChangerPhoto;

  /// No description provided for @profileChangerPhotoProfil.
  ///
  /// In fr, this message translates to:
  /// **'Changer de photo de profil'**
  String get profileChangerPhotoProfil;

  /// No description provided for @profileQRCode.
  ///
  /// In fr, this message translates to:
  /// **'QR Code'**
  String get profileQRCode;

  /// No description provided for @profilePartagerProfil.
  ///
  /// In fr, this message translates to:
  /// **'Partager profil'**
  String get profilePartagerProfil;

  /// No description provided for @profileStatistiques.
  ///
  /// In fr, this message translates to:
  /// **'Mes statistiques'**
  String get profileStatistiques;

  /// No description provided for @profileTachesTerminees.
  ///
  /// In fr, this message translates to:
  /// **'Tâches terminées'**
  String get profileTachesTerminees;

  /// No description provided for @profile1GroupeCommun.
  ///
  /// In fr, this message translates to:
  /// **'1 groupe en commun'**
  String get profile1GroupeCommun;

  /// No description provided for @profileOrganisezRienEnsembleInstant.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’organisez rien ensemble pour l’instant.'**
  String get profileOrganisezRienEnsembleInstant;

  /// No description provided for @tasksAvezPrisTache.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez pris cette tâche.'**
  String get tasksAvezPrisTache;

  /// No description provided for @tasksAvezRenduTacheGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez rendu cette tâche au groupe.'**
  String get tasksAvezRenduTacheGroupe;

  /// No description provided for @tasksQuelquVientPrendreAvant.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu’un vient de la prendre avant vous.'**
  String get tasksQuelquVientPrendreAvant;

  /// No description provided for @tasksTache.
  ///
  /// In fr, this message translates to:
  /// **'Cette tâche n’est pas la vôtre.'**
  String get tasksTache;

  /// No description provided for @tasksTacheEteConfieeRefusez.
  ///
  /// In fr, this message translates to:
  /// **'Cette tâche vous a été confiée : refusez-la plutôt que de la rendre.'**
  String get tasksTacheEteConfieeRefusez;

  /// No description provided for @tasksFaitesPartieGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne faites plus partie de ce groupe.'**
  String get tasksFaitesPartieGroupe;

  /// No description provided for @tasksTachePuEtreCreee.
  ///
  /// In fr, this message translates to:
  /// **'La tâche n’a pas pu être créée. Réessayez dans un instant.'**
  String get tasksTachePuEtreCreee;

  /// No description provided for @tasksTachePuEtreModifiee.
  ///
  /// In fr, this message translates to:
  /// **'La tâche n’a pas pu être modifiée. Réessayez dans un instant.'**
  String get tasksTachePuEtreModifiee;

  /// No description provided for @tasksTacheConfiee.
  ///
  /// In fr, this message translates to:
  /// **'Tâche confiée'**
  String get tasksTacheConfiee;

  /// No description provided for @tasksTacheIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Tâche introuvable'**
  String get tasksTacheIntrouvable;

  /// No description provided for @tasksEteSupprimeeAvezAcces.
  ///
  /// In fr, this message translates to:
  /// **'Elle a été supprimée, ou vous n’y avez plus accès. Il n’y a plus rien à accepter.'**
  String get tasksEteSupprimeeAvezAcces;

  /// No description provided for @tasksRevenirAccueil.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à l’accueil'**
  String get tasksRevenirAccueil;

  /// No description provided for @tasksTacheEteConfiee.
  ///
  /// In fr, this message translates to:
  /// **'Cette tâche vous a été confiée'**
  String get tasksTacheEteConfiee;

  /// No description provided for @tasksConfieTache.
  ///
  /// In fr, this message translates to:
  /// **'vous a confié une tâche'**
  String get tasksConfieTache;

  /// No description provided for @tasksAssignee.
  ///
  /// In fr, this message translates to:
  /// **'Assignée à'**
  String get tasksAssignee;

  /// No description provided for @tasksEcheanceDejaPassee.
  ///
  /// In fr, this message translates to:
  /// **'L’échéance est déjà passée.'**
  String get tasksEcheanceDejaPassee;

  /// No description provided for @tasksAvezAccepteTache.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez accepté cette tâche.'**
  String get tasksAvezAccepteTache;

  /// No description provided for @tasksAvezDeclineTache.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez décliné cette tâche.'**
  String get tasksAvezDeclineTache;

  /// No description provided for @tasksAvezTerminePart.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez terminé votre part.'**
  String get tasksAvezTerminePart;

  /// No description provided for @tasksTacheAssignee.
  ///
  /// In fr, this message translates to:
  /// **'Cette tâche ne vous est pas assignée.'**
  String get tasksTacheAssignee;

  /// No description provided for @tasksOuvrirTache.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la tâche'**
  String get tasksOuvrirTache;

  /// No description provided for @tasksTacheAcceptee.
  ///
  /// In fr, this message translates to:
  /// **'Tâche acceptée.'**
  String get tasksTacheAcceptee;

  /// No description provided for @tasksTacheDeclinee.
  ///
  /// In fr, this message translates to:
  /// **'Tâche déclinée.'**
  String get tasksTacheDeclinee;

  /// No description provided for @tasksModifierTache.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la tâche'**
  String get tasksModifierTache;

  /// No description provided for @tasksSupprimerTache.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la tâche'**
  String get tasksSupprimerTache;

  /// No description provided for @tasksEteSupprimeeAvezAcces2.
  ///
  /// In fr, this message translates to:
  /// **'Elle a été supprimée, ou vous n’y avez plus accès.'**
  String get tasksEteSupprimeeAvezAcces2;

  /// No description provided for @tasksPersonneInstantImporteQuel.
  ///
  /// In fr, this message translates to:
  /// **'Personne pour l’instant. N’importe quel membre du groupe peut s’en charger.'**
  String get tasksPersonneInstantImporteQuel;

  /// No description provided for @tasksRetirer.
  ///
  /// In fr, this message translates to:
  /// **'Me retirer'**
  String get tasksRetirer;

  /// No description provided for @tasksJeMCharge.
  ///
  /// In fr, this message translates to:
  /// **'Je m’en charge'**
  String get tasksJeMCharge;

  /// No description provided for @tasksChargezTache.
  ///
  /// In fr, this message translates to:
  /// **'Vous vous chargez de cette tâche.'**
  String get tasksChargezTache;

  /// No description provided for @tasksChargiezDeja.
  ///
  /// In fr, this message translates to:
  /// **'Vous vous en chargiez déjà.'**
  String get tasksChargiezDeja;

  /// No description provided for @tasksChargez.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne vous en chargez plus.'**
  String get tasksChargez;

  /// No description provided for @tasksEtiezAssigneTache.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’étiez pas assigné à cette tâche.'**
  String get tasksEtiezAssigneTache;

  /// No description provided for @tasksQuelquChargeDejaPassez.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu’un s’en charge déjà. Passez par « Modifier » pour changer les assignés.'**
  String get tasksQuelquChargeDejaPassez;

  /// No description provided for @tasksRienCocherAjoutezQu.
  ///
  /// In fr, this message translates to:
  /// **'Rien à cocher. Ajoutez ce qu’il faut prendre : chacun verra ce qui reste.'**
  String get tasksRienCocherAjoutezQu;

  /// No description provided for @tasksAjouterArticle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un article'**
  String get tasksAjouterArticle;

  /// No description provided for @tasksAjouterListe.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la liste'**
  String get tasksAjouterListe;

  /// No description provided for @tasksRetirerListe.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la liste'**
  String get tasksRetirerListe;

  /// No description provided for @tasksRouvrirTache.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir la tâche'**
  String get tasksRouvrirTache;

  /// No description provided for @tasksMarquerCommeTerminee.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme terminée'**
  String get tasksMarquerCommeTerminee;

  /// No description provided for @tasksTachesIndisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Tâches indisponibles'**
  String get tasksTachesIndisponibles;

  /// No description provided for @tasksAucuneTache.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tâche'**
  String get tasksAucuneTache;

  /// No description provided for @tasksFaitRienEncoreEte.
  ///
  /// In fr, this message translates to:
  /// **'Tout est fait — ou rien n’a encore été noté.'**
  String get tasksFaitRienEncoreEte;

  /// No description provided for @tasksGroupeAucuneTacheInstant.
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe n’a aucune tâche pour l’instant.'**
  String get tasksGroupeAucuneTacheInstant;

  /// No description provided for @tasksAssigner.
  ///
  /// In fr, this message translates to:
  /// **'Assigner à'**
  String get tasksAssigner;

  /// No description provided for @tasksMembresGroupeOntEncore.
  ///
  /// In fr, this message translates to:
  /// **'Les membres du groupe n’ont pas encore été chargés.'**
  String get tasksMembresGroupeOntEncore;

  /// No description provided for @tasksExAcheterPain.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Acheter le pain'**
  String get tasksExAcheterPain;

  /// No description provided for @tasksJelvoEnverraNotificationPersonne.
  ///
  /// In fr, this message translates to:
  /// **'Jelvo enverra une notification à la personne assignée'**
  String get tasksJelvoEnverraNotificationPersonne;

  /// No description provided for @tasksTachesRecurrentes.
  ///
  /// In fr, this message translates to:
  /// **'Pour les tâches récurrentes'**
  String get tasksTachesRecurrentes;

  /// No description provided for @tasksCreerTache.
  ///
  /// In fr, this message translates to:
  /// **'Créer la tâche'**
  String get tasksCreerTache;

  /// No description provided for @tasksProposeeGroupeCarteAffichera.
  ///
  /// In fr, this message translates to:
  /// **'Proposée à tout le groupe : une carte s’affichera dans la conversation, et le premier qui accepte la prend.'**
  String get tasksProposeeGroupeCarteAffichera;

  /// No description provided for @tasksConfieeListeRecevraNotification.
  ///
  /// In fr, this message translates to:
  /// **'Confiée à {liste}, qui recevra une notification.'**
  String tasksConfieeListeRecevraNotification(Object liste);

  /// No description provided for @tasksConfieeListeRecevrontNotification.
  ///
  /// In fr, this message translates to:
  /// **'Confiée à {liste}, qui recevront une notification.'**
  String tasksConfieeListeRecevrontNotification(Object liste);

  /// No description provided for @tasksEcheancePrioriteDescription.
  ///
  /// In fr, this message translates to:
  /// **'Échéance, priorité, description…'**
  String get tasksEcheancePrioriteDescription;

  /// No description provided for @tasksQuFautSavoirOccuper.
  ///
  /// In fr, this message translates to:
  /// **'Ce qu’il faut savoir pour s’en occuper'**
  String get tasksQuFautSavoirOccuper;

  /// No description provided for @tasksDonnezTitreTache.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un titre à la tâche.'**
  String get tasksDonnezTitreTache;

  /// No description provided for @tasksTacheEteModifiee.
  ///
  /// In fr, this message translates to:
  /// **'La tâche a été modifiée.'**
  String get tasksTacheEteModifiee;

  /// No description provided for @tasksTacheTitreEteCreee.
  ///
  /// In fr, this message translates to:
  /// **'La tâche « {titre} » a été créée.'**
  String tasksTacheTitreEteCreee(Object titre);

  /// No description provided for @routerPageIntrouvable.
  ///
  /// In fr, this message translates to:
  /// **'Page introuvable'**
  String get routerPageIntrouvable;

  /// No description provided for @routerAucunEcranCorrespondLocation.
  ///
  /// In fr, this message translates to:
  /// **'Aucun écran ne correspond à « {location} ».'**
  String routerAucunEcranCorrespondLocation(Object location);

  /// No description provided for @calendarRecurrenceJamais.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get calendarRecurrenceJamais;

  /// No description provided for @calendarRappelAucun.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get calendarRappelAucun;

  /// No description provided for @coreDemain.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get coreDemain;

  /// No description provided for @coreHier.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get coreHier;

  /// No description provided for @coreIlYaMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {minutes} min'**
  String coreIlYaMinutes(int minutes);

  /// No description provided for @coreIlYaHeures.
  ///
  /// In fr, this message translates to:
  /// **'il y a {heures} h'**
  String coreIlYaHeures(int heures);

  /// Ancienneté en jours — pluriel ICU, et non un « s » collé en Dart.
  ///
  /// In fr, this message translates to:
  /// **'{jours, plural, one{il y a {jours} jour} other{il y a {jours} jours}}'**
  String coreIlYaJours(int jours);

  /// No description provided for @coreLeDate.
  ///
  /// In fr, this message translates to:
  /// **'le {date}'**
  String coreLeDate(String date);

  /// No description provided for @createEvenement.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get createEvenement;

  /// No description provided for @createTache.
  ///
  /// In fr, this message translates to:
  /// **'Tâche'**
  String get createTache;

  /// No description provided for @createGroupe.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get createGroupe;

  /// No description provided for @profileApparence.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get profileApparence;

  /// No description provided for @profileApparenceAutomatique.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get profileApparenceAutomatique;

  /// No description provided for @profileApparenceClair.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get profileApparenceClair;

  /// No description provided for @profileApparenceSombre.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get profileApparenceSombre;

  /// No description provided for @groupsTachesEnCours.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} tâche en cours} other{{count} tâches en cours}}'**
  String groupsTachesEnCours(int count);

  /// No description provided for @groupsEvenementsAVenir.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} événement à venir} other{{count} événements à venir}}'**
  String groupsEvenementsAVenir(int count);

  /// No description provided for @groupsVousAdministrezCeGroupe.
  ///
  /// In fr, this message translates to:
  /// **'{membres} · vous administrez ce groupe'**
  String groupsVousAdministrezCeGroupe(String membres);

  /// No description provided for @authMoinsCaracteres.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {min} caractères'**
  String authMoinsCaracteres(int min);

  /// No description provided for @homeBonjour.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeBonjour;

  /// No description provided for @homeBonsoir.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get homeBonsoir;

  /// No description provided for @calendarPersonnel.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get calendarPersonnel;

  /// No description provided for @calendarJournee.
  ///
  /// In fr, this message translates to:
  /// **'Journée'**
  String get calendarJournee;

  /// No description provided for @calendarFeteSonAnniversaire.
  ///
  /// In fr, this message translates to:
  /// **'{nom} fête son anniversaire'**
  String calendarFeteSonAnniversaire(String nom);

  /// No description provided for @navNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navParametres.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navParametres;

  /// No description provided for @coreStatutInformation.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get coreStatutInformation;

  /// No description provided for @coreStatutConfirme.
  ///
  /// In fr, this message translates to:
  /// **'Confirmé'**
  String get coreStatutConfirme;

  /// No description provided for @coreStatutEnAttente.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get coreStatutEnAttente;

  /// No description provided for @coreStatutConflit.
  ///
  /// In fr, this message translates to:
  /// **'Conflit'**
  String get coreStatutConflit;

  /// No description provided for @coreStatutInactif.
  ///
  /// In fr, this message translates to:
  /// **'Inactif'**
  String get coreStatutInactif;

  /// No description provided for @notificationsActives.
  ///
  /// In fr, this message translates to:
  /// **'Actives'**
  String get notificationsActives;

  /// No description provided for @notificationsNotification.
  ///
  /// In fr, this message translates to:
  /// **'Notification'**
  String get notificationsNotification;

  /// No description provided for @chatUnePersonneEcrit.
  ///
  /// In fr, this message translates to:
  /// **'{nom} est en train d’écrire…'**
  String chatUnePersonneEcrit(String nom);

  /// No description provided for @chatDeuxPersonnesEcrivent.
  ///
  /// In fr, this message translates to:
  /// **'{premier} et {second} sont en train d’écrire…'**
  String chatDeuxPersonnesEcrivent(String premier, String second);

  /// No description provided for @chatAPrisLaTache.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a pris la tâche'**
  String chatAPrisLaTache(String nom);

  /// No description provided for @chatAAccepteLaTache.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a accepté la tâche'**
  String chatAAccepteLaTache(String nom);

  /// No description provided for @chatARefuseLaTache.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a refusé la tâche'**
  String chatARefuseLaTache(String nom);

  /// No description provided for @chatATermineLaTache.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a terminé la tâche'**
  String chatATermineLaTache(String nom);

  /// No description provided for @chatTacheAttribueeA.
  ///
  /// In fr, this message translates to:
  /// **'Tâche attribuée à {nom}'**
  String chatTacheAttribueeA(String nom);

  /// No description provided for @groupsInvitationDe.
  ///
  /// In fr, this message translates to:
  /// **'Invitation de {nom}'**
  String groupsInvitationDe(String nom);

  /// No description provided for @calendarRappel.
  ///
  /// In fr, this message translates to:
  /// **'Rappel'**
  String get calendarRappel;

  /// No description provided for @calendarRepeter.
  ///
  /// In fr, this message translates to:
  /// **'Répéter'**
  String get calendarRepeter;

  /// No description provided for @groupsMembreCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} membre} other{{count} membres}}'**
  String groupsMembreCount(int count);

  /// No description provided for @groupsEvenementCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} événement} other{{count} événements}}'**
  String groupsEvenementCount(int count);

  /// No description provided for @groupsTacheOuverteCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} tâche ouverte} other{{count} tâches ouvertes}}'**
  String groupsTacheOuverteCount(int count);

  /// No description provided for @coreJourEtHeure.
  ///
  /// In fr, this message translates to:
  /// **'{jour} · {heures}'**
  String coreJourEtHeure(String jour, String heures);

  /// No description provided for @groupsRetraitMembreConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'{nom} n’aura plus accès au groupe. Vous pourrez l’inviter à nouveau plus tard.'**
  String groupsRetraitMembreConfirmation(String nom);

  /// No description provided for @groupsQuitterConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne verrez plus « {groupe} ». Si vous en êtes le dernier administrateur, le plus ancien membre prendra le relais.'**
  String groupsQuitterConfirmation(String groupe);

  /// No description provided for @groupsSupprimerConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'« {groupe} » disparaîtra pour tous ses membres. Cette action ne peut pas être annulée depuis l’application.'**
  String groupsSupprimerConfirmation(String groupe);

  /// No description provided for @groupsInvitationRecueJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a reçu votre invitation, jusqu’au {date}.'**
  String groupsInvitationRecueJusquAu(String nom, String date);

  /// No description provided for @coreRetirer.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get coreRetirer;

  /// No description provided for @coreQuitter.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get coreQuitter;

  /// No description provided for @coreSupprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get coreSupprimer;

  /// No description provided for @tasksTacheSupprimee.
  ///
  /// In fr, this message translates to:
  /// **'« {titre} » a été supprimée.'**
  String tasksTacheSupprimee(String titre);

  /// No description provided for @tasksSupprimerConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'« {titre} » disparaîtra pour tout le monde. Cette action ne peut pas être annulée depuis l’application.'**
  String tasksSupprimerConfirmation(String titre);

  /// No description provided for @coreVous.
  ///
  /// In fr, this message translates to:
  /// **'{nom} (vous)'**
  String coreVous(String nom);

  /// No description provided for @coreSurTotal.
  ///
  /// In fr, this message translates to:
  /// **'{fait} sur {total}'**
  String coreSurTotal(int fait, int total);

  /// No description provided for @tasksCochePar.
  ///
  /// In fr, this message translates to:
  /// **'Coché par {nom}'**
  String tasksCochePar(String nom);

  /// No description provided for @tasksListe.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get tasksListe;

  /// No description provided for @tasksEcheance.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get tasksEcheance;

  /// No description provided for @tasksAucune.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get tasksAucune;

  /// No description provided for @calendarEvenementSupprime.
  ///
  /// In fr, this message translates to:
  /// **'« {titre} » a été supprimé.'**
  String calendarEvenementSupprime(String titre);

  /// No description provided for @calendarSupprimerConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'« {titre} » disparaîtra pour tous les participants. Cette action ne peut pas être annulée depuis l’application.'**
  String calendarSupprimerConfirmation(String titre);

  /// No description provided for @calendarParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get calendarParticipants;

  /// No description provided for @calendarOuiCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} oui'**
  String calendarOuiCount(int count);

  /// No description provided for @calendarVousAvezRepondu.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez répondu : {reponse}. Vous pouvez encore changer d’avis.'**
  String calendarVousAvezRepondu(String reponse);

  /// No description provided for @calendarReponseEnregistree.
  ///
  /// In fr, this message translates to:
  /// **'Réponse enregistrée : {reponse}.'**
  String calendarReponseEnregistree(String reponse);

  /// No description provided for @groupsPartagezCeLien.
  ///
  /// In fr, this message translates to:
  /// **'Partagez ce lien par SMS, messagerie ou e-mail. La personne pourra créer son compte puis rejoindre « {groupe} ».'**
  String groupsPartagezCeLien(String groupe);

  /// No description provided for @groupsRejoinsSurJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins « {groupe} » sur Jelvo : {url}'**
  String groupsRejoinsSurJelvo(String groupe, String url);

  /// No description provided for @groupsInvitationARejoindre.
  ///
  /// In fr, this message translates to:
  /// **'Invitation à rejoindre {groupe}'**
  String groupsInvitationARejoindre(String groupe);

  /// No description provided for @groupsUtilisationsExpireLe.
  ///
  /// In fr, this message translates to:
  /// **'{utilisations} · expire le {date}'**
  String groupsUtilisationsExpireLe(String utilisations, String date);

  /// No description provided for @groupsAdhesionJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'Adhésion jusqu’au {date}'**
  String groupsAdhesionJusquAu(String date);

  /// No description provided for @groupsUtilisationCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} utilisation} other{{count} utilisations}}'**
  String groupsUtilisationCount(int count);

  /// No description provided for @groupsUtilisationSurMax.
  ///
  /// In fr, this message translates to:
  /// **'{utilisations} sur {max}'**
  String groupsUtilisationSurMax(String utilisations, int max);

  /// No description provided for @contactsGroupeCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} groupe} other{{count} groupes}}'**
  String contactsGroupeCount(int count);

  /// No description provided for @contactsPersonnesSouhaitentVousAjouter.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} personne souhaite vous ajouter} other{{count} personnes souhaitent vous ajouter}}'**
  String contactsPersonnesSouhaitentVousAjouter(int count);

  /// No description provided for @contactsFaitMaintenantPartie.
  ///
  /// In fr, this message translates to:
  /// **'{nom} fait maintenant partie de vos contacts.'**
  String contactsFaitMaintenantPartie(String nom);

  /// No description provided for @contactsAjoutezMoiSurJelvo.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez-moi sur Jelvo : {pseudo}'**
  String contactsAjoutezMoiSurJelvo(String pseudo);

  /// No description provided for @contactsNomEtMessage.
  ///
  /// In fr, this message translates to:
  /// **'{nom} — {message}'**
  String contactsNomEtMessage(String nom, String message);

  /// No description provided for @contactsRejoignezMoi.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez-moi sur Jelvo pour organiser nos sorties : {url}'**
  String contactsRejoignezMoi(String url);

  /// No description provided for @contactsMonPseudoLigne.
  ///
  /// In fr, this message translates to:
  /// **'\nMon pseudo : {pseudo}'**
  String contactsMonPseudoLigne(String pseudo);

  /// No description provided for @contactsRetraitConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'{nom} ne fera plus partie de vos contacts, et vous ne ferez plus partie des siens.'**
  String contactsRetraitConfirmation(String nom);

  /// No description provided for @contactsAEteRetire.
  ///
  /// In fr, this message translates to:
  /// **'{nom} a été retiré.'**
  String contactsAEteRetire(String nom);

  /// No description provided for @coreParticipantCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} participant} other{{count} participants}}'**
  String coreParticipantCount(int count);

  /// No description provided for @coreMessageNonLuCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} message non lu} other{{count} messages non lus}}'**
  String coreMessageNonLuCount(int count);

  /// No description provided for @authCodeEnvoyeA.
  ///
  /// In fr, this message translates to:
  /// **'Nous avons envoyé un code à six chiffres à {email}.'**
  String authCodeEnvoyeA(String email);

  /// No description provided for @authFormatPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Minuscules, chiffres et points, de {min} à {max} caractères.'**
  String authFormatPseudo(int min, int max);

  /// No description provided for @availabilityDateEtPlage.
  ///
  /// In fr, this message translates to:
  /// **'{date} · {plage}'**
  String availabilityDateEtPlage(String date, String plage);

  /// No description provided for @availabilityDe.
  ///
  /// In fr, this message translates to:
  /// **'De {heure}'**
  String availabilityDe(String heure);

  /// No description provided for @availabilityA.
  ///
  /// In fr, this message translates to:
  /// **'À {heure}'**
  String availabilityA(String heure);

  /// No description provided for @calendarPuceEtDate.
  ///
  /// In fr, this message translates to:
  /// **' • {date}'**
  String calendarPuceEtDate(String date);

  /// No description provided for @calendarRienNeCorrespond.
  ///
  /// In fr, this message translates to:
  /// **'Rien ne correspond à « {terme} ».'**
  String calendarRienNeCorrespond(String terme);

  /// No description provided for @coreSurTotalTexte.
  ///
  /// In fr, this message translates to:
  /// **'{fait} sur {total}'**
  String coreSurTotalTexte(int fait, int total);

  /// No description provided for @calendarHeuresMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{heures} h {minutes}'**
  String calendarHeuresMinutes(int heures, String minutes);

  /// No description provided for @calendarHeures.
  ///
  /// In fr, this message translates to:
  /// **'{heures} h'**
  String calendarHeures(int heures);

  /// No description provided for @chatMegaoctets.
  ///
  /// In fr, this message translates to:
  /// **'{taille} Mo'**
  String chatMegaoctets(String taille);

  /// No description provided for @chatKilooctets.
  ///
  /// In fr, this message translates to:
  /// **'{taille} ko'**
  String chatKilooctets(int taille);

  /// No description provided for @chatJusquAEnvironUneMinute.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’à {taille}, environ une minute'**
  String chatJusquAEnvironUneMinute(String taille);

  /// No description provided for @chatVideoTropLourde.
  ///
  /// In fr, this message translates to:
  /// **'Cette vidéo pèse {taille}, au-delà des {max} acceptés. Filmez plus court, ou envoyez-la autrement.'**
  String chatVideoTropLourde(String taille, String max);

  /// No description provided for @chatEcheanceDateHeure.
  ///
  /// In fr, this message translates to:
  /// **'Échéance {date} à {heure}'**
  String chatEcheanceDateHeure(String date, String heure);

  /// No description provided for @groupsInvitationEnAttenteCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} invitation en attente} other{{count} invitations en attente}}'**
  String groupsInvitationEnAttenteCount(int count);

  /// No description provided for @groupsAdhesionTemporaireJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'Adhésion temporaire : jusqu’au {date}.'**
  String groupsAdhesionTemporaireJusquAu(String date);

  /// No description provided for @groupsAdhesionTemporaireVousFerezPartie.
  ///
  /// In fr, this message translates to:
  /// **'Adhésion temporaire : vous ferez partie du groupe jusqu’au {date}.'**
  String groupsAdhesionTemporaireVousFerezPartie(String date);

  /// No description provided for @groupsCreezIciPartageAvec.
  ///
  /// In fr, this message translates to:
  /// **'Ce que vous créez ici sera partagé avec « {groupe} ».'**
  String groupsCreezIciPartageAvec(String groupe);

  /// No description provided for @groupsJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu’au {date}'**
  String groupsJusquAu(String date);

  /// No description provided for @groupsAdhesionJusquAuPuisDisparait.
  ///
  /// In fr, this message translates to:
  /// **'Adhésion jusqu’au {date}, puis le groupe disparaîtra de son application.'**
  String groupsAdhesionJusquAuPuisDisparait(String date);

  /// No description provided for @groupsMembreJusquAu.
  ///
  /// In fr, this message translates to:
  /// **'{nom} fait partie du groupe jusqu’au {date}.'**
  String groupsMembreJusquAu(String nom, String date);

  /// No description provided for @groupsMembreSansTerme.
  ///
  /// In fr, this message translates to:
  /// **'{nom} fait partie du groupe sans terme.'**
  String groupsMembreSansTerme(String nom);

  /// No description provided for @homeTacheCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} tâche} other{{count} tâches}}'**
  String homeTacheCount(int count);

  /// No description provided for @homeVirguleEvenementCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{, {count} événement} other{, {count} événements}}'**
  String homeVirguleEvenementCount(int count);

  /// No description provided for @homeVirguleTacheCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{, {count} tâche} other{, {count} tâches}}'**
  String homeVirguleTacheCount(int count);

  /// No description provided for @notificationsVousConvie.
  ///
  /// In fr, this message translates to:
  /// **'{nom} vous convie.'**
  String notificationsVousConvie(String nom);

  /// No description provided for @notificationsVousConvieAvecGroupe.
  ///
  /// In fr, this message translates to:
  /// **'{nom} vous convie avec « {groupe} ».'**
  String notificationsVousConvieAvecGroupe(String nom, String groupe);

  /// No description provided for @profileVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String profileVersion(String version);

  /// No description provided for @profileRetrouvezMoi.
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez-moi sur Jelvo : {pseudo}\n{code}'**
  String profileRetrouvezMoi(String pseudo, String code);

  /// No description provided for @profileVotrePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Votre pseudo : {pseudo}'**
  String profileVotrePseudo(String pseudo);

  /// No description provided for @profileRetraitCarnetConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'{nom} ne figurera plus dans votre carnet. Vos groupes communs ne changent pas.'**
  String profileRetraitCarnetConfirmation(String nom);

  /// No description provided for @profileGroupesCommunsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} groupe en commun} other{{count} groupes en commun}}'**
  String profileGroupesCommunsCount(int count);

  /// No description provided for @tasksEcheanceDate.
  ///
  /// In fr, this message translates to:
  /// **'Échéance {date}'**
  String tasksEcheanceDate(String date);

  /// No description provided for @coreDateAHeure.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {heure}'**
  String coreDateAHeure(String date, String heure);

  /// No description provided for @tasksTerminees.
  ///
  /// In fr, this message translates to:
  /// **'Terminées'**
  String get tasksTerminees;

  /// No description provided for @tasksConfieeAuxPersonnes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Confiée à {count} personne, qui recevra une notification.} other{Confiée à {count} personnes, qui recevront une notification.}}'**
  String tasksConfieeAuxPersonnes(int count);

  /// No description provided for @coreDeuxNoms.
  ///
  /// In fr, this message translates to:
  /// **'{premier} et {second}'**
  String coreDeuxNoms(String premier, String second);

  /// No description provided for @coreDeuxNomsEtAutres.
  ///
  /// In fr, this message translates to:
  /// **'{premier}, {second} et {reste, plural, one{{reste} autre} other{{reste} autres}}'**
  String coreDeuxNomsEtAutres(String premier, String second, int reste);

  /// No description provided for @tasksArticlesCoches.
  ///
  /// In fr, this message translates to:
  /// **'{faits} sur {total} articles'**
  String tasksArticlesCoches(int faits, int total);

  /// No description provided for @tasksPrioriteLabel.
  ///
  /// In fr, this message translates to:
  /// **'{priorite} priorité'**
  String tasksPrioriteLabel(String priorite);

  /// No description provided for @navBadgeNonLus.
  ///
  /// In fr, this message translates to:
  /// **'{destination}, {count, plural, one{{count} non lu} other{{count} non lus}}'**
  String navBadgeNonLus(String destination, int count);

  /// No description provided for @profileLangue.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get profileLangue;

  /// No description provided for @profileLangueDuTelephone.
  ///
  /// In fr, this message translates to:
  /// **'Celle du téléphone'**
  String get profileLangueDuTelephone;

  /// No description provided for @profileLangueDuTelephoneAide.
  ///
  /// In fr, this message translates to:
  /// **'Suit le réglage de l’appareil, et l’anglais si la langue n’est pas proposée'**
  String get profileLangueDuTelephoneAide;

  /// No description provided for @profileLangueFrancais.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get profileLangueFrancais;

  /// No description provided for @profileLangueAllemand.
  ///
  /// In fr, this message translates to:
  /// **'Allemand'**
  String get profileLangueAllemand;

  /// No description provided for @profileLangueAnglais.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get profileLangueAnglais;

  /// No description provided for @profileLangueEspagnol.
  ///
  /// In fr, this message translates to:
  /// **'Espagnol'**
  String get profileLangueEspagnol;

  /// No description provided for @homeBonWeekEnd.
  ///
  /// In fr, this message translates to:
  /// **'Bon week-end'**
  String get homeBonWeekEnd;

  /// Heure à laquelle « Bon après-midi » commence à se dire dans cette langue. L'espagnol dit « buenas tardes » après le déjeuner, vers 14 h, pas à midi.
  ///
  /// In fr, this message translates to:
  /// **'12'**
  String get coreDebutApresMidi;

  /// Heure à laquelle « Bonsoir » commence à se dire dans cette langue.
  ///
  /// In fr, this message translates to:
  /// **'18'**
  String get coreDebutSoiree;

  /// No description provided for @coreDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get coreDescription;

  /// No description provided for @coreRechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get coreRechercher;

  /// No description provided for @coreProfil.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get coreProfil;

  /// No description provided for @coreLieu.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get coreLieu;

  /// No description provided for @coreAnniversaire.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire'**
  String get coreAnniversaire;

  /// No description provided for @coreAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get coreAutre;

  /// No description provided for @corePrenom.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get corePrenom;

  /// No description provided for @coreNom.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get coreNom;

  /// No description provided for @corePseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get corePseudo;

  /// No description provided for @coreHintPseudo.
  ///
  /// In fr, this message translates to:
  /// **'pseudo'**
  String get coreHintPseudo;

  /// No description provided for @coreFiltres.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get coreFiltres;

  /// No description provided for @coreRepetition.
  ///
  /// In fr, this message translates to:
  /// **'Répétition'**
  String get coreRepetition;

  /// No description provided for @coreInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Invitation'**
  String get coreInvitation;

  /// No description provided for @coreInvitations.
  ///
  /// In fr, this message translates to:
  /// **'Invitations'**
  String get coreInvitations;

  /// No description provided for @coreChoisir.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get coreChoisir;

  /// No description provided for @corePriorite.
  ///
  /// In fr, this message translates to:
  /// **'Priorité'**
  String get corePriorite;

  /// No description provided for @coreDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get coreDate;

  /// No description provided for @coreHoraires.
  ///
  /// In fr, this message translates to:
  /// **'Horaires'**
  String get coreHoraires;

  /// No description provided for @coreDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get coreDisponible;

  /// No description provided for @coreTout.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get coreTout;

  /// No description provided for @coreAfficher.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get coreAfficher;

  /// No description provided for @coreFin.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get coreFin;

  /// No description provided for @coreVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get coreVideo;

  /// No description provided for @coreJoindre.
  ///
  /// In fr, this message translates to:
  /// **'Joindre'**
  String get coreJoindre;

  /// No description provided for @coreFilmer.
  ///
  /// In fr, this message translates to:
  /// **'Filmer'**
  String get coreFilmer;

  /// No description provided for @coreScanner.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get coreScanner;

  /// No description provided for @coreResultats.
  ///
  /// In fr, this message translates to:
  /// **'Résultats'**
  String get coreResultats;

  /// No description provided for @coreEffacer.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get coreEffacer;

  /// No description provided for @coreFavoris.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get coreFavoris;

  /// No description provided for @coreGerer.
  ///
  /// In fr, this message translates to:
  /// **'Gérer'**
  String get coreGerer;

  /// No description provided for @coreActions.
  ///
  /// In fr, this message translates to:
  /// **'Actions'**
  String get coreActions;

  /// No description provided for @coreDiscussion.
  ///
  /// In fr, this message translates to:
  /// **'Discussion'**
  String get coreDiscussion;

  /// No description provided for @coreInviter.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get coreInviter;

  /// No description provided for @coreSuggestions.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions'**
  String get coreSuggestions;

  /// No description provided for @corePartager.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get corePartager;

  /// No description provided for @coreAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get coreAdmin;

  /// No description provided for @coreCommencer.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get coreCommencer;

  /// No description provided for @coreCompte.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get coreCompte;

  /// No description provided for @coreDeconnexion.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get coreDeconnexion;

  /// No description provided for @coreJour.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get coreJour;

  /// No description provided for @coreMois.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get coreMois;

  /// No description provided for @coreEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get coreEmail;

  /// No description provided for @coreBio.
  ///
  /// In fr, this message translates to:
  /// **'Bio'**
  String get coreBio;

  /// No description provided for @coreModifier.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get coreModifier;

  /// No description provided for @coreContinuer.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get coreContinuer;

  /// No description provided for @coreVerifier.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get coreVerifier;

  /// No description provided for @coreExceptions.
  ///
  /// In fr, this message translates to:
  /// **'Exceptions'**
  String get coreExceptions;

  /// No description provided for @coreEvenements.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get coreEvenements;

  /// No description provided for @coreTaches.
  ///
  /// In fr, this message translates to:
  /// **'Tâches'**
  String get coreTaches;

  /// No description provided for @coreExemplePrenom.
  ///
  /// In fr, this message translates to:
  /// **'Camille'**
  String get coreExemplePrenom;

  /// No description provided for @coreExempleNom.
  ///
  /// In fr, this message translates to:
  /// **'Rousseau'**
  String get coreExempleNom;

  /// No description provided for @corePlusDOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’options'**
  String get corePlusDOptions;

  /// No description provided for @profileSupprimerCompte.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get profileSupprimerCompte;

  /// No description provided for @profileSuppressionDefinitive.
  ///
  /// In fr, this message translates to:
  /// **'Cette suppression est définitive : elle ne peut pas être annulée.'**
  String get profileSuppressionDefinitive;

  /// No description provided for @profileSuppressionCeQuiDisparait.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui disparaît'**
  String get profileSuppressionCeQuiDisparait;

  /// No description provided for @profileSuppressionIdentite.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom, votre pseudo, votre adresse e-mail et votre photo'**
  String get profileSuppressionIdentite;

  /// No description provided for @profileSuppressionProfil.
  ///
  /// In fr, this message translates to:
  /// **'Votre bio, votre anniversaire et vos disponibilités'**
  String get profileSuppressionProfil;

  /// No description provided for @profileSuppressionContacts.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts, et vos demandes en attente'**
  String get profileSuppressionContacts;

  /// No description provided for @profileSuppressionGroupes.
  ///
  /// In fr, this message translates to:
  /// **'Vos adhésions aux groupes. Si vous êtes la seule personne à administrer un groupe, le plus ancien membre prend votre place.'**
  String get profileSuppressionGroupes;

  /// No description provided for @profileSuppressionNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Vos notifications et vos abonnements'**
  String get profileSuppressionNotifications;

  /// No description provided for @profileSuppressionVocaux.
  ///
  /// In fr, this message translates to:
  /// **'Vos messages vocaux, qui portent votre voix'**
  String get profileSuppressionVocaux;

  /// No description provided for @profileSuppressionCeQuiReste.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui reste'**
  String get profileSuppressionCeQuiReste;

  /// No description provided for @profileSuppressionMessages.
  ///
  /// In fr, this message translates to:
  /// **'Vos messages écrits, signés « Compte supprimé », pour ne pas trouer les échanges des autres'**
  String get profileSuppressionMessages;

  /// No description provided for @profileSuppressionMedias.
  ///
  /// In fr, this message translates to:
  /// **'Les photos et les vidéos que vous avez partagées'**
  String get profileSuppressionMedias;

  /// No description provided for @profileSuppressionGroupeContenu.
  ///
  /// In fr, this message translates to:
  /// **'Les tâches et les événements que vous avez créés dans un groupe'**
  String get profileSuppressionGroupeContenu;

  /// No description provided for @profileSuppressionReinscription.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez vous réinscrire plus tard avec la même adresse.'**
  String get profileSuppressionReinscription;

  /// No description provided for @profileSuppressionMotDePasse.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get profileSuppressionMotDePasse;

  /// No description provided for @profileSuppressionMotDePasseAide.
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer que c’est bien vous'**
  String get profileSuppressionMotDePasseAide;

  /// No description provided for @profileSuppressionConfirmer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get profileSuppressionConfirmer;

  /// No description provided for @profileSuppressionMotDePasseIncorrect.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get profileSuppressionMotDePasseIncorrect;

  /// No description provided for @profileSuppressionEchec.
  ///
  /// In fr, this message translates to:
  /// **'La suppression n’a pas abouti. Votre compte est intact : réessayez dans un instant.'**
  String get profileSuppressionEchec;

  /// No description provided for @profileSuppressionFaite.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été supprimé.'**
  String get profileSuppressionFaite;

  /// No description provided for @coreCompteSupprime.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé'**
  String get coreCompteSupprime;

  /// No description provided for @coreMembre.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get coreMembre;

  /// No description provided for @coreEpingle.
  ///
  /// In fr, this message translates to:
  /// **'Épinglé'**
  String get coreEpingle;

  /// No description provided for @coreEpingler.
  ///
  /// In fr, this message translates to:
  /// **'Épingler'**
  String get coreEpingler;

  /// No description provided for @coreRouvrir.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir'**
  String get coreRouvrir;

  /// No description provided for @chatEcouter.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get chatEcouter;

  /// No description provided for @tasksAssignes.
  ///
  /// In fr, this message translates to:
  /// **'Assignés'**
  String get tasksAssignes;

  /// No description provided for @tasksPersonnelle.
  ///
  /// In fr, this message translates to:
  /// **'Personnelle'**
  String get tasksPersonnelle;

  /// No description provided for @chatCompteurTaches.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{tâche} other{tâches}}'**
  String chatCompteurTaches(int count);

  /// No description provided for @chatCompteurEvenements.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{événement} other{événements}}'**
  String chatCompteurEvenements(int count);

  /// No description provided for @contactsCompteurGroupes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{groupe} other{groupes}}'**
  String contactsCompteurGroupes(int count);

  /// No description provided for @tasksLibre.
  ///
  /// In fr, this message translates to:
  /// **'Libre'**
  String get tasksLibre;

  /// No description provided for @coreIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get coreIndisponible;

  /// No description provided for @coreInconnu.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get coreInconnu;

  /// No description provided for @coreAutres.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get coreAutres;

  /// No description provided for @coreContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get coreContact;

  /// No description provided for @coreDateChoisir.
  ///
  /// In fr, this message translates to:
  /// **'Date…'**
  String get coreDateChoisir;

  /// No description provided for @chatEmojis.
  ///
  /// In fr, this message translates to:
  /// **'Emojis'**
  String get chatEmojis;

  /// No description provided for @chatEnvoyer.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get chatEnvoyer;

  /// No description provided for @authRetirerAvatar.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l’avatar'**
  String get authRetirerAvatar;

  /// No description provided for @groupsRejoindre.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get groupsRejoindre;

  /// No description provided for @notificationsActivees.
  ///
  /// In fr, this message translates to:
  /// **'Activées'**
  String get notificationsActivees;

  /// No description provided for @notificationsPartielles.
  ///
  /// In fr, this message translates to:
  /// **'Partielles'**
  String get notificationsPartielles;

  /// No description provided for @notificationsDesactivees.
  ///
  /// In fr, this message translates to:
  /// **'Désactivées'**
  String get notificationsDesactivees;

  /// No description provided for @notificationsRefusees.
  ///
  /// In fr, this message translates to:
  /// **'Refusées'**
  String get notificationsRefusees;

  /// No description provided for @notificationsIndisponibles.
  ///
  /// In fr, this message translates to:
  /// **'Indisponibles'**
  String get notificationsIndisponibles;

  /// No description provided for @notificationsVoirInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Voir l’invitation'**
  String get notificationsVoirInvitation;
}

class _AppTextsDelegate extends LocalizationsDelegate<AppTexts> {
  const _AppTextsDelegate();

  @override
  Future<AppTexts> load(Locale locale) {
    return SynchronousFuture<AppTexts>(lookupAppTexts(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppTextsDelegate old) => false;
}

AppTexts lookupAppTexts(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppTextsDe();
    case 'en':
      return AppTextsEn();
    case 'es':
      return AppTextsEs();
    case 'fr':
      return AppTextsFr();
  }

  throw FlutterError(
    'AppTexts.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
