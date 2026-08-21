import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/auth/widgets/avatar_picker.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/models/avatar_catalog.dart';
import 'package:jelvo/features/profile/models/profile.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeProfileRepository> _pumpApp(
  WidgetTester tester, {
  Profile? profile,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeProfileRepository profils = FakeProfileRepository(profile: profile);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profils),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return profils;
}

Future<void> _ouvrirGalerie(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choisir un avatar'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Galerie d’avatars', () {
    testWidgets('le profil ouvre la galerie, sans perdre le choix « photo »', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();

      // Les deux voies cohabitent : l'aperçu prend une photo, le bouton ouvre
      // la galerie.
      expect(find.text('Choisir un avatar'), findsOneWidget);
      expect(find.byType(AvatarPicker), findsOneWidget);

      await tester.tap(find.text('Choisir un avatar'));
      await tester.pumpAndSettle();

      expect(find.text('Utiliser cet avatar'), findsOneWidget);
    });

    testWidgets('choisir puis confirmer enregistre l’avatar', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _pumpApp(tester);
      await _ouvrirGalerie(tester);

      // La sélection et la confirmation sont deux gestes : toucher une
      // vignette ne doit rien enregistrer.
      await tester.tap(
        find.bySemanticsLabel('Avatar ${avatarsPredefinis.first}'),
      );
      await tester.pumpAndSettle();
      expect(profils.lastChosenAvatar, isNull);

      await tester.tap(find.text('Utiliser cet avatar'));
      await tester.pumpAndSettle();

      expect(profils.lastChosenAvatar, avatarsPredefinis.first);
    });

    testWidgets('sans sélection, la confirmation reste inerte', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _pumpApp(tester);
      await _ouvrirGalerie(tester);

      await tester.tap(find.text('Utiliser cet avatar'));
      await tester.pumpAndSettle();

      expect(profils.lastChosenAvatar, isNull);
      // On reste sur la galerie plutôt que de refermer sur un non-choix.
      expect(find.text('Utiliser cet avatar'), findsOneWidget);
    });

    testWidgets('l’avatar déjà choisi est mis en évidence à l’ouverture', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        profile: const Profile(
          id: 'utilisateur-test',
          pseudo: 'camille.rousseau',
          firstName: 'Camille',
          lastName: 'Rousseau',
          avatarPreset: 'p3_05',
        ),
      );
      await _ouvrirGalerie(tester);

      // On éprouve l'anneau violet — ce qui se voit — plutôt qu'un drapeau
      // d'accessibilité, dont l'API bouge d'une version de Flutter à l'autre.
      final BoxDecoration decor =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.bySemanticsLabel('Avatar p3_05'),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decor.border!.top.color, AppColors.primary);
      expect(decor.border!.top.width, 3);
    });
  });

  group('Exclusivité photo / avatar', () {
    testWidgets('choisir un avatar efface la photo', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _pumpApp(
        tester,
        profile: const Profile(
          id: 'utilisateur-test',
          pseudo: 'camille.rousseau',
          firstName: 'Camille',
          lastName: 'Rousseau',
          avatarUrl: 'https://exemple.test/photo.jpg',
        ),
      );
      await _ouvrirGalerie(tester);

      await tester.tap(find.bySemanticsLabel('Avatar ${avatarsPredefinis[2]}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utiliser cet avatar'));
      await tester.pumpAndSettle();

      final Profile? apres = await profils.fetchProfile('utilisateur-test');
      expect(apres!.avatarPreset, avatarsPredefinis[2]);
      expect(
        apres.avatarUrl,
        isNull,
        reason: 'le dernier choisi doit vider l’autre',
      );
      expect(apres.avatarAAfficher, 'preset:${avatarsPredefinis[2]}');
    });
  });
}
