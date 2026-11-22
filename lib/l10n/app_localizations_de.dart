// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppTextsDe extends AppTexts {
  AppTextsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Jelvo';

  @override
  String get navHome => 'Start';

  @override
  String get navGroups => 'Gruppen';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navContacts => 'Kontakte';

  @override
  String get createNewGroup => 'Neue Gruppe';

  @override
  String get createNewEvent => 'Neuer Termin';

  @override
  String get createAddContact => 'Kontakt hinzufügen';

  @override
  String get createTitle => 'Erstellen';

  @override
  String get createQuestion => 'Was möchtest du erstellen?';

  @override
  String get createIntro =>
      'Wähle eine Art und fülle das Wichtigste aus. Details kannst du später ergänzen.';

  @override
  String get createDetails => 'Details';

  @override
  String get createGroupField => 'Gruppe';

  @override
  String get createPersonalOption => 'Privat – nur für dich sichtbar';

  @override
  String get createPickDate => 'Datum wählen';

  @override
  String get createDueDate => 'Fällig am';

  @override
  String get createTime => 'Uhrzeit';

  @override
  String get createMissingDate => 'Wähle das Datum des Termins.';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonRequiredField => 'Dieses Feld ist erforderlich.';

  @override
  String get commonOptional => 'Optional';

  @override
  String get homeSubtitle => 'Hier ist dein Tag auf einen Blick.';

  @override
  String get homeToday => 'Heute';

  @override
  String get homeNoEventTitle => 'Freier Tag';

  @override
  String get homeNoEventMessage => 'Für heute ist noch nichts geplant.';

  @override
  String get homeSoon => 'Bald fällig';

  @override
  String get homeNothingUrgent => 'Nichts Dringendes';

  @override
  String get homeAllUpToDateTitle => 'Alles erledigt';

  @override
  String get homeAllUpToDateMessage =>
      'In den nächsten 48 Stunden ist keine Aufgabe fällig.';

  @override
  String get homeMyGroups => 'Meine Gruppen';

  @override
  String get homeMostActive => 'Derzeit am aktivsten';

  @override
  String get homeSeeAll => 'Alle ansehen';

  @override
  String homeEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '1 Termin',
      zero: 'Keine Termine',
    );
    return '$_temp0';
  }

  @override
  String homeTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben bald fällig',
      one: '1 Aufgabe bald fällig',
      zero: 'Keine Aufgaben',
    );
    return '$_temp0';
  }

  @override
  String get groupUpcoming => 'Demnächst';

  @override
  String get groupNothingPlanned => 'Nichts geplant';

  @override
  String get groupNoEventTitle => 'Keine Termine';

  @override
  String get groupNoEventMessage =>
      'Schlage der Gruppe ein Datum vor: alle antworten mit ja, vielleicht oder nein.';

  @override
  String get groupProposeDate => 'Datum vorschlagen';

  @override
  String get groupTasksToDo => 'Offene Aufgaben';

  @override
  String get groupNoTaskTitle => 'Keine offenen Aufgaben';

  @override
  String get groupNoTaskMessage =>
      'Teilt auf, was zu tun ist: alle sehen ihren Teil.';

  @override
  String get groupAddTask => 'Aufgabe hinzufügen';

  @override
  String get groupAdd => 'Hinzufügen';

  @override
  String get groupAddToGroup => 'Zur Gruppe hinzufügen';

  @override
  String groupCreationSheetIntro(String name) {
    return 'Was du hier erstellst, wird mit „$name“ geteilt.';
  }

  @override
  String get groupMembers => 'Mitglieder';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
      zero: 'Keine Mitglieder',
    );
    return '$_temp0';
  }

  @override
  String get taskStatusTodo => 'Offen';

  @override
  String get taskStatusDone => 'Erledigt';

  @override
  String get taskStatusOverdue => 'Überfällig';

  @override
  String get taskPriorityLow => 'Niedrig';

  @override
  String get taskPriorityMedium => 'Normal';

  @override
  String get taskPriorityHigh => 'Hoch';

  @override
  String get taskAssigneePending => 'Offen';

  @override
  String get taskAssigneeAccepted => 'Angenommen';

  @override
  String get taskAssigneeDeclined => 'Abgelehnt';

  @override
  String get taskAccept => 'Annehmen';

  @override
  String get taskDecline => 'Ablehnen';

  @override
  String taskListProgress(int checked, int total) {
    return '$checked von $total Punkten';
  }

  @override
  String get eventAnswerYes => 'Ja';

  @override
  String get eventAnswerMaybe => 'Vielleicht';

  @override
  String get eventAnswerNo => 'Nein';

  @override
  String get eventAnswerPending => 'Offen';

  @override
  String get errorGeneric =>
      'Es ist ein Fehler aufgetreten. Versuche es gleich noch einmal.';

  @override
  String get errorNetwork =>
      'Keine Verbindung. Prüfe deinen Internetzugang und versuche es erneut.';

  @override
  String get errorForbidden =>
      'Dir fehlen die nötigen Rechte für diese Aktion.';

  @override
  String get errorNotSaved =>
      'Die Daten konnten nicht gespeichert werden. Versuche es gleich noch einmal.';

  @override
  String get coreAujourdHui => 'Heute';

  @override
  String get coreInstant => 'gerade eben';

  @override
  String coreDateLabelTimeLabel(Object dateLabel, Object timeLabel) {
    return '$dateLabel · $timeLabel';
  }

  @override
  String get coreVoirMembres => 'Alle Mitglieder ansehen';

  @override
  String get corePersonneNom => 'Niemand mit diesem Namen.';

  @override
  String get coreMarquerTacheCommeTerminee => 'Aufgabe als erledigt markieren';

  @override
  String authMessageDiagnosticRaw(Object _message, Object raw) {
    return '$_message\n\n[Diagnose] $raw';
  }

  @override
  String get authEnvoiPhotoEchoueReessayez =>
      'Das Hochladen des Fotos ist fehlgeschlagen. Versuche es gleich noch einmal.';

  @override
  String get authIdentifiantsIncorrectsVerifiezSaisie =>
      'Falsche Anmeldedaten. Prüfe deine Eingabe und versuche es erneut.';

  @override
  String get authAdresseEMailEncore =>
      'Deine E-Mail-Adresse ist noch nicht bestätigt.';

  @override
  String get authAdresseEMailDeja =>
      'Diese E-Mail-Adresse wird bereits verwendet. Melde dich an oder wähle eine andere Adresse.';

  @override
  String get authCodeExpireDemandezNouveau =>
      'Dieser Code ist abgelaufen. Fordere einen neuen an.';

  @override
  String get authCodeIncorrectVerifiezSix =>
      'Falscher Code. Prüfe die sechs Ziffern aus der E-Mail.';

  @override
  String get authTropTentativesPatientezMinute =>
      'Zu viele Versuche. Warte eine Minute, bevor du es erneut versuchst.';

  @override
  String get authMotPasseTropFaible =>
      'Dieses Passwort ist zu schwach. Wähle ein stärkeres.';

  @override
  String get authNouveauMotPasseDoit =>
      'Das neue Passwort muss sich vom alten unterscheiden.';

  @override
  String get authAucunCompteCorrespondInformations =>
      'Kein Konto passt zu diesen Angaben.';

  @override
  String get authSessionExpireReconnectez =>
      'Deine Sitzung ist abgelaufen. Melde dich erneut an.';

  @override
  String get authConnexionEchoueReessayezInstant =>
      'Die Anmeldung ist fehlgeschlagen. Versuche es gleich noch einmal.';

  @override
  String get authPseudoVientEtrePris =>
      'Dieser Benutzername wurde gerade vergeben. Wähle einen anderen.';

  @override
  String get authFonctionnaliteAttendMiseJour =>
      'Diese Funktion wartet auf eine Aktualisierung der Datenbank. Versuche es später erneut oder melde es, wenn es bestehen bleibt.';

  @override
  String get authChoisissezPseudo => 'Wähle einen Benutzernamen.';

  @override
  String authPseudoDoitContenirMoins(Object pseudoMinLength) {
    return 'Der Benutzername muss mindestens $pseudoMinLength Zeichen lang sein.';
  }

  @override
  String authPseudoDoitDepasserPseudoMaxLength(Object pseudoMaxLength) {
    return 'Der Benutzername darf höchstens $pseudoMaxLength Zeichen lang sein.';
  }

  @override
  String get authUniquementMinusculesChiffresPoints =>
      'Nur Kleinbuchstaben, Ziffern und Punkte.';

  @override
  String get authRenseignezAdresseEMail => 'Gib deine E-Mail-Adresse ein.';

  @override
  String get authAdresseEMailSemble =>
      'Diese E-Mail-Adresse sieht unvollständig aus.';

  @override
  String get authChoisissezMotPasse => 'Wähle ein Passwort.';

  @override
  String authMoinsPasswordMinLengthCaracteresNecessaires(
    Object passwordMinLength,
  ) {
    return 'Mindestens $passwordMinLength Zeichen sind erforderlich.';
  }

  @override
  String get authAjoutezMoinsMajuscule =>
      'Füge mindestens einen Großbuchstaben hinzu.';

  @override
  String get authAjoutezMoinsChiffre => 'Füge mindestens eine Ziffer hinzu.';

  @override
  String get authConnexionPseudoEncoreDisponible =>
      'Die Anmeldung mit Benutzernamen ist noch nicht verfügbar. Nutze deine E-Mail-Adresse.';

  @override
  String get authMotPasseOublie => 'Passwort vergessen';

  @override
  String get authIndiquezAdresseEMail =>
      'Gib deine E-Mail-Adresse ein: wir senden dir einen sechsstelligen Code, um ein neues zu wählen.';

  @override
  String get authAdresseEMail => 'E-Mail-Adresse';

  @override
  String get authEnvoyerCode => 'Code senden';

  @override
  String get authContentRevoir => 'Schön, dich wiederzusehen';

  @override
  String get authConnectezRetrouverGroupesAgenda =>
      'Melde dich an, um deine Gruppen und deinen Kalender wiederzufinden.';

  @override
  String get authPseudoAdresseEMail => 'Benutzername oder E-Mail-Adresse';

  @override
  String get authMotPasseOublie2 => 'Passwort vergessen?';

  @override
  String get authConnecter => 'Anmelden';

  @override
  String get authEncoreCompte => 'Noch kein Konto?';

  @override
  String get authInscrire => 'Registrieren';

  @override
  String get authSouvenirMoi => 'Angemeldet bleiben';

  @override
  String get authResterezConnecteJusquDeconnexion =>
      'Du bleibst angemeldet, bis du dich abmeldest.';

  @override
  String get authSerezDeconnecteFermetureApplication =>
      'Du wirst abgemeldet, wenn die App geschlossen wird.';

  @override
  String get authJelvoInstalleEcranAccueil =>
      'Auf dem Startbildschirm installiert hat Jelvo seine eigene Sitzung: die Anmeldung dort ist ein eigener Schritt, getrennt von Safari – auch wenn dieses Kästchen angekreuzt ist.';

  @override
  String get authRenseignezPseudoAdresseE =>
      'Gib deinen Benutzernamen oder deine E-Mail-Adresse ein.';

  @override
  String get authRenseignezMotPasse => 'Gib dein Passwort ein.';

  @override
  String get authNouveauMotPasse => 'Neues Passwort';

  @override
  String get authSaisissezCodeRecuPuis =>
      'Gib den erhaltenen Code ein und wähle dann ein neues Passwort.';

  @override
  String authSaisissezCodeEnvoyeEmail(Object email) {
    return 'Gib den an $email gesendeten Code ein und wähle dann ein neues Passwort.';
  }

  @override
  String get authCodeVerification => 'Bestätigungscode';

  @override
  String get auth8CaracteresMinimum => 'Mindestens 8 Zeichen';

  @override
  String get authChangerMotPasse => 'Passwort ändern';

  @override
  String get authRenvoyerCode => 'Code erneut senden';

  @override
  String get authEnvoiCours => 'Wird gesendet…';

  @override
  String authNouveauCodePossibleSecondsLeft(Object _secondsLeft) {
    return 'Neuer Code möglich in $_secondsLeft s';
  }

  @override
  String get authSaisissezSixChiffresCode =>
      'Gib die sechs Ziffern des Codes ein.';

  @override
  String get authMotPasseEteMis => 'Dein Passwort wurde aktualisiert.';

  @override
  String get authNouveauCodeVientEtre =>
      'Ein neuer Code wurde gerade gesendet.';

  @override
  String get authCreerCompte => 'Konto erstellen';

  @override
  String get authChoisissezPseudoSecurisezCompte =>
      'Wähle einen Benutzernamen und sichere dein Konto.';

  @override
  String get authEtape12 => 'Schritt 1 von 2';

  @override
  String get authCreantCompteAcceptezRecevoir =>
      'Mit der Erstellung eines Kontos stimmst du zu, eine Bestätigungs-E-Mail zu erhalten.';

  @override
  String get authAppelezComment => 'Wie heißt du?';

  @override
  String get authProchesReconnaitrontFacilement =>
      'Deine Angehörigen erkennen dich so leichter.';

  @override
  String get authEtape22 => 'Schritt 2 von 2';

  @override
  String get authCreerCompte2 => 'Mein Konto erstellen';

  @override
  String get authRenseignezPrenom => 'Gib deinen Vornamen ein.';

  @override
  String get authRenseignezNom => 'Gib deinen Nachnamen ein.';

  @override
  String authCompteCreeMaisProfil(Object warning) {
    return 'Konto erstellt, aber das Profil konnte nicht gespeichert werden: $warning';
  }

  @override
  String get authVerifiezEMail => 'Prüfe deine E-Mails';

  @override
  String get authSaisissezCodeSixChiffres =>
      'Gib den sechsstelligen Code ein, den wir dir gerade gesendet haben.';

  @override
  String get authChoisirPhotoProfil => 'Profilbild wählen';

  @override
  String get authOuvertureGalerie => 'Galerie wird geöffnet…';

  @override
  String get authRetirerPhoto => 'Foto entfernen';

  @override
  String get authAjouterPhotoFacultatif => 'Foto hinzufügen (optional)';

  @override
  String get authPhotoPuEtreOuverte =>
      'Das Foto konnte nicht geöffnet werden. Versuche es erneut.';

  @override
  String get authMotPasse => 'Passwort';

  @override
  String get authMotPasse2 => 'Dein Passwort';

  @override
  String get authAfficherMotPasse => 'Passwort anzeigen';

  @override
  String get authMasquerMotPasse => 'Passwort verbergen';

  @override
  String get authMajuscule => 'Ein Großbuchstabe';

  @override
  String get authChiffre => 'Eine Ziffer';

  @override
  String get authPseudoDejaPris => 'Dieser Benutzername ist bereits vergeben.';

  @override
  String get authPseudoDisponible => 'Dieser Benutzername ist frei.';

  @override
  String get authCodeVerificationSixChiffres =>
      'Sechsstelliger Bestätigungscode';

  @override
  String get availabilityChaqueSemaine => 'Jede Woche';

  @override
  String get availabilityDatePrecise => 'Ein bestimmtes Datum';

  @override
  String get availabilityCreneauPuEtreEnregistre =>
      'Das Zeitfenster konnte nicht gespeichert werden. Versuche es gleich noch einmal.';

  @override
  String get availabilityDisponibilites => 'Meine Verfügbarkeit';

  @override
  String get availabilityNouveauCreneau => 'Neues Zeitfenster';

  @override
  String get availabilityDisponibilitesIndisponibles =>
      'Verfügbarkeit nicht abrufbar';

  @override
  String get availabilitySemaineType => 'Meine typische Woche';

  @override
  String get availabilityCreneauxReviennentChaqueSemaine =>
      'Zeitfenster, die jede Woche wiederkehren';

  @override
  String get availabilityAucunCreneauRecurrentRien =>
      'Kein wiederkehrendes Zeitfenster. Ohne Angabe sehen andere dich als „Unbekannt“.';

  @override
  String get availabilityDatePrecisePrimeSemaine =>
      'Ein bestimmtes Datum, das Vorrang vor der typischen Woche hat';

  @override
  String get availabilityAucuneExceptionJourConge =>
      'Keine Ausnahmen. Ein freier Tag oder eine Reise gehört hierhin.';

  @override
  String get availabilityAjouterCreneau => 'Zeitfenster hinzufügen';

  @override
  String get availabilityContactsMembresGroupesVoient =>
      'Deine Kontakte und die Mitglieder deiner Gruppen sehen nur „Verfügbar“, „Nicht verfügbar“ oder „Unbekannt“. Niemals deine Zeiten, niemals den Grund.';

  @override
  String get availabilityModifierCreneau => 'Zeitfenster bearbeiten';

  @override
  String get availabilitySupprimerCreneau => 'Zeitfenster löschen';

  @override
  String get availabilityCreneauSupprime => 'Zeitfenster gelöscht.';

  @override
  String get availabilityCreneauExisteListeVa =>
      'Dieses Zeitfenster gibt es nicht mehr. Die Liste wird aktualisiert.';

  @override
  String get availabilityAjouterCreneau2 => 'Zeitfenster hinzufügen';

  @override
  String get availabilityChoisissezDateCreneau =>
      'Wähle das Datum des Zeitfensters.';

  @override
  String get availabilityFinDoitSuivreDebut =>
      'Das Ende muss nach dem Beginn liegen.';

  @override
  String get availabilityCreneauModifie => 'Zeitfenster geändert.';

  @override
  String get availabilityCreneauAjoute => 'Zeitfenster hinzugefügt.';

  @override
  String get availabilityDisponible => 'Wer ist verfügbar?';

  @override
  String get availabilityHeureChoisieVoyezQu =>
      'Zur gewählten Uhrzeit. Du siehst nur ein Wort, niemals ihre Zeitfenster.';

  @override
  String get availabilityDisponibilitesIndisponiblesInstant =>
      'Die Verfügbarkeit ist derzeit nicht abrufbar.';

  @override
  String get calendarJours => 'Täglich';

  @override
  String get calendarToutesSemaines => 'Wöchentlich';

  @override
  String get calendarToutesDeuxSemaines => 'Alle zwei Wochen';

  @override
  String get calendarMois => 'Monatlich';

  @override
  String get calendarAns => 'Jährlich';

  @override
  String get calendar10MinutesAvant => '10 Minuten vorher';

  @override
  String get calendar1HeureAvant => '1 Stunde vorher';

  @override
  String get calendarVeille => 'Am Tag davor';

  @override
  String get calendar1SemaineAvant => '1 Woche vorher';

  @override
  String calendarMinutesMin(Object minutes) {
    return '$minutes Min.';
  }

  @override
  String get calendarEvenementPuEtreCree =>
      'Der Termin konnte nicht erstellt werden. Versuche es gleich noch einmal.';

  @override
  String get calendarEvenementPuEtreModifie =>
      'Der Termin konnte nicht geändert werden. Versuche es gleich noch einmal.';

  @override
  String get calendarSemainePrecedente => 'Vorige Woche';

  @override
  String get calendarSemaineSuivante => 'Nächste Woche';

  @override
  String get calendarRienFiltres => 'Nichts mit diesen Filtern';

  @override
  String get calendarFiltrePoseJourneeEntiere =>
      'Ein Filter ist gesetzt: der ganze Tag enthält vielleicht noch anderes.';

  @override
  String get calendarNiEvenementNiTache =>
      'Kein Termin, keine Aufgabe und kein angegebenes Zeitfenster für diesen Tag.';

  @override
  String get calendarCreerEvenement => 'Termin erstellen';

  @override
  String get calendarModifierEvenement => 'Termin bearbeiten';

  @override
  String get calendarSupprimerEvenement => 'Termin löschen';

  @override
  String get calendarEvenementIntrouvable => 'Termin nicht gefunden';

  @override
  String get calendarEteSupprimeAvezAcces =>
      'Er wurde gelöscht, oder du hast keinen Zugriff mehr darauf.';

  @override
  String get calendarNonPrecise => 'Nicht angegeben';

  @override
  String get calendarReponse => 'Deine Antwort';

  @override
  String get calendarPersonneEncoreEteConvie =>
      'Es wurde noch niemand eingeladen.';

  @override
  String get calendarEteSupprimeAvezAcces2 =>
      'Er wurde gelöscht, oder du hast keinen Zugriff mehr darauf. Es gibt nichts mehr zu bestätigen.';

  @override
  String get calendarRevenirCalendrier => 'Zurück zum Kalender';

  @override
  String get calendarMembre => 'Ein Mitglied';

  @override
  String get calendarConvieEvenement => 'lädt dich zu einem Termin ein';

  @override
  String get calendarPropos => 'Info';

  @override
  String get calendarCetEvenementDejaEu =>
      'Dieser Termin hat schon stattgefunden.';

  @override
  String get calendarSerez => 'Bist du dabei?';

  @override
  String get calendarVoirDetailEvenement => 'Termindetails ansehen';

  @override
  String get calendarCreneauxDeclaresFondJournee =>
      'Die angegebenen Zeitfenster, als Hintergrund des Tages. Sie gehören zu keiner Gruppe.';

  @override
  String get calendarEvenementTache => 'Ein Termin, eine Aufgabe…';

  @override
  String get calendarDeuxLettresSuffisentChercher =>
      'Zwei Buchstaben genügen für die Suche.';

  @override
  String get calendarTitre => 'Titel *';

  @override
  String get calendarExDejeunerChezCamille => 'Z. B.: Mittagessen bei Camille';

  @override
  String get calendarExPetitComptoir => 'Z. B.: Le Petit Comptoir';

  @override
  String get calendarEffacerLieu => 'Ort löschen';

  @override
  String get calendarQuFautSavoirQu =>
      'Was man wissen muss, was man mitbringen soll';

  @override
  String get calendarInviterMembresGroupe => 'Gruppenmitglieder einladen';

  @override
  String get calendarJelvoPreviendraParticipants =>
      'Jelvo benachrichtigt die Teilnehmenden';

  @override
  String get calendarRendezReguliers => 'Für regelmäßige Treffen';

  @override
  String get calendarEnregistrerModifications => 'Änderungen speichern';

  @override
  String get calendarCreerEvenement2 => 'Termin erstellen';

  @override
  String get calendarDate => 'Datum *';

  @override
  String get calendarHeure => 'Uhrzeit *';

  @override
  String get calendarMembres => 'Alle Mitglieder';

  @override
  String get calendarSelectionMembresGroupeConvies =>
      'Ohne Auswahl werden alle Mitglieder der Gruppe eingeladen.';

  @override
  String get calendarDonnezTitreEvenement => 'Gib dem Termin einen Titel.';

  @override
  String get calendarEvenementEteModifie => 'Der Termin wurde geändert.';

  @override
  String calendarEvenementTitreEteCree(Object titre) {
    return 'Der Termin „$titre“ wurde erstellt.';
  }

  @override
  String get calendarQuelGroupe => 'In welcher Gruppe? *';

  @override
  String get calendarSeulVerrez => 'Nur du siehst ihn';

  @override
  String get calendarQuelGroupe2 => 'In welcher Gruppe?';

  @override
  String chatMoMo(Object mo) {
    return '$mo MB';
  }

  @override
  String chatOuiOui(Object oui) {
    return '$oui Ja';
  }

  @override
  String chatPeutEtrePeutEtre(Object peutEtre) {
    return '$peutEtre Vielleicht';
  }

  @override
  String chatNonNon(Object non) {
    return '$non Nein';
  }

  @override
  String get chatAucuneReponse => 'Keine Antwort';

  @override
  String get chatQuelqu => 'Jemand';

  @override
  String get chatMessagePuEtreEnvoye =>
      'Die Nachricht konnte nicht gesendet werden. Versuche es gleich noch einmal.';

  @override
  String get chatConversationIndisponible => 'Unterhaltung nicht verfügbar';

  @override
  String get chatRienEncore => 'Noch nichts';

  @override
  String get chatLancezConversationPersonneEncore =>
      'Starte die Unterhaltung: hier hat noch niemand geschrieben.';

  @override
  String chatReagirEmoji(Object emoji) {
    return 'Mit $emoji reagieren';
  }

  @override
  String get chatSupprimerMessage => 'Nachricht löschen';

  @override
  String get chatPouvezSupprimerMessages =>
      'Du kannst nur deine eigenen Nachrichten löschen';

  @override
  String get chatMessageSupprime => 'Nachricht gelöscht.';

  @override
  String get chatMessagePeutEtreSupprime =>
      'Diese Nachricht kann nicht mehr gelöscht werden.';

  @override
  String get chatNouvelleTache => 'Neue Aufgabe';

  @override
  String get chatCreerTacheFaire => 'Eine Aufgabe erstellen';

  @override
  String get chatPlanifierEvenement => 'Einen Termin planen';

  @override
  String get chatPhotoVideo => 'Foto oder Video';

  @override
  String get chatEnvoyerMedia => 'Medien senden';

  @override
  String get chatRienPrevuInstant => 'Derzeit nichts geplant';

  @override
  String get chatPhotoGalerie => 'Foto aus der Galerie';

  @override
  String get chatPrendrePhoto => 'Foto aufnehmen';

  @override
  String get chatVideoGalerie => 'Video aus der Galerie';

  @override
  String get chatMediaPuEtreLu =>
      'Diese Datei konnte nicht gelesen werden. Versuche es erneut.';

  @override
  String get chatNonEnvoyeReessayer => 'Nicht gesendet – erneut versuchen';

  @override
  String get chatMessageSupprime2 => 'Nachricht gelöscht';

  @override
  String get chatTacheEteSupprimee => 'Diese Aufgabe wurde gelöscht.';

  @override
  String get chatDesister => 'Zurückziehen';

  @override
  String get chatProposeeGroupePersonneEncore =>
      'Der Gruppe angeboten – noch hat sie niemand übernommen.';

  @override
  String get chatCetEvenementEteSupprime => 'Dieser Termin wurde gelöscht.';

  @override
  String get chatTresBienTacheReste =>
      'In Ordnung – die Aufgabe bleibt der Gruppe angeboten.';

  @override
  String get chatMicrophoneAccessibleAutorisezReglages =>
      'Das Mikrofon ist nicht zugänglich. Erlaube es in den Einstellungen deines Browsers und öffne die Unterhaltung erneut.';

  @override
  String get chatAjouterConversation => 'Zur Unterhaltung hinzufügen';

  @override
  String get chatMessage => 'Deine Nachricht';

  @override
  String get chatFermerEmojis => 'Emojis schließen';

  @override
  String get chatEnregistrerMessageVocal => 'Sprachnachricht aufnehmen';

  @override
  String get chatAnnulerEnregistrement => 'Aufnahme abbrechen';

  @override
  String get chatEnregistrement => 'Aufnahme…';

  @override
  String get chatEnvoyerMessageVocal => 'Sprachnachricht senden';

  @override
  String get chatPlusieursPersonnesTrainEcrire => 'Mehrere Personen schreiben…';

  @override
  String get chatMettrePause => 'Pause';

  @override
  String get contactsDemandeEnvoyee => 'Anfrage gesendet.';

  @override
  String get contactsPersonneFaitDejaPartie =>
      'Diese Person ist schon einer deiner Kontakte.';

  @override
  String get contactsDemandeDejaAttente => 'Eine Anfrage ist bereits offen.';

  @override
  String get contactsPouvezAjouterMeme =>
      'Du kannst dich nicht selbst hinzufügen.';

  @override
  String get contactsQRCode => 'Mein QR-Code';

  @override
  String get contactsCherchezPseudo => 'Nach einem Benutzernamen suchen';

  @override
  String get contactsSaisissezMoinsDeuxCaracteres =>
      'Gib mindestens zwei Zeichen ein, um jemanden zu finden, oder scanne den QR-Code.';

  @override
  String get contactsRechercheIndisponible => 'Suche nicht verfügbar';

  @override
  String get contactsAucunResultat => 'Keine Ergebnisse';

  @override
  String contactsAucunPseudoCommenceTerm(Object term) {
    return 'Kein Benutzername beginnt mit „$term“.';
  }

  @override
  String get contactsDejaCarnet => 'Schon in den Kontakten';

  @override
  String get contactsContacts => 'Meine Kontakte';

  @override
  String get contactsRechercherContact => 'Kontakt suchen';

  @override
  String get contactsDemandesRecues => 'Erhaltene Anfragen';

  @override
  String get contactsCarnetIndisponible => 'Kontakte nicht verfügbar';

  @override
  String get contactsCarnetVide => 'Keine Kontakte';

  @override
  String get contactsAjoutezProchesLeurPseudo =>
      'Füge deine Angehörigen über ihren Benutzernamen hinzu oder scanne ihren QR-Code, um gemeinsam zu planen.';

  @override
  String contactsAucunContactCorrespondQuery(Object query) {
    return 'Kein Kontakt passt zu „$query“.';
  }

  @override
  String get contactsDemandeRefusee => 'Anfrage abgelehnt.';

  @override
  String get contactsFaitesScannerCodeEtre =>
      'Lass diesen Code scannen, um als Kontakt hinzugefügt zu werden. Er enthält nur deinen Benutzernamen – keine E-Mail-Adresse, keinen Kalender.';

  @override
  String get contactsPartagerPseudo => 'Meinen Benutzernamen teilen';

  @override
  String get contactsPseudoJelvo => 'Mein Jelvo-Benutzername';

  @override
  String get contactsScannerQRCode => 'QR-Code scannen';

  @override
  String get contactsScanIndisponibleIci => 'Scannen hier nicht verfügbar';

  @override
  String get contactsChercherPseudo => 'Nach Benutzernamen suchen';

  @override
  String get contactsCameraInaccessible => 'Kamera nicht zugänglich';

  @override
  String get contactsAutorisezAccesCameraScanner =>
      'Erlaube den Kamerazugriff, um einen QR-Code zu scannen.';

  @override
  String get contactsVisezQRCodeProche =>
      'Richte die Kamera auf den QR-Code einer Person, um ihr eine Kontaktanfrage zu senden.';

  @override
  String get contactsQRCodeProfilJelvo =>
      'Dieser QR-Code ist kein Jelvo-Profil.';

  @override
  String contactsAucunComptePortePseudo(Object pseudo) {
    return 'Kein Konto trägt den Benutzernamen @$pseudo.';
  }

  @override
  String get contactsScannerQRCode2 => 'QR-Code scannen';

  @override
  String get contactsAjouterContactQRCode => 'Kontakt per QR-Code hinzufügen';

  @override
  String get contactsRechercherPseudo => 'Benutzernamen suchen';

  @override
  String get contactsTrouverUtilisateurJelvo =>
      'Eine Jelvo-Nutzerin oder einen Nutzer finden';

  @override
  String get contactsInviterAmi => 'Freund einladen';

  @override
  String get contactsEnvoyerInvitationJelvo => 'Jelvo-Einladung senden';

  @override
  String get contactsRejoignezMoiJelvo => 'Komm zu mir auf Jelvo';

  @override
  String get contactsRetirerFavoris => 'Aus Favoriten entfernen';

  @override
  String get contactsAjouterFavoris => 'Zu Favoriten hinzufügen';

  @override
  String get contactsFavorisTeteCarnet =>
      'Favoriten stehen oben in deinen Kontakten';

  @override
  String get contactsRetirerContacts => 'Aus meinen Kontakten entfernen';

  @override
  String get contactsRelationSupprimeeDeuxCotes =>
      'Die Verbindung wird auf beiden Seiten gelöscht';

  @override
  String get contactsRetirerContact => 'Diesen Kontakt entfernen';

  @override
  String get contactsGererFavoris => 'Favoriten verwalten';

  @override
  String get contactsFavoriPersonnelAutreSait =>
      'Der Favorit ist privat: die andere Person erfährt nichts davon.';

  @override
  String get contactsAjoutezAbordContactsEpingler =>
      'Füge erst Kontakte hinzu, die du anpinnen kannst.';

  @override
  String get contactsEpinglezProchesRetrouverIci =>
      'Pinne deine Angehörigen an, um sie hier wiederzufinden.';

  @override
  String get contactsScanQRCodeDemande =>
      'Zum Scannen eines QR-Codes braucht es eine Kamera: das geht in der mobilen App. Hier kannst du die Person über ihren Benutzernamen suchen.';

  @override
  String get createCreneauAgendaSeulPartage =>
      'Ein Zeitfenster in deinem Kalender, allein oder geteilt';

  @override
  String get createActionFaireEcheanceResponsable =>
      'Etwas zu tun, mit Frist und Zuständigkeit';

  @override
  String get createEspacePartageProchesAmis =>
      'Ein geteilter Ort für Familie oder Freunde';

  @override
  String get createChoisissezTypeFormulaireOuvre =>
      'Wähle eine Art: das Formular öffnet sich direkt darunter.';

  @override
  String get groupsLienInvitationExisteValable =>
      'Dieser Einladungslink existiert nicht oder ist nicht mehr gültig.';

  @override
  String get groupsLienInvitationExpireDemandez =>
      'Dieser Einladungslink ist abgelaufen. Bitte die Gruppe um einen neuen.';

  @override
  String get groupsLienInvitationEteRevoque =>
      'Die Gruppe hat diesen Einladungslink widerrufen.';

  @override
  String get groupsLienDejaServiNombre =>
      'Dieser Link wurde schon so oft genutzt wie vorgesehen.';

  @override
  String get groupsAvezRejointGroupe => 'Du bist der Gruppe beigetreten.';

  @override
  String get groupsFaitesDejaPartieGroupe =>
      'Du gehörst dieser Gruppe schon an.';

  @override
  String get groupsLienInvitationExpire =>
      'Dieser Einladungslink ist abgelaufen.';

  @override
  String get groupsLienInvitationEteRevoque2 =>
      'Dieser Einladungslink wurde widerrufen.';

  @override
  String get groupsConnectezRejoindreGroupe =>
      'Melde dich an, um dieser Gruppe beizutreten.';

  @override
  String get groupsAvezQuitteGroupe => 'Du hast die Gruppe verlassen.';

  @override
  String get groupsAvezQuitteGroupeAncien =>
      'Du hast die Gruppe verlassen. Das dienstälteste Mitglied wird Admin.';

  @override
  String get groupsEtiezDernierMembreGroupe =>
      'Du warst das letzte Mitglied: die Gruppe wurde gelöscht.';

  @override
  String get groupsFaitesPartieGroupe => 'Du gehörst dieser Gruppe nicht an.';

  @override
  String groupsNomDesormaisAdministrateur(Object nom) {
    return '$nom ist jetzt Administrator.';
  }

  @override
  String groupsNomAdministrateur(Object nom) {
    return '$nom ist kein Administrator mehr.';
  }

  @override
  String groupsNomEteRetireGroupe(Object nom) {
    return '$nom wurde aus der Gruppe entfernt.';
  }

  @override
  String groupsAdhesionNomDesormaisTemporaire(Object nom) {
    return 'Die Mitgliedschaft von $nom ist jetzt befristet.';
  }

  @override
  String groupsNomFaitPartieGroupe(Object nom, Object terme) {
    return '$nom gehört der Gruppe bis zum $terme an.';
  }

  @override
  String groupsAdhesionNomTerme(Object nom) {
    return 'Die Mitgliedschaft von $nom hat kein Enddatum mehr.';
  }

  @override
  String get groupsEtaitDejaCasRien =>
      'Das war schon so, es hat sich nichts geändert.';

  @override
  String get groupsDateDejaPasseeDepart =>
      'Dieses Datum liegt in der Vergangenheit. Für einen sofortigen Austritt nutze „Aus der Gruppe entfernen“.';

  @override
  String groupsNomDejaAdministrateur(Object nom) {
    return '$nom ist schon Administrator.';
  }

  @override
  String get groupsGroupeDoitGarderMoins =>
      'Eine Gruppe braucht mindestens einen Administrator. Benenne vorher jemand anderen.';

  @override
  String get groupsSeulAdministrateurGroupePeut =>
      'Das kann nur ein Administrator der Gruppe.';

  @override
  String groupsNomAdministrateur2(Object nom) {
    return '$nom ist kein Administrator.';
  }

  @override
  String groupsNomFaitPartieGroupe2(Object nom) {
    return '$nom gehört der Gruppe nicht mehr an.';
  }

  @override
  String get groupsPartirMemeUtilisezQuitter =>
      'Um selbst zu gehen, nutze „Gruppe verlassen“.';

  @override
  String get groupsActionAboutiReessayezInstant =>
      'Die Aktion ist nicht durchgegangen. Versuche es gleich noch einmal.';

  @override
  String get groupsJamaisUtilise => 'Noch nie genutzt';

  @override
  String get groupsInvitationDejaAcceptee => 'Einladung schon angenommen';

  @override
  String get groupsInvitationDejaRefusee => 'Einladung schon abgelehnt';

  @override
  String get groupsInvitationExpiree => 'Einladung abgelaufen';

  @override
  String get groupsEtesDejaMembre => 'Du bist schon Mitglied';

  @override
  String get groupsGroupeSupprime => 'Gruppe gelöscht';

  @override
  String get groupsInvitationIntrouvable => 'Einladung nicht gefunden';

  @override
  String get groupsAvezDejaRejointGroupe =>
      'Du bist dieser Gruppe schon beigetreten. Öffne sie, um ihre Termine, Aufgaben und Unterhaltung zu finden.';

  @override
  String get groupsAvezDeclineInvitationDemandez =>
      'Du hast diese Einladung abgelehnt. Bitte um eine neue, falls du es dir anders überlegst.';

  @override
  String get groupsInvitationPasseDateLimite =>
      'Die Frist dieser Einladung ist abgelaufen. Bitte die Gruppe um eine neue.';

  @override
  String get groupsFaitesDejaPartieGroupe2 =>
      'Du gehörst dieser Gruppe schon an, wohl über einen geteilten Link.';

  @override
  String get groupsGroupeInvitaitEteSupprime =>
      'Die Gruppe, die dich eingeladen hat, wurde gelöscht. Es gibt nichts mehr beizutreten.';

  @override
  String get groupsInvitationExisteEtaitDestinee =>
      'Diese Einladung existiert nicht oder war nicht für dich gedacht.';

  @override
  String get groupsGroupe => 'diese Gruppe';

  @override
  String get groupsGroupePuEtreCree =>
      'Die Gruppe konnte nicht erstellt werden. Versuche es gleich noch einmal.';

  @override
  String get groupsGroupeIndisponible => 'Gruppe nicht verfügbar';

  @override
  String get groupsGroupeIntrouvable => 'Gruppe nicht gefunden';

  @override
  String get groupsGroupeEteSupprimeFaites =>
      'Diese Gruppe wurde gelöscht, oder du gehörst ihr nicht mehr an.';

  @override
  String get groupsRevenirGroupes => 'Zurück zu den Gruppen';

  @override
  String get groupsInviterQuelqu => 'Jemanden einladen';

  @override
  String get groupsPartagerLien => 'Link teilen';

  @override
  String get groupsModifierGroupe => 'Gruppe bearbeiten';

  @override
  String get groupsQuitterGroupe => 'Gruppe verlassen';

  @override
  String get groupsSupprimerGroupe => 'Gruppe löschen';

  @override
  String get groupsAucunMembreAfficher => 'Keine Mitglieder zum Anzeigen';

  @override
  String get groupsListeMembresPuEtre =>
      'Die Mitgliederliste konnte nicht geladen werden. Versuche es gleich noch einmal.';

  @override
  String get groupsVoir => 'Alle ansehen';

  @override
  String get groupsAjouterEvenement => 'Termin hinzufügen';

  @override
  String get groupsTachesPrioritaires => 'Vordringliche Aufgaben';

  @override
  String get groupsRetirerMembre => 'Dieses Mitglied entfernen';

  @override
  String get groupsGroupeEteSupprime => 'Die Gruppe wurde gelöscht.';

  @override
  String get groupsDecrivezGroupePhrase =>
      'Beschreibe diese Gruppe in einem Satz.';

  @override
  String get groupsInviterMembre => 'Mitglied einladen';

  @override
  String get groupsCherchezPersonnePseudoRecevra =>
      'Suche die Person über ihren Benutzernamen. Sie erhält eine Einladung zum Annehmen.';

  @override
  String groupsNameRecuInvitation(Object name) {
    return '$name hat deine Einladung erhalten.';
  }

  @override
  String groupsNameFaitDejaPartie(Object name) {
    return '$name gehört der Gruppe schon an.';
  }

  @override
  String groupsNameDejaInvitationAttente(Object name) {
    return '$name hat schon eine offene Einladung.';
  }

  @override
  String get groupsDateFinChoisieDeja =>
      'Das gewählte Enddatum liegt in der Vergangenheit.';

  @override
  String get groupsSeulAdministrateurPeutFixer =>
      'Nur ein Administrator kann eine Mitgliedsdauer festlegen.';

  @override
  String get groupsSeulsMembresGroupePeuvent =>
      'Nur Mitglieder der Gruppe können einladen.';

  @override
  String get groupsSaisissezMoinsDeuxCaracteres =>
      'Gib mindestens zwei Zeichen ein.';

  @override
  String get groupsCreezGroupeInvitezPremiers =>
      'Erstelle deine Gruppe und lade die ersten Mitglieder ein.';

  @override
  String get groupsPhotoGroupe => 'Gruppenfoto';

  @override
  String get groupsNomGroupe => 'Gruppenname *';

  @override
  String get groupsExFamilleRousseau => 'Z. B.: Familie Rousseau';

  @override
  String get groupsDescriptionOptionnelle => 'Beschreibung (optional)';

  @override
  String get groupsDecrivezBrievementButGroupe =>
      'Beschreibe kurz, wofür diese Gruppe da ist';

  @override
  String get groupsCreerGroupe => 'Gruppe erstellen';

  @override
  String get groupsDonnezNomGroupe => 'Gib deiner Gruppe einen Namen.';

  @override
  String groupsNomDoitDepasserNameMaxLength(Object _nameMaxLength) {
    return 'Der Name darf höchstens $_nameMaxLength Zeichen lang sein.';
  }

  @override
  String get groupsGroupeCree1Invitation =>
      'Gruppe erstellt, 1 Einladung gesendet.';

  @override
  String groupsGroupeCreeEnvoyeesInvitations(Object envoyees) {
    return 'Gruppe erstellt, $envoyees Einladungen gesendet.';
  }

  @override
  String get groupsGroupeCreeMaisInvitation =>
      'Gruppe erstellt, aber die Einladung konnte nicht gesendet werden.';

  @override
  String groupsGroupeCreeMaisAucune(Object echecs) {
    return 'Gruppe erstellt, aber keine der $echecs Einladungen konnte gesendet werden.';
  }

  @override
  String groupsGroupeCreeEnvoyeesInvitation(Object envoyees, Object echecs) {
    return 'Gruppe erstellt, $envoyees Einladung(en) gesendet, $echecs nicht gesendet.';
  }

  @override
  String get groupsGroupePrive => 'Private Gruppe';

  @override
  String get groupsSeulsMembresInvitesPourront =>
      'Nur eingeladene Mitglieder können beitreten und die Inhalte sehen. Alle Jelvo-Gruppen sind privat.';

  @override
  String get groupsRechercherGroupe => 'Gruppe suchen';

  @override
  String get groupsEffacerRecherche => 'Suche löschen';

  @override
  String get groupsGroupesIndisponibles => 'Gruppen nicht verfügbar';

  @override
  String get groupsAucunGroupeMoment => 'Noch keine Gruppen';

  @override
  String get groupsCreezGroupePartagerAgenda =>
      'Erstelle eine Gruppe, um einen Kalender zu teilen und Aufgaben mit deinen Angehörigen aufzuteilen.';

  @override
  String get groupsCreerGroupe2 => 'Gruppe erstellen';

  @override
  String get groupsAucunGroupeNom => 'Keine Gruppe mit diesem Namen';

  @override
  String groupsAucunGroupesCorrespondTerme(Object terme) {
    return 'Keine deiner Gruppen passt zu „$terme“.';
  }

  @override
  String get groupsInviteRejoindreGroupe =>
      'Du wurdest in eine Gruppe eingeladen.';

  @override
  String get groupsInvitationsIndisponibles => 'Einladungen nicht verfügbar';

  @override
  String get groupsAucuneInvitation => 'Keine Einladungen';

  @override
  String get groupsQuandProcheInviteraGroupe =>
      'Wenn dich jemand in eine Gruppe einlädt, erscheint die Einladung hier.';

  @override
  String get groupsInvitationIndisponible => 'Einladung nicht verfügbar';

  @override
  String get groupsInviteRejoindreGroupe2 => 'lädt dich in eine Gruppe ein';

  @override
  String get groupsCree => 'Erstellt am';

  @override
  String get groupsDejaGroupe => 'Schon in der Gruppe';

  @override
  String get groupsInvitationRefusee => 'Einladung abgelehnt.';

  @override
  String get groupsOuvrirGroupe => 'Gruppe öffnen';

  @override
  String get groupsLienInutilisable => 'Link nicht nutzbar';

  @override
  String get groupsRevenirAccueil => 'Zurück zum Start';

  @override
  String get groupsEtesInviteRejoindreGroupe =>
      'Du bist eingeladen, dieser Gruppe auf Jelvo beizutreten.';

  @override
  String get groupsRejoindreGroupe => 'Gruppe beitreten';

  @override
  String get groupsCreerCompteRejoindre => 'Konto erstellen und beitreten';

  @override
  String get groupsAiDejaCompte => 'Ich habe schon ein Konto';

  @override
  String get groupsGroupeSeraRejointAutomatiquement =>
      'Du trittst der Gruppe automatisch bei, sobald dein Konto erstellt ist.';

  @override
  String get groupsCreezIciSeraPartage =>
      'Was du hier erstellst, wird mit der Gruppe geteilt.';

  @override
  String get groupsDateProposerMembres =>
      'Ein Datum, das du den Mitgliedern vorschlägst';

  @override
  String get groupsQuelqueChoseFaireRepartir => 'Etwas zu tun, zum Aufteilen';

  @override
  String get groupsAjouterMembres => 'Mitglieder hinzufügen';

  @override
  String get groupsChoisirContacts => 'Aus meinen Kontakten wählen';

  @override
  String get groupsParcourirCarnetJelvo => 'Meine Jelvo-Kontakte durchsehen';

  @override
  String get groupsInviterLien => 'Per Link einladen';

  @override
  String get groupsProposeApresCreation => 'Wird nach dem Erstellen angeboten';

  @override
  String get groupsPartagerLienInvitation => 'Einladungslink teilen';

  @override
  String get groupsInvitationsPartentCreationGroupe =>
      'Die Einladungen gehen beim Erstellen der Gruppe raus.';

  @override
  String get groupsAucunContactNom => 'Kein Kontakt mit diesem Namen.';

  @override
  String get groupsPersonneInviteInstant => 'Derzeit ist niemand eingeladen.';

  @override
  String get groups1PersonneSeraInvitee => '1 Person wird eingeladen.';

  @override
  String groupsNombrePersonnesSerontInvitees(Object nombre) {
    return '$nombre Personen werden eingeladen.';
  }

  @override
  String get groupsRetirer => 'Alle entfernen';

  @override
  String get groupsCarnetVideInstantPourrez =>
      'Deine Kontakte sind noch leer. Du kannst später über den Gruppenbildschirm, einen geteilten Link oder den Benutzernamen einladen.';

  @override
  String get groupsChoisirPhotoGroupe => 'Gruppenfoto wählen';

  @override
  String get groupsChangerPhoto => 'Foto ändern';

  @override
  String get groupsAjouterPhoto => 'Foto hinzufügen';

  @override
  String get groupsTachesNenRetard => 'Aufgaben\nüberfällig';

  @override
  String get groupsEvenementsNaVenir => 'Termine\ndemnächst';

  @override
  String get groupsAucunLienActifMoment => 'Derzeit kein aktiver Link.';

  @override
  String get groupsDureeAccordeeProchainLien =>
      'Dauer, die der nächste Link gewährt';

  @override
  String get groupsGenererLien => 'Link erzeugen';

  @override
  String get groupsGenererAutreLien => 'Weiteren Link erzeugen';

  @override
  String get groupsLienCopiePressePapiers =>
      'Link in die Zwischenablage kopiert.';

  @override
  String get groupsCopierLien => 'Link kopieren';

  @override
  String get groupsRevoquerLien => 'Link widerrufen';

  @override
  String get groupsGererMembre => 'Dieses Mitglied verwalten';

  @override
  String get groupsRetirerRoleAdministrateur => 'Administratorrolle entziehen';

  @override
  String get groupsNommerAdministrateur => 'Zum Administrator machen';

  @override
  String get groupsModifierDureeAdhesion => 'Mitgliedsdauer ändern';

  @override
  String get groupsRendreAdhesionTemporaire => 'Mitgliedschaft befristen';

  @override
  String get groupsRetirerGroupe => 'Aus der Gruppe entfernen';

  @override
  String get groupsDureeAdhesion => 'Mitgliedsdauer';

  @override
  String get groupsTerme => 'Ohne Enddatum';

  @override
  String get groupsFinAdhesion => 'Ende der Mitgliedschaft';

  @override
  String get groupsNouvelleDuree => 'Neue Dauer';

  @override
  String get homeBonApresMidi => 'Guten Tag';

  @override
  String get homeCreezGroupePartagerAgenda =>
      'Erstelle eine Gruppe, um Kalender, Aufgaben und eine Unterhaltung zu teilen.';

  @override
  String homeBasePrenom(Object base, Object prenom) {
    return '$base, $prenom';
  }

  @override
  String get homeAgenda => 'Mein Tag';

  @override
  String get homeVoirCalendrier => 'Kalender ansehen';

  @override
  String get homeVoirAgenda1 => 'Meinen ganzen Tag ansehen (1 weiterer)';

  @override
  String homeVoirAgendaReste(Object reste) {
    return 'Meinen ganzen Tag ansehen ($reste weitere)';
  }

  @override
  String get homeTaches => 'Meine Aufgaben';

  @override
  String get homeVoirToutesTaches => 'Alle meine Aufgaben ansehen';

  @override
  String get home1Tache => '1 Aufgabe';

  @override
  String get homeSemaine => 'diese Woche';

  @override
  String get homeTraiter => 'zu erledigen';

  @override
  String get homeAucuneTacheAttendEtre => 'Keine Aufgabe wartet auf dich.';

  @override
  String get homeDejaAgenda => 'Schon in deinem Tag';

  @override
  String get homeTachesJourFigurentChronologie =>
      'Deine Aufgaben für heute stehen oben in der Zeitleiste.';

  @override
  String homeValeurLibelleDetail(Object valeur, Object libelle, Object detail) {
    return '$valeur $libelle, $detail';
  }

  @override
  String homeValeurLibelle(Object valeur, Object libelle) {
    return '$valeur $libelle';
  }

  @override
  String get homeAujourdHui => ', heute';

  @override
  String get homeRienPrevu => ', nichts geplant';

  @override
  String get notificationsGroupe => 'eine Gruppe';

  @override
  String get notificationsContact => 'Ein Kontakt';

  @override
  String get notificationsEvenement => 'ein Termin';

  @override
  String get notificationsTache => 'eine Aufgabe';

  @override
  String notificationsInvitationRejoindreGroupName(Object groupName) {
    return 'Einladung zu $groupName';
  }

  @override
  String get notificationsDemandeContact => 'Kontaktanfrage';

  @override
  String notificationsSenderNameInviteRejoindreGroupName(
    Object senderName,
    Object groupName,
  ) {
    return '$senderName lädt dich zu „$groupName“ ein.';
  }

  @override
  String notificationsSenderNameSouhaiteAjouterContacts(Object senderName) {
    return '$senderName möchte dich zu den Kontakten hinzufügen.';
  }

  @override
  String notificationsSenderNameConfieTache(Object senderName) {
    return '$senderName hat dir diese Aufgabe übertragen.';
  }

  @override
  String notificationsSenderNameAccepteTache(Object senderName) {
    return '$senderName nimmt diese Aufgabe an.';
  }

  @override
  String notificationsSenderNameDeclineTache(Object senderName) {
    return '$senderName lehnt diese Aufgabe ab.';
  }

  @override
  String get notificationsFeteAnniversaireAujourdHui => 'hat heute Geburtstag.';

  @override
  String get notificationsAvezNouvelleNotification =>
      'Du hast eine neue Benachrichtigung.';

  @override
  String get notificationsVoirDemande => 'Anfrage ansehen';

  @override
  String get notificationsVoirEvenement => 'Termin ansehen';

  @override
  String get notificationsVoirTache => 'Aufgabe ansehen';

  @override
  String get notificationsGroupesDiscussions => 'Gruppen und Unterhaltungen';

  @override
  String get notificationsTachesRappels => 'Aufgaben und Erinnerungen';

  @override
  String get notificationsMarquerCommeLu => 'Alle gelesen';

  @override
  String get notificationsNotificationsIndisponibles =>
      'Benachrichtigungen nicht verfügbar';

  @override
  String get notificationsAucuneNotification => 'Keine Benachrichtigungen';

  @override
  String get notificationsInvitationsGroupeDemandesContact =>
      'Gruppeneinladungen und Kontaktanfragen erscheinen hier.';

  @override
  String get notificationsNotificationsPush => 'Push-Benachrichtigungen';

  @override
  String get notificationsInstaller => 'Zu installieren';

  @override
  String get notificationsActiverNotifications =>
      'Benachrichtigungen aktivieren';

  @override
  String get notificationsDesactiverCetAppareil =>
      'Auf diesem Gerät deaktivieren';

  @override
  String get notificationsNotificationsActives => 'Benachrichtigungen aktiv';

  @override
  String get notificationsNotificationsRefusees =>
      'Benachrichtigungen abgelehnt';

  @override
  String get notificationsInstallezJelvoRecevoir =>
      'Installiere Jelvo, um sie zu erhalten';

  @override
  String get notificationsNotificationsDesactivees => 'Benachrichtigungen aus';

  @override
  String get notificationsNotificationsIndisponiblesIci =>
      'Benachrichtigungen hier nicht verfügbar';

  @override
  String get notificationsCetAppareilRecevraNotifications =>
      'Dieses Gerät erhält die Benachrichtigungen, die du in den Einstellungen angekreuzt lässt.';

  @override
  String get notificationsAvezRefuseAutorisationApplication =>
      'Du hast die Erlaubnis abgelehnt. Die App kann sie nicht erneut anfragen: sie lässt sich in den Einstellungen deines Browsers wieder öffnen, in der Zeile „Benachrichtigungen“ der Website.';

  @override
  String get notificationsIPhoneIPadNotificationsExistent =>
      'Auf iPhone und iPad gibt es Benachrichtigungen nur in Jelvo, wenn es dem Startbildschirm hinzugefügt wurde. In einem Safari-Tab bietet das System sie gar nicht an.';

  @override
  String get notificationsNavigateurDemanderaAutorisationPourrez =>
      'Dein Browser fragt dich nach der Erlaubnis. Du kannst sie jederzeit wieder ändern.';

  @override
  String get notificationsVersionApplicationGereNotifications =>
      'Diese Version der App unterstützt keine Systembenachrichtigungen.';

  @override
  String get notificationsAutorisationRefuseeRouvreReglages =>
      'Erlaubnis abgelehnt. Sie lässt sich in den Einstellungen deines Browsers wieder öffnen, nicht hier.';

  @override
  String get notificationsNotificationsOntPuEtre =>
      'Die Benachrichtigungen konnten nicht aktiviert werden.';

  @override
  String get notificationsNotificationsDesactiveesCetAppareil =>
      'Benachrichtigungen auf diesem Gerät deaktiviert.';

  @override
  String get notifications1TouchezBoutonPartager =>
      '1. Tippe auf die Teilen-Taste von Safari.';

  @override
  String get notifications2ChoisissezEcranAccueil =>
      '2. Wähle „Zum Home-Bildschirm“.';

  @override
  String get notifications3OuvrezJelvoDepuis =>
      '3. Öffne Jelvo über das Symbol und melde dich erneut an.';

  @override
  String get notificationsReconnexionErreurApplicationInstallee =>
      'Die erneute Anmeldung ist kein Fehler: die installierte App hat ihren eigenen Speicher, getrennt von Safari.';

  @override
  String get onboardingBienvenueJelvo => 'Willkommen bei Jelvo';

  @override
  String get onboardingAppRassembleGroupesProjets =>
      'Die App, die deine Gruppen, deine Vorhaben und deine Angehörigen zusammenbringt.';

  @override
  String get onboardingGroupesMemeEndroit => 'Alle deine Gruppen an einem Ort';

  @override
  String get onboardingOrganisezProjetsActivitesEchanges =>
      'Organisiere Vorhaben, Aktivitäten und Gespräche mit Leichtigkeit.';

  @override
  String get onboardingAgendaPartageSynchronise =>
      'Ein geteilter, synchroner Kalender';

  @override
  String get onboardingManquezAucunEvenementImportant =>
      'Verpasse keinen wichtigen Termin mehr.';

  @override
  String get onboardingTachesClairesEfficaces => 'Klare, wirksame Aufgaben';

  @override
  String get onboardingAttribuezSuivezAccomplissezEnsemble =>
      'Verteilt, verfolgt und erreicht eure Ziele gemeinsam.';

  @override
  String get profileProposJelvo => 'Über Jelvo';

  @override
  String get profileJelvoReunitGroupesEvenements =>
      'Jelvo bringt deine Gruppen, Termine, Aufgaben und Verfügbarkeiten an einem Ort zusammen – für Familie, Freunde und WG.';

  @override
  String get profileBonSavoir => 'Gut zu wissen';

  @override
  String get profileJelvoApplicationWebInstallable =>
      'Jelvo ist eine installierbare Web-App. Auf dem iPhone funktionieren Benachrichtigungen erst, wenn das Symbol zum Startbildschirm hinzugefügt wurde, und die installierte App hat ihre eigene Sitzung: dort musst du dich erneut anmelden.';

  @override
  String get profileChoisirAvatar => 'Avatar wählen';

  @override
  String get profileUtiliserCetAvatar => 'Diesen Avatar verwenden';

  @override
  String profileAvatarId(Object id) {
    return 'Avatar $id';
  }

  @override
  String get profileChangerMotPasse => 'Passwort ändern';

  @override
  String get profileMotPasseChange => 'Passwort geändert.';

  @override
  String get profileModifierProfil => 'Profil bearbeiten';

  @override
  String get profileProfilEnregistre => 'Profil gespeichert.';

  @override
  String get profileProfil => 'Mein Profil';

  @override
  String get profileProfilIndisponible => 'Profil nicht verfügbar';

  @override
  String get profileProfilIntrouvable => 'Profil nicht gefunden';

  @override
  String get profileProfilEncoreEteCree =>
      'Dein Profil wurde noch nicht erstellt. Melde dich erneut an, um es abzuschließen.';

  @override
  String get profileProfilJelvo => 'Mein Jelvo-Profil';

  @override
  String get profileAutresVoientQuMot =>
      'Andere sehen nur ein Wort: verfügbar, nicht verfügbar oder unbekannt.';

  @override
  String get profileLectureAboutiReessayezInstant =>
      'Das Laden ist nicht durchgegangen. Versuche es gleich noch einmal.';

  @override
  String get profilePersonneCompteJelvo =>
      'Diese Person hat kein Jelvo-Konto mehr.';

  @override
  String get profileAnnulerDemande => 'Anfrage zurückziehen';

  @override
  String get profileAjouterContact => 'Als Kontakt hinzufügen';

  @override
  String get profileRetirerContact => 'Diesen Kontakt entfernen?';

  @override
  String get profileActionAbouti => 'Die Aktion ist nicht durchgegangen.';

  @override
  String get profileInformationsPersonnelles => 'Persönliche Angaben';

  @override
  String get profileDeconnecter => 'Abmelden';

  @override
  String get profileDevrezSaisirNouveauIdentifiants =>
      'Du musst deine Anmeldedaten erneut eingeben, um zurückzukommen.';

  @override
  String get profileJourMoisSeulementJelvo =>
      'Nur Tag und Monat. Jelvo fragt nicht nach deinem Geburtsjahr.';

  @override
  String get profileContactsVoientPrevenusJour =>
      'Deine Kontakte sehen es und werden am Tag selbst benachrichtigt.';

  @override
  String get profileAnneesNonBissextilesSera =>
      'In Nicht-Schaltjahren wird er am 28. Februar gefeiert, dem letzten Tag des Monats.';

  @override
  String get profileSuitReglageTelephone =>
      'Folgt der Einstellung deines Telefons';

  @override
  String get profileFondBlancTexteSombre => 'Weißer Hintergrund, dunkler Text';

  @override
  String get profileFondSombreTexteClair => 'Dunkler Hintergrund, heller Text';

  @override
  String get profileChoixVautCetAppareil =>
      'Diese Wahl gilt nur auf diesem Gerät.';

  @override
  String get profilePhotoProfil => 'Profilbild';

  @override
  String get profileChoisirPhoto => 'Foto wählen';

  @override
  String get profileDepuisPhotosAppareil => 'Aus den Fotos auf deinem Gerät';

  @override
  String get profileChoisirAvatarJelvo => 'Jelvo-Avatar wählen';

  @override
  String get profileQuatreVingtTreizeIllustrations =>
      'Dreiundneunzig Illustrationen zur Auswahl';

  @override
  String get profileInitialesPrendrontPlace =>
      'Deine Initialen treten an seine Stelle';

  @override
  String get profileAjoutezJourMoisAnnee =>
      'Füge Tag und Monat hinzu, ohne das Jahr';

  @override
  String get profileAdresseIndisponible => 'Adresse nicht verfügbar';

  @override
  String get profileQuelquesMots => 'Ein paar Worte über dich';

  @override
  String get profileAjoutezQuelquesMots => 'Schreib ein paar Worte über dich';

  @override
  String get profileEnregistrerBio => 'Bio speichern';

  @override
  String get profileModifierBio => 'Bio bearbeiten';

  @override
  String get profileChangerPhoto => 'Foto ändern';

  @override
  String get profileChangerPhotoProfil => 'Profilbild ändern';

  @override
  String get profileQRCode => 'QR-Code';

  @override
  String get profilePartagerProfil => 'Profil teilen';

  @override
  String get profileStatistiques => 'Meine Zahlen';

  @override
  String get profileTachesTerminees => 'Erledigte Aufgaben';

  @override
  String get profile1GroupeCommun => '1 gemeinsame Gruppe';

  @override
  String get profileOrganisezRienEnsembleInstant =>
      'Ihr organisiert derzeit nichts gemeinsam.';

  @override
  String get tasksAvezPrisTache => 'Du hast diese Aufgabe übernommen.';

  @override
  String get tasksAvezRenduTacheGroupe =>
      'Du hast diese Aufgabe an die Gruppe zurückgegeben.';

  @override
  String get tasksQuelquVientPrendreAvant =>
      'Jemand hat sie dir gerade weggenommen.';

  @override
  String get tasksTache => 'Diese Aufgabe ist nicht deine.';

  @override
  String get tasksTacheEteConfieeRefusez =>
      'Diese Aufgabe wurde dir übertragen: lehne sie ab, statt sie zurückzugeben.';

  @override
  String get tasksFaitesPartieGroupe =>
      'Du gehörst dieser Gruppe nicht mehr an.';

  @override
  String get tasksTachePuEtreCreee =>
      'Die Aufgabe konnte nicht erstellt werden. Versuche es gleich noch einmal.';

  @override
  String get tasksTachePuEtreModifiee =>
      'Die Aufgabe konnte nicht geändert werden. Versuche es gleich noch einmal.';

  @override
  String get tasksTacheConfiee => 'Aufgabe übertragen';

  @override
  String get tasksTacheIntrouvable => 'Aufgabe nicht gefunden';

  @override
  String get tasksEteSupprimeeAvezAcces =>
      'Sie wurde gelöscht, oder du hast keinen Zugriff mehr darauf. Es gibt nichts mehr anzunehmen.';

  @override
  String get tasksRevenirAccueil => 'Zurück zum Start';

  @override
  String get tasksTacheEteConfiee => 'Diese Aufgabe wurde dir übertragen';

  @override
  String get tasksConfieTache => 'hat dir eine Aufgabe übertragen';

  @override
  String get tasksAssignee => 'Zugewiesen an';

  @override
  String get tasksEcheanceDejaPassee => 'Die Frist ist schon abgelaufen.';

  @override
  String get tasksAvezAccepteTache => 'Du hast diese Aufgabe angenommen.';

  @override
  String get tasksAvezDeclineTache => 'Du hast diese Aufgabe abgelehnt.';

  @override
  String get tasksAvezTerminePart => 'Du hast deinen Teil erledigt.';

  @override
  String get tasksTacheAssignee => 'Diese Aufgabe ist dir nicht zugewiesen.';

  @override
  String get tasksOuvrirTache => 'Aufgabe öffnen';

  @override
  String get tasksTacheAcceptee => 'Aufgabe angenommen.';

  @override
  String get tasksTacheDeclinee => 'Aufgabe abgelehnt.';

  @override
  String get tasksModifierTache => 'Aufgabe bearbeiten';

  @override
  String get tasksSupprimerTache => 'Aufgabe löschen';

  @override
  String get tasksEteSupprimeeAvezAcces2 =>
      'Sie wurde gelöscht, oder du hast keinen Zugriff mehr darauf.';

  @override
  String get tasksPersonneInstantImporteQuel =>
      'Derzeit niemand. Jedes Mitglied der Gruppe kann sie übernehmen.';

  @override
  String get tasksRetirer => 'Zurückziehen';

  @override
  String get tasksJeMCharge => 'Ich mache das';

  @override
  String get tasksChargezTache => 'Du übernimmst diese Aufgabe.';

  @override
  String get tasksChargiezDeja => 'Du hattest sie schon übernommen.';

  @override
  String get tasksChargez => 'Du übernimmst sie nicht mehr.';

  @override
  String get tasksEtiezAssigneTache =>
      'Du warst dieser Aufgabe nicht zugewiesen.';

  @override
  String get tasksQuelquChargeDejaPassez =>
      'Jemand übernimmt sie schon. Über „Bearbeiten“ kannst du die Zuweisung ändern.';

  @override
  String get tasksRienCocherAjoutezQu =>
      'Nichts zum Abhaken. Trage ein, was nötig ist: alle sehen, was noch fehlt.';

  @override
  String get tasksAjouterArticle => 'Punkt hinzufügen';

  @override
  String get tasksAjouterListe => 'Zur Liste hinzufügen';

  @override
  String get tasksRetirerListe => 'Aus der Liste entfernen';

  @override
  String get tasksRouvrirTache => 'Aufgabe wieder öffnen';

  @override
  String get tasksMarquerCommeTerminee => 'Als erledigt markieren';

  @override
  String get tasksTachesIndisponibles => 'Aufgaben nicht verfügbar';

  @override
  String get tasksAucuneTache => 'Keine Aufgaben';

  @override
  String get tasksFaitRienEncoreEte =>
      'Alles erledigt – oder es wurde noch nichts notiert.';

  @override
  String get tasksGroupeAucuneTacheInstant =>
      'Diese Gruppe hat derzeit keine Aufgaben.';

  @override
  String get tasksAssigner => 'Zuweisen an';

  @override
  String get tasksMembresGroupeOntEncore =>
      'Die Mitglieder der Gruppe sind noch nicht geladen.';

  @override
  String get tasksExAcheterPain => 'Z. B.: Brot kaufen';

  @override
  String get tasksJelvoEnverraNotificationPersonne =>
      'Jelvo sendet der zugewiesenen Person eine Benachrichtigung';

  @override
  String get tasksTachesRecurrentes => 'Für wiederkehrende Aufgaben';

  @override
  String get tasksCreerTache => 'Aufgabe erstellen';

  @override
  String get tasksProposeeGroupeCarteAffichera =>
      'Der ganzen Gruppe angeboten: in der Unterhaltung erscheint eine Karte, und wer zuerst annimmt, übernimmt sie.';

  @override
  String tasksConfieeListeRecevraNotification(Object liste) {
    return 'An $liste übertragen, mit Benachrichtigung.';
  }

  @override
  String tasksConfieeListeRecevrontNotification(Object liste) {
    return 'An $liste übertragen, mit Benachrichtigung.';
  }

  @override
  String get tasksEcheancePrioriteDescription =>
      'Frist, Priorität, Beschreibung…';

  @override
  String get tasksQuFautSavoirOccuper =>
      'Was man wissen muss, um sie zu übernehmen';

  @override
  String get tasksDonnezTitreTache => 'Gib der Aufgabe einen Titel.';

  @override
  String get tasksTacheEteModifiee => 'Die Aufgabe wurde geändert.';

  @override
  String tasksTacheTitreEteCreee(Object titre) {
    return 'Die Aufgabe „$titre“ wurde erstellt.';
  }

  @override
  String get routerPageIntrouvable => 'Seite nicht gefunden';

  @override
  String routerAucunEcranCorrespondLocation(Object location) {
    return 'Kein Bildschirm passt zu „$location“.';
  }

  @override
  String get calendarRecurrenceJamais => 'Nie';

  @override
  String get calendarRappelAucun => 'Keine';

  @override
  String get coreDemain => 'Morgen';

  @override
  String get coreHier => 'Gestern';

  @override
  String coreIlYaMinutes(int minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String coreIlYaHeures(int heures) {
    return 'vor $heures Std.';
  }

  @override
  String coreIlYaJours(int jours) {
    String _temp0 = intl.Intl.pluralLogic(
      jours,
      locale: localeName,
      other: 'vor $jours Tagen',
      one: 'vor $jours Tag',
    );
    return '$_temp0';
  }

  @override
  String coreLeDate(String date) {
    return 'am $date';
  }

  @override
  String get createEvenement => 'Termin';

  @override
  String get createTache => 'Aufgabe';

  @override
  String get createGroupe => 'Gruppe';

  @override
  String get profileApparence => 'Erscheinungsbild';

  @override
  String get profileApparenceAutomatique => 'Automatisch';

  @override
  String get profileApparenceClair => 'Hell';

  @override
  String get profileApparenceSombre => 'Dunkel';

  @override
  String groupsTachesEnCours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Aufgaben',
      one: '$count offene Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementsAVenir(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine demnächst',
      one: '$count Termin demnächst',
    );
    return '$_temp0';
  }

  @override
  String groupsVousAdministrezCeGroupe(String membres) {
    return '$membres · du verwaltest diese Gruppe';
  }

  @override
  String authMoinsCaracteres(int min) {
    return 'Mindestens $min Zeichen';
  }

  @override
  String get homeBonjour => 'Guten Morgen';

  @override
  String get homeBonsoir => 'Guten Abend';

  @override
  String get calendarPersonnel => 'Privat';

  @override
  String get calendarJournee => 'Ganztägig';

  @override
  String calendarFeteSonAnniversaire(String nom) {
    return '$nom hat Geburtstag';
  }

  @override
  String get navNotifications => 'Benachrichtigungen';

  @override
  String get navParametres => 'Einstellungen';

  @override
  String get coreStatutInformation => 'Information';

  @override
  String get coreStatutConfirme => 'Bestätigt';

  @override
  String get coreStatutEnAttente => 'Offen';

  @override
  String get coreStatutConflit => 'Konflikt';

  @override
  String get coreStatutInactif => 'Inaktiv';

  @override
  String get notificationsActives => 'Aktiv';

  @override
  String get notificationsNotification => 'Benachrichtigung';

  @override
  String chatUnePersonneEcrit(String nom) {
    return '$nom schreibt…';
  }

  @override
  String chatDeuxPersonnesEcrivent(String premier, String second) {
    return '$premier und $second schreiben…';
  }

  @override
  String chatAPrisLaTache(String nom) {
    return '$nom hat die Aufgabe übernommen';
  }

  @override
  String chatAAccepteLaTache(String nom) {
    return '$nom hat die Aufgabe angenommen';
  }

  @override
  String chatARefuseLaTache(String nom) {
    return '$nom hat die Aufgabe abgelehnt';
  }

  @override
  String chatATermineLaTache(String nom) {
    return '$nom hat die Aufgabe erledigt';
  }

  @override
  String chatTacheAttribueeA(String nom) {
    return 'Aufgabe zugewiesen an $nom';
  }

  @override
  String groupsInvitationDe(String nom) {
    return 'Einladung von $nom';
  }

  @override
  String get calendarRappel => 'Erinnerung';

  @override
  String get calendarRepeter => 'Wiederholen';

  @override
  String groupsMembreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '$count Mitglied',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '$count Termin',
    );
    return '$_temp0';
  }

  @override
  String groupsTacheOuverteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Aufgaben',
      one: '$count offene Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String coreJourEtHeure(String jour, String heures) {
    return '$jour · $heures';
  }

  @override
  String groupsRetraitMembreConfirmation(String nom) {
    return '$nom hat dann keinen Zugriff mehr auf die Gruppe. Du kannst die Person später erneut einladen.';
  }

  @override
  String groupsQuitterConfirmation(String groupe) {
    return 'Du siehst „$groupe“ dann nicht mehr. Wenn du der letzte Administrator bist, übernimmt das dienstälteste Mitglied.';
  }

  @override
  String groupsSupprimerConfirmation(String groupe) {
    return '„$groupe“ verschwindet für alle Mitglieder. Diese Aktion kann in der App nicht widerrufen werden.';
  }

  @override
  String groupsInvitationRecueJusquAu(String nom, String date) {
    return '$nom hat deine Einladung erhalten, bis zum $date.';
  }

  @override
  String get coreRetirer => 'Entfernen';

  @override
  String get coreQuitter => 'Verlassen';

  @override
  String get coreSupprimer => 'Löschen';

  @override
  String tasksTacheSupprimee(String titre) {
    return '„$titre“ wurde gelöscht.';
  }

  @override
  String tasksSupprimerConfirmation(String titre) {
    return '„$titre“ verschwindet für alle. Diese Aktion kann in der App nicht widerrufen werden.';
  }

  @override
  String coreVous(String nom) {
    return '$nom (du)';
  }

  @override
  String coreSurTotal(int fait, int total) {
    return '$fait von $total';
  }

  @override
  String tasksCochePar(String nom) {
    return 'Abgehakt von $nom';
  }

  @override
  String get tasksListe => 'Liste';

  @override
  String get tasksEcheance => 'Fällig am';

  @override
  String get tasksAucune => 'Keine';

  @override
  String calendarEvenementSupprime(String titre) {
    return '„$titre“ wurde gelöscht.';
  }

  @override
  String calendarSupprimerConfirmation(String titre) {
    return '„$titre“ verschwindet für alle Teilnehmenden. Diese Aktion kann in der App nicht widerrufen werden.';
  }

  @override
  String get calendarParticipants => 'Teilnehmende';

  @override
  String calendarOuiCount(int count) {
    return '$count Ja';
  }

  @override
  String calendarVousAvezRepondu(String reponse) {
    return 'Du hast geantwortet: $reponse. Du kannst es dir noch anders überlegen.';
  }

  @override
  String calendarReponseEnregistree(String reponse) {
    return 'Antwort gespeichert: $reponse.';
  }

  @override
  String groupsPartagezCeLien(String groupe) {
    return 'Teile diesen Link per SMS, Messenger oder E-Mail. Die Person kann dann ihr Konto erstellen und „$groupe“ beitreten.';
  }

  @override
  String groupsRejoinsSurJelvo(String groupe, String url) {
    return 'Komm zu „$groupe“ auf Jelvo: $url';
  }

  @override
  String groupsInvitationARejoindre(String groupe) {
    return 'Einladung zu $groupe';
  }

  @override
  String groupsUtilisationsExpireLe(String utilisations, String date) {
    return '$utilisations · läuft ab am $date';
  }

  @override
  String groupsAdhesionJusquAu(String date) {
    return 'Mitgliedschaft bis zum $date';
  }

  @override
  String groupsUtilisationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nutzungen',
      one: '$count Nutzung',
    );
    return '$_temp0';
  }

  @override
  String groupsUtilisationSurMax(String utilisations, int max) {
    return '$utilisations von $max';
  }

  @override
  String contactsGroupeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gruppen',
      one: '$count Gruppe',
    );
    return '$_temp0';
  }

  @override
  String contactsPersonnesSouhaitentVousAjouter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen möchten dich hinzufügen',
      one: '$count Person möchte dich hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String contactsFaitMaintenantPartie(String nom) {
    return '$nom ist jetzt einer deiner Kontakte.';
  }

  @override
  String contactsAjoutezMoiSurJelvo(String pseudo) {
    return 'Füge mich auf Jelvo hinzu: $pseudo';
  }

  @override
  String contactsNomEtMessage(String nom, String message) {
    return '$nom – $message';
  }

  @override
  String contactsRejoignezMoi(String url) {
    return 'Komm zu mir auf Jelvo, dann können wir gemeinsam planen: $url';
  }

  @override
  String contactsMonPseudoLigne(String pseudo) {
    return '\nMein Benutzername: $pseudo';
  }

  @override
  String contactsRetraitConfirmation(String nom) {
    return '$nom ist dann keiner deiner Kontakte mehr, und du bist keiner der ihren.';
  }

  @override
  String contactsAEteRetire(String nom) {
    return '$nom wurde entfernt.';
  }

  @override
  String coreParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Teilnehmende',
      one: '$count Teilnehmende/r',
    );
    return '$_temp0';
  }

  @override
  String coreMessageNonLuCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ungelesene Nachrichten',
      one: '$count ungelesene Nachricht',
    );
    return '$_temp0';
  }

  @override
  String authCodeEnvoyeA(String email) {
    return 'Wir haben einen sechsstelligen Code an $email gesendet.';
  }

  @override
  String authFormatPseudo(int min, int max) {
    return 'Kleinbuchstaben, Ziffern und Punkte, von $min bis $max Zeichen.';
  }

  @override
  String availabilityDateEtPlage(String date, String plage) {
    return '$date · $plage';
  }

  @override
  String availabilityDe(String heure) {
    return 'Von $heure';
  }

  @override
  String availabilityA(String heure) {
    return 'Bis $heure';
  }

  @override
  String calendarPuceEtDate(String date) {
    return ' • $date';
  }

  @override
  String calendarRienNeCorrespond(String terme) {
    return 'Nichts passt zu „$terme“.';
  }

  @override
  String coreSurTotalTexte(int fait, int total) {
    return '$fait von $total';
  }

  @override
  String calendarHeuresMinutes(int heures, String minutes) {
    return '$heures Std. $minutes';
  }

  @override
  String calendarHeures(int heures) {
    return '$heures Std.';
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
    return 'Bis zu $taille, etwa eine Minute';
  }

  @override
  String chatVideoTropLourde(String taille, String max) {
    return 'Dieses Video wiegt $taille und liegt über den erlaubten $max. Filme kürzer, oder sende es auf anderem Weg.';
  }

  @override
  String chatEcheanceDateHeure(String date, String heure) {
    return 'Fällig am $date um $heure';
  }

  @override
  String groupsInvitationEnAttenteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Einladungen',
      one: '$count offene Einladung',
    );
    return '$_temp0';
  }

  @override
  String groupsAdhesionTemporaireJusquAu(String date) {
    return 'Befristete Mitgliedschaft: bis zum $date.';
  }

  @override
  String groupsAdhesionTemporaireVousFerezPartie(String date) {
    return 'Befristete Mitgliedschaft: du gehörst der Gruppe bis zum $date an.';
  }

  @override
  String groupsCreezIciPartageAvec(String groupe) {
    return 'Was du hier erstellst, wird mit „$groupe“ geteilt.';
  }

  @override
  String groupsJusquAu(String date) {
    return 'Bis zum $date';
  }

  @override
  String groupsAdhesionJusquAuPuisDisparait(String date) {
    return 'Mitgliedschaft bis zum $date, danach verschwindet die Gruppe aus ihrer App.';
  }

  @override
  String groupsMembreJusquAu(String nom, String date) {
    return '$nom gehört der Gruppe bis zum $date an.';
  }

  @override
  String groupsMembreSansTerme(String nom) {
    return '$nom gehört der Gruppe ohne Enddatum an.';
  }

  @override
  String homeTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben',
      one: '$count Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count Termine',
      one: ', $count Termin',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count Aufgaben',
      one: ', $count Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String notificationsVousConvie(String nom) {
    return '$nom lädt dich ein.';
  }

  @override
  String notificationsVousConvieAvecGroupe(String nom, String groupe) {
    return '$nom lädt dich mit „$groupe“ ein.';
  }

  @override
  String profileVersion(String version) {
    return 'Version $version';
  }

  @override
  String profileRetrouvezMoi(String pseudo, String code) {
    return 'Finde mich auf Jelvo: $pseudo\n$code';
  }

  @override
  String profileVotrePseudo(String pseudo) {
    return 'Dein Benutzername: $pseudo';
  }

  @override
  String profileRetraitCarnetConfirmation(String nom) {
    return '$nom erscheint dann nicht mehr in deinen Kontakten. An euren gemeinsamen Gruppen ändert sich nichts.';
  }

  @override
  String profileGroupesCommunsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gemeinsame Gruppen',
      one: '$count gemeinsame Gruppe',
    );
    return '$_temp0';
  }

  @override
  String tasksEcheanceDate(String date) {
    return 'Fällig am $date';
  }

  @override
  String coreDateAHeure(String date, String heure) {
    return '$date um $heure';
  }

  @override
  String get tasksTerminees => 'Erledigt';

  @override
  String tasksConfieeAuxPersonnes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'An $count Personen übertragen, die eine Benachrichtigung erhalten.',
      one: 'An $count Person übertragen, die eine Benachrichtigung erhält.',
    );
    return '$_temp0';
  }

  @override
  String coreDeuxNoms(String premier, String second) {
    return '$premier und $second';
  }

  @override
  String coreDeuxNomsEtAutres(String premier, String second, int reste) {
    String _temp0 = intl.Intl.pluralLogic(
      reste,
      locale: localeName,
      other: '$reste weitere',
      one: '$reste weitere Person',
    );
    return '$premier, $second und $_temp0';
  }

  @override
  String tasksArticlesCoches(int faits, int total) {
    return '$faits von $total Punkten';
  }

  @override
  String tasksPrioriteLabel(String priorite) {
    return 'Priorität $priorite';
  }

  @override
  String navBadgeNonLus(String destination, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ungelesen',
      one: '$count ungelesen',
    );
    return '$destination, $_temp0';
  }

  @override
  String get profileLangue => 'Sprache';

  @override
  String get profileLangueDuTelephone => 'Die des Telefons';

  @override
  String get profileLangueDuTelephoneAide =>
      'Folgt der Geräteeinstellung, und Englisch, wenn die Sprache nicht angeboten wird';

  @override
  String get profileLangueFrancais => 'Französisch';

  @override
  String get profileLangueAllemand => 'Deutsch';

  @override
  String get profileLangueAnglais => 'Englisch';

  @override
  String get profileLangueEspagnol => 'Spanisch';

  @override
  String get homeBonWeekEnd => 'Schönes Wochenende';

  @override
  String get coreDebutApresMidi => '12';

  @override
  String get coreDebutSoiree => '18';

  @override
  String get coreDescription => 'Beschreibung';

  @override
  String get coreRechercher => 'Suchen';

  @override
  String get coreProfil => 'Profil';

  @override
  String get coreLieu => 'Ort';

  @override
  String get coreAnniversaire => 'Geburtstag';

  @override
  String get coreAutre => 'Andere';

  @override
  String get corePrenom => 'Vorname';

  @override
  String get coreNom => 'Nachname';

  @override
  String get corePseudo => 'Benutzername';

  @override
  String get coreHintPseudo => 'benutzername';

  @override
  String get coreFiltres => 'Filter';

  @override
  String get coreRepetition => 'Wiederholung';

  @override
  String get coreInvitation => 'Einladung';

  @override
  String get coreInvitations => 'Einladungen';

  @override
  String get coreChoisir => 'Wählen';

  @override
  String get corePriorite => 'Priorität';

  @override
  String get coreDate => 'Datum';

  @override
  String get coreHoraires => 'Uhrzeit';

  @override
  String get coreDisponible => 'Verfügbar';

  @override
  String get coreTout => 'Alle';

  @override
  String get coreAfficher => 'Anzeigen';

  @override
  String get coreFin => 'Ende';

  @override
  String get coreVideo => 'Video';

  @override
  String get coreJoindre => 'Anhängen';

  @override
  String get coreFilmer => 'Aufnehmen';

  @override
  String get coreScanner => 'Scannen';

  @override
  String get coreResultats => 'Ergebnisse';

  @override
  String get coreEffacer => 'Löschen';

  @override
  String get coreFavoris => 'Favoriten';

  @override
  String get coreGerer => 'Verwalten';

  @override
  String get coreActions => 'Aktionen';

  @override
  String get coreDiscussion => 'Chat';

  @override
  String get coreInviter => 'Einladen';

  @override
  String get coreSuggestions => 'Vorschläge';

  @override
  String get corePartager => 'Teilen';

  @override
  String get coreAdmin => 'Admin';

  @override
  String get coreCommencer => 'Los geht’s';

  @override
  String get coreCompte => 'Konto';

  @override
  String get coreDeconnexion => 'Abmelden';

  @override
  String get coreJour => 'Tag';

  @override
  String get coreMois => 'Monat';

  @override
  String get coreEmail => 'E-Mail';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreModifier => 'Bearbeiten';

  @override
  String get coreContinuer => 'Weiter';

  @override
  String get coreVerifier => 'Bestätigen';

  @override
  String get coreExceptions => 'Ausnahmen';

  @override
  String get coreEvenements => 'Termine';

  @override
  String get coreTaches => 'Aufgaben';

  @override
  String get coreExemplePrenom => 'Max';

  @override
  String get coreExempleNom => 'Mustermann';

  @override
  String get corePlusDOptions => 'Weitere Optionen';

  @override
  String get profileSupprimerCompte => 'Mein Konto löschen';

  @override
  String get profileSuppressionDefinitive =>
      'Diese Löschung ist endgültig: sie kann nicht widerrufen werden.';

  @override
  String get profileSuppressionCeQuiDisparait => 'Was verschwindet';

  @override
  String get profileSuppressionIdentite =>
      'Dein Name, dein Benutzername, deine E-Mail-Adresse und dein Foto';

  @override
  String get profileSuppressionProfil =>
      'Deine Bio, dein Geburtstag und deine Verfügbarkeiten';

  @override
  String get profileSuppressionContacts =>
      'Deine Kontakte und deine offenen Anfragen';

  @override
  String get profileSuppressionGroupes =>
      'Deine Gruppenmitgliedschaften. Wenn du eine Gruppe allein verwaltest, übernimmt das älteste Mitglied deine Rolle.';

  @override
  String get profileSuppressionNotifications =>
      'Deine Benachrichtigungen und deine Abos';

  @override
  String get profileSuppressionVocaux =>
      'Deine Sprachnachrichten, die deine Stimme tragen';

  @override
  String get profileSuppressionCeQuiReste => 'Was bleibt';

  @override
  String get profileSuppressionMessages =>
      'Deine geschriebenen Nachrichten, mit „Gelöschtes Konto“ gezeichnet, damit die Gespräche der anderen keine Lücken bekommen';

  @override
  String get profileSuppressionMedias =>
      'Die Fotos und Videos, die du geteilt hast';

  @override
  String get profileSuppressionGroupeContenu =>
      'Die Aufgaben und Termine, die du in einer Gruppe erstellt hast';

  @override
  String get profileSuppressionReinscription =>
      'Du kannst dich später mit derselben Adresse neu anmelden.';

  @override
  String get profileSuppressionMotDePasse => 'Passwort';

  @override
  String get profileSuppressionMotDePasseAide =>
      'Um zu bestätigen, dass du es bist';

  @override
  String get profileSuppressionConfirmer => 'Endgültig löschen';

  @override
  String get profileSuppressionMotDePasseIncorrect => 'Falsches Passwort.';

  @override
  String get profileSuppressionEchec =>
      'Die Löschung ist nicht durchgegangen. Dein Konto ist unverändert: versuche es gleich noch einmal.';

  @override
  String get profileSuppressionFaite => 'Dein Konto wurde gelöscht.';

  @override
  String get coreCompteSupprime => 'Gelöschtes Konto';

  @override
  String get coreMembre => 'Mitglied';

  @override
  String get coreEpingle => 'Angepinnt';

  @override
  String get coreEpingler => 'Anpinnen';

  @override
  String get coreRouvrir => 'Wieder öffnen';

  @override
  String get chatEcouter => 'Abspielen';

  @override
  String get tasksAssignes => 'Zugewiesen';

  @override
  String get tasksPersonnelle => 'Persönlich';

  @override
  String chatCompteurTaches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aufgaben',
      one: 'Aufgabe',
    );
    return '$_temp0';
  }

  @override
  String chatCompteurEvenements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Termine',
      one: 'Termin',
    );
    return '$_temp0';
  }

  @override
  String contactsCompteurGroupes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gruppen',
      one: 'Gruppe',
    );
    return '$_temp0';
  }

  @override
  String get tasksLibre => 'Frei';

  @override
  String get coreIndisponible => 'Nicht verfügbar';

  @override
  String get coreInconnu => 'Unbekannt';

  @override
  String get coreAutres => 'Sonstige';

  @override
  String get coreContact => 'Kontakt';

  @override
  String get coreDateChoisir => 'Datum…';

  @override
  String get chatEmojis => 'Emojis';

  @override
  String get chatEnvoyer => 'Senden';

  @override
  String get authRetirerAvatar => 'Avatar entfernen';

  @override
  String get groupsRejoindre => 'Beitreten';

  @override
  String get notificationsActivees => 'Aktiviert';

  @override
  String get notificationsPartielles => 'Teilweise';

  @override
  String get notificationsDesactivees => 'Deaktiviert';

  @override
  String get notificationsRefusees => 'Abgelehnt';

  @override
  String get notificationsIndisponibles => 'Nicht verfügbar';

  @override
  String get notificationsVoirInvitation => 'Einladung ansehen';

  @override
  String get signalementMotifSpam => 'Spam oder Werbung';

  @override
  String get signalementMotifHarcelement => 'Belästigung';

  @override
  String get signalementMotifHaine => 'Hassrede';

  @override
  String get signalementMotifSexuel => 'Sexuelle Inhalte';

  @override
  String get signalementMotifViolence => 'Gewalt oder Drohungen';

  @override
  String get signalementMotifAutre => 'Etwas anderes';

  @override
  String get signalementAideSpam =>
      'Wiederholte Nachrichten, unerwünschte Links';

  @override
  String get signalementAideHarcelement =>
      'Aufdringlichkeit, Einschüchterung, wiederholter Spott';

  @override
  String get signalementAideHaine =>
      'Angriff wegen Herkunft, Religion, Geschlecht oder Orientierung';

  @override
  String get signalementAideSexuel =>
      'Unerwünschte sexuelle Bilder oder Äußerungen';

  @override
  String get signalementAideViolence => 'Drohungen, Aufruf zu Schaden';

  @override
  String get signalementAideAutre => 'Beschreiben Sie es unten';

  @override
  String get signalementEnvoye => 'Meldung gesendet. Sie wird geprüft.';

  @override
  String get signalementDejaEnvoye =>
      'Sie haben dies bereits gemeldet, und es ist noch nicht bearbeitet.';

  @override
  String get signalementIntrouvable => 'Das gibt es nicht mehr.';

  @override
  String get signalementNonMembre => 'Sie gehören nicht zu dieser Gruppe.';

  @override
  String get signalementSoiMeme => 'Sie können sich nicht selbst melden.';

  @override
  String get signalementMotifInconnu => 'Dieser Grund wird nicht erkannt.';

  @override
  String get signalementNonConnecte =>
      'Melden Sie sich erneut an, um zu melden.';

  @override
  String get signalementNonModerateur =>
      'Sie haben keinen Zugang zur Moderation.';

  @override
  String get signalementMarqueTraite => 'Meldung bearbeitet.';

  @override
  String get signalementRouvert => 'Meldung wieder geöffnet.';

  @override
  String get signalementMessageSupprime => 'Nachricht gelöscht.';

  @override
  String get signalementMessageDejaSupprime =>
      'Diese Nachricht war schon gelöscht.';

  @override
  String get signalementSignaler => 'Melden';

  @override
  String get signalementTitreMessage => 'Diese Nachricht melden';

  @override
  String get signalementTitreGroupe => 'Diese Gruppe melden';

  @override
  String get signalementTitreProfil => 'Dieses Profil melden';

  @override
  String get signalementConfidentiel =>
      'Die betroffene Person wird nicht benachrichtigt und erfährt nicht, wer gemeldet hat.';

  @override
  String get signalementContenuGarde =>
      'Der gemeldete Inhalt wird kopiert, damit er lesbar bleibt, auch wenn er danach gelöscht wird.';

  @override
  String get signalementCommentaire => 'Angaben';

  @override
  String get signalementCommentaireAide =>
      'Optional – was beim Verstehen hilft';

  @override
  String get signalementEnvoyer => 'Meldung senden';

  @override
  String get signalementChoisirMotif => 'Wählen Sie einen Grund.';

  @override
  String get moderationTitre => 'Meldungen';

  @override
  String get moderationATraiter => 'Zu bearbeiten';

  @override
  String get moderationTraites => 'Bearbeitet';

  @override
  String get moderationVideTitre => 'Nichts zu bearbeiten';

  @override
  String get moderationVideMessage =>
      'Keine Meldung wartet. Das ist die gute Nachricht.';

  @override
  String get moderationVideTraitesTitre => 'Keine bearbeitete Meldung';

  @override
  String get moderationVideTraitesMessage =>
      'Was Sie als bearbeitet markieren, wird hier abgelegt.';

  @override
  String get moderationCibleMessage => 'Nachricht';

  @override
  String get moderationCibleGroupe => 'Gruppe';

  @override
  String get moderationCibleProfil => 'Profil';

  @override
  String moderationSignalePar(String nom) {
    return 'Gemeldet von $nom';
  }

  @override
  String moderationVise(String nom) {
    return 'Betrifft $nom';
  }

  @override
  String moderationDansGroupe(String groupe) {
    return 'In $groupe';
  }

  @override
  String get moderationContenuRecopie => 'Gemeldeter Inhalt';

  @override
  String get moderationMessageEfface =>
      'Diese Nachricht wurde seit der Meldung gelöscht.';

  @override
  String get moderationMediaImage => 'Ein Foto';

  @override
  String get moderationMediaVideo => 'Ein Video';

  @override
  String get moderationMediaAudio => 'Eine Sprachnachricht';

  @override
  String get moderationSupprimerMessage => 'Nachricht löschen';

  @override
  String get moderationSupprimerConfirmation =>
      'Die Sprechblase wird für die ganze Gruppe zu „Nachricht gelöscht“. Die Meldung behält, was geschrieben wurde.';

  @override
  String get moderationMarquerTraite => 'Als bearbeitet markieren';

  @override
  String get moderationRouvrir => 'Wieder öffnen';

  @override
  String get moderationNote => 'Notiz';

  @override
  String get moderationNoteAide => 'Optional – was Sie getan haben';

  @override
  String get moderationAucunLevier =>
      'Bei einer Gruppe oder einem Profil ist die Notiz der einzige Hebel: Weder das Schließen eines Kontos noch das Löschen einer Gruppe geschieht von hier.';

  @override
  String get profileSignalements => 'Meldungen';

  @override
  String get moderationIndisponible => 'Meldungen nicht verfügbar';

  @override
  String moderationEnTete(String cible, String motif) {
    return '$cible · $motif';
  }

  @override
  String moderationCitation(String texte) {
    return '„$texte“';
  }

  @override
  String get errorBlocked => 'Diese Person kann nicht hinzugefügt werden.';

  @override
  String get profileBloquer => 'Blockieren';

  @override
  String get profileDebloquer => 'Entsperren';

  @override
  String get profileBloques => 'Blockierte Personen';

  @override
  String get blocageTitre => 'Diese Person blockieren?';

  @override
  String get blocageCeQueCaFait =>
      'Sie kann Sie nicht mehr in eine Gruppe einladen, als Kontakt hinzufügen oder Ihnen eine Aufgabe zuweisen. Ihre Kontaktverbindung wird entfernt.';

  @override
  String get blocageGroupePartage =>
      'Sie teilen eine Gruppe: Dort bleibt sie sichtbar, und die Unterhaltung ändert sich nicht. Um ihr nicht mehr zu begegnen, verlassen Sie die Gruppe.';

  @override
  String get blocageBloque => 'Person blockiert.';

  @override
  String get blocageDejaBloque => 'Diese Person ist schon blockiert.';

  @override
  String get blocageDebloque => 'Person entsperrt.';

  @override
  String get blocagePasBloque => 'Diese Person war nicht blockiert.';

  @override
  String get blocageSoiMeme => 'Sie können sich nicht selbst blockieren.';

  @override
  String get blocageIntrouvable => 'Diese Person gibt es nicht mehr.';

  @override
  String get blocageVideTitre => 'Niemand ist blockiert';

  @override
  String get blocageVideMessage =>
      'Sie können jemanden über sein Profil blockieren.';

  @override
  String blocageDepuis(String depuis) {
    return 'Blockiert $depuis';
  }

  @override
  String get blocageDebloquerConfirmation =>
      'Sie kann Sie wieder einladen, hinzufügen und Ihnen Aufgaben zuweisen. Ihre Kontaktverbindung kommt nicht zurück.';

  @override
  String get profileBloqueeCestVous => 'Sie haben diese Person blockiert.';
}
