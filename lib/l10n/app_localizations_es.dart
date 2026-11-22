// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppTextsEs extends AppTexts {
  AppTextsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Jelvo';

  @override
  String get navHome => 'Inicio';

  @override
  String get navGroups => 'Grupos';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navContacts => 'Contactos';

  @override
  String get createNewGroup => 'Nuevo grupo';

  @override
  String get createNewEvent => 'Nuevo evento';

  @override
  String get createAddContact => 'Añadir un contacto';

  @override
  String get createTitle => 'Crear';

  @override
  String get createQuestion => '¿Qué quieres crear?';

  @override
  String get createIntro =>
      'Elige un tipo y rellena lo esencial. Podrás añadir los detalles más tarde.';

  @override
  String get createDetails => 'Detalles';

  @override
  String get createGroupField => 'Grupo';

  @override
  String get createPersonalOption => 'Personal: solo lo ves tú';

  @override
  String get createPickDate => 'Elegir la fecha';

  @override
  String get createDueDate => 'Fecha límite';

  @override
  String get createTime => 'Hora';

  @override
  String get createMissingDate => 'Elige la fecha del evento.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRequiredField => 'Este campo es obligatorio.';

  @override
  String get commonOptional => 'Opcional';

  @override
  String get homeSubtitle => 'Aquí tienes tu día de un vistazo.';

  @override
  String get homeToday => 'Hoy';

  @override
  String get homeNoEventTitle => 'Día libre';

  @override
  String get homeNoEventMessage => 'Todavía no hay nada previsto para hoy.';

  @override
  String get homeSoon => 'Para pronto';

  @override
  String get homeNothingUrgent => 'Nada urgente';

  @override
  String get homeAllUpToDateTitle => 'Todo al día';

  @override
  String get homeAllUpToDateMessage =>
      'Ninguna tarea vence en las próximas 48 horas.';

  @override
  String get homeMyGroups => 'Mis grupos';

  @override
  String get homeMostActive => 'Los más activos ahora';

  @override
  String get homeSeeAll => 'Ver todo';

  @override
  String homeEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
      zero: 'Ningún evento',
    );
    return '$_temp0';
  }

  @override
  String homeTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas que vencen pronto',
      one: '1 tarea que vence pronto',
      zero: 'Ninguna tarea',
    );
    return '$_temp0';
  }

  @override
  String get groupUpcoming => 'Próximamente';

  @override
  String get groupNothingPlanned => 'Nada previsto';

  @override
  String get groupNoEventTitle => 'Ningún evento';

  @override
  String get groupNoEventMessage =>
      'Propón una fecha al grupo: cada persona responderá sí, quizá o no.';

  @override
  String get groupProposeDate => 'Proponer una fecha';

  @override
  String get groupTasksToDo => 'Tareas pendientes';

  @override
  String get groupNoTaskTitle => 'Ninguna tarea abierta';

  @override
  String get groupNoTaskMessage =>
      'Repartid lo que hay que hacer: cada persona verá su parte.';

  @override
  String get groupAddTask => 'Añadir una tarea';

  @override
  String get groupAdd => 'Añadir';

  @override
  String get groupAddToGroup => 'Añadir al grupo';

  @override
  String groupCreationSheetIntro(String name) {
    return 'Lo que crees aquí se compartirá con «$name».';
  }

  @override
  String get groupMembers => 'Miembros';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
      zero: 'Ningún miembro',
    );
    return '$_temp0';
  }

  @override
  String get taskStatusTodo => 'Pendiente';

  @override
  String get taskStatusDone => 'Terminada';

  @override
  String get taskStatusOverdue => 'Atrasada';

  @override
  String get taskPriorityLow => 'Baja';

  @override
  String get taskPriorityMedium => 'Normal';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskAssigneePending => 'En espera';

  @override
  String get taskAssigneeAccepted => 'Aceptada';

  @override
  String get taskAssigneeDeclined => 'Rechazada';

  @override
  String get taskAccept => 'Aceptar';

  @override
  String get taskDecline => 'Rechazar';

  @override
  String taskListProgress(int checked, int total) {
    return '$checked de $total artículos';
  }

  @override
  String get eventAnswerYes => 'Sí';

  @override
  String get eventAnswerMaybe => 'Quizá';

  @override
  String get eventAnswerNo => 'No';

  @override
  String get eventAnswerPending => 'En espera';

  @override
  String get errorGeneric =>
      'Se ha producido un error. Reinténtalo en un momento.';

  @override
  String get errorNetwork =>
      'Sin conexión. Comprueba tu acceso a internet y vuelve a intentarlo.';

  @override
  String get errorForbidden =>
      'No tienes los permisos necesarios para esta acción.';

  @override
  String get errorNotSaved =>
      'No se han podido guardar los datos. Reinténtalo en un momento.';

  @override
  String get coreAujourdHui => 'Hoy';

  @override
  String get coreInstant => 'ahora mismo';

  @override
  String coreDateLabelTimeLabel(Object dateLabel, Object timeLabel) {
    return '$dateLabel · $timeLabel';
  }

  @override
  String get coreVoirMembres => 'Ver todos los miembros';

  @override
  String get corePersonneNom => 'Nadie con ese nombre.';

  @override
  String get coreMarquerTacheCommeTerminee => 'Marcar la tarea como terminada';

  @override
  String authMessageDiagnosticRaw(Object _message, Object raw) {
    return '$_message\n\n[diagnóstico] $raw';
  }

  @override
  String get authEnvoiPhotoEchoueReessayez =>
      'No se ha podido subir la foto. Reinténtalo en un momento.';

  @override
  String get authIdentifiantsIncorrectsVerifiezSaisie =>
      'Credenciales incorrectas. Comprueba lo que has escrito y vuelve a intentarlo.';

  @override
  String get authAdresseEMailEncore =>
      'Tu correo electrónico aún no está verificado.';

  @override
  String get authAdresseEMailDeja =>
      'Este correo electrónico ya está en uso. Inicia sesión o elige otra dirección.';

  @override
  String get authCodeExpireDemandezNouveau =>
      'Este código ha caducado. Solicita uno nuevo.';

  @override
  String get authCodeIncorrectVerifiezSix =>
      'Código incorrecto. Comprueba los seis dígitos que has recibido por correo.';

  @override
  String get authTropTentativesPatientezMinute =>
      'Demasiados intentos. Espera un minuto antes de reintentarlo.';

  @override
  String get authMotPasseTropFaible =>
      'Esta contraseña es demasiado débil. Elige una más robusta.';

  @override
  String get authNouveauMotPasseDoit =>
      'La nueva contraseña debe ser distinta de la anterior.';

  @override
  String get authAucunCompteCorrespondInformations =>
      'Ninguna cuenta coincide con estos datos.';

  @override
  String get authSessionExpireReconnectez =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión.';

  @override
  String get authConnexionEchoueReessayezInstant =>
      'No se ha podido iniciar sesión. Reinténtalo en un momento.';

  @override
  String get authPseudoVientEtrePris =>
      'Este usuario acaba de ser ocupado. Elige otro.';

  @override
  String get authFonctionnaliteAttendMiseJour =>
      'Esta función está esperando una actualización de la base de datos. Reinténtalo más tarde o avísanos si persiste.';

  @override
  String get authChoisissezPseudo => 'Elige un nombre de usuario.';

  @override
  String authPseudoDoitContenirMoins(Object pseudoMinLength) {
    return 'El nombre de usuario debe tener al menos $pseudoMinLength caracteres.';
  }

  @override
  String authPseudoDoitDepasserPseudoMaxLength(Object pseudoMaxLength) {
    return 'El nombre de usuario no debe superar $pseudoMaxLength caracteres.';
  }

  @override
  String get authUniquementMinusculesChiffresPoints =>
      'Solo minúsculas, cifras y puntos.';

  @override
  String get authRenseignezAdresseEMail => 'Indica tu correo electrónico.';

  @override
  String get authAdresseEMailSemble =>
      'Este correo electrónico parece incompleto.';

  @override
  String get authChoisissezMotPasse => 'Elige una contraseña.';

  @override
  String authMoinsPasswordMinLengthCaracteresNecessaires(
    Object passwordMinLength,
  ) {
    return 'Se necesitan al menos $passwordMinLength caracteres.';
  }

  @override
  String get authAjoutezMoinsMajuscule => 'Añade al menos una mayúscula.';

  @override
  String get authAjoutezMoinsChiffre => 'Añade al menos una cifra.';

  @override
  String get authConnexionPseudoEncoreDisponible =>
      'Iniciar sesión con el nombre de usuario todavía no está disponible. Usa tu correo electrónico.';

  @override
  String get authMotPasseOublie => 'Contraseña olvidada';

  @override
  String get authIndiquezAdresseEMail =>
      'Indica tu correo electrónico: te enviaremos un código de seis dígitos para elegir una nueva.';

  @override
  String get authAdresseEMail => 'Correo electrónico';

  @override
  String get authEnvoyerCode => 'Enviar el código';

  @override
  String get authContentRevoir => 'Qué bien volver a verte';

  @override
  String get authConnectezRetrouverGroupesAgenda =>
      'Inicia sesión para recuperar tus grupos y tu agenda.';

  @override
  String get authPseudoAdresseEMail => 'Usuario o correo electrónico';

  @override
  String get authMotPasseOublie2 => '¿Has olvidado la contraseña?';

  @override
  String get authConnecter => 'Iniciar sesión';

  @override
  String get authEncoreCompte => '¿Todavía no tienes cuenta?';

  @override
  String get authInscrire => 'Registrarse';

  @override
  String get authSouvenirMoi => 'Recordarme';

  @override
  String get authResterezConnecteJusquDeconnexion =>
      'Seguirás con la sesión abierta hasta que cierres sesión.';

  @override
  String get authSerezDeconnecteFermetureApplication =>
      'Se cerrará tu sesión al cerrar la aplicación.';

  @override
  String get authJelvoInstalleEcranAccueil =>
      'Jelvo instalado en la pantalla de inicio tiene su propia sesión: iniciarla allí es un paso aparte de Safari, incluso con esta casilla marcada.';

  @override
  String get authRenseignezPseudoAdresseE =>
      'Indica tu nombre de usuario o tu correo electrónico.';

  @override
  String get authRenseignezMotPasse => 'Indica tu contraseña.';

  @override
  String get authNouveauMotPasse => 'Nueva contraseña';

  @override
  String get authSaisissezCodeRecuPuis =>
      'Escribe el código recibido y elige una nueva contraseña.';

  @override
  String authSaisissezCodeEnvoyeEmail(Object email) {
    return 'Escribe el código enviado a $email y elige una nueva contraseña.';
  }

  @override
  String get authCodeVerification => 'Código de verificación';

  @override
  String get auth8CaracteresMinimum => '8 caracteres como mínimo';

  @override
  String get authChangerMotPasse => 'Cambiar la contraseña';

  @override
  String get authRenvoyerCode => 'Reenviar el código';

  @override
  String get authEnvoiCours => 'Enviando…';

  @override
  String authNouveauCodePossibleSecondsLeft(Object _secondsLeft) {
    return 'Nuevo código disponible en $_secondsLeft s';
  }

  @override
  String get authSaisissezSixChiffresCode =>
      'Escribe los seis dígitos del código.';

  @override
  String get authMotPasseEteMis => 'Tu contraseña se ha actualizado.';

  @override
  String get authNouveauCodeVientEtre => 'Se acaba de enviar un nuevo código.';

  @override
  String get authCreerCompte => 'Crear tu cuenta';

  @override
  String get authChoisissezPseudoSecurisezCompte =>
      'Elige un nombre de usuario y protege tu cuenta.';

  @override
  String get authEtape12 => 'Paso 1 de 2';

  @override
  String get authCreantCompteAcceptezRecevoir =>
      'Al crear una cuenta, aceptas recibir un correo de verificación.';

  @override
  String get authAppelezComment => '¿Cómo te llamas?';

  @override
  String get authProchesReconnaitrontFacilement =>
      'Tus allegados te reconocerán más fácilmente.';

  @override
  String get authEtape22 => 'Paso 2 de 2';

  @override
  String get authCreerCompte2 => 'Crear mi cuenta';

  @override
  String get authRenseignezPrenom => 'Indica tu nombre.';

  @override
  String get authRenseignezNom => 'Indica tus apellidos.';

  @override
  String authCompteCreeMaisProfil(Object warning) {
    return 'Cuenta creada, pero no se ha podido guardar el perfil: $warning';
  }

  @override
  String get authVerifiezEMail => 'Comprueba tu correo';

  @override
  String get authSaisissezCodeSixChiffres =>
      'Escribe el código de seis dígitos que acabamos de enviarte.';

  @override
  String get authChoisirPhotoProfil => 'Elegir una foto de perfil';

  @override
  String get authOuvertureGalerie => 'Abriendo la galería…';

  @override
  String get authRetirerPhoto => 'Quitar la foto';

  @override
  String get authAjouterPhotoFacultatif => 'Añadir una foto (opcional)';

  @override
  String get authPhotoPuEtreOuverte =>
      'No se ha podido abrir la foto. Reinténtalo.';

  @override
  String get authMotPasse => 'Contraseña';

  @override
  String get authMotPasse2 => 'Tu contraseña';

  @override
  String get authAfficherMotPasse => 'Mostrar la contraseña';

  @override
  String get authMasquerMotPasse => 'Ocultar la contraseña';

  @override
  String get authMajuscule => 'Una mayúscula';

  @override
  String get authChiffre => 'Una cifra';

  @override
  String get authPseudoDejaPris => 'Este nombre de usuario ya está ocupado.';

  @override
  String get authPseudoDisponible => 'Este nombre de usuario está disponible.';

  @override
  String get authCodeVerificationSixChiffres =>
      'Código de verificación de seis dígitos';

  @override
  String get availabilityChaqueSemaine => 'Cada semana';

  @override
  String get availabilityDatePrecise => 'Una fecha concreta';

  @override
  String get availabilityCreneauPuEtreEnregistre =>
      'No se ha podido guardar el intervalo. Reinténtalo en un momento.';

  @override
  String get availabilityDisponibilites => 'Mi disponibilidad';

  @override
  String get availabilityNouveauCreneau => 'Nuevo intervalo';

  @override
  String get availabilityDisponibilitesIndisponibles =>
      'Disponibilidad no accesible';

  @override
  String get availabilitySemaineType => 'Mi semana tipo';

  @override
  String get availabilityCreneauxReviennentChaqueSemaine =>
      'Intervalos que se repiten cada semana';

  @override
  String get availabilityAucunCreneauRecurrentRien =>
      'Ningún intervalo recurrente. Sin nada declarado, los demás te ven como «Desconocido».';

  @override
  String get availabilityDatePrecisePrimeSemaine =>
      'Una fecha concreta, que prevalece sobre la semana tipo';

  @override
  String get availabilityAucuneExceptionJourConge =>
      'Ninguna excepción. Un día libre o un viaje se pone aquí.';

  @override
  String get availabilityAjouterCreneau => 'Añadir un intervalo';

  @override
  String get availabilityContactsMembresGroupesVoient =>
      'Tus contactos y los miembros de tus grupos solo ven «Disponible», «No disponible» o «Desconocido». Nunca tus horarios, nunca el motivo.';

  @override
  String get availabilityModifierCreneau => 'Modificar el intervalo';

  @override
  String get availabilitySupprimerCreneau => 'Eliminar el intervalo';

  @override
  String get availabilityCreneauSupprime => 'Intervalo eliminado.';

  @override
  String get availabilityCreneauExisteListeVa =>
      'Este intervalo ya no existe. La lista se va a actualizar.';

  @override
  String get availabilityAjouterCreneau2 => 'Añadir el intervalo';

  @override
  String get availabilityChoisissezDateCreneau =>
      'Elige la fecha del intervalo.';

  @override
  String get availabilityFinDoitSuivreDebut =>
      'El final debe ir después del inicio.';

  @override
  String get availabilityCreneauModifie => 'Intervalo modificado.';

  @override
  String get availabilityCreneauAjoute => 'Intervalo añadido.';

  @override
  String get availabilityDisponible => '¿Quién está disponible?';

  @override
  String get availabilityHeureChoisieVoyezQu =>
      'A la hora elegida. Solo ves una palabra, nunca sus intervalos.';

  @override
  String get availabilityDisponibilitesIndisponiblesInstant =>
      'La disponibilidad no está accesible por ahora.';

  @override
  String get calendarJours => 'Todos los días';

  @override
  String get calendarToutesSemaines => 'Todas las semanas';

  @override
  String get calendarToutesDeuxSemaines => 'Cada dos semanas';

  @override
  String get calendarMois => 'Todos los meses';

  @override
  String get calendarAns => 'Todos los años';

  @override
  String get calendar10MinutesAvant => '10 minutos antes';

  @override
  String get calendar1HeureAvant => '1 hora antes';

  @override
  String get calendarVeille => 'El día anterior';

  @override
  String get calendar1SemaineAvant => '1 semana antes';

  @override
  String calendarMinutesMin(Object minutes) {
    return '$minutes min';
  }

  @override
  String get calendarEvenementPuEtreCree =>
      'No se ha podido crear el evento. Reinténtalo en un momento.';

  @override
  String get calendarEvenementPuEtreModifie =>
      'No se ha podido modificar el evento. Reinténtalo en un momento.';

  @override
  String get calendarSemainePrecedente => 'Semana anterior';

  @override
  String get calendarSemaineSuivante => 'Semana siguiente';

  @override
  String get calendarRienFiltres => 'Nada con estos filtros';

  @override
  String get calendarFiltrePoseJourneeEntiere =>
      'Hay un filtro puesto: el día completo puede contener otra cosa.';

  @override
  String get calendarNiEvenementNiTache =>
      'Ni evento, ni tarea, ni intervalo declarado para este día.';

  @override
  String get calendarCreerEvenement => 'Crear un evento';

  @override
  String get calendarModifierEvenement => 'Modificar el evento';

  @override
  String get calendarSupprimerEvenement => 'Eliminar el evento';

  @override
  String get calendarEvenementIntrouvable => 'Evento no encontrado';

  @override
  String get calendarEteSupprimeAvezAcces =>
      'Se ha eliminado, o ya no tienes acceso.';

  @override
  String get calendarNonPrecise => 'Sin especificar';

  @override
  String get calendarReponse => 'Tu respuesta';

  @override
  String get calendarPersonneEncoreEteConvie =>
      'Todavía no se ha invitado a nadie.';

  @override
  String get calendarEteSupprimeAvezAcces2 =>
      'Se ha eliminado, o ya no tienes acceso. No queda nada por confirmar.';

  @override
  String get calendarRevenirCalendrier => 'Volver al calendario';

  @override
  String get calendarMembre => 'Un miembro';

  @override
  String get calendarConvieEvenement => 'te invita a un evento';

  @override
  String get calendarPropos => 'Acerca de';

  @override
  String get calendarCetEvenementDejaEu => 'Este evento ya ha tenido lugar.';

  @override
  String get calendarSerez => '¿Vas a ir?';

  @override
  String get calendarVoirDetailEvenement => 'Ver el detalle del evento';

  @override
  String get calendarCreneauxDeclaresFondJournee =>
      'Los intervalos declarados, como fondo del día. No dependen de ningún grupo.';

  @override
  String get calendarEvenementTache => 'Un evento, una tarea…';

  @override
  String get calendarDeuxLettresSuffisentChercher =>
      'Con dos letras basta para buscar.';

  @override
  String get calendarTitre => 'Título *';

  @override
  String get calendarExDejeunerChezCamille => 'Ej.: Comida en casa de Camille';

  @override
  String get calendarExPetitComptoir => 'Ej.: Le Petit Comptoir';

  @override
  String get calendarEffacerLieu => 'Borrar el lugar';

  @override
  String get calendarQuFautSavoirQu =>
      'Lo que hay que saber, lo que hay que llevar';

  @override
  String get calendarInviterMembresGroupe => 'Invitar a miembros del grupo';

  @override
  String get calendarJelvoPreviendraParticipants =>
      'Jelvo avisará a los participantes';

  @override
  String get calendarRendezReguliers => 'Para las citas periódicas';

  @override
  String get calendarEnregistrerModifications => 'Guardar los cambios';

  @override
  String get calendarCreerEvenement2 => 'Crear el evento';

  @override
  String get calendarDate => 'Fecha *';

  @override
  String get calendarHeure => 'Hora *';

  @override
  String get calendarMembres => 'Todos los miembros';

  @override
  String get calendarSelectionMembresGroupeConvies =>
      'Sin selección, se invita a todos los miembros del grupo.';

  @override
  String get calendarDonnezTitreEvenement => 'Pon un título al evento.';

  @override
  String get calendarEvenementEteModifie => 'El evento se ha modificado.';

  @override
  String calendarEvenementTitreEteCree(Object titre) {
    return 'El evento «$titre» se ha creado.';
  }

  @override
  String get calendarQuelGroupe => '¿En qué grupo? *';

  @override
  String get calendarSeulVerrez => 'Solo lo verás tú';

  @override
  String get calendarQuelGroupe2 => '¿En qué grupo?';

  @override
  String chatMoMo(Object mo) {
    return '$mo MB';
  }

  @override
  String chatOuiOui(Object oui) {
    return '$oui sí';
  }

  @override
  String chatPeutEtrePeutEtre(Object peutEtre) {
    return '$peutEtre quizá';
  }

  @override
  String chatNonNon(Object non) {
    return '$non no';
  }

  @override
  String get chatAucuneReponse => 'Ninguna respuesta';

  @override
  String get chatQuelqu => 'Alguien';

  @override
  String get chatMessagePuEtreEnvoye =>
      'No se ha podido enviar el mensaje. Reinténtalo en un momento.';

  @override
  String get chatConversationIndisponible => 'Conversación no disponible';

  @override
  String get chatRienEncore => 'Nada todavía';

  @override
  String get chatLancezConversationPersonneEncore =>
      'Empieza la conversación: aún nadie ha escrito aquí.';

  @override
  String chatReagirEmoji(Object emoji) {
    return 'Reaccionar $emoji';
  }

  @override
  String get chatSupprimerMessage => 'Eliminar el mensaje';

  @override
  String get chatPouvezSupprimerMessages => 'Solo puedes eliminar tus mensajes';

  @override
  String get chatMessageSupprime => 'Mensaje eliminado.';

  @override
  String get chatMessagePeutEtreSupprime =>
      'Este mensaje ya no se puede eliminar.';

  @override
  String get chatNouvelleTache => 'Nueva tarea';

  @override
  String get chatCreerTacheFaire => 'Crear una tarea pendiente';

  @override
  String get chatPlanifierEvenement => 'Planificar un evento';

  @override
  String get chatPhotoVideo => 'Foto o vídeo';

  @override
  String get chatEnvoyerMedia => 'Enviar un archivo';

  @override
  String get chatRienPrevuInstant => 'Nada previsto por ahora';

  @override
  String get chatPhotoGalerie => 'Foto de la galería';

  @override
  String get chatPrendrePhoto => 'Hacer una foto';

  @override
  String get chatVideoGalerie => 'Vídeo de la galería';

  @override
  String get chatMediaPuEtreLu =>
      'No se ha podido leer este archivo. Reinténtalo.';

  @override
  String get chatNonEnvoyeReessayer => 'No enviado: reintentar';

  @override
  String get chatMessageSupprime2 => 'Mensaje eliminado';

  @override
  String get chatTacheEteSupprimee => 'Esta tarea se ha eliminado.';

  @override
  String get chatDesister => 'Dejarla';

  @override
  String get chatProposeeGroupePersonneEncore =>
      'Propuesta al grupo: nadie la ha tomado todavía.';

  @override
  String get chatCetEvenementEteSupprime => 'Este evento se ha eliminado.';

  @override
  String get chatTresBienTacheReste =>
      'De acuerdo: la tarea sigue propuesta al grupo.';

  @override
  String get chatMicrophoneAccessibleAutorisezReglages =>
      'El micrófono no está accesible. Permítelo en los ajustes de tu navegador y vuelve a abrir la conversación.';

  @override
  String get chatAjouterConversation => 'Añadir a la conversación';

  @override
  String get chatMessage => 'Tu mensaje';

  @override
  String get chatFermerEmojis => 'Cerrar los emojis';

  @override
  String get chatEnregistrerMessageVocal => 'Grabar un mensaje de voz';

  @override
  String get chatAnnulerEnregistrement => 'Cancelar la grabación';

  @override
  String get chatEnregistrement => 'Grabando…';

  @override
  String get chatEnvoyerMessageVocal => 'Enviar el mensaje de voz';

  @override
  String get chatPlusieursPersonnesTrainEcrire =>
      'Varias personas están escribiendo…';

  @override
  String get chatMettrePause => 'Pausar';

  @override
  String get contactsDemandeEnvoyee => 'Solicitud enviada.';

  @override
  String get contactsPersonneFaitDejaPartie =>
      'Esta persona ya es uno de tus contactos.';

  @override
  String get contactsDemandeDejaAttente => 'Ya hay una solicitud pendiente.';

  @override
  String get contactsPouvezAjouterMeme => 'No puedes añadirte a ti mismo.';

  @override
  String get contactsQRCode => 'Mi código QR';

  @override
  String get contactsCherchezPseudo => 'Busca un nombre de usuario';

  @override
  String get contactsSaisissezMoinsDeuxCaracteres =>
      'Escribe al menos dos caracteres para encontrar a alguien, o escanea su código QR.';

  @override
  String get contactsRechercheIndisponible => 'Búsqueda no disponible';

  @override
  String get contactsAucunResultat => 'Ningún resultado';

  @override
  String contactsAucunPseudoCommenceTerm(Object term) {
    return 'Ningún nombre de usuario empieza por «$term».';
  }

  @override
  String get contactsDejaCarnet => 'Ya está en tus contactos';

  @override
  String get contactsContacts => 'Mis contactos';

  @override
  String get contactsRechercherContact => 'Buscar un contacto';

  @override
  String get contactsDemandesRecues => 'Solicitudes recibidas';

  @override
  String get contactsCarnetIndisponible => 'Contactos no disponibles';

  @override
  String get contactsCarnetVide => 'Sin contactos';

  @override
  String get contactsAjoutezProchesLeurPseudo =>
      'Añade a tus allegados por su nombre de usuario o escaneando su código QR para planificar juntos.';

  @override
  String contactsAucunContactCorrespondQuery(Object query) {
    return 'Ningún contacto coincide con «$query».';
  }

  @override
  String get contactsDemandeRefusee => 'Solicitud rechazada.';

  @override
  String get contactsFaitesScannerCodeEtre =>
      'Deja que escaneen este código para que te añadan como contacto. Solo contiene tu nombre de usuario: ni correo, ni agenda.';

  @override
  String get contactsPartagerPseudo => 'Compartir mi nombre de usuario';

  @override
  String get contactsPseudoJelvo => 'Mi usuario de Jelvo';

  @override
  String get contactsScannerQRCode => 'Escanear un código QR';

  @override
  String get contactsScanIndisponibleIci => 'Escaneo no disponible aquí';

  @override
  String get contactsChercherPseudo => 'Buscar por nombre de usuario';

  @override
  String get contactsCameraInaccessible => 'Cámara no accesible';

  @override
  String get contactsAutorisezAccesCameraScanner =>
      'Permite el acceso a la cámara para escanear un código QR.';

  @override
  String get contactsVisezQRCodeProche =>
      'Apunta al código QR de alguien para enviarle una solicitud de contacto.';

  @override
  String get contactsQRCodeProfilJelvo =>
      'Este código QR no es un perfil de Jelvo.';

  @override
  String contactsAucunComptePortePseudo(Object pseudo) {
    return 'Ninguna cuenta tiene el nombre de usuario @$pseudo.';
  }

  @override
  String get contactsScannerQRCode2 => 'Escanear un código QR';

  @override
  String get contactsAjouterContactQRCode =>
      'Añadir un contacto con su código QR';

  @override
  String get contactsRechercherPseudo => 'Buscar un nombre de usuario';

  @override
  String get contactsTrouverUtilisateurJelvo =>
      'Encontrar a un usuario de Jelvo';

  @override
  String get contactsInviterAmi => 'Invitar a un amigo';

  @override
  String get contactsEnvoyerInvitationJelvo => 'Enviar una invitación de Jelvo';

  @override
  String get contactsRejoignezMoiJelvo => 'Únete a mí en Jelvo';

  @override
  String get contactsRetirerFavoris => 'Quitar de favoritos';

  @override
  String get contactsAjouterFavoris => 'Añadir a favoritos';

  @override
  String get contactsFavorisTeteCarnet =>
      'Los favoritos van al principio de tus contactos';

  @override
  String get contactsRetirerContacts => 'Quitar de mis contactos';

  @override
  String get contactsRelationSupprimeeDeuxCotes =>
      'La relación se elimina por ambas partes';

  @override
  String get contactsRetirerContact => 'Quitar este contacto';

  @override
  String get contactsGererFavoris => 'Gestionar los favoritos';

  @override
  String get contactsFavoriPersonnelAutreSait =>
      'El favorito es personal: la otra persona no lo sabe.';

  @override
  String get contactsAjoutezAbordContactsEpingler =>
      'Añade primero contactos para fijar.';

  @override
  String get contactsEpinglezProchesRetrouverIci =>
      'Fija a tus allegados para encontrarlos aquí.';

  @override
  String get contactsScanQRCodeDemande =>
      'Escanear un código QR necesita una cámara: está disponible en la aplicación móvil. Aquí, busca a la persona por su nombre de usuario.';

  @override
  String get createCreneauAgendaSeulPartage =>
      'Un hueco en tu agenda, solo o compartido';

  @override
  String get createActionFaireEcheanceResponsable =>
      'Algo que hacer, con fecha límite y responsable';

  @override
  String get createEspacePartageProchesAmis =>
      'Un espacio compartido con tus allegados o tus amigos';

  @override
  String get createChoisissezTypeFormulaireOuvre =>
      'Elige un tipo: el formulario se abre justo debajo.';

  @override
  String get groupsLienInvitationExisteValable =>
      'Este enlace de invitación no existe o ya no es válido.';

  @override
  String get groupsLienInvitationExpireDemandez =>
      'Este enlace de invitación ha caducado. Pide uno nuevo al grupo.';

  @override
  String get groupsLienInvitationEteRevoque =>
      'El grupo ha revocado este enlace de invitación.';

  @override
  String get groupsLienDejaServiNombre =>
      'Este enlace ya se ha usado el número de veces previsto.';

  @override
  String get groupsAvezRejointGroupe => 'Te has unido al grupo.';

  @override
  String get groupsFaitesDejaPartieGroupe => 'Ya formas parte de este grupo.';

  @override
  String get groupsLienInvitationExpire =>
      'Este enlace de invitación ha caducado.';

  @override
  String get groupsLienInvitationEteRevoque2 =>
      'Este enlace de invitación se ha revocado.';

  @override
  String get groupsConnectezRejoindreGroupe =>
      'Inicia sesión para unirte a este grupo.';

  @override
  String get groupsAvezQuitteGroupe => 'Has salido del grupo.';

  @override
  String get groupsAvezQuitteGroupeAncien =>
      'Has salido del grupo. El miembro más antiguo pasa a ser administrador.';

  @override
  String get groupsEtiezDernierMembreGroupe =>
      'Eras el último miembro: el grupo se ha eliminado.';

  @override
  String get groupsFaitesPartieGroupe => 'No formas parte de este grupo.';

  @override
  String groupsNomDesormaisAdministrateur(Object nom) {
    return '$nom ya es administrador.';
  }

  @override
  String groupsNomAdministrateur(Object nom) {
    return '$nom ya no es administrador.';
  }

  @override
  String groupsNomEteRetireGroupe(Object nom) {
    return '$nom se ha quitado del grupo.';
  }

  @override
  String groupsAdhesionNomDesormaisTemporaire(Object nom) {
    return 'La pertenencia de $nom ahora es temporal.';
  }

  @override
  String groupsNomFaitPartieGroupe(Object nom, Object terme) {
    return '$nom forma parte del grupo hasta el $terme.';
  }

  @override
  String groupsAdhesionNomTerme(Object nom) {
    return 'La pertenencia de $nom ya no tiene fecha de fin.';
  }

  @override
  String get groupsEtaitDejaCasRien => 'Ya era así, no ha cambiado nada.';

  @override
  String get groupsDateDejaPasseeDepart =>
      'Esa fecha ya ha pasado. Para una salida inmediata, usa «Quitar del grupo».';

  @override
  String groupsNomDejaAdministrateur(Object nom) {
    return '$nom ya es administrador.';
  }

  @override
  String get groupsGroupeDoitGarderMoins =>
      'Un grupo debe conservar al menos un administrador. Nombra antes a otra persona.';

  @override
  String get groupsSeulAdministrateurGroupePeut =>
      'Solo un administrador del grupo puede hacerlo.';

  @override
  String groupsNomAdministrateur2(Object nom) {
    return '$nom no es administrador.';
  }

  @override
  String groupsNomFaitPartieGroupe2(Object nom) {
    return '$nom ya no forma parte del grupo.';
  }

  @override
  String get groupsPartirMemeUtilisezQuitter =>
      'Para salir tú, usa «Salir del grupo».';

  @override
  String get groupsActionAboutiReessayezInstant =>
      'La acción no se ha completado. Reinténtalo en un momento.';

  @override
  String get groupsJamaisUtilise => 'Nunca usado';

  @override
  String get groupsInvitationDejaAcceptee => 'Invitación ya aceptada';

  @override
  String get groupsInvitationDejaRefusee => 'Invitación ya rechazada';

  @override
  String get groupsInvitationExpiree => 'Invitación caducada';

  @override
  String get groupsEtesDejaMembre => 'Ya eres miembro';

  @override
  String get groupsGroupeSupprime => 'Grupo eliminado';

  @override
  String get groupsInvitationIntrouvable => 'Invitación no encontrada';

  @override
  String get groupsAvezDejaRejointGroupe =>
      'Ya te has unido a este grupo. Ábrelo para encontrar sus eventos, sus tareas y su conversación.';

  @override
  String get groupsAvezDeclineInvitationDemandez =>
      'Has rechazado esta invitación. Pide otra si cambias de opinión.';

  @override
  String get groupsInvitationPasseDateLimite =>
      'Esta invitación ha pasado su fecha límite. Pide una nueva al grupo.';

  @override
  String get groupsFaitesDejaPartieGroupe2 =>
      'Ya formas parte de este grupo, probablemente por un enlace compartido.';

  @override
  String get groupsGroupeInvitaitEteSupprime =>
      'El grupo que te invitaba se ha eliminado. Ya no hay nada a lo que unirse.';

  @override
  String get groupsInvitationExisteEtaitDestinee =>
      'Esta invitación no existe, o no era para ti.';

  @override
  String get groupsGroupe => 'este grupo';

  @override
  String get groupsGroupePuEtreCree =>
      'No se ha podido crear el grupo. Reinténtalo en un momento.';

  @override
  String get groupsGroupeIndisponible => 'Grupo no disponible';

  @override
  String get groupsGroupeIntrouvable => 'Grupo no encontrado';

  @override
  String get groupsGroupeEteSupprimeFaites =>
      'Este grupo se ha eliminado, o ya no formas parte de él.';

  @override
  String get groupsRevenirGroupes => 'Volver a los grupos';

  @override
  String get groupsInviterQuelqu => 'Invitar a alguien';

  @override
  String get groupsPartagerLien => 'Compartir un enlace';

  @override
  String get groupsModifierGroupe => 'Modificar el grupo';

  @override
  String get groupsQuitterGroupe => 'Salir del grupo';

  @override
  String get groupsSupprimerGroupe => 'Eliminar el grupo';

  @override
  String get groupsAucunMembreAfficher => 'Ningún miembro que mostrar';

  @override
  String get groupsListeMembresPuEtre =>
      'No se ha podido cargar la lista de miembros. Reinténtalo en un momento.';

  @override
  String get groupsVoir => 'Ver todo';

  @override
  String get groupsAjouterEvenement => 'Añadir un evento';

  @override
  String get groupsTachesPrioritaires => 'Tareas prioritarias';

  @override
  String get groupsRetirerMembre => 'Quitar a este miembro';

  @override
  String get groupsGroupeEteSupprime => 'El grupo se ha eliminado.';

  @override
  String get groupsDecrivezGroupePhrase => 'Describe este grupo en una frase.';

  @override
  String get groupsInviterMembre => 'Invitar a un miembro';

  @override
  String get groupsCherchezPersonnePseudoRecevra =>
      'Busca a la persona por su nombre de usuario. Recibirá una invitación para aceptar.';

  @override
  String groupsNameRecuInvitation(Object name) {
    return '$name ha recibido tu invitación.';
  }

  @override
  String groupsNameFaitDejaPartie(Object name) {
    return '$name ya forma parte del grupo.';
  }

  @override
  String groupsNameDejaInvitationAttente(Object name) {
    return '$name ya tiene una invitación pendiente.';
  }

  @override
  String get groupsDateFinChoisieDeja =>
      'La fecha de fin elegida ya ha pasado.';

  @override
  String get groupsSeulAdministrateurPeutFixer =>
      'Solo un administrador puede fijar una duración de pertenencia.';

  @override
  String get groupsSeulsMembresGroupePeuvent =>
      'Solo los miembros del grupo pueden invitar.';

  @override
  String get groupsSaisissezMoinsDeuxCaracteres =>
      'Escribe al menos dos caracteres.';

  @override
  String get groupsCreezGroupeInvitezPremiers =>
      'Crea tu grupo e invita a los primeros miembros.';

  @override
  String get groupsPhotoGroupe => 'Foto del grupo';

  @override
  String get groupsNomGroupe => 'Nombre del grupo *';

  @override
  String get groupsExFamilleRousseau => 'Ej.: Familia Rousseau';

  @override
  String get groupsDescriptionOptionnelle => 'Descripción (opcional)';

  @override
  String get groupsDecrivezBrievementButGroupe =>
      'Describe brevemente para qué sirve este grupo';

  @override
  String get groupsCreerGroupe => 'Crear el grupo';

  @override
  String get groupsDonnezNomGroupe => 'Pon un nombre a tu grupo.';

  @override
  String groupsNomDoitDepasserNameMaxLength(Object _nameMaxLength) {
    return 'El nombre no debe superar $_nameMaxLength caracteres.';
  }

  @override
  String get groupsGroupeCree1Invitation =>
      'Grupo creado, 1 invitación enviada.';

  @override
  String groupsGroupeCreeEnvoyeesInvitations(Object envoyees) {
    return 'Grupo creado, $envoyees invitaciones enviadas.';
  }

  @override
  String get groupsGroupeCreeMaisInvitation =>
      'Grupo creado, pero la invitación no ha podido salir.';

  @override
  String groupsGroupeCreeMaisAucune(Object echecs) {
    return 'Grupo creado, pero ninguna de las $echecs invitaciones ha podido salir.';
  }

  @override
  String groupsGroupeCreeEnvoyeesInvitation(Object envoyees, Object echecs) {
    return 'Grupo creado, $envoyees invitación(es) enviada(s), $echecs no enviadas.';
  }

  @override
  String get groupsGroupePrive => 'Grupo privado';

  @override
  String get groupsSeulsMembresInvitesPourront =>
      'Solo los miembros invitados podrán unirse y ver su contenido. Todos los grupos de Jelvo lo son.';

  @override
  String get groupsRechercherGroupe => 'Buscar un grupo';

  @override
  String get groupsEffacerRecherche => 'Borrar la búsqueda';

  @override
  String get groupsGroupesIndisponibles => 'Grupos no disponibles';

  @override
  String get groupsAucunGroupeMoment => 'Ningún grupo por ahora';

  @override
  String get groupsCreezGroupePartagerAgenda =>
      'Crea un grupo para compartir una agenda y repartir las tareas con tus allegados.';

  @override
  String get groupsCreerGroupe2 => 'Crear un grupo';

  @override
  String get groupsAucunGroupeNom => 'Ningún grupo con ese nombre';

  @override
  String groupsAucunGroupesCorrespondTerme(Object terme) {
    return 'Ninguno de tus grupos coincide con «$terme».';
  }

  @override
  String get groupsInviteRejoindreGroupe =>
      'Te han invitado a unirte a un grupo.';

  @override
  String get groupsInvitationsIndisponibles => 'Invitaciones no disponibles';

  @override
  String get groupsAucuneInvitation => 'Ninguna invitación';

  @override
  String get groupsQuandProcheInviteraGroupe =>
      'Cuando alguien te invite a un grupo, la invitación aparecerá aquí.';

  @override
  String get groupsInvitationIndisponible => 'Invitación no disponible';

  @override
  String get groupsInviteRejoindreGroupe2 => 'te invita a unirte a un grupo';

  @override
  String get groupsCree => 'Creado el';

  @override
  String get groupsDejaGroupe => 'Ya en el grupo';

  @override
  String get groupsInvitationRefusee => 'Invitación rechazada.';

  @override
  String get groupsOuvrirGroupe => 'Abrir el grupo';

  @override
  String get groupsLienInutilisable => 'Enlace no utilizable';

  @override
  String get groupsRevenirAccueil => 'Volver al inicio';

  @override
  String get groupsEtesInviteRejoindreGroupe =>
      'Te invitan a unirte a este grupo en Jelvo.';

  @override
  String get groupsRejoindreGroupe => 'Unirse al grupo';

  @override
  String get groupsCreerCompteRejoindre => 'Crear una cuenta para unirse';

  @override
  String get groupsAiDejaCompte => 'Ya tengo una cuenta';

  @override
  String get groupsGroupeSeraRejointAutomatiquement =>
      'Te unirás al grupo automáticamente en cuanto se cree tu cuenta.';

  @override
  String get groupsCreezIciSeraPartage =>
      'Lo que crees aquí se compartirá con el grupo.';

  @override
  String get groupsDateProposerMembres =>
      'Una fecha que proponer a los miembros';

  @override
  String get groupsQuelqueChoseFaireRepartir => 'Algo que hacer, para repartir';

  @override
  String get groupsAjouterMembres => 'Añadir miembros';

  @override
  String get groupsChoisirContacts => 'Elegir entre mis contactos';

  @override
  String get groupsParcourirCarnetJelvo => 'Ver mis contactos de Jelvo';

  @override
  String get groupsInviterLien => 'Invitar por enlace';

  @override
  String get groupsProposeApresCreation => 'Se propone tras la creación';

  @override
  String get groupsPartagerLienInvitation =>
      'Compartir un enlace de invitación';

  @override
  String get groupsInvitationsPartentCreationGroupe =>
      'Las invitaciones salen al crear el grupo.';

  @override
  String get groupsAucunContactNom => 'Ningún contacto con ese nombre.';

  @override
  String get groupsPersonneInviteInstant => 'Por ahora no hay nadie invitado.';

  @override
  String get groups1PersonneSeraInvitee => 'Se invitará a 1 persona.';

  @override
  String groupsNombrePersonnesSerontInvitees(Object nombre) {
    return 'Se invitará a $nombre personas.';
  }

  @override
  String get groupsRetirer => 'Quitar todo';

  @override
  String get groupsCarnetVideInstantPourrez =>
      'Tus contactos están vacíos por ahora. Podrás invitar desde la pantalla del grupo, por enlace compartido o por nombre de usuario.';

  @override
  String get groupsChoisirPhotoGroupe => 'Elegir una foto de grupo';

  @override
  String get groupsChangerPhoto => 'Cambiar la foto';

  @override
  String get groupsAjouterPhoto => 'Añadir una foto';

  @override
  String get groupsTachesNenRetard => 'tareas\natrasadas';

  @override
  String get groupsEvenementsNaVenir => 'eventos\npróximos';

  @override
  String get groupsAucunLienActifMoment => 'Ningún enlace activo por ahora.';

  @override
  String get groupsDureeAccordeeProchainLien =>
      'Duración que concede el próximo enlace';

  @override
  String get groupsGenererLien => 'Generar un enlace';

  @override
  String get groupsGenererAutreLien => 'Generar otro enlace';

  @override
  String get groupsLienCopiePressePapiers => 'Enlace copiado al portapapeles.';

  @override
  String get groupsCopierLien => 'Copiar el enlace';

  @override
  String get groupsRevoquerLien => 'Revocar el enlace';

  @override
  String get groupsGererMembre => 'Gestionar este miembro';

  @override
  String get groupsRetirerRoleAdministrateur =>
      'Quitar el rol de administrador';

  @override
  String get groupsNommerAdministrateur => 'Nombrar administrador';

  @override
  String get groupsModifierDureeAdhesion =>
      'Modificar la duración de la pertenencia';

  @override
  String get groupsRendreAdhesionTemporaire => 'Hacer la pertenencia temporal';

  @override
  String get groupsRetirerGroupe => 'Quitar del grupo';

  @override
  String get groupsDureeAdhesion => 'Duración de la pertenencia';

  @override
  String get groupsTerme => 'Sin fecha de fin';

  @override
  String get groupsFinAdhesion => 'Fin de la pertenencia';

  @override
  String get groupsNouvelleDuree => 'Nueva duración';

  @override
  String get homeBonApresMidi => 'Buenas tardes';

  @override
  String get homeCreezGroupePartagerAgenda =>
      'Crea un grupo para compartir una agenda, tareas y una conversación.';

  @override
  String homeBasePrenom(Object base, Object prenom) {
    return '$base, $prenom';
  }

  @override
  String get homeAgenda => 'Mi día';

  @override
  String get homeVoirCalendrier => 'Ver calendario';

  @override
  String get homeVoirAgenda1 => 'Ver todo mi día (1 más)';

  @override
  String homeVoirAgendaReste(Object reste) {
    return 'Ver todo mi día ($reste más)';
  }

  @override
  String get homeTaches => 'Mis tareas';

  @override
  String get homeVoirToutesTaches => 'Ver todas mis tareas';

  @override
  String get home1Tache => '1 tarea';

  @override
  String get homeSemaine => 'esta semana';

  @override
  String get homeTraiter => 'por resolver';

  @override
  String get homeAucuneTacheAttendEtre => 'Ninguna tarea está esperando.';

  @override
  String get homeDejaAgenda => 'Ya está en tu día';

  @override
  String get homeTachesJourFigurentChronologie =>
      'Tus tareas de hoy aparecen en la cronología de arriba.';

  @override
  String homeValeurLibelleDetail(Object valeur, Object libelle, Object detail) {
    return '$valeur $libelle, $detail';
  }

  @override
  String homeValeurLibelle(Object valeur, Object libelle) {
    return '$valeur $libelle';
  }

  @override
  String get homeAujourdHui => ', hoy';

  @override
  String get homeRienPrevu => ', nada previsto';

  @override
  String get notificationsGroupe => 'un grupo';

  @override
  String get notificationsContact => 'Un contacto';

  @override
  String get notificationsEvenement => 'un evento';

  @override
  String get notificationsTache => 'una tarea';

  @override
  String notificationsInvitationRejoindreGroupName(Object groupName) {
    return 'Invitación para unirse a $groupName';
  }

  @override
  String get notificationsDemandeContact => 'Solicitud de contacto';

  @override
  String notificationsSenderNameInviteRejoindreGroupName(
    Object senderName,
    Object groupName,
  ) {
    return '$senderName te invita a unirte a «$groupName».';
  }

  @override
  String notificationsSenderNameSouhaiteAjouterContacts(Object senderName) {
    return '$senderName quiere añadirte a sus contactos.';
  }

  @override
  String notificationsSenderNameConfieTache(Object senderName) {
    return '$senderName te ha encargado esta tarea.';
  }

  @override
  String notificationsSenderNameAccepteTache(Object senderName) {
    return '$senderName acepta esta tarea.';
  }

  @override
  String notificationsSenderNameDeclineTache(Object senderName) {
    return '$senderName rechaza esta tarea.';
  }

  @override
  String get notificationsFeteAnniversaireAujourdHui =>
      'celebra su cumpleaños hoy.';

  @override
  String get notificationsAvezNouvelleNotification =>
      'Tienes una nueva notificación.';

  @override
  String get notificationsVoirDemande => 'Ver la solicitud';

  @override
  String get notificationsVoirEvenement => 'Ver el evento';

  @override
  String get notificationsVoirTache => 'Ver la tarea';

  @override
  String get notificationsGroupesDiscussions => 'Grupos y conversaciones';

  @override
  String get notificationsTachesRappels => 'Tareas y recordatorios';

  @override
  String get notificationsMarquerCommeLu => 'Marcar leídas';

  @override
  String get notificationsNotificationsIndisponibles =>
      'Notificaciones no disponibles';

  @override
  String get notificationsAucuneNotification => 'Ninguna notificación';

  @override
  String get notificationsInvitationsGroupeDemandesContact =>
      'Las invitaciones a un grupo y las solicitudes de contacto aparecerán aquí.';

  @override
  String get notificationsNotificationsPush => 'Notificaciones push';

  @override
  String get notificationsInstaller => 'Hay que instalar';

  @override
  String get notificationsActiverNotifications => 'Activar las notificaciones';

  @override
  String get notificationsDesactiverCetAppareil =>
      'Desactivar en este dispositivo';

  @override
  String get notificationsNotificationsActives => 'Notificaciones activas';

  @override
  String get notificationsNotificationsRefusees => 'Notificaciones rechazadas';

  @override
  String get notificationsInstallezJelvoRecevoir =>
      'Instala Jelvo para recibirlas';

  @override
  String get notificationsNotificationsDesactivees =>
      'Notificaciones desactivadas';

  @override
  String get notificationsNotificationsIndisponiblesIci =>
      'Notificaciones no disponibles aquí';

  @override
  String get notificationsCetAppareilRecevraNotifications =>
      'Este dispositivo recibirá las notificaciones que dejes marcadas en los ajustes.';

  @override
  String get notificationsAvezRefuseAutorisationApplication =>
      'Has rechazado el permiso. La aplicación ya no puede volver a pedirlo: se reabre en los ajustes de tu navegador, en la línea «Notificaciones» del sitio.';

  @override
  String get notificationsIPhoneIPadNotificationsExistent =>
      'En iPhone y iPad, las notificaciones solo existen en Jelvo añadido a la pantalla de inicio. En una pestaña de Safari, el sistema no las ofrece.';

  @override
  String get notificationsNavigateurDemanderaAutorisationPourrez =>
      'Tu navegador te pedirá permiso. Podrás cambiarlo en cualquier momento.';

  @override
  String get notificationsVersionApplicationGereNotifications =>
      'Esta versión de la aplicación no admite notificaciones del sistema.';

  @override
  String get notificationsAutorisationRefuseeRouvreReglages =>
      'Permiso rechazado. Se reabre en los ajustes de tu navegador, no aquí.';

  @override
  String get notificationsNotificationsOntPuEtre =>
      'No se han podido activar las notificaciones.';

  @override
  String get notificationsNotificationsDesactiveesCetAppareil =>
      'Notificaciones desactivadas en este dispositivo.';

  @override
  String get notifications1TouchezBoutonPartager =>
      '1. Toca el botón Compartir de Safari.';

  @override
  String get notifications2ChoisissezEcranAccueil =>
      '2. Elige «Añadir a pantalla de inicio».';

  @override
  String get notifications3OuvrezJelvoDepuis =>
      '3. Abre Jelvo desde el icono y vuelve a iniciar sesión.';

  @override
  String get notificationsReconnexionErreurApplicationInstallee =>
      'Volver a iniciar sesión no es un error: la aplicación instalada tiene su propio almacenamiento, distinto de Safari.';

  @override
  String get onboardingBienvenueJelvo => 'Bienvenido a Jelvo';

  @override
  String get onboardingAppRassembleGroupesProjets =>
      'La app que reúne tus grupos, tus planes y a tus allegados.';

  @override
  String get onboardingGroupesMemeEndroit =>
      'Todos tus grupos en un mismo lugar';

  @override
  String get onboardingOrganisezProjetsActivitesEchanges =>
      'Organiza tus planes, actividades y conversaciones con facilidad.';

  @override
  String get onboardingAgendaPartageSynchronise =>
      'Una agenda compartida y sincronizada';

  @override
  String get onboardingManquezAucunEvenementImportant =>
      'No vuelvas a perderte ningún evento importante.';

  @override
  String get onboardingTachesClairesEfficaces => 'Tareas claras y eficaces';

  @override
  String get onboardingAttribuezSuivezAccomplissezEnsemble =>
      'Asignad, seguid y alcanzad juntos vuestros objetivos.';

  @override
  String get profileProposJelvo => 'Acerca de Jelvo';

  @override
  String get profileJelvoReunitGroupesEvenements =>
      'Jelvo reúne tus grupos, tus eventos, tus tareas y tu disponibilidad en un mismo lugar: para la familia, los amigos, el piso compartido.';

  @override
  String get profileBonSavoir => 'Conviene saber';

  @override
  String get profileJelvoApplicationWebInstallable =>
      'Jelvo es una aplicación web instalable. En iPhone, las notificaciones solo funcionan una vez añadido el icono a la pantalla de inicio, y la aplicación instalada tiene su propia sesión: hay que iniciarla allí.';

  @override
  String get profileChoisirAvatar => 'Elegir un avatar';

  @override
  String get profileUtiliserCetAvatar => 'Usar este avatar';

  @override
  String profileAvatarId(Object id) {
    return 'Avatar $id';
  }

  @override
  String get profileChangerMotPasse => 'Cambiar la contraseña';

  @override
  String get profileMotPasseChange => 'Contraseña cambiada.';

  @override
  String get profileModifierProfil => 'Editar el perfil';

  @override
  String get profileProfilEnregistre => 'Perfil guardado.';

  @override
  String get profileProfil => 'Mi perfil';

  @override
  String get profileProfilIndisponible => 'Perfil no disponible';

  @override
  String get profileProfilIntrouvable => 'Perfil no encontrado';

  @override
  String get profileProfilEncoreEteCree =>
      'Tu perfil aún no se ha creado. Vuelve a iniciar sesión para terminarlo.';

  @override
  String get profileProfilJelvo => 'Mi perfil de Jelvo';

  @override
  String get profileAutresVoientQuMot =>
      'Los demás solo ven una palabra: disponible, no disponible o desconocido.';

  @override
  String get profileLectureAboutiReessayezInstant =>
      'La carga no se ha completado. Reinténtalo en un momento.';

  @override
  String get profilePersonneCompteJelvo =>
      'Esta persona ya no tiene cuenta en Jelvo.';

  @override
  String get profileAnnulerDemande => 'Cancelar la solicitud';

  @override
  String get profileAjouterContact => 'Añadir como contacto';

  @override
  String get profileRetirerContact => '¿Quitar este contacto?';

  @override
  String get profileActionAbouti => 'La acción no se ha completado.';

  @override
  String get profileInformationsPersonnelles => 'Datos personales';

  @override
  String get profileDeconnecter => 'Cerrar sesión';

  @override
  String get profileDevrezSaisirNouveauIdentifiants =>
      'Tendrás que escribir otra vez tus credenciales para volver.';

  @override
  String get profileJourMoisSeulementJelvo =>
      'Solo el día y el mes. Jelvo no pide tu año de nacimiento.';

  @override
  String get profileContactsVoientPrevenusJour =>
      'Tus contactos lo ven y reciben un aviso ese mismo día.';

  @override
  String get profileAnneesNonBissextilesSera =>
      'En los años no bisiestos se celebrará el 28 de febrero, último día del mes.';

  @override
  String get profileSuitReglageTelephone => 'Sigue el ajuste de tu teléfono';

  @override
  String get profileFondBlancTexteSombre => 'Fondo blanco, texto oscuro';

  @override
  String get profileFondSombreTexteClair => 'Fondo oscuro, texto claro';

  @override
  String get profileChoixVautCetAppareil =>
      'Esta elección solo vale en este dispositivo.';

  @override
  String get profilePhotoProfil => 'Foto de perfil';

  @override
  String get profileChoisirPhoto => 'Elegir una foto';

  @override
  String get profileDepuisPhotosAppareil => 'Desde las fotos de tu dispositivo';

  @override
  String get profileChoisirAvatarJelvo => 'Elegir un avatar de Jelvo';

  @override
  String get profileQuatreVingtTreizeIllustrations =>
      'Noventa y tres ilustraciones para elegir';

  @override
  String get profileInitialesPrendrontPlace =>
      'Tus iniciales ocuparán su lugar';

  @override
  String get profileAjoutezJourMoisAnnee => 'Añade el día y el mes, sin el año';

  @override
  String get profileAdresseIndisponible => 'Dirección no disponible';

  @override
  String get profileQuelquesMots => 'Unas palabras sobre ti';

  @override
  String get profileAjoutezQuelquesMots => 'Añade unas palabras sobre ti';

  @override
  String get profileEnregistrerBio => 'Guardar la biografía';

  @override
  String get profileModifierBio => 'Editar la biografía';

  @override
  String get profileChangerPhoto => 'Cambiar de foto';

  @override
  String get profileChangerPhotoProfil => 'Cambiar la foto de perfil';

  @override
  String get profileQRCode => 'Código QR';

  @override
  String get profilePartagerProfil => 'Compartir perfil';

  @override
  String get profileStatistiques => 'Mis estadísticas';

  @override
  String get profileTachesTerminees => 'Tareas terminadas';

  @override
  String get profile1GroupeCommun => '1 grupo en común';

  @override
  String get profileOrganisezRienEnsembleInstant =>
      'Por ahora no organizáis nada juntos.';

  @override
  String get tasksAvezPrisTache => 'Has tomado esta tarea.';

  @override
  String get tasksAvezRenduTacheGroupe => 'Has devuelto esta tarea al grupo.';

  @override
  String get tasksQuelquVientPrendreAvant =>
      'Alguien la ha tomado justo antes que tú.';

  @override
  String get tasksTache => 'Esta tarea no es tuya.';

  @override
  String get tasksTacheEteConfieeRefusez =>
      'Esta tarea te la han encargado: recházala en lugar de devolverla.';

  @override
  String get tasksFaitesPartieGroupe => 'Ya no formas parte de este grupo.';

  @override
  String get tasksTachePuEtreCreee =>
      'No se ha podido crear la tarea. Reinténtalo en un momento.';

  @override
  String get tasksTachePuEtreModifiee =>
      'No se ha podido modificar la tarea. Reinténtalo en un momento.';

  @override
  String get tasksTacheConfiee => 'Tarea asignada';

  @override
  String get tasksTacheIntrouvable => 'Tarea no encontrada';

  @override
  String get tasksEteSupprimeeAvezAcces =>
      'Se ha eliminado, o ya no tienes acceso. No queda nada por aceptar.';

  @override
  String get tasksRevenirAccueil => 'Volver al inicio';

  @override
  String get tasksTacheEteConfiee => 'Te han encargado esta tarea';

  @override
  String get tasksConfieTache => 'te ha encargado una tarea';

  @override
  String get tasksAssignee => 'Asignada a';

  @override
  String get tasksEcheanceDejaPassee => 'La fecha límite ya ha pasado.';

  @override
  String get tasksAvezAccepteTache => 'Has aceptado esta tarea.';

  @override
  String get tasksAvezDeclineTache => 'Has rechazado esta tarea.';

  @override
  String get tasksAvezTerminePart => 'Has terminado tu parte.';

  @override
  String get tasksTacheAssignee => 'Esta tarea no está asignada a ti.';

  @override
  String get tasksOuvrirTache => 'Abrir la tarea';

  @override
  String get tasksTacheAcceptee => 'Tarea aceptada.';

  @override
  String get tasksTacheDeclinee => 'Tarea rechazada.';

  @override
  String get tasksModifierTache => 'Modificar la tarea';

  @override
  String get tasksSupprimerTache => 'Eliminar la tarea';

  @override
  String get tasksEteSupprimeeAvezAcces2 =>
      'Se ha eliminado, o ya no tienes acceso.';

  @override
  String get tasksPersonneInstantImporteQuel =>
      'Nadie por ahora. Cualquier miembro del grupo puede encargarse.';

  @override
  String get tasksRetirer => 'Dejarla';

  @override
  String get tasksJeMCharge => 'Me encargo';

  @override
  String get tasksChargezTache => 'Te encargas de esta tarea.';

  @override
  String get tasksChargiezDeja => 'Ya te encargabas de ella.';

  @override
  String get tasksChargez => 'Ya no te encargas de ella.';

  @override
  String get tasksEtiezAssigneTache => 'No estabas asignado a esta tarea.';

  @override
  String get tasksQuelquChargeDejaPassez =>
      'Alguien ya se encarga. Usa «Modificar» para cambiar las personas asignadas.';

  @override
  String get tasksRienCocherAjoutezQu =>
      'Nada que marcar. Añade lo que hace falta: cada persona verá lo que queda.';

  @override
  String get tasksAjouterArticle => 'Añadir un artículo';

  @override
  String get tasksAjouterListe => 'Añadir a la lista';

  @override
  String get tasksRetirerListe => 'Quitar de la lista';

  @override
  String get tasksRouvrirTache => 'Reabrir la tarea';

  @override
  String get tasksMarquerCommeTerminee => 'Marcar como terminada';

  @override
  String get tasksTachesIndisponibles => 'Tareas no disponibles';

  @override
  String get tasksAucuneTache => 'Ninguna tarea';

  @override
  String get tasksFaitRienEncoreEte =>
      'Todo está hecho, o aún no se ha anotado nada.';

  @override
  String get tasksGroupeAucuneTacheInstant =>
      'Este grupo no tiene tareas por ahora.';

  @override
  String get tasksAssigner => 'Asignar a';

  @override
  String get tasksMembresGroupeOntEncore =>
      'Los miembros del grupo aún no se han cargado.';

  @override
  String get tasksExAcheterPain => 'Ej.: Comprar el pan';

  @override
  String get tasksJelvoEnverraNotificationPersonne =>
      'Jelvo enviará una notificación a la persona asignada';

  @override
  String get tasksTachesRecurrentes => 'Para las tareas periódicas';

  @override
  String get tasksCreerTache => 'Crear la tarea';

  @override
  String get tasksProposeeGroupeCarteAffichera =>
      'Propuesta a todo el grupo: aparecerá una tarjeta en la conversación, y la primera persona que acepte se la queda.';

  @override
  String tasksConfieeListeRecevraNotification(Object liste) {
    return 'Encargada a $liste, que recibirá una notificación.';
  }

  @override
  String tasksConfieeListeRecevrontNotification(Object liste) {
    return 'Encargada a $liste, que recibirán una notificación.';
  }

  @override
  String get tasksEcheancePrioriteDescription =>
      'Fecha límite, prioridad, descripción…';

  @override
  String get tasksQuFautSavoirOccuper => 'Lo que hay que saber para encargarse';

  @override
  String get tasksDonnezTitreTache => 'Pon un título a la tarea.';

  @override
  String get tasksTacheEteModifiee => 'La tarea se ha modificado.';

  @override
  String tasksTacheTitreEteCreee(Object titre) {
    return 'La tarea «$titre» se ha creado.';
  }

  @override
  String get routerPageIntrouvable => 'Página no encontrada';

  @override
  String routerAucunEcranCorrespondLocation(Object location) {
    return 'Ninguna pantalla coincide con «$location».';
  }

  @override
  String get calendarRecurrenceJamais => 'Nunca';

  @override
  String get calendarRappelAucun => 'Ninguno';

  @override
  String get coreDemain => 'Mañana';

  @override
  String get coreHier => 'Ayer';

  @override
  String coreIlYaMinutes(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String coreIlYaHeures(int heures) {
    return 'hace $heures h';
  }

  @override
  String coreIlYaJours(int jours) {
    String _temp0 = intl.Intl.pluralLogic(
      jours,
      locale: localeName,
      other: 'hace $jours días',
      one: 'hace $jours día',
    );
    return '$_temp0';
  }

  @override
  String coreLeDate(String date) {
    return 'el $date';
  }

  @override
  String get createEvenement => 'Evento';

  @override
  String get createTache => 'Tarea';

  @override
  String get createGroupe => 'Grupo';

  @override
  String get profileApparence => 'Apariencia';

  @override
  String get profileApparenceAutomatique => 'Automática';

  @override
  String get profileApparenceClair => 'Clara';

  @override
  String get profileApparenceSombre => 'Oscura';

  @override
  String groupsTachesEnCours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas en curso',
      one: '$count tarea en curso',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementsAVenir(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos próximos',
      one: '$count evento próximo',
    );
    return '$_temp0';
  }

  @override
  String groupsVousAdministrezCeGroupe(String membres) {
    return '$membres · administras este grupo';
  }

  @override
  String authMoinsCaracteres(int min) {
    return 'Al menos $min caracteres';
  }

  @override
  String get homeBonjour => 'Buenos días';

  @override
  String get homeBonsoir => 'Buenas noches';

  @override
  String get calendarPersonnel => 'Personal';

  @override
  String get calendarJournee => 'Todo el día';

  @override
  String calendarFeteSonAnniversaire(String nom) {
    return '$nom celebra su cumpleaños';
  }

  @override
  String get navNotifications => 'Notificaciones';

  @override
  String get navParametres => 'Ajustes';

  @override
  String get coreStatutInformation => 'Información';

  @override
  String get coreStatutConfirme => 'Confirmado';

  @override
  String get coreStatutEnAttente => 'En espera';

  @override
  String get coreStatutConflit => 'Conflicto';

  @override
  String get coreStatutInactif => 'Inactivo';

  @override
  String get notificationsActives => 'Activas';

  @override
  String get notificationsNotification => 'Notificación';

  @override
  String chatUnePersonneEcrit(String nom) {
    return '$nom está escribiendo…';
  }

  @override
  String chatDeuxPersonnesEcrivent(String premier, String second) {
    return '$premier y $second están escribiendo…';
  }

  @override
  String chatAPrisLaTache(String nom) {
    return '$nom ha tomado la tarea';
  }

  @override
  String chatAAccepteLaTache(String nom) {
    return '$nom ha aceptado la tarea';
  }

  @override
  String chatARefuseLaTache(String nom) {
    return '$nom ha rechazado la tarea';
  }

  @override
  String chatATermineLaTache(String nom) {
    return '$nom ha terminado la tarea';
  }

  @override
  String chatTacheAttribueeA(String nom) {
    return 'Tarea asignada a $nom';
  }

  @override
  String groupsInvitationDe(String nom) {
    return 'Invitación de $nom';
  }

  @override
  String get calendarRappel => 'Recordatorio';

  @override
  String get calendarRepeter => 'Repetir';

  @override
  String groupsMembreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '$count miembro',
    );
    return '$_temp0';
  }

  @override
  String groupsEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '$count evento',
    );
    return '$_temp0';
  }

  @override
  String groupsTacheOuverteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas abiertas',
      one: '$count tarea abierta',
    );
    return '$_temp0';
  }

  @override
  String coreJourEtHeure(String jour, String heures) {
    return '$jour · $heures';
  }

  @override
  String groupsRetraitMembreConfirmation(String nom) {
    return '$nom ya no tendrá acceso al grupo. Podrás volver a invitarle más adelante.';
  }

  @override
  String groupsQuitterConfirmation(String groupe) {
    return 'Ya no verás «$groupe». Si eres su último administrador, el miembro más antiguo tomará el relevo.';
  }

  @override
  String groupsSupprimerConfirmation(String groupe) {
    return '«$groupe» desaparecerá para todos sus miembros. Esta acción no se puede deshacer desde la aplicación.';
  }

  @override
  String groupsInvitationRecueJusquAu(String nom, String date) {
    return '$nom ha recibido tu invitación, hasta el $date.';
  }

  @override
  String get coreRetirer => 'Quitar';

  @override
  String get coreQuitter => 'Salir';

  @override
  String get coreSupprimer => 'Eliminar';

  @override
  String tasksTacheSupprimee(String titre) {
    return '«$titre» se ha eliminado.';
  }

  @override
  String tasksSupprimerConfirmation(String titre) {
    return '«$titre» desaparecerá para todo el mundo. Esta acción no se puede deshacer desde la aplicación.';
  }

  @override
  String coreVous(String nom) {
    return '$nom (tú)';
  }

  @override
  String coreSurTotal(int fait, int total) {
    return '$fait de $total';
  }

  @override
  String tasksCochePar(String nom) {
    return 'Marcado por $nom';
  }

  @override
  String get tasksListe => 'Lista';

  @override
  String get tasksEcheance => 'Fecha límite';

  @override
  String get tasksAucune => 'Ninguna';

  @override
  String calendarEvenementSupprime(String titre) {
    return '«$titre» se ha eliminado.';
  }

  @override
  String calendarSupprimerConfirmation(String titre) {
    return '«$titre» desaparecerá para todos los participantes. Esta acción no se puede deshacer desde la aplicación.';
  }

  @override
  String get calendarParticipants => 'Participantes';

  @override
  String calendarOuiCount(int count) {
    return '$count sí';
  }

  @override
  String calendarVousAvezRepondu(String reponse) {
    return 'Has respondido: $reponse. Todavía puedes cambiar de opinión.';
  }

  @override
  String calendarReponseEnregistree(String reponse) {
    return 'Respuesta guardada: $reponse.';
  }

  @override
  String groupsPartagezCeLien(String groupe) {
    return 'Comparte este enlace por SMS, mensajería o correo. La persona podrá crear su cuenta y unirse a «$groupe».';
  }

  @override
  String groupsRejoinsSurJelvo(String groupe, String url) {
    return 'Únete a «$groupe» en Jelvo: $url';
  }

  @override
  String groupsInvitationARejoindre(String groupe) {
    return 'Invitación para unirse a $groupe';
  }

  @override
  String groupsUtilisationsExpireLe(String utilisations, String date) {
    return '$utilisations · caduca el $date';
  }

  @override
  String groupsAdhesionJusquAu(String date) {
    return 'Pertenencia hasta el $date';
  }

  @override
  String groupsUtilisationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count usos',
      one: '$count uso',
    );
    return '$_temp0';
  }

  @override
  String groupsUtilisationSurMax(String utilisations, int max) {
    return '$utilisations de $max';
  }

  @override
  String contactsGroupeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grupos',
      one: '$count grupo',
    );
    return '$_temp0';
  }

  @override
  String contactsPersonnesSouhaitentVousAjouter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas quieren añadirte',
      one: '$count persona quiere añadirte',
    );
    return '$_temp0';
  }

  @override
  String contactsFaitMaintenantPartie(String nom) {
    return '$nom ya es uno de tus contactos.';
  }

  @override
  String contactsAjoutezMoiSurJelvo(String pseudo) {
    return 'Añádeme en Jelvo: $pseudo';
  }

  @override
  String contactsNomEtMessage(String nom, String message) {
    return '$nom — $message';
  }

  @override
  String contactsRejoignezMoi(String url) {
    return 'Únete a mí en Jelvo para organizar nuestros planes: $url';
  }

  @override
  String contactsMonPseudoLigne(String pseudo) {
    return '\nMi usuario: $pseudo';
  }

  @override
  String contactsRetraitConfirmation(String nom) {
    return '$nom ya no será uno de tus contactos, y tú ya no serás uno de los suyos.';
  }

  @override
  String contactsAEteRetire(String nom) {
    return '$nom se ha quitado.';
  }

  @override
  String coreParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participantes',
      one: '$count participante',
    );
    return '$_temp0';
  }

  @override
  String coreMessageNonLuCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes sin leer',
      one: '$count mensaje sin leer',
    );
    return '$_temp0';
  }

  @override
  String authCodeEnvoyeA(String email) {
    return 'Hemos enviado un código de seis dígitos a $email.';
  }

  @override
  String authFormatPseudo(int min, int max) {
    return 'Minúsculas, cifras y puntos, de $min a $max caracteres.';
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
    return 'A $heure';
  }

  @override
  String calendarPuceEtDate(String date) {
    return ' • $date';
  }

  @override
  String calendarRienNeCorrespond(String terme) {
    return 'Nada coincide con «$terme».';
  }

  @override
  String coreSurTotalTexte(int fait, int total) {
    return '$fait de $total';
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
    return 'Hasta $taille, alrededor de un minuto';
  }

  @override
  String chatVideoTropLourde(String taille, String max) {
    return 'Este vídeo pesa $taille, por encima de los $max admitidos. Graba algo más corto, o envíalo de otra forma.';
  }

  @override
  String chatEcheanceDateHeure(String date, String heure) {
    return 'Vence el $date a las $heure';
  }

  @override
  String groupsInvitationEnAttenteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones pendientes',
      one: '$count invitación pendiente',
    );
    return '$_temp0';
  }

  @override
  String groupsAdhesionTemporaireJusquAu(String date) {
    return 'Pertenencia temporal: hasta el $date.';
  }

  @override
  String groupsAdhesionTemporaireVousFerezPartie(String date) {
    return 'Pertenencia temporal: formarás parte del grupo hasta el $date.';
  }

  @override
  String groupsCreezIciPartageAvec(String groupe) {
    return 'Lo que crees aquí se compartirá con «$groupe».';
  }

  @override
  String groupsJusquAu(String date) {
    return 'Hasta el $date';
  }

  @override
  String groupsAdhesionJusquAuPuisDisparait(String date) {
    return 'Pertenencia hasta el $date; después el grupo desaparecerá de su aplicación.';
  }

  @override
  String groupsMembreJusquAu(String nom, String date) {
    return '$nom forma parte del grupo hasta el $date.';
  }

  @override
  String groupsMembreSansTerme(String nom) {
    return '$nom forma parte del grupo sin fecha de fin.';
  }

  @override
  String homeTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas',
      one: '$count tarea',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleEvenementCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count eventos',
      one: ', $count evento',
    );
    return '$_temp0';
  }

  @override
  String homeVirguleTacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ', $count tareas',
      one: ', $count tarea',
    );
    return '$_temp0';
  }

  @override
  String notificationsVousConvie(String nom) {
    return '$nom te invita.';
  }

  @override
  String notificationsVousConvieAvecGroupe(String nom, String groupe) {
    return '$nom te invita con «$groupe».';
  }

  @override
  String profileVersion(String version) {
    return 'Versión $version';
  }

  @override
  String profileRetrouvezMoi(String pseudo, String code) {
    return 'Encuéntrame en Jelvo: $pseudo\n$code';
  }

  @override
  String profileVotrePseudo(String pseudo) {
    return 'Tu usuario: $pseudo';
  }

  @override
  String profileRetraitCarnetConfirmation(String nom) {
    return '$nom ya no aparecerá en tus contactos. Vuestros grupos en común no cambian.';
  }

  @override
  String profileGroupesCommunsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grupos en común',
      one: '$count grupo en común',
    );
    return '$_temp0';
  }

  @override
  String tasksEcheanceDate(String date) {
    return 'Vence el $date';
  }

  @override
  String coreDateAHeure(String date, String heure) {
    return '$date a las $heure';
  }

  @override
  String get tasksTerminees => 'Terminadas';

  @override
  String tasksConfieeAuxPersonnes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encargada a $count personas, que recibirán una notificación.',
      one: 'Encargada a $count persona, que recibirá una notificación.',
    );
    return '$_temp0';
  }

  @override
  String coreDeuxNoms(String premier, String second) {
    return '$premier y $second';
  }

  @override
  String coreDeuxNomsEtAutres(String premier, String second, int reste) {
    String _temp0 = intl.Intl.pluralLogic(
      reste,
      locale: localeName,
      other: '$reste más',
      one: '$reste más',
    );
    return '$premier, $second y $_temp0';
  }

  @override
  String tasksArticlesCoches(int faits, int total) {
    return '$faits de $total artículos';
  }

  @override
  String tasksPrioriteLabel(String priorite) {
    return 'Prioridad $priorite';
  }

  @override
  String navBadgeNonLus(String destination, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sin leer',
      one: '$count sin leer',
    );
    return '$destination, $_temp0';
  }

  @override
  String get profileLangue => 'Idioma';

  @override
  String get profileLangueDuTelephone => 'El del teléfono';

  @override
  String get profileLangueDuTelephoneAide =>
      'Sigue el ajuste del dispositivo, y el inglés si el idioma no está disponible';

  @override
  String get profileLangueFrancais => 'Francés';

  @override
  String get profileLangueAllemand => 'Alemán';

  @override
  String get profileLangueAnglais => 'Inglés';

  @override
  String get profileLangueEspagnol => 'Español';

  @override
  String get homeBonWeekEnd => 'Buen fin de semana';

  @override
  String get coreDebutApresMidi => '14';

  @override
  String get coreDebutSoiree => '20';

  @override
  String get coreDescription => 'Descripción';

  @override
  String get coreRechercher => 'Buscar';

  @override
  String get coreProfil => 'Perfil';

  @override
  String get coreLieu => 'Lugar';

  @override
  String get coreAnniversaire => 'Cumpleaños';

  @override
  String get coreAutre => 'Otro';

  @override
  String get corePrenom => 'Nombre';

  @override
  String get coreNom => 'Apellidos';

  @override
  String get corePseudo => 'Usuario';

  @override
  String get coreHintPseudo => 'usuario';

  @override
  String get coreFiltres => 'Filtros';

  @override
  String get coreRepetition => 'Repetición';

  @override
  String get coreInvitation => 'Invitación';

  @override
  String get coreInvitations => 'Invitaciones';

  @override
  String get coreChoisir => 'Elegir';

  @override
  String get corePriorite => 'Prioridad';

  @override
  String get coreDate => 'Fecha';

  @override
  String get coreHoraires => 'Horario';

  @override
  String get coreDisponible => 'Disponible';

  @override
  String get coreTout => 'Todo';

  @override
  String get coreAfficher => 'Mostrar';

  @override
  String get coreFin => 'Fin';

  @override
  String get coreVideo => 'Vídeo';

  @override
  String get coreJoindre => 'Adjuntar';

  @override
  String get coreFilmer => 'Grabar';

  @override
  String get coreScanner => 'Escanear';

  @override
  String get coreResultats => 'Resultados';

  @override
  String get coreEffacer => 'Borrar';

  @override
  String get coreFavoris => 'Favoritos';

  @override
  String get coreGerer => 'Gestionar';

  @override
  String get coreActions => 'Acciones';

  @override
  String get coreDiscussion => 'Chat';

  @override
  String get coreInviter => 'Invitar';

  @override
  String get coreSuggestions => 'Sugerencias';

  @override
  String get corePartager => 'Compartir';

  @override
  String get coreAdmin => 'Admin';

  @override
  String get coreCommencer => 'Empezar';

  @override
  String get coreCompte => 'Cuenta';

  @override
  String get coreDeconnexion => 'Cerrar sesión';

  @override
  String get coreJour => 'Día';

  @override
  String get coreMois => 'Mes';

  @override
  String get coreEmail => 'Correo';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreModifier => 'Editar';

  @override
  String get coreContinuer => 'Continuar';

  @override
  String get coreVerifier => 'Verificar';

  @override
  String get coreExceptions => 'Excepciones';

  @override
  String get coreEvenements => 'Eventos';

  @override
  String get coreTaches => 'Tareas';

  @override
  String get coreExemplePrenom => 'Lucía';

  @override
  String get coreExempleNom => 'García';

  @override
  String get corePlusDOptions => 'Más opciones';

  @override
  String get profileSupprimerCompte => 'Eliminar mi cuenta';

  @override
  String get profileSuppressionDefinitive =>
      'Esta eliminación es definitiva: no se puede deshacer.';

  @override
  String get profileSuppressionCeQuiDisparait => 'Lo que desaparece';

  @override
  String get profileSuppressionIdentite =>
      'Tu nombre, tu usuario, tu correo electrónico y tu foto';

  @override
  String get profileSuppressionProfil =>
      'Tu biografía, tu cumpleaños y tu disponibilidad';

  @override
  String get profileSuppressionContacts =>
      'Tus contactos y tus solicitudes pendientes';

  @override
  String get profileSuppressionGroupes =>
      'Tus pertenencias a grupos. Si eres la única persona que administra un grupo, el miembro más antiguo ocupa tu lugar.';

  @override
  String get profileSuppressionNotifications =>
      'Tus notificaciones y tus suscripciones';

  @override
  String get profileSuppressionVocaux =>
      'Tus mensajes de voz, que llevan tu voz';

  @override
  String get profileSuppressionCeQuiReste => 'Lo que se queda';

  @override
  String get profileSuppressionMessages =>
      'Tus mensajes escritos, firmados «Cuenta eliminada», para no dejar huecos en las conversaciones de los demás';

  @override
  String get profileSuppressionMedias =>
      'Las fotos y los vídeos que has compartido';

  @override
  String get profileSuppressionGroupeContenu =>
      'Las tareas y los eventos que has creado en un grupo';

  @override
  String get profileSuppressionReinscription =>
      'Podrás registrarte de nuevo más adelante con la misma dirección.';

  @override
  String get profileSuppressionMotDePasse => 'Contraseña';

  @override
  String get profileSuppressionMotDePasseAide => 'Para confirmar que eres tú';

  @override
  String get profileSuppressionConfirmer => 'Eliminar definitivamente';

  @override
  String get profileSuppressionMotDePasseIncorrect => 'Contraseña incorrecta.';

  @override
  String get profileSuppressionEchec =>
      'La eliminación no se ha completado. Tu cuenta está intacta: inténtalo de nuevo en un momento.';

  @override
  String get profileSuppressionFaite => 'Tu cuenta ha sido eliminada.';

  @override
  String get coreCompteSupprime => 'Cuenta eliminada';

  @override
  String get coreMembre => 'Miembro';

  @override
  String get coreEpingle => 'Fijado';

  @override
  String get coreEpingler => 'Fijar';

  @override
  String get coreRouvrir => 'Reabrir';

  @override
  String get chatEcouter => 'Escuchar';

  @override
  String get tasksAssignes => 'Asignados';

  @override
  String get tasksPersonnelle => 'Personal';

  @override
  String chatCompteurTaches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tareas',
      one: 'tarea',
    );
    return '$_temp0';
  }

  @override
  String chatCompteurEvenements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'eventos',
      one: 'evento',
    );
    return '$_temp0';
  }

  @override
  String contactsCompteurGroupes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'grupos',
      one: 'grupo',
    );
    return '$_temp0';
  }

  @override
  String get tasksLibre => 'Libre';

  @override
  String get coreIndisponible => 'No disponible';

  @override
  String get coreInconnu => 'Desconocido';

  @override
  String get coreAutres => 'Otras';

  @override
  String get coreContact => 'Contacto';

  @override
  String get coreDateChoisir => 'Fecha…';

  @override
  String get chatEmojis => 'Emojis';

  @override
  String get chatEnvoyer => 'Enviar';

  @override
  String get authRetirerAvatar => 'Quitar el avatar';

  @override
  String get groupsRejoindre => 'Unirme';

  @override
  String get notificationsActivees => 'Activadas';

  @override
  String get notificationsPartielles => 'Parciales';

  @override
  String get notificationsDesactivees => 'Desactivadas';

  @override
  String get notificationsRefusees => 'Rechazadas';

  @override
  String get notificationsIndisponibles => 'No disponibles';

  @override
  String get notificationsVoirInvitation => 'Ver la invitación';
}
