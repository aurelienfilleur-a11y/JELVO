import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/models/notification_category.dart';
import '../../notifications/providers/push_providers.dart';
import '../../notifications/push/push_service.dart';
import '../../notifications/repository/push_repository.dart';
import '../../notifications/widgets/notification_sheets.dart';
import '../widgets/appearance_sheet.dart';
import '../widgets/language_sheet.dart';
import '../widgets/settings_card.dart';

/// Écran Paramètres : trois cartes titrées, puis la déconnexion.
///
/// **Aucune ligne ne s'affiche sans mener quelque part.** La maquette en
/// proposait douze ; celles que Jelvo ne sait pas encore tenir — sécurité et
/// confidentialité, sessions actives, thème sombre, langue, fuseau horaire,
/// aide et support — sont absentes plutôt que grisées ou décoratives. Une
/// carte de trois lignes vraies vaut mieux qu'une de six dont la moitié
/// ment. Voir « Écran Paramètres » dans `CLAUDE.md` pour l'inventaire et le
/// coût de chacune.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deconnexion = false;

  @override
  Widget build(BuildContext context) {
    final PushStatus statutPush =
        ref.watch(pushStatusProvider).value ?? PushStatus.nonSupporte;
    final List<NotificationPreference> preferences =
        ref.watch(notificationPreferencesProvider).value ??
        const <NotificationPreference>[];

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: Text(AppTexts.of(context).navParametres),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AppTexts.of(context).commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            SettingsCard(
              titre: AppTexts.of(context).coreCompte,
              lignes: <Widget>[
                SettingsRow(
                  icone: Icons.person_outline_rounded,
                  libelle: AppTexts.of(context).profileInformationsPersonnelles,
                  onTap: () => context.pushNamed(AppRoutes.profileEdit),
                ),
                SettingsRow(
                  icone: Icons.lock_outline_rounded,
                  libelle: AppTexts.of(context).profileChangerMotPasse,
                  onTap: () => context.pushNamed(AppRoutes.changePassword),
                ),
              ],
            ),

            AppSpacing.gapLg,
            SettingsCard(
              titre: AppTexts.of(context).navNotifications,
              lignes: <Widget>[
                // La ligne du haut coupe tout : sans autorisation, aucun type
                // ne part, quel que soit son interrupteur.
                SettingsRow(
                  icone: Icons.notifications_none_rounded,
                  libelle: AppTexts.of(context).notificationsNotificationsPush,
                  valeur: libellePush(statutPush, AppTexts.of(context)),
                  couleurValeur: statutPush == PushStatus.actif
                      ? context.couleurs.primary
                      : context.couleurs.textSecondary,
                  onTap: () => PushPermissionSheet.ouvrir(context),
                ),
                for (final NotificationCategory categorie
                    in NotificationCategory.visibles(preferences))
                  _ligneCategorie(categorie, preferences),
              ],
            ),

            AppSpacing.gapLg,
            SettingsCard(
              titre: AppTexts.of(context).coreAutre,
              lignes: <Widget>[
                SettingsRow(
                  icone: Icons.contrast_rounded,
                  libelle: AppTexts.of(context).profileApparence,
                  valeur: Apparence.depuis(
                    ref.watch(themeModeProvider),
                  ).libelle(AppTexts.of(context)),
                  onTap: () => AppearanceSheet.ouvrir(context),
                ),
                SettingsRow(
                  icone: Icons.translate_rounded,
                  libelle: AppTexts.of(context).profileLangue,
                  valeur: _langueCourante(context, ref),
                  onTap: () => LanguageSheet.ouvrir(context),
                ),
                SettingsRow(
                  icone: Icons.info_outline_rounded,
                  libelle: AppTexts.of(context).profileProposJelvo,
                  valeur: 'v${AppConfig.version}',
                  onTap: () => context.pushNamed(AppRoutes.about),
                ),
              ],
            ),

            AppSpacing.gapLg,
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: _deconnexion
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : SettingsRow(
                      icone: Icons.logout_rounded,
                      libelle: AppTexts.of(context).coreDeconnexion,
                      destructif: true,
                      onTap: _confirmerDeconnexion,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneCategorie(
    NotificationCategory categorie,
    List<NotificationPreference> preferences,
  ) {
    final CategoryState etat = CategoryState.depuis(
      categorie.preferencesDe(preferences),
    );
    return SettingsRow(
      icone: categorie.icon,
      libelle: categorie.label(AppTexts.of(context)),
      valeur: etat.label(AppTexts.of(context)),
      couleurValeur: etat.color(context.couleurs),
      onTap: () => NotificationCategorySheet.ouvrir(context, categorie),
    );
  }

  Future<void> _confirmerDeconnexion() async {
    final bool confirme =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogue) => AlertDialog(
            title: Text(AppTexts.of(context).profileDeconnecter),
            content: Text(
              AppTexts.of(context).profileDevrezSaisirNouveauIdentifiants,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogue).pop(false),
                child: Text(AppTexts.of(context).commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogue).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: context.couleurs.danger,
                ),
                child: Text(AppTexts.of(context).profileDeconnecter),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirme || !mounted) return;

    setState(() => _deconnexion = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      // La garde du routeur ramène à la connexion dès la session fermée.
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthFailure.from(error).message(AppTexts.of(context))),
        ),
      );
    } finally {
      if (mounted) setState(() => _deconnexion = false);
    }
  }

  /// Ce que la ligne annonce : la langue choisie, ou celle du téléphone.
  ///
  /// **Pas le code `fr` ni le drapeau d'un pays** : un drapeau désigne un
  /// État et non une langue — l'espagnol est parlé dans vingt pays, et aucun
  /// ne peut raisonnablement le représenter.
  String _langueCourante(BuildContext context, WidgetRef ref) {
    final AppTexts t = AppTexts.of(context);
    final Locale? choix = ref.watch(localeProvider);
    return choix == null
        ? t.profileLangueDuTelephone
        : LanguageSheet.nomNatif(choix);
  }
}
