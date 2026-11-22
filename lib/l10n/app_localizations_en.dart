// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppTextsEn extends AppTexts {
  AppTextsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jelvo';

  @override
  String get navHome => 'Home';

  @override
  String get navGroups => 'Groups';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navContacts => 'Contacts';

  @override
  String get createNewGroup => 'New group';

  @override
  String get createNewEvent => 'New event';

  @override
  String get createAddContact => 'Add a contact';

  @override
  String get createTitle => 'Create';

  @override
  String get createQuestion => 'What would you like to create?';

  @override
  String get createIntro =>
      'Pick a type, then fill in the essentials. You can add the details later.';

  @override
  String get createDetails => 'Details';

  @override
  String get createGroupField => 'Group';

  @override
  String get createPersonalOption => 'Personal — visible to you only';

  @override
  String get createPickDate => 'Choose the date';

  @override
  String get createDueDate => 'Due date';

  @override
  String get createTime => 'Time';

  @override
  String get createMissingDate => 'Choose the date of the event.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRequiredField => 'This field is required.';

  @override
  String get commonOptional => 'Optional';

  @override
  String get homeSubtitle => 'Here is your day at a glance.';

  @override
  String get homeToday => 'Today';

  @override
  String get homeNoEventTitle => 'Free day';

  @override
  String get homeNoEventMessage => 'Nothing is planned for today yet.';

  @override
  String get homeSoon => 'Coming up';

  @override
  String get homeNothingUrgent => 'Nothing urgent';

  @override
  String get homeAllUpToDateTitle => 'All caught up';

  @override
  String get homeAllUpToDateMessage => 'No task is due in the next 48 hours.';

  @override
  String get homeMyGroups => 'My groups';

  @override
  String get homeMostActive => 'Most active right now';

  @override
  String get homeSeeAll => 'See all';

  @override
  String homeEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String homeTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks due soon',
      one: '1 task due soon',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String get groupUpcoming => 'Upcoming';

  @override
  String get groupNothingPlanned => 'Nothing planned';

  @override
  String get groupNoEventTitle => 'No events';

  @override
  String get groupNoEventMessage =>
      'Suggest a date to the group: everyone replies yes, maybe or no.';

  @override
  String get groupProposeDate => 'Suggest a date';

  @override
  String get groupTasksToDo => 'Tasks to do';

  @override
  String get groupNoTaskTitle => 'No open tasks';

  @override
  String get groupNoTaskMessage =>
      'Share out what needs doing: everyone sees their part.';

  @override
  String get groupAddTask => 'Add a task';

  @override
  String get groupAdd => 'Add';

  @override
  String get groupAddToGroup => 'Add to the group';

  @override
  String groupCreationSheetIntro(String name) {
    return 'What you create here will be shared with “$name”.';
  }

  @override
  String get groupMembers => 'Members';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get taskStatusTodo => 'To do';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusOverdue => 'Overdue';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskPriorityMedium => 'Normal';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String get taskAssigneePending => 'Pending';

  @override
  String get taskAssigneeAccepted => 'Accepted';

  @override
  String get taskAssigneeDeclined => 'Declined';

  @override
  String get taskAccept => 'Accept';

  @override
  String get taskDecline => 'Decline';

  @override
  String taskListProgress(int checked, int total) {
    return '$checked of $total items';
  }

  @override
  String get eventAnswerYes => 'Yes';

  @override
  String get eventAnswerMaybe => 'Maybe';

  @override
  String get eventAnswerNo => 'No';

  @override
  String get eventAnswerPending => 'Pending';

  @override
  String get errorGeneric => 'Something went wrong. Try again in a moment.';

  @override
  String get errorNetwork =>
      'No connection. Check your internet access, then try again.';

  @override
  String get errorForbidden =>
      'You do not have the permissions needed for this action.';

  @override
  String get errorNotSaved =>
      'The data could not be saved. Try again in a moment.';

  @override
  String get coreAujourdHui => 'Today';

  @override
  String get coreInstant => 'just now';

  @override
  String coreDateLabelTimeLabel(Object dateLabel, Object timeLabel) {
    return '$dateLabel · $timeLabel';
  }

  @override
  String get coreVoirMembres => 'See all members';

  @override
  String get corePersonneNom => 'Nobody by that name.';

  @override
  String get coreMarquerTacheCommeTerminee => 'Mark the task as done';

  @override
  String authMessageDiagnosticRaw(Object _message, Object raw) {
    return '$_message\n\n[diagnostic] $raw';
  }

  @override
  String get authEnvoiPhotoEchoueReessayez =>
      'Uploading the photo failed. Try again in a moment.';

  @override
  String get authIdentifiantsIncorrectsVerifiezSaisie =>
      'Incorrect credentials. Check what you typed, then try again.';

  @override
  String get authAdresseEMailEncore =>
      'Your email address is not verified yet.';

  @override
  String get authAdresseEMailDeja =>
      'This email address is already in use. Sign in or choose another address.';

  @override
  String get authCodeExpireDemandezNouveau =>
      'This code has expired. Request a new one.';

  @override
  String get authCodeIncorrectVerifiezSix =>
      'Incorrect code. Check the six digits sent to you by email.';

  @override
  String get authTropTentativesPatientezMinute =>
      'Too many attempts. Wait a minute before trying again.';

  @override
  String get authMotPasseTropFaible =>
      'This password is too weak. Choose a stronger one.';

  @override
  String get authNouveauMotPasseDoit =>
      'The new password must differ from the old one.';

  @override
  String get authAucunCompteCorrespondInformations =>
      'No account matches these details.';

  @override
  String get authSessionExpireReconnectez =>
      'Your session has expired. Sign in again.';

  @override
  String get authConnexionEchoueReessayezInstant =>
      'Signing in failed. Try again in a moment.';

  @override
  String get authPseudoVientEtrePris =>
      'This username has just been taken. Choose another one.';

  @override
  String get authFonctionnaliteAttendMiseJour =>
      'This feature is waiting on a database update. Try again later, or report it if it persists.';

  @override
  String get authChoisissezPseudo => 'Choose a username.';

  @override
  String authPseudoDoitContenirMoins(Object pseudoMinLength) {
    return 'The username must be at least $pseudoMinLength characters long.';
  }

  @override
  String authPseudoDoitDepasserPseudoMaxLength(Object pseudoMaxLength) {
    return 'The username must not exceed $pseudoMaxLength characters.';
  }

  @override
  String get authUniquementMinusculesChiffresPoints =>
      'Lowercase letters, digits and dots only.';

  @override
  String get authRenseignezAdresseEMail => 'Enter your email address.';

  @override
  String get authAdresseEMailSemble => 'This email address looks incomplete.';

  @override
  String get authChoisissezMotPasse => 'Choose a password.';

  @override
  String authMoinsPasswordMinLengthCaracteresNecessaires(
    Object passwordMinLength,
  ) {
    return 'At least $passwordMinLength characters are required.';
  }

  @override
  String get authAjoutezMoinsMajuscule => 'Add at least one capital letter.';

  @override
  String get authAjoutezMoinsChiffre => 'Add at least one digit.';

  @override
  String get authConnexionPseudoEncoreDisponible =>
      'Signing in with a username is not available yet. Use your email address.';

  @override
  String get authMotPasseOublie => 'Forgotten password';

  @override
  String get authIndiquezAdresseEMail =>
      'Enter your email address: we will send you a six-digit code to choose a new one.';

  @override
  String get authAdresseEMail => 'Email address';

  @override
  String get authEnvoyerCode => 'Send the code';

  @override
  String get authContentRevoir => 'Good to see you again';

  @override
  String get authConnectezRetrouverGroupesAgenda =>
      'Sign in to find your groups and your calendar.';

  @override
  String get authPseudoAdresseEMail => 'Username or email address';

  @override
  String get authMotPasseOublie2 => 'Forgotten your password?';

  @override
  String get authConnecter => 'Sign in';

  @override
  String get authEncoreCompte => 'No account yet?';

  @override
  String get authInscrire => 'Sign up';

  @override
  String get authSouvenirMoi => 'Remember me';

  @override
  String get authResterezConnecteJusquDeconnexion =>
      'You will stay signed in until you sign out.';

  @override
  String get authSerezDeconnecteFermetureApplication =>
      'You will be signed out when the app closes.';

  @override
  String get authJelvoInstalleEcranAccueil =>
      'Jelvo installed on your home screen has its own session: signing in there is separate from Safari, even with this box ticked.';

  @override
  String get authRenseignezPseudoAdresseE =>
      'Enter your username or your email address.';

  @override
  String get authRenseignezMotPasse => 'Enter your password.';

  @override
  String get authNouveauMotPasse => 'New password';

  @override
  String get authSaisissezCodeRecuPuis =>
      'Enter the code you received, then choose a new password.';

  @override
  String authSaisissezCodeEnvoyeEmail(Object email) {
    return 'Enter the code sent to $email, then choose a new password.';
  }

  @override
  String get authCodeVerification => 'Verification code';

  @override
  String get auth8CaracteresMinimum => '8 characters minimum';

  @override
  String get authChangerMotPasse => 'Change the password';

  @override
  String get authRenvoyerCode => 'Resend the code';

  @override
  String get authEnvoiCours => 'Sending…';

  @override
  String authNouveauCodePossibleSecondsLeft(Object _secondsLeft) {
    return 'New code available in $_secondsLeft s';
  }

  @override
  String get authSaisissezSixChiffresCode =>
      'Enter the six digits of the code.';

  @override
  String get authMotPasseEteMis => 'Your password has been updated.';

  @override
  String get authNouveauCodeVientEtre => 'A new code has just been sent.';

  @override
  String get authCreerCompte => 'Create your account';

  @override
  String get authChoisissezPseudoSecurisezCompte =>
      'Choose a username and secure your account.';

  @override
  String get authEtape12 => 'Step 1 of 2';

  @override
  String get authCreantCompteAcceptezRecevoir =>
      'By creating an account, you agree to receive a verification email.';

  @override
  String get authAppelezComment => 'What is your name?';

  @override
  String get authProchesReconnaitrontFacilement =>
      'Your friends and family will recognise you more easily.';

  @override
  String get authEtape22 => 'Step 2 of 2';

  @override
  String get authCreerCompte2 => 'Create my account';

  @override
  String get authRenseignezPrenom => 'Enter your first name.';

  @override
  String get authRenseignezNom => 'Enter your last name.';

  @override
  String authCompteCreeMaisProfil(Object warning) {
    return 'Account created, but the profile could not be saved: $warning';
  }

  @override
  String get authVerifiezEMail => 'Check your email';

  @override
  String get authSaisissezCodeSixChiffres =>
      'Enter the six-digit code we have just sent you.';

  @override
  String get authChoisirPhotoProfil => 'Choose a profile picture';

  @override
  String get authOuvertureGalerie => 'Opening the gallery…';

  @override
  String get authRetirerPhoto => 'Remove the photo';

  @override
  String get authAjouterPhotoFacultatif => 'Add a photo (optional)';

  @override
  String get authPhotoPuEtreOuverte =>
      'The photo could not be opened. Try again.';

  @override
  String get authMotPasse => 'Password';

  @override
  String get authMotPasse2 => 'Your password';

  @override
  String get authAfficherMotPasse => 'Show the password';

  @override
  String get authMasquerMotPasse => 'Hide the password';

  @override
  String get authMajuscule => 'One capital letter';

  @override
  String get authChiffre => 'One digit';

  @override
  String get authPseudoDejaPris => 'This username is already taken.';

  @override
  String get authPseudoDisponible => 'This username is available.';

  @override
  String get authCodeVerificationSixChiffres => 'Six-digit verification code';

  @override
  String get availabilityChaqueSemaine => 'Every week';

  @override
  String get availabilityDatePrecise => 'A specific date';

  @override
  String get availabilityCreneauPuEtreEnregistre =>
      'The time slot could not be saved. Try again in a moment.';

  @override
  String get availabilityDisponibilites => 'My availability';

  @override
  String get availabilityNouveauCreneau => 'New time slot';

  @override
  String get availabilityDisponibilitesIndisponibles =>
      'Availability unavailable';

  @override
  String get availabilitySemaineType => 'My typical week';

  @override
  String get availabilityCreneauxReviennentChaqueSemaine =>
      'Slots that come back every week';

  @override
  String get availabilityAucunCreneauRecurrentRien =>
      'No recurring slot. With nothing declared, others see you as “Unknown”.';

  @override
  String get availabilityDatePrecisePrimeSemaine =>
      'A specific date, which overrides the typical week';

  @override
  String get availabilityAucuneExceptionJourConge =>
      'No exceptions. A day off or a trip goes here.';

  @override
  String get availabilityAjouterCreneau => 'Add a time slot';

  @override
  String get availabilityContactsMembresGroupesVoient =>
      'Your contacts and the members of your groups only see “Available”, “Unavailable” or “Unknown”. Never your hours, never the reason.';

  @override
  String get availabilityModifierCreneau => 'Edit the time slot';

  @override
  String get availabilitySupprimerCreneau => 'Delete the time slot';

  @override
  String get availabilityCreneauSupprime => 'Time slot deleted.';

  @override
  String get availabilityCreneauExisteListeVa =>
      'This time slot no longer exists. The list will refresh.';

  @override
  String get availabilityAjouterCreneau2 => 'Add the time slot';

  @override
  String get availabilityChoisissezDateCreneau =>
      'Choose the date of the time slot.';

  @override
  String get availabilityFinDoitSuivreDebut =>
      'The end must come after the start.';

  @override
  String get availabilityCreneauModifie => 'Time slot updated.';

  @override
  String get availabilityCreneauAjoute => 'Time slot added.';

  @override
  String get availabilityDisponible => 'Who is available?';

  @override
  String get availabilityHeureChoisieVoyezQu =>
      'At the chosen time. You only see a word, never their slots.';

  @override
  String get availabilityDisponibilitesIndisponiblesInstant =>
      'Availability is unavailable for now.';

  @override
  String get calendarJours => 'Every day';

  @override
  String get calendarToutesSemaines => 'Every week';

  @override
  String get calendarToutesDeuxSemaines => 'Every two weeks';

  @override
  String get calendarMois => 'Every month';

  @override
  String get calendarAns => 'Every year';

  @override
  String get calendar10MinutesAvant => '10 minutes before';

  @override
  String get calendar1HeureAvant => '1 hour before';

  @override
  String get calendarVeille => 'The day before';

  @override
  String get calendar1SemaineAvant => '1 week before';

  @override
  String calendarMinutesMin(Object minutes) {
    return '$minutes min';
  }

  @override
  String get calendarEvenementPuEtreCree =>
      'The event could not be created. Try again in a moment.';

  @override
  String get calendarEvenementPuEtreModifie =>
      'The event could not be updated. Try again in a moment.';

  @override
  String get calendarSemainePrecedente => 'Previous week';

  @override
  String get calendarSemaineSuivante => 'Next week';

  @override
  String get calendarRienFiltres => 'Nothing with these filters';

  @override
  String get calendarFiltrePoseJourneeEntiere =>
      'A filter is on: the full day may hold something else.';

  @override
  String get calendarNiEvenementNiTache =>
      'No event, no task and no declared slot for this day.';

  @override
  String get calendarCreerEvenement => 'Create an event';

  @override
  String get calendarModifierEvenement => 'Edit the event';

  @override
  String get calendarSupprimerEvenement => 'Delete the event';

  @override
  String get calendarEvenementIntrouvable => 'Event not found';

  @override
  String get calendarEteSupprimeAvezAcces =>
      'It has been deleted, or you no longer have access to it.';

  @override
  String get calendarNonPrecise => 'Not specified';

  @override
  String get calendarReponse => 'Your reply';

  @override
  String get calendarPersonneEncoreEteConvie => 'Nobody has been invited yet.';

  @override
  String get calendarEteSupprimeAvezAcces2 =>
      'It has been deleted, or you no longer have access to it. There is nothing left to confirm.';

  @override
  String get calendarRevenirCalendrier => 'Back to the calendar';

  @override
  String get calendarMembre => 'A member';

  @override
  String get calendarConvieEvenement => 'invites you to an event';

  @override
  String get calendarPropos => 'About';

  @override
  String get calendarCetEvenementDejaEu =>
      'This event has already taken place.';

  @override
  String get calendarSerez => 'Will you be there?';

  @override
  String get calendarVoirDetailEvenement => 'See the event details';

  @override
  String get calendarCreneauxDeclaresFondJournee =>
      'Declared slots, as the backdrop of the day. They do not belong to any group.';

  @override
  String get calendarEvenementTache => 'An event, a task…';

  @override
  String get calendarDeuxLettresSuffisentChercher =>
      'Two letters are enough to search.';

  @override
  String get calendarTitre => 'Title *';

  @override
  String get calendarExDejeunerChezCamille => 'E.g. Lunch at Camille’s';

  @override
  String get calendarExPetitComptoir => 'E.g. Le Petit Comptoir';

  @override
  String get calendarEffacerLieu => 'Clear the location';

  @override
  String get calendarQuFautSavoirQu => 'What to know, what to bring';

  @override
  String get calendarInviterMembresGroupe => 'Invite members of the group';

  @override
  String get calendarJelvoPreviendraParticipants =>
      'Jelvo will notify the participants';

  @override
  String get calendarRendezReguliers => 'For recurring get-togethers';

  @override
  String get calendarEnregistrerModifications => 'Save the changes';

  @override
  String get calendarCreerEvenement2 => 'Create the event';

  @override
  String get calendarDate => 'Date *';

  @override
  String get calendarHeure => 'Time *';

  @override
  String get calendarMembres => 'All members';

  @override
  String get calendarSelectionMembresGroupeConvies =>
      'With no selection, every member of the group is invited.';

  @override
  String get calendarDonnezTitreEvenement => 'Give the event a title.';

  @override
  String get calendarEvenementEteModifie => 'The event has been updated.';

  @override
  String calendarEvenementTitreEteCree(Object titre) {
    return 'The event “$titre” has been created.';
  }

  @override
  String get calendarQuelGroupe => 'In which group? *';

  @override
  String get calendarSeulVerrez => 'Only you will see it';

  @override
  String get calendarQuelGroupe2 => 'In which group?';

  @override
  String chatMoMo(Object mo) {
    return '$mo MB';
  }

  @override
  String chatOuiOui(Object oui) {
    return '$oui yes';
  }

  @override
  String chatPeutEtrePeutEtre(Object peutEtre) {
    return '$peutEtre maybe';
  }

  @override
  String chatNonNon(Object non) {
    return '$non no';
  }

  @override
  String get chatAucuneReponse => 'No replies';

  @override
  String get chatQuelqu => 'Someone';

  @override
  String get chatMessagePuEtreEnvoye =>
      'The message could not be sent. Try again in a moment.';

  @override
  String get chatConversationIndisponible => 'Conversation unavailable';

  @override
  String get chatRienEncore => 'Nothing yet';

  @override
  String get chatLancezConversationPersonneEncore =>
      'Start the conversation: nobody has written here yet.';

  @override
  String chatReagirEmoji(Object emoji) {
    return 'React $emoji';
  }

  @override
  String get chatSupprimerMessage => 'Delete the message';

  @override
  String get chatPouvezSupprimerMessages =>
      'You can only delete your own messages';

  @override
  String get chatMessageSupprime => 'Message deleted.';

  @override
  String get chatMessagePeutEtreSupprime =>
      'This message can no longer be deleted.';

  @override
  String get chatNouvelleTache => 'New task';

  @override
  String get chatCreerTacheFaire => 'Create a task to do';

  @override
  String get chatPlanifierEvenement => 'Plan an event';

  @override
  String get chatPhotoVideo => 'Photo or video';

  @override
  String get chatEnvoyerMedia => 'Send a media file';

  @override
  String get chatRienPrevuInstant => 'Nothing planned for now';

  @override
  String get chatPhotoGalerie => 'Photo from the gallery';

  @override
  String get chatPrendrePhoto => 'Take a photo';

  @override
  String get chatVideoGalerie => 'Video from the gallery';

  @override
  String get chatMediaPuEtreLu =>
      'This media file could not be read. Try again.';

  @override
  String get chatNonEnvoyeReessayer => 'Not sent — try again';

  @override
  String get chatMessageSupprime2 => 'Message deleted';

  @override
  String get chatTacheEteSupprimee => 'This task has been deleted.';

  @override
  String get chatDesister => 'Step down';

  @override
  String get chatProposeeGroupePersonneEncore =>
      'Offered to the group — nobody has taken it yet.';

  @override
  String get chatCetEvenementEteSupprime => 'This event has been deleted.';

  @override
  String get chatTresBienTacheReste =>
      'Fine — the task stays offered to the group.';

  @override
  String get chatMicrophoneAccessibleAutorisezReglages =>
      'The microphone is not accessible. Allow it in your browser settings, then reopen the conversation.';

  @override
  String get chatAjouterConversation => 'Add to the conversation';

  @override
  String get chatMessage => 'Your message';

  @override
  String get chatFermerEmojis => 'Close the emojis';

  @override
  String get chatEnregistrerMessageVocal => 'Record a voice message';

  @override
  String get chatAnnulerEnregistrement => 'Cancel the recording';

  @override
  String get chatEnregistrement => 'Recording…';

  @override
  String get chatEnvoyerMessageVocal => 'Send the voice message';

  @override
  String get chatPlusieursPersonnesTrainEcrire => 'Several people are typing…';

  @override
  String get chatMettrePause => 'Pause';

  @override
  String get contactsDemandeEnvoyee => 'Request sent.';

  @override
  String get contactsPersonneFaitDejaPartie =>
      'This person is already one of your contacts.';

  @override
  String get contactsDemandeDejaAttente => 'A request is already pending.';

  @override
  String get contactsPouvezAjouterMeme => 'You cannot add yourself.';

  @override
  String get contactsQRCode => 'My QR code';

  @override
  String get contactsCherchezPseudo => 'Search for a username';

  @override
  String get contactsSaisissezMoinsDeuxCaracteres =>
      'Type at least two characters to find someone, or scan their QR code.';

  @override
  String get contactsRechercheIndisponible => 'Search unavailable';

  @override
  String get contactsAucunResultat => 'No results';

  @override
  String contactsAucunPseudoCommenceTerm(Object term) {
    return 'No username starts with “$term”.';
  }

  @override
  String get contactsDejaCarnet => 'Already in your contacts';

  @override
  String get contactsContacts => 'My contacts';

  @override
  String get contactsRechercherContact => 'Search for a contact';

  @override
  String get contactsDemandesRecues => 'Requests received';

  @override
  String get contactsCarnetIndisponible => 'Contacts unavailable';

  @override
  String get contactsCarnetVide => 'No contacts';

  @override
  String get contactsAjoutezProchesLeurPseudo =>
      'Add your friends and family by username, or by scanning their QR code, to plan together.';

  @override
  String contactsAucunContactCorrespondQuery(Object query) {
    return 'No contact matches “$query”.';
  }

  @override
  String get contactsDemandeRefusee => 'Request declined.';

  @override
  String get contactsFaitesScannerCodeEtre =>
      'Have this code scanned to be added as a contact. It only contains your username — no email address, no calendar.';

  @override
  String get contactsPartagerPseudo => 'Share my username';

  @override
  String get contactsPseudoJelvo => 'My Jelvo username';

  @override
  String get contactsScannerQRCode => 'Scan a QR code';

  @override
  String get contactsScanIndisponibleIci => 'Scanning unavailable here';

  @override
  String get contactsChercherPseudo => 'Search by username';

  @override
  String get contactsCameraInaccessible => 'Camera unavailable';

  @override
  String get contactsAutorisezAccesCameraScanner =>
      'Allow camera access to scan a QR code.';

  @override
  String get contactsVisezQRCodeProche =>
      'Point at someone’s QR code to send them a contact request.';

  @override
  String get contactsQRCodeProfilJelvo =>
      'This QR code is not a Jelvo profile.';

  @override
  String contactsAucunComptePortePseudo(Object pseudo) {
    return 'No account has the username @$pseudo.';
  }

  @override
  String get contactsScannerQRCode2 => 'Scan a QR code';

  @override
  String get contactsAjouterContactQRCode => 'Add a contact with their QR code';

  @override
  String get contactsRechercherPseudo => 'Search for a username';

  @override
  String get contactsTrouverUtilisateurJelvo => 'Find a Jelvo user';

  @override
  String get contactsInviterAmi => 'Invite a friend';

  @override
  String get contactsEnvoyerInvitationJelvo => 'Send a Jelvo invitation';

  @override
  String get contactsRejoignezMoiJelvo => 'Join me on Jelvo';

  @override
  String get contactsRetirerFavoris => 'Remove from favourites';

  @override
  String get contactsAjouterFavoris => 'Add to favourites';

  @override
  String get contactsFavorisTeteCarnet =>
      'Favourites come first in your contacts';

  @override
  String get contactsRetirerContacts => 'Remove from my contacts';

  @override
  String get contactsRelationSupprimeeDeuxCotes =>
      'The connection is removed on both sides';

  @override
  String get contactsRetirerContact => 'Remove this contact';

  @override
  String get contactsGererFavoris => 'Manage favourites';

  @override
  String get contactsFavoriPersonnelAutreSait =>
      'Favourites are private: the other person knows nothing about it.';

  @override
  String get contactsAjoutezAbordContactsEpingler =>
      'Add some contacts to pin first.';

  @override
  String get contactsEpinglezProchesRetrouverIci =>
      'Pin your closest people to find them here.';

  @override
  String get contactsScanQRCodeDemande =>
      'Scanning a QR code needs a camera: it is available in the mobile app. Here, search for the person by username.';

  @override
  String get createCreneauAgendaSeulPartage =>
      'A slot in your calendar, on your own or shared';

  @override
  String get createActionFaireEcheanceResponsable =>
      'Something to do, with a due date and someone in charge';

  @override
  String get createEspacePartageProchesAmis =>
      'A shared space with your family or your friends';

  @override
  String get createChoisissezTypeFormulaireOuvre =>
      'Pick a type: the form opens just below.';

  @override
  String get groupsLienInvitationExisteValable =>
      'This invitation link does not exist or is no longer valid.';

  @override
  String get groupsLienInvitationExpireDemandez =>
      'This invitation link has expired. Ask the group for a new one.';

  @override
  String get groupsLienInvitationEteRevoque =>
      'This invitation link has been revoked by the group.';

  @override
  String get groupsLienDejaServiNombre =>
      'This link has already been used the intended number of times.';

  @override
  String get groupsAvezRejointGroupe => 'You have joined the group.';

  @override
  String get groupsFaitesDejaPartieGroupe =>
      'You are already part of this group.';

  @override
  String get groupsLienInvitationExpire => 'This invitation link has expired.';

  @override
  String get groupsLienInvitationEteRevoque2 =>
      'This invitation link has been revoked.';

  @override
  String get groupsConnectezRejoindreGroupe => 'Sign in to join this group.';

  @override
  String get groupsAvezQuitteGroupe => 'You have left the group.';

  @override
  String get groupsAvezQuitteGroupeAncien =>
      'You have left the group. The longest-standing member becomes admin.';

  @override
  String get groupsEtiezDernierMembreGroupe =>
      'You were the last member: the group has been deleted.';

  @override
  String get groupsFaitesPartieGroupe => 'You are not part of this group.';

  @override
  String groupsNomDesormaisAdministrateur(Object nom) {
    return '$nom is now an administrator.';
  }

  @override
  String groupsNomAdministrateur(Object nom) {
    return '$nom is no longer an administrator.';
  }

  @override
  String groupsNomEteRetireGroupe(Object nom) {
    return '$nom has been removed from the group.';
  }

  @override
  String groupsAdhesionNomDesormaisTemporaire(Object nom) {
    return '$nom’s membership is now temporary.';
  }

  @override
  String groupsNomFaitPartieGroupe(Object nom, Object terme) {
    return '$nom is part of the group until $terme.';
  }

  @override
  String groupsAdhesionNomTerme(Object nom) {
    return '$nom’s membership no longer has an end date.';
  }

  @override
  String get groupsEtaitDejaCasRien =>
      'That was already the case, nothing has changed.';

  @override
  String get groupsDateDejaPasseeDepart =>
      'That date has already passed. For an immediate departure, use “Remove from the group”.';

  @override
  String groupsNomDejaAdministrateur(Object nom) {
    return '$nom is already an administrator.';
  }

  @override
  String get groupsGroupeDoitGarderMoins =>
      'A group must keep at least one administrator. Appoint someone else first.';

  @override
  String get groupsSeulAdministrateurGroupePeut =>
      'Only a group administrator can do that.';

  @override
  String groupsNomAdministrateur2(Object nom) {
    return '$nom is not an administrator.';
  }

  @override
  String groupsNomFaitPartieGroupe2(Object nom) {
    return '$nom is no longer part of the group.';
  }

  @override
  String get groupsPartirMemeUtilisezQuitter =>
      'To leave yourself, use “Leave the group”.';

  @override
  String get groupsActionAboutiReessayezInstant =>
      'The action did not go through. Try again in a moment.';

  @override
  String get groupsJamaisUtilise => 'Never used';

  @override
  String get groupsInvitationDejaAcceptee => 'Invitation already accepted';

  @override
  String get groupsInvitationDejaRefusee => 'Invitation already declined';

  @override
  String get groupsInvitationExpiree => 'Invitation expired';

  @override
  String get groupsEtesDejaMembre => 'You are already a member';

  @override
  String get groupsGroupeSupprime => 'Group deleted';

  @override
  String get groupsInvitationIntrouvable => 'Invitation not found';

  @override
  String get groupsAvezDejaRejointGroupe =>
      'You have already joined this group. Open it to find its events, its tasks and its conversation.';

  @override
  String get groupsAvezDeclineInvitationDemandez =>
      'You declined this invitation. Ask for a new one if you change your mind.';

  @override
  String get groupsInvitationPasseDateLimite =>
      'This invitation is past its deadline. Ask the group for a new one.';

  @override
  String get groupsFaitesDejaPartieGroupe2 =>
      'You are already part of this group, probably through a shared link.';

  @override
  String get groupsGroupeInvitaitEteSupprime =>
      'The group that invited you has been deleted. There is nothing left to join.';

  @override
  String get groupsInvitationExisteEtaitDestinee =>
      'This invitation does not exist, or it was not meant for you.';

  @override
  String get groupsGroupe => 'this group';

  @override
  String get groupsGroupePuEtreCree =>
      'The group could not be created. Try again in a moment.';

  @override
  String get groupsGroupeIndisponible => 'Group unavailable';

  @override
  String get groupsGroupeIntrouvable => 'Group not found';

  @override
  String get groupsGroupeEteSupprimeFaites =>
      'This group has been deleted, or you are no longer part of it.';

  @override
  String get groupsRevenirGroupes => 'Back to the groups';

  @override
  String get groupsInviterQuelqu => 'Invite someone';

  @override
  String get groupsPartagerLien => 'Share a link';

  @override
  String get groupsModifierGroupe => 'Edit the group';

  @override
  String get groupsQuitterGroupe => 'Leave the group';

  @override
  String get groupsSupprimerGroupe => 'Delete the group';

  @override
  String get groupsAucunMembreAfficher => 'No members to show';

  @override
  String get groupsListeMembresPuEtre =>
      'The list of members could not be loaded. Try again in a moment.';

  @override
  String get groupsVoir => 'See all';

  @override
  String get groupsAjouterEvenement => 'Add an event';

  @override
  String get groupsTachesPrioritaires => 'Priority tasks';

  @override
  String get groupsRetirerMembre => 'Remove this member';

  @override
  String get groupsGroupeEteSupprime => 'The group has been deleted.';

  @override
  String get groupsDecrivezGroupePhrase =>
      'Describe this group in one sentence.';

  @override
  String get groupsInviterMembre => 'Invite a member';

  @override
  String get groupsCherchezPersonnePseudoRecevra =>
      'Search for the person by username. They will get an invitation to accept.';

  @override
  String groupsNameRecuInvitation(Object name) {
    return '$name has received your invitation.';
  }

  @override
  String groupsNameFaitDejaPartie(Object name) {
    return '$name is already part of the group.';
  }

  @override
  String groupsNameDejaInvitationAttente(Object name) {
    return '$name already has a pending invitation.';
  }

  @override
  String get groupsDateFinChoisieDeja =>
      'The end date you chose has already passed.';

  @override
  String get groupsSeulAdministrateurPeutFixer =>
      'Only an administrator can set a membership duration.';

  @override
  String get groupsSeulsMembresGroupePeuvent =>
      'Only members of the group can invite.';

  @override
  String get groupsSaisissezMoinsDeuxCaracteres =>
      'Type at least two characters.';

  @override
  String get groupsCreezGroupeInvitezPremiers =>
      'Create your group and invite the first members.';

  @override
  String get groupsPhotoGroupe => 'Group photo';

  @override
  String get groupsNomGroupe => 'Group name *';

  @override
  String get groupsExFamilleRousseau => 'E.g. The Rousseau family';

  @override
  String get groupsDescriptionOptionnelle => 'Description (optional)';

  @override
  String get groupsDecrivezBrievementButGroupe =>
      'Briefly describe what this group is for';

  @override
  String get groupsCreerGroupe => 'Create the group';

  @override
  String get groupsDonnezNomGroupe => 'Give your group a name.';

  @override
  String groupsNomDoitDepasserNameMaxLength(Object _nameMaxLength) {
    return 'The name must not exceed $_nameMaxLength characters.';
  }

  @override
  String get groupsGroupeCree1Invitation => 'Group created, 1 invitation sent.';

  @override
  String groupsGroupeCreeEnvoyeesInvitations(Object envoyees) {
    return 'Group created, $envoyees invitations sent.';
  }

  @override
  String get groupsGroupeCreeMaisInvitation =>
      'Group created, but the invitation could not be sent.';

  @override
  String groupsGroupeCreeMaisAucune(Object echecs) {
    return 'Group created, but none of the $echecs invitations could be sent.';
  }

  @override
  String groupsGroupeCreeEnvoyeesInvitation(Object envoyees, Object echecs) {
    return 'Group created, $envoyees invitation(s) sent, $echecs not sent.';
  }

  @override
  String get groupsGroupePrive => 'Private group';

  @override
  String get groupsSeulsMembresInvitesPourront =>
      'Only invited members will be able to join it and see its content. Every Jelvo group is private.';

  @override
  String get groupsRechercherGroupe => 'Search for a group';

  @override
  String get groupsEffacerRecherche => 'Clear the search';

  @override
  String get groupsGroupesIndisponibles => 'Groups unavailable';

  @override
  String get groupsAucunGroupeMoment => 'No groups yet';

  @override
  String get groupsCreezGroupePartagerAgenda =>
      'Create a group to share a calendar and split up the tasks with the people close to you.';

  @override
  String get groupsCreerGroupe2 => 'Create a group';

  @override
  String get groupsAucunGroupeNom => 'No group by that name';

  @override
  String groupsAucunGroupesCorrespondTerme(Object terme) {
    return 'None of your groups matches “$terme”.';
  }

  @override
  String get groupsInviteRejoindreGroupe =>
      'You have been invited to join a group.';

  @override
  String get groupsInvitationsIndisponibles => 'Invitations unavailable';

  @override
  String get groupsAucuneInvitation => 'No invitations';

  @override
  String get groupsQuandProcheInviteraGroupe =>
      'When someone invites you to a group, the invitation will appear here.';

  @override
  String get groupsInvitationIndisponible => 'Invitation unavailable';

  @override
  String get groupsInviteRejoindreGroupe2 => 'invites you to join a group';

  @override
  String get groupsCree => 'Created on';

  @override
  String get groupsDejaGroupe => 'Already in the group';

  @override
  String get groupsInvitationRefusee => 'Invitation declined.';

  @override
  String get groupsOuvrirGroupe => 'Open the group';

  @override
  String get groupsLienInutilisable => 'Link unusable';

  @override
  String get groupsRevenirAccueil => 'Back to home';

  @override
  String get groupsEtesInviteRejoindreGroupe =>
      'You are invited to join this group on Jelvo.';

  @override
  String get groupsRejoindreGroupe => 'Join the group';

  @override
  String get groupsCreerCompteRejoindre => 'Create an account to join';

  @override
  String get groupsAiDejaCompte => 'I already have an account';

  @override
  String get groupsGroupeSeraRejointAutomatiquement =>
      'You will join the group automatically once your account is created.';

  @override
  String get groupsCreezIciSeraPartage =>
      'What you create here will be shared with the group.';

  @override
  String get groupsDateProposerMembres => 'A date to suggest to the members';

  @override
  String get groupsQuelqueChoseFaireRepartir => 'Something to do, to share out';

  @override
  String get groupsAjouterMembres => 'Add members';

  @override
  String get groupsChoisirContacts => 'Choose from my contacts';

  @override
  String get groupsParcourirCarnetJelvo => 'Browse my Jelvo contacts';

  @override
  String get groupsInviterLien => 'Invite by link';

  @override
  String get groupsProposeApresCreation => 'Offered after creation';

  @override
  String get groupsPartagerLienInvitation => 'Share an invitation link';

  @override
  String get groupsInvitationsPartentCreationGroupe =>
      'The invitations go out when the group is created.';

  @override
  String get groupsAucunContactNom => 'No contact by that name.';

  @override
  String get groupsPersonneInviteInstant => 'Nobody is invited for now.';

  @override
  String get groups1PersonneSeraInvitee => '1 person will be invited.';

  @override
  String groupsNombrePersonnesSerontInvitees(Object nombre) {
    return '$nombre people will be invited.';
  }

  @override
  String get groupsRetirer => 'Remove all';

  @override
  String get groupsCarnetVideInstantPourrez =>
      'Your contacts are empty for now. You will be able to invite from the group screen, by shared link or by username.';

  @override
  String get groupsChoisirPhotoGroupe => 'Choose a group photo';

  @override
  String get groupsChangerPhoto => 'Change the photo';

  @override
  String get groupsAjouterPhoto => 'Add a photo';

  @override
  String get groupsTachesNenRetard => 'tasks\noverdue';

  @override
  String get groupsEvenementsNaVenir => 'events\ncoming up';

  @override
  String get groupsAucunLienActifMoment => 'No active link for now.';

  @override
  String get groupsDureeAccordeeProchainLien =>
      'Duration granted by the next link';

  @override
  String get groupsGenererLien => 'Generate a link';

  @override
  String get groupsGenererAutreLien => 'Generate another link';

  @override
  String get groupsLienCopiePressePapiers => 'Link copied to the clipboard.';

  @override
  String get groupsCopierLien => 'Copy the link';

  @override
  String get groupsRevoquerLien => 'Revoke the link';

  @override
  String get groupsGererMembre => 'Manage this member';

  @override
  String get groupsRetirerRoleAdministrateur => 'Remove the administrator role';

  @override
  String get groupsNommerAdministrateur => 'Make administrator';

  @override
  String get groupsModifierDureeAdhesion => 'Change the membership duration';

  @override
  String get groupsRendreAdhesionTemporaire => 'Make the membership temporary';

  @override
  String get groupsRetirerGroupe => 'Remove from the group';

  @override
  String get groupsDureeAdhesion => 'Membership duration';

  @override
  String get groupsTerme => 'No end date';

  @override
  String get groupsFinAdhesion => 'End of membership';

  @override
  String get groupsNouvelleDuree => 'New duration';

  @override
  String get homeBonApresMidi => 'Good afternoon';

  @override
  String get homeCreezGroupePartagerAgenda =>
      'Create a group to share a calendar, tasks and a conversation.';

  @override
  String homeBasePrenom(Object base, Object prenom) {
    return '$base $prenom';
  }

  @override
  String get homeAgenda => 'My day';

  @override
  String get homeVoirCalendrier => 'See calendar';

  @override
  String get homeVoirAgenda1 => 'See my whole day (1 more)';

  @override
  String homeVoirAgendaReste(Object reste) {
    return 'See my whole day ($reste more)';
  }

  @override
  String get homeTaches => 'My tasks';

  @override
  String get homeVoirToutesTaches => 'See all my tasks';

  @override
  String get home1Tache => '1 task';

  @override
  String get homeSemaine => 'this week';

  @override
  String get homeTraiter => 'to handle';

  @override
  String get homeAucuneTacheAttendEtre => 'No task is waiting to be handled.';

  @override
  String get homeDejaAgenda => 'Already in your day';

  @override
  String get homeTachesJourFigurentChronologie =>
      'Your tasks for today appear in the timeline above.';

  @override
  String homeValeurLibelleDetail(Object valeur, Object libelle, Object detail) {
    return '$valeur $libelle, $detail';
  }

  @override
  String homeValeurLibelle(Object valeur, Object libelle) {
    return '$valeur $libelle';
  }

  @override
  String get homeAujourdHui => ', today';

  @override
  String get homeRienPrevu => ', nothing planned';

  @override
  String get notificationsGroupe => 'a group';

  @override
  String get notificationsContact => 'A contact';

  @override
  String get notificationsEvenement => 'an event';

  @override
  String get notificationsTache => 'a task';

  @override
  String notificationsInvitationRejoindreGroupName(Object groupName) {
    return 'Invitation to join $groupName';
  }

  @override
  String get notificationsDemandeContact => 'Contact request';

  @override
  String notificationsSenderNameInviteRejoindreGroupName(
    Object senderName,
    Object groupName,
  ) {
    return '$senderName invites you to join “$groupName”.';
  }

  @override
  String notificationsSenderNameSouhaiteAjouterContacts(Object senderName) {
    return '$senderName would like to add you to their contacts.';
  }

  @override
  String notificationsSenderNameConfieTache(Object senderName) {
    return '$senderName has given you this task.';
  }

  @override
  String notificationsSenderNameAccepteTache(Object senderName) {
    return '$senderName accepts this task.';
  }

  @override
  String notificationsSenderNameDeclineTache(Object senderName) {
    return '$senderName declines this task.';
  }

  @override
  String get notificationsFeteAnniversaireAujourdHui => 'has a birthday today.';

  @override
  String get notificationsAvezNouvelleNotification =>
      'You have a new notification.';

  @override
  String get notificationsVoirDemande => 'See the request';

  @override
  String get notificationsVoirEvenement => 'See the event';

  @override
  String get notificationsVoirTache => 'See the task';

  @override
  String get notificationsGroupesDiscussions => 'Groups and conversations';

  @override
  String get notificationsTachesRappels => 'Tasks and reminders';

  @override
  String get notificationsMarquerCommeLu => 'Mark all read';

  @override
  String get notificationsNotificationsIndisponibles =>
      'Notifications unavailable';

  @override
  String get notificationsAucuneNotification => 'No notifications';

  @override
  String get notificationsInvitationsGroupeDemandesContact =>
      'Group invitations and contact requests will appear here.';

  @override
  String get notificationsNotificationsPush => 'Push notifications';

  @override
  String get notificationsInstaller => 'To install';

  @override
  String get notificationsActiverNotifications => 'Turn on notifications';

  @override
  String get notificationsDesactiverCetAppareil => 'Turn off on this device';

  @override
  String get notificationsNotificationsActives => 'Notifications on';

  @override
  String get notificationsNotificationsRefusees => 'Notifications refused';

  @override
  String get notificationsInstallezJelvoRecevoir =>
      'Install Jelvo to receive them';

  @override
  String get notificationsNotificationsDesactivees => 'Notifications off';

  @override
  String get notificationsNotificationsIndisponiblesIci =>
      'Notifications unavailable here';

  @override
  String get notificationsCetAppareilRecevraNotifications =>
      'This device will receive the notifications you leave ticked in the settings.';

  @override
  String get notificationsAvezRefuseAutorisationApplication =>
      'You refused permission. The app can no longer ask again: it reopens in your browser settings, on the site’s “Notifications” row.';

  @override
  String get notificationsIPhoneIPadNotificationsExistent =>
      'On iPhone and iPad, notifications only exist in Jelvo added to the home screen. In a Safari tab, the system does not offer them at all.';

  @override
  String get notificationsNavigateurDemanderaAutorisationPourrez =>
      'Your browser will ask you for permission. You can change your mind at any time.';

  @override
  String get notificationsVersionApplicationGereNotifications =>
      'This version of the app does not support system notifications.';

  @override
  String get notificationsAutorisationRefuseeRouvreReglages =>
      'Permission refused. It reopens in your browser settings, not here.';

  @override
  String get notificationsNotificationsOntPuEtre =>
      'Notifications could not be turned on.';

  @override
  String get notificationsNotificationsDesactiveesCetAppareil =>
      'Notifications turned off on this device.';

  @override
  String get notifications1TouchezBoutonPartager =>
      '1. Tap Safari’s Share button.';

  @override
  String get notifications2ChoisissezEcranAccueil =>
      '2. Choose “Add to Home Screen”.';

  @override
  String get notifications3OuvrezJelvoDepuis =>
      '3. Open Jelvo from the icon, then sign in again.';

  @override
  String get notificationsReconnexionErreurApplicationInstallee =>
      'Signing in again is not a bug: the installed app has its own storage, separate from Safari.';

  @override
  String get onboardingBienvenueJelvo => 'Welcome to Jelvo';

  @override
  String get onboardingAppRassembleGroupesProjets =>
      'The app that brings together your groups, your plans and the people close to you.';

  @override
  String get onboardingGroupesMemeEndroit => 'All your groups in one place';

  @override
  String get onboardingOrganisezProjetsActivitesEchanges =>
      'Organise your plans, activities and conversations with ease.';

  @override
  String get onboardingAgendaPartageSynchronise => 'A shared, synced calendar';

  @override
  String get onboardingManquezAucunEvenementImportant =>
      'Never miss an important event again.';

  @override
  String get onboardingTachesClairesEfficaces => 'Clear, effective tasks';

  @override
  String get onboardingAttribuezSuivezAccomplissezEnsemble =>
      'Assign, follow and reach your goals together.';

  @override
  String get profileProposJelvo => 'About Jelvo';

  @override
  String get profileJelvoReunitGroupesEvenements =>
      'Jelvo brings together your groups, your events, your tasks and your availability in one place — for family, friends and flatmates.';

  @override
  String get profileBonSavoir => 'Good to know';

  @override
  String get profileJelvoApplicationWebInstallable =>
      'Jelvo is an installable web app. On iPhone, notifications only work once the icon has been added to the home screen, and the installed app has its own session: you need to sign in there.';

  @override
  String get profileChoisirAvatar => 'Choose an avatar';

  @override
  String get profileUtiliserCetAvatar => 'Use this avatar';

  @override
  String profileAvatarId(Object id) {
    return 'Avatar $id';
  }

  @override
  String get profileChangerMotPasse => 'Change password';

  @override
  String get profileMotPasseChange => 'Password changed.';

  @override
  String get profileModifierProfil => 'Edit profile';

  @override
  String get profileProfilEnregistre => 'Profile saved.';

  @override
  String get profileProfil => 'My profile';

  @override
  String get profileProfilIndisponible => 'Profile unavailable';

  @override
  String get profileProfilIntrouvable => 'Profile not found';

  @override
  String get profileProfilEncoreEteCree =>
      'Your profile has not been created yet. Sign in again to finish it.';

  @override
  String get profileProfilJelvo => 'My Jelvo profile';

  @override
  String get profileAutresVoientQuMot =>
      'Others only see a word: available, unavailable or unknown.';

  @override
  String get profileLectureAboutiReessayezInstant =>
      'Loading did not go through. Try again in a moment.';

  @override
  String get profilePersonneCompteJelvo =>
      'This person no longer has a Jelvo account.';

  @override
  String get profileAnnulerDemande => 'Cancel the request';

  @override
  String get profileAjouterContact => 'Add as a contact';

  @override
  String get profileRetirerContact => 'Remove this contact?';

  @override
  String get profileActionAbouti => 'The action did not go through.';

  @override
  String get profileInformationsPersonnelles => 'Personal details';

  @override
  String get profileDeconnecter => 'Sign out';

  @override
  String get profileDevrezSaisirNouveauIdentifiants =>
      'You will have to enter your credentials again to come back.';

  @override
  String get profileJourMoisSeulementJelvo =>
      'The day and the month only. Jelvo does not ask for your year of birth.';

  @override
  String get profileContactsVoientPrevenusJour =>
      'Your contacts see it, and are notified on the day.';

  @override
  String get profileAnneesNonBissextilesSera =>
      'In non-leap years, it will be celebrated on 28 February, the last day of the month.';

  @override
  String get profileSuitReglageTelephone => 'Follows your phone’s setting';

  @override
  String get profileFondBlancTexteSombre => 'White background, dark text';

  @override
  String get profileFondSombreTexteClair => 'Dark background, light text';

  @override
  String get profileChoixVautCetAppareil =>
      'This choice only applies on this device.';

  @override
  String get profilePhotoProfil => 'Profile picture';

  @override
  String get profileChoisirPhoto => 'Choose a photo';

  @override
  String get profileDepuisPhotosAppareil => 'From the photos on your device';

  @override
  String get profileChoisirAvatarJelvo => 'Choose a Jelvo avatar';

  @override
  String get profileQuatreVingtTreizeIllustrations =>
      'Ninety-three illustrations to choose from';

  @override
  String get profileInitialesPrendrontPlace =>
      'Your initials will take its place';

  @override
  String get profileAjoutezJourMoisAnnee =>
      'Add the day and the month, without the year';

  @override
  String get profileAdresseIndisponible => 'Address unavailable';

  @override
  String get profileQuelquesMots => 'A few words about you';

  @override
  String get profileAjoutezQuelquesMots => 'Add a few words about you';

  @override
  String get profileEnregistrerBio => 'Save the bio';

  @override
  String get profileModifierBio => 'Edit the bio';

  @override
  String get profileChangerPhoto => 'Change photo';

  @override
  String get profileChangerPhotoProfil => 'Change profile picture';

  @override
  String get profileQRCode => 'QR code';

  @override
  String get profilePartagerProfil => 'Share profile';

  @override
  String get profileStatistiques => 'My stats';

  @override
  String get profileTachesTerminees => 'Tasks done';

  @override
  String get profile1GroupeCommun => '1 group in common';

  @override
  String get profileOrganisezRienEnsembleInstant =>
      'You are not organising anything together for now.';

  @override
  String get tasksAvezPrisTache => 'You have taken this task.';

  @override
  String get tasksAvezRenduTacheGroupe =>
      'You have given this task back to the group.';

  @override
  String get tasksQuelquVientPrendreAvant =>
      'Someone has just taken it before you.';

  @override
  String get tasksTache => 'This task is not yours.';

  @override
  String get tasksTacheEteConfieeRefusez =>
      'This task was given to you: decline it rather than giving it back.';

  @override
  String get tasksFaitesPartieGroupe => 'You are no longer part of this group.';

  @override
  String get tasksTachePuEtreCreee =>
      'The task could not be created. Try again in a moment.';

  @override
  String get tasksTachePuEtreModifiee =>
      'The task could not be updated. Try again in a moment.';

  @override
  String get tasksTacheConfiee => 'Task assigned';

  @override
  String get tasksTacheIntrouvable => 'Task not found';

  @override
  String get tasksEteSupprimeeAvezAcces =>
      'It has been deleted, or you no longer have access to it. There is nothing left to accept.';

  @override
  String get tasksRevenirAccueil => 'Back to home';

  @override
  String get tasksTacheEteConfiee => 'This task has been given to you';

  @override
  String get tasksConfieTache => 'has given you a task';

  @override
  String get tasksAssignee => 'Assigned to';

  @override
  String get tasksEcheanceDejaPassee => 'The due date has already passed.';

  @override
  String get tasksAvezAccepteTache => 'You have accepted this task.';

  @override
  String get tasksAvezDeclineTache => 'You have declined this task.';

  @override
  String get tasksAvezTerminePart => 'You have finished your part.';

  @override
  String get tasksTacheAssignee => 'This task is not assigned to you.';

  @override
  String get tasksOuvrirTache => 'Open the task';

  @override
  String get tasksTacheAcceptee => 'Task accepted.';

  @override
  String get tasksTacheDeclinee => 'Task declined.';

  @override
  String get tasksModifierTache => 'Edit the task';

  @override
  String get tasksSupprimerTache => 'Delete the task';

  @override
  String get tasksEteSupprimeeAvezAcces2 =>
      'It has been deleted, or you no longer have access to it.';

  @override
  String get tasksPersonneInstantImporteQuel =>
      'Nobody for now. Any member of the group can take it on.';

  @override
  String get tasksRetirer => 'Step down';

  @override
  String get tasksJeMCharge => 'I’ll take it';

  @override
  String get tasksChargezTache => 'You are taking on this task.';

  @override
  String get tasksChargiezDeja => 'You were already taking it on.';

  @override
  String get tasksChargez => 'You are no longer taking it on.';

  @override
  String get tasksEtiezAssigneTache => 'You were not assigned to this task.';

  @override
  String get tasksQuelquChargeDejaPassez =>
      'Someone is already taking it on. Use “Edit” to change the assignees.';

  @override
  String get tasksRienCocherAjoutezQu =>
      'Nothing to tick. Add what is needed: everyone will see what is left.';

  @override
  String get tasksAjouterArticle => 'Add an item';

  @override
  String get tasksAjouterListe => 'Add to the list';

  @override
  String get tasksRetirerListe => 'Remove from the list';

  @override
  String get tasksRouvrirTache => 'Reopen the task';

  @override
  String get tasksMarquerCommeTerminee => 'Mark as done';

  @override
  String get tasksTachesIndisponibles => 'Tasks unavailable';

  @override
  String get tasksAucuneTache => 'No tasks';

  @override
  String get tasksFaitRienEncoreEte =>
      'Everything is done — or nothing has been noted down yet.';

  @override
  String get tasksGroupeAucuneTacheInstant =>
      'This group has no tasks for now.';

  @override
  String get tasksAssigner => 'Assign to';

  @override
  String get tasksMembresGroupeOntEncore =>
      'The members of the group have not been loaded yet.';

  @override
  String get tasksExAcheterPain => 'E.g. Buy the bread';

  @override
  String get tasksJelvoEnverraNotificationPersonne =>
      'Jelvo will send a notification to the assigned person';

  @override
  String get tasksTachesRecurrentes => 'For recurring tasks';

  @override
  String get tasksCreerTache => 'Create the task';

  @override
  String get tasksProposeeGroupeCarteAffichera =>
      'Offered to the whole group: a card will show up in the conversation, and the first to accept takes it.';

  @override
  String tasksConfieeListeRecevraNotification(Object liste) {
    return 'Given to $liste, who will get a notification.';
  }

  @override
  String tasksConfieeListeRecevrontNotification(Object liste) {
    return 'Given to $liste, who will get a notification.';
  }

  @override
  String get tasksEcheancePrioriteDescription =>
      'Due date, priority, description…';

  @override
  String get tasksQuFautSavoirOccuper => 'What to know in order to handle it';

  @override
  String get tasksDonnezTitreTache => 'Give the task a title.';

  @override
  String get tasksTacheEteModifiee => 'The task has been updated.';

  @override
  String tasksTacheTitreEteCreee(Object titre) {
    return 'The task “$titre” has been created.';
  }

  @override
  String get routerPageIntrouvable => 'Page not found';

  @override
  String routerAucunEcranCorrespondLocation(Object location) {
    return 'No screen matches “$location”.';
  }

  @override
  String get calendarRecurrenceJamais => 'Never';

  @override
  String get calendarRappelAucun => 'None';

  @override
  String get coreDemain => 'Tomorrow';

  @override
  String get coreHier => 'Yesterday';

  @override
  String coreIlYaMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String coreIlYaHeures(int heures) {
    return '$heures h ago';
  }

  @override
  String coreIlYaJours(int jours) {
    String _temp0 = intl.Intl.pluralLogic(
      jours,
      locale: localeName,
      other: '$jours days ago',
      one: '$jours day ago',
    );
    return '$_temp0';
  }

  @override
  String coreLeDate(String date) {
    return 'on $date';
  }

  @override
  String get createEvenement => 'Event';

  @override
  String get createTache => 'Task';

  @override
  String get createGroupe => 'Group';

  @override
  String get profileApparence => 'Appearance';

  @override
  String get profileApparenceAutomatique => 'Automatic';

  @override
  String get profileApparenceClair => 'Light';

  @override
  String get profileApparenceSombre => 'Dark';

  @override
  String groupsTachesEnCours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks in progress',
      one: '$count task in progress',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementsAVenir(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events coming up',
      one: '$count event coming up',
    );
    return '$_temp0';
  }

  @override
  String groupsVousAdministrezCeGroupe(String membres) {
    return '$membres · you administer this group';
  }

  @override
  String authMoinsCaracteres(int min) {
    return 'At least $min characters';
  }

  @override
  String get homeBonjour => 'Good morning';

  @override
  String get homeBonsoir => 'Good evening';

  @override
  String get calendarPersonnel => 'Personal';

  @override
  String get calendarJournee => 'All day';

  @override
  String calendarFeteSonAnniversaire(String nom) {
    return 'It’s $nom’s birthday';
  }

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navParametres => 'Settings';

  @override
  String get coreStatutInformation => 'Information';

  @override
  String get coreStatutConfirme => 'Confirmed';

  @override
  String get coreStatutEnAttente => 'Pending';

  @override
  String get coreStatutConflit => 'Conflict';

  @override
  String get coreStatutInactif => 'Inactive';

  @override
  String get notificationsActives => 'On';

  @override
  String get notificationsNotification => 'Notification';

  @override
  String chatUnePersonneEcrit(String nom) {
    return '$nom is typing…';
  }

  @override
  String chatDeuxPersonnesEcrivent(String premier, String second) {
    return '$premier and $second are typing…';
  }

  @override
  String chatAPrisLaTache(String nom) {
    return '$nom has taken the task';
  }

  @override
  String chatAAccepteLaTache(String nom) {
    return '$nom has accepted the task';
  }

  @override
  String chatARefuseLaTache(String nom) {
    return '$nom has declined the task';
  }

  @override
  String chatATermineLaTache(String nom) {
    return '$nom has finished the task';
  }

  @override
  String chatTacheAttribueeA(String nom) {
    return 'Task assigned to $nom';
  }

  @override
  String groupsInvitationDe(String nom) {
    return 'Invitation from $nom';
  }

  @override
  String get calendarRappel => 'Reminder';

  @override
  String get calendarRepeter => 'Repeat';

  @override
  String groupsMembreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return '$_temp0';
  }

  @override
  String groupsTacheOuverteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '$count open task',
    );
    return '$_temp0';
  }

  @override
  String coreJourEtHeure(String jour, String heures) {
    return '$jour · $heures';
  }

  @override
  String groupsRetraitMembreConfirmation(String nom) {
    return '$nom will no longer have access to the group. You can invite them again later.';
  }

  @override
  String groupsQuitterConfirmation(String groupe) {
    return 'You will no longer see “$groupe”. If you are its last administrator, the longest-standing member will take over.';
  }

  @override
  String groupsSupprimerConfirmation(String groupe) {
    return '“$groupe” will disappear for all its members. This action cannot be undone from the app.';
  }

  @override
  String groupsInvitationRecueJusquAu(String nom, String date) {
    return '$nom has received your invitation, until $date.';
  }

  @override
  String get coreRetirer => 'Remove';

  @override
  String get coreQuitter => 'Leave';

  @override
  String get coreSupprimer => 'Delete';

  @override
  String tasksTacheSupprimee(String titre) {
    return '“$titre” has been deleted.';
  }

  @override
  String tasksSupprimerConfirmation(String titre) {
    return '“$titre” will disappear for everyone. This action cannot be undone from the app.';
  }

  @override
  String coreVous(String nom) {
    return '$nom (you)';
  }

  @override
  String coreSurTotal(int fait, int total) {
    return '$fait of $total';
  }

  @override
  String tasksCochePar(String nom) {
    return 'Ticked by $nom';
  }

  @override
  String get tasksListe => 'List';

  @override
  String get tasksEcheance => 'Due date';

  @override
  String get tasksAucune => 'None';

  @override
  String calendarEvenementSupprime(String titre) {
    return '“$titre” has been deleted.';
  }

  @override
  String calendarSupprimerConfirmation(String titre) {
    return '“$titre” will disappear for all the participants. This action cannot be undone from the app.';
  }

  @override
  String get calendarParticipants => 'Participants';

  @override
  String calendarOuiCount(int count) {
    return '$count yes';
  }

  @override
  String calendarVousAvezRepondu(String reponse) {
    return 'You replied: $reponse. You can still change your mind.';
  }

  @override
  String calendarReponseEnregistree(String reponse) {
    return 'Reply saved: $reponse.';
  }

  @override
  String groupsPartagezCeLien(String groupe) {
    return 'Share this link by text, messaging app or email. The person will be able to create their account and then join “$groupe”.';
  }

  @override
  String groupsRejoinsSurJelvo(String groupe, String url) {
    return 'Join “$groupe” on Jelvo: $url';
  }

  @override
  String groupsInvitationARejoindre(String groupe) {
    return 'Invitation to join $groupe';
  }

  @override
  String groupsUtilisationsExpireLe(String utilisations, String date) {
    return '$utilisations · expires on $date';
  }

  @override
  String groupsAdhesionJusquAu(String date) {
    return 'Membership until $date';
  }

  @override
  String groupsUtilisationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uses',
      one: '$count use',
    );
    return '$_temp0';
  }

  @override
  String groupsUtilisationSurMax(String utilisations, int max) {
    return '$utilisations of $max';
  }

  @override
  String contactsGroupeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '$count group',
    );
    return '$_temp0';
  }

  @override
  String contactsPersonnesSouhaitentVousAjouter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people want to add you',
      one: '$count person wants to add you',
    );
    return '$_temp0';
  }

  @override
  String contactsFaitMaintenantPartie(String nom) {
    return '$nom is now one of your contacts.';
  }

  @override
  String contactsAjoutezMoiSurJelvo(String pseudo) {
    return 'Add me on Jelvo: $pseudo';
  }

  @override
  String contactsNomEtMessage(String nom, String message) {
    return '$nom — $message';
  }

  @override
  String contactsRejoignezMoi(String url) {
    return 'Join me on Jelvo so we can plan our get-togethers: $url';
  }

  @override
  String contactsMonPseudoLigne(String pseudo) {
    return '\nMy username: $pseudo';
  }

  @override
  String contactsRetraitConfirmation(String nom) {
    return '$nom will no longer be one of your contacts, and you will no longer be one of theirs.';
  }

  @override
  String contactsAEteRetire(String nom) {
    return '$nom has been removed.';
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
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String authCodeEnvoyeA(String email) {
    return 'We have sent a six-digit code to $email.';
  }

  @override
  String authFormatPseudo(int min, int max) {
    return 'Lowercase letters, digits and dots, from $min to $max characters.';
  }

  @override
  String availabilityDateEtPlage(String date, String plage) {
    return '$date · $plage';
  }

  @override
  String availabilityDe(String heure) {
    return 'From $heure';
  }

  @override
  String availabilityA(String heure) {
    return 'To $heure';
  }

  @override
  String calendarPuceEtDate(String date) {
    return ' • $date';
  }

  @override
  String calendarRienNeCorrespond(String terme) {
    return 'Nothing matches “$terme”.';
  }

  @override
  String coreSurTotalTexte(int fait, int total) {
    return '$fait of $total';
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
    return '$taille MB';
  }

  @override
  String chatKilooctets(int taille) {
    return '$taille kB';
  }

  @override
  String chatJusquAEnvironUneMinute(String taille) {
    return 'Up to $taille, about a minute';
  }

  @override
  String chatVideoTropLourde(String taille, String max) {
    return 'This video weighs $taille, beyond the $max accepted. Film something shorter, or send it another way.';
  }

  @override
  String chatEcheanceDateHeure(String date, String heure) {
    return 'Due $date at $heure';
  }

  @override
  String groupsInvitationEnAttenteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending invitations',
      one: '$count pending invitation',
    );
    return '$_temp0';
  }

  @override
  String groupsAdhesionTemporaireJusquAu(String date) {
    return 'Temporary membership: until $date.';
  }

  @override
  String groupsAdhesionTemporaireVousFerezPartie(String date) {
    return 'Temporary membership: you will be part of the group until $date.';
  }

  @override
  String groupsCreezIciPartageAvec(String groupe) {
    return 'What you create here will be shared with “$groupe”.';
  }

  @override
  String groupsJusquAu(String date) {
    return 'Until $date';
  }

  @override
  String groupsAdhesionJusquAuPuisDisparait(String date) {
    return 'Membership until $date, after which the group will disappear from their app.';
  }

  @override
  String groupsMembreJusquAu(String nom, String date) {
    return '$nom is part of the group until $date.';
  }

  @override
  String groupsMembreSansTerme(String nom) {
    return '$nom is part of the group with no end date.';
  }

  @override
  String homeTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '$count task',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count events',
      one: ', $count event',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count tasks',
      one: ', $count task',
    );
    return '$_temp0';
  }

  @override
  String notificationsVousConvie(String nom) {
    return '$nom is inviting you.';
  }

  @override
  String notificationsVousConvieAvecGroupe(String nom, String groupe) {
    return '$nom is inviting you with “$groupe”.';
  }

  @override
  String profileVersion(String version) {
    return 'Version $version';
  }

  @override
  String profileRetrouvezMoi(String pseudo, String code) {
    return 'Find me on Jelvo: $pseudo\n$code';
  }

  @override
  String profileVotrePseudo(String pseudo) {
    return 'Your username: $pseudo';
  }

  @override
  String profileRetraitCarnetConfirmation(String nom) {
    return '$nom will no longer appear in your contacts. Your groups in common do not change.';
  }

  @override
  String profileGroupesCommunsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups in common',
      one: '$count group in common',
    );
    return '$_temp0';
  }

  @override
  String tasksEcheanceDate(String date) {
    return 'Due $date';
  }

  @override
  String coreDateAHeure(String date, String heure) {
    return '$date at $heure';
  }

  @override
  String get tasksTerminees => 'Done';

  @override
  String tasksConfieeAuxPersonnes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Given to $count people, who will get a notification.',
      one: 'Given to $count person, who will get a notification.',
    );
    return '$_temp0';
  }

  @override
  String coreDeuxNoms(String premier, String second) {
    return '$premier and $second';
  }

  @override
  String coreDeuxNomsEtAutres(String premier, String second, int reste) {
    String _temp0 = intl.Intl.pluralLogic(
      reste,
      locale: localeName,
      other: '$reste others',
      one: '$reste other',
    );
    return '$premier, $second and $_temp0';
  }

  @override
  String tasksArticlesCoches(int faits, int total) {
    return '$faits of $total items';
  }

  @override
  String tasksPrioriteLabel(String priorite) {
    return '$priorite priority';
  }

  @override
  String navBadgeNonLus(String destination, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '$count unread',
    );
    return '$destination, $_temp0';
  }

  @override
  String get profileLangue => 'Language';

  @override
  String get profileLangueDuTelephone => 'Your phone’s language';

  @override
  String get profileLangueDuTelephoneAide =>
      'Follows the device setting, and English if the language is not offered';

  @override
  String get profileLangueFrancais => 'French';

  @override
  String get profileLangueAllemand => 'German';

  @override
  String get profileLangueAnglais => 'English';

  @override
  String get profileLangueEspagnol => 'Spanish';

  @override
  String get homeBonWeekEnd => 'Have a great weekend';

  @override
  String get coreDebutApresMidi => '12';

  @override
  String get coreDebutSoiree => '18';

  @override
  String get coreDescription => 'Description';

  @override
  String get coreRechercher => 'Search';

  @override
  String get coreProfil => 'Profile';

  @override
  String get coreLieu => 'Location';

  @override
  String get coreAnniversaire => 'Birthday';

  @override
  String get coreAutre => 'Other';

  @override
  String get corePrenom => 'First name';

  @override
  String get coreNom => 'Last name';

  @override
  String get corePseudo => 'Username';

  @override
  String get coreHintPseudo => 'username';

  @override
  String get coreFiltres => 'Filters';

  @override
  String get coreRepetition => 'Repeat';

  @override
  String get coreInvitation => 'Invitation';

  @override
  String get coreInvitations => 'Invitations';

  @override
  String get coreChoisir => 'Choose';

  @override
  String get corePriorite => 'Priority';

  @override
  String get coreDate => 'Date';

  @override
  String get coreHoraires => 'Time';

  @override
  String get coreDisponible => 'Available';

  @override
  String get coreTout => 'All';

  @override
  String get coreAfficher => 'Show';

  @override
  String get coreFin => 'End';

  @override
  String get coreVideo => 'Video';

  @override
  String get coreJoindre => 'Attach';

  @override
  String get coreFilmer => 'Record';

  @override
  String get coreScanner => 'Scan';

  @override
  String get coreResultats => 'Results';

  @override
  String get coreEffacer => 'Clear';

  @override
  String get coreFavoris => 'Favorites';

  @override
  String get coreGerer => 'Manage';

  @override
  String get coreActions => 'Actions';

  @override
  String get coreDiscussion => 'Chat';

  @override
  String get coreInviter => 'Invite';

  @override
  String get coreSuggestions => 'Suggestions';

  @override
  String get corePartager => 'Share';

  @override
  String get coreAdmin => 'Admin';

  @override
  String get coreCommencer => 'Get started';

  @override
  String get coreCompte => 'Account';

  @override
  String get coreDeconnexion => 'Sign out';

  @override
  String get coreJour => 'Day';

  @override
  String get coreMois => 'Month';

  @override
  String get coreEmail => 'Email';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreModifier => 'Edit';

  @override
  String get coreContinuer => 'Continue';

  @override
  String get coreVerifier => 'Verify';

  @override
  String get coreExceptions => 'Exceptions';

  @override
  String get coreEvenements => 'Events';

  @override
  String get coreTaches => 'Tasks';

  @override
  String get coreExemplePrenom => 'Alex';

  @override
  String get coreExempleNom => 'Taylor';

  @override
  String get corePlusDOptions => 'More options';

  @override
  String get profileSupprimerCompte => 'Delete my account';

  @override
  String get profileSuppressionDefinitive =>
      'This deletion is permanent: it cannot be undone.';

  @override
  String get profileSuppressionCeQuiDisparait => 'What disappears';

  @override
  String get profileSuppressionIdentite =>
      'Your name, your username, your email address and your photo';

  @override
  String get profileSuppressionProfil =>
      'Your bio, your birthday and your availability';

  @override
  String get profileSuppressionContacts =>
      'Your contacts, and your pending requests';

  @override
  String get profileSuppressionGroupes =>
      'Your group memberships. If you are the only person administering a group, the longest-standing member takes over.';

  @override
  String get profileSuppressionNotifications =>
      'Your notifications and your subscriptions';

  @override
  String get profileSuppressionVocaux =>
      'Your voice messages, which carry your voice';

  @override
  String get profileSuppressionCeQuiReste => 'What stays';

  @override
  String get profileSuppressionMessages =>
      'Your written messages, signed “Deleted account”, so as not to punch holes in other people’s conversations';

  @override
  String get profileSuppressionMedias =>
      'The photos and videos you have shared';

  @override
  String get profileSuppressionGroupeContenu =>
      'The tasks and events you have created in a group';

  @override
  String get profileSuppressionReinscription =>
      'You will be able to sign up again later with the same address.';

  @override
  String get profileSuppressionMotDePasse => 'Password';

  @override
  String get profileSuppressionMotDePasseAide => 'To confirm it is really you';

  @override
  String get profileSuppressionConfirmer => 'Delete permanently';

  @override
  String get profileSuppressionMotDePasseIncorrect => 'Incorrect password.';

  @override
  String get profileSuppressionEchec =>
      'The deletion did not go through. Your account is intact: try again in a moment.';

  @override
  String get profileSuppressionFaite => 'Your account has been deleted.';

  @override
  String get coreCompteSupprime => 'Deleted account';

  @override
  String get coreMembre => 'Member';

  @override
  String get coreEpingle => 'Pinned';

  @override
  String get coreEpingler => 'Pin';

  @override
  String get coreRouvrir => 'Reopen';

  @override
  String get chatEcouter => 'Play';

  @override
  String get tasksAssignes => 'Assignees';

  @override
  String get tasksPersonnelle => 'Personal';

  @override
  String chatCompteurTaches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tasks',
      one: 'task',
    );
    return '$_temp0';
  }

  @override
  String chatCompteurEvenements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'events',
      one: 'event',
    );
    return '$_temp0';
  }

  @override
  String contactsCompteurGroupes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'groups',
      one: 'group',
    );
    return '$_temp0';
  }

  @override
  String get tasksLibre => 'Free';

  @override
  String get coreIndisponible => 'Unavailable';

  @override
  String get coreInconnu => 'Unknown';

  @override
  String get coreAutres => 'Other';

  @override
  String get coreContact => 'Contact';

  @override
  String get coreDateChoisir => 'Date…';

  @override
  String get chatEmojis => 'Emojis';

  @override
  String get chatEnvoyer => 'Send';

  @override
  String get authRetirerAvatar => 'Remove the avatar';

  @override
  String get groupsRejoindre => 'Join';

  @override
  String get notificationsActivees => 'On';

  @override
  String get notificationsPartielles => 'Partial';

  @override
  String get notificationsDesactivees => 'Off';

  @override
  String get notificationsRefusees => 'Blocked';

  @override
  String get notificationsIndisponibles => 'Unavailable';

  @override
  String get notificationsVoirInvitation => 'View the invitation';

  @override
  String get signalementMotifSpam => 'Spam or advertising';

  @override
  String get signalementMotifHarcelement => 'Harassment';

  @override
  String get signalementMotifHaine => 'Hate speech';

  @override
  String get signalementMotifSexuel => 'Sexual content';

  @override
  String get signalementMotifViolence => 'Violence or threats';

  @override
  String get signalementMotifAutre => 'Something else';

  @override
  String get signalementAideSpam => 'Repeated messages, unsolicited links';

  @override
  String get signalementAideHarcelement =>
      'Persistence, intimidation, repeated mockery';

  @override
  String get signalementAideHaine =>
      'Attack based on origin, religion, gender or orientation';

  @override
  String get signalementAideSexuel => 'Unwanted sexual images or remarks';

  @override
  String get signalementAideViolence => 'Threats, incitement to harm';

  @override
  String get signalementAideAutre => 'Describe it below';

  @override
  String get signalementEnvoye => 'Report sent. It will be reviewed.';

  @override
  String get signalementDejaEnvoye =>
      'You have already reported this, and it is not yet handled.';

  @override
  String get signalementIntrouvable => 'This no longer exists.';

  @override
  String get signalementNonMembre => 'You are not part of this group.';

  @override
  String get signalementSoiMeme => 'You cannot report yourself.';

  @override
  String get signalementMotifInconnu => 'This reason is not recognised.';

  @override
  String get signalementNonConnecte => 'Sign in again to report.';

  @override
  String get signalementNonModerateur =>
      'You do not have access to moderation.';

  @override
  String get signalementMarqueTraite => 'Report handled.';

  @override
  String get signalementRouvert => 'Report reopened.';

  @override
  String get signalementMessageSupprime => 'Message deleted.';

  @override
  String get signalementMessageDejaSupprime =>
      'This message was already deleted.';

  @override
  String get signalementSignaler => 'Report';

  @override
  String get signalementTitreMessage => 'Report this message';

  @override
  String get signalementTitreGroupe => 'Report this group';

  @override
  String get signalementTitreProfil => 'Report this profile';

  @override
  String get signalementConfidentiel =>
      'The person concerned is not notified, and will not know who reported.';

  @override
  String get signalementContenuGarde =>
      'The reported content is copied, so it stays readable even if it is deleted afterwards.';

  @override
  String get signalementCommentaire => 'Details';

  @override
  String get signalementCommentaireAide =>
      'Optional — what helps to understand';

  @override
  String get signalementEnvoyer => 'Send the report';

  @override
  String get signalementChoisirMotif => 'Choose a reason.';

  @override
  String get moderationTitre => 'Reports';

  @override
  String get moderationATraiter => 'To handle';

  @override
  String get moderationTraites => 'Handled';

  @override
  String get moderationVideTitre => 'Nothing to handle';

  @override
  String get moderationVideMessage =>
      'No report is waiting. That is the good news.';

  @override
  String get moderationVideTraitesTitre => 'No handled report';

  @override
  String get moderationVideTraitesMessage =>
      'What you mark as handled will be filed here.';

  @override
  String get moderationCibleMessage => 'Message';

  @override
  String get moderationCibleGroupe => 'Group';

  @override
  String get moderationCibleProfil => 'Profile';

  @override
  String moderationSignalePar(String nom) {
    return 'Reported by $nom';
  }

  @override
  String moderationVise(String nom) {
    return 'About $nom';
  }

  @override
  String moderationDansGroupe(String groupe) {
    return 'In $groupe';
  }

  @override
  String get moderationContenuRecopie => 'Reported content';

  @override
  String get moderationMessageEfface =>
      'This message has been deleted since the report.';

  @override
  String get moderationMediaImage => 'A photo';

  @override
  String get moderationMediaVideo => 'A video';

  @override
  String get moderationMediaAudio => 'A voice message';

  @override
  String get moderationSupprimerMessage => 'Delete the message';

  @override
  String get moderationSupprimerConfirmation =>
      'The bubble closes as “message deleted” for the whole group. The report keeps what had been written.';

  @override
  String get moderationMarquerTraite => 'Mark as handled';

  @override
  String get moderationRouvrir => 'Reopen';

  @override
  String get moderationNote => 'Note';

  @override
  String get moderationNoteAide => 'Optional — what you did';

  @override
  String get moderationAucunLevier =>
      'For a group or a profile, the note is the only lever: neither closing an account nor deleting a group is done from here.';

  @override
  String get profileSignalements => 'Reports';

  @override
  String get moderationIndisponible => 'Reports unavailable';

  @override
  String moderationEnTete(String cible, String motif) {
    return '$cible · $motif';
  }

  @override
  String moderationCitation(String texte) {
    return '“$texte”';
  }

  @override
  String get errorBlocked => 'This person cannot be added.';

  @override
  String get profileBloquer => 'Block';

  @override
  String get profileDebloquer => 'Unblock';

  @override
  String get profileBloques => 'Blocked people';

  @override
  String get blocageTitre => 'Block this person?';

  @override
  String get blocageCeQueCaFait =>
      'They will no longer be able to invite you to a group, add you as a contact, or assign you a task. Your contact link is removed.';

  @override
  String get blocageGroupePartage =>
      'You share a group: they will stay visible there, and the conversation does not change. To stop crossing paths, leave the group.';

  @override
  String get blocageBloque => 'Person blocked.';

  @override
  String get blocageDejaBloque => 'This person is already blocked.';

  @override
  String get blocageDebloque => 'Person unblocked.';

  @override
  String get blocagePasBloque => 'This person was not blocked.';

  @override
  String get blocageSoiMeme => 'You cannot block yourself.';

  @override
  String get blocageIntrouvable => 'This person no longer exists.';

  @override
  String get blocageVideTitre => 'Nobody is blocked';

  @override
  String get blocageVideMessage => 'You can block someone from their profile.';

  @override
  String blocageDepuis(String depuis) {
    return 'Blocked $depuis';
  }

  @override
  String get blocageDebloquerConfirmation =>
      'They will be able to invite you, add you and assign you tasks again. Your contact link does not come back.';

  @override
  String get profileBloqueeCestVous => 'You have blocked this person.';
}
