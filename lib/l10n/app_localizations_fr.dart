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
}
