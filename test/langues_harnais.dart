import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/features/signalements/models/blocage.dart';
import 'package:jelvo/features/signalements/models/signalement.dart';
import 'package:jelvo/features/signalements/providers/signalement_providers.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/language_storage.dart';
import 'package:jelvo/demarrage.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/notifications/push/push_service.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_signalement_repository.dart';
import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';
import 'fakes/fake_voice.dart';

/// Un mercredi, en pleine matinée : ni week-end, ni soir.
final DateTime mercrediMatin = DateTime(2026, 8, 5, 9);

Future<LanguageStorage> pumpAppLangue(
  WidgetTester tester, {
  Locale? choix,
  List<Locale>? telephone,
  Size taille = const Size(420, 2400),
  FakePushRepository? push,
  PushStatus? statutPush,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (telephone != null) {
    tester.platformDispatcher.localesTestValue = telephone;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeChatRepository chat = FakeChatRepository();
  addTearDown(chat.dispose);
  final LanguageStorage langue = EphemeralLanguageStorage(langue: choix);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(mercrediMatin)),
        languageStorageProvider.overrideWithValue(langue),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
        voiceRecorderProvider.overrideWithValue(FakeVoiceRecorder()),
        voicePlayerFactoryProvider.overrideWithValue(FakeVoicePlayer.new),
        pushServiceProvider.overrideWithValue(
          FakePushService(statut: statutPush ?? PushStatus.aAutoriser),
        ),
        pushRepositoryProvider.overrideWithValue(push ?? FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        // **Modérateur, et avec de quoi remplir les cartes.** Un faux dépôt
        // vide rendrait l'état vide de l'écran de modération, et les
        // libellés les plus longs — « Als bearbeitet markieren », « la note
        // est le seul levier » — échapperaient au balayage. C'est la même
        // raison qui fait viser les écrans par le routeur plutôt que par des
        // touches : les débordements se trouvent là où le texte est.
        signalementRepositoryProvider.overrideWithValue(
          FakeSignalementRepository(
            moderateur: true,
            // Une personne bloquée, pour que la carte de la liste ait du
            // texte à mesurer : « Blockierte Personen » et « Entsperren »
            // sur une même ligne, à 360 dp.
            bloques: <PersonneBloquee>[
              PersonneBloquee(
                userId: 'u2',
                creeLe: DateTime(2026, 8, 3, 8),
                pseudo: 'lea.marchand',
                nom: 'Léa Marchand',
              ),
            ],
            signalements: <Signalement>[
              Signalement(
                id: 's1',
                cible: SignalementCible.message,
                motif: SignalementMotif.harcelement,
                creeLe: DateTime(2026, 8, 3, 8),
                commentaire: 'Il insiste depuis trois jours',
                contexte: const <String, dynamic>{
                  'contenu': 'Texte signalé',
                  'groupe_nom': 'Famille Rousseau',
                },
                messageId: 'm1',
                groupId: 'g1',
                profilId: 'u2',
                auteurNom: 'Camille Rousseau',
                viseNom: 'Léa Marchand',
                groupeNom: 'Famille Rousseau',
                messageEfface: false,
              ),
              Signalement(
                id: 's2',
                cible: SignalementCible.group,
                motif: SignalementMotif.violence,
                creeLe: DateTime(2026, 8, 3, 7),
                groupId: 'g1',
                groupeNom: 'Famille Rousseau',
                auteurNom: 'Camille Rousseau',
              ),
            ],
          ),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
      ],
      child: const SignalDeDemarrage(child: JelvoApp()),
    ),
  );
  await tester.pumpAndSettle();
  return langue;
}
