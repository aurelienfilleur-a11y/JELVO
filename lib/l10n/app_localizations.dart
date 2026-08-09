import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

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
}

class _AppTextsDelegate extends LocalizationsDelegate<AppTexts> {
  const _AppTextsDelegate();

  @override
  Future<AppTexts> load(Locale locale) {
    return SynchronousFuture<AppTexts>(lookupAppTexts(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppTextsDelegate old) => false;
}

AppTexts lookupAppTexts(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
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
