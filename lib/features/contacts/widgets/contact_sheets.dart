import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../profile/models/anniversaire.dart';
import '../../profile/models/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';

/// Les trois moyens d'ajouter quelqu'un, dans une feuille.
///
/// Ils existaient déjà — le scanner, la recherche par pseudo — mais dispersés
/// derrière un bouton d'en-tête. Les réunir donne à la question « comment
/// j'ajoute quelqu'un ? » une seule réponse.
class AddContactSheet extends ConsumerWidget {
  const AddContactSheet({super.key});

  static Future<void> ouvrir(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const AddContactSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(AppTexts.of(context).createAddContact, style: context.typo.h2),
            AppSpacing.gapLg,

            _Choix(
              icone: Icons.qr_code_scanner_rounded,
              couleur: context.couleurs.primary,
              titre: AppTexts.of(context).contactsScannerQRCode2,
              aide: AppTexts.of(context).contactsAjouterContactQRCode,
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(AppRoutes.scanContact);
              },
            ),
            Divider(height: 1, indent: 64, color: context.couleurs.border),
            _Choix(
              icone: Icons.search_rounded,
              couleur: context.couleurs.success,
              titre: AppTexts.of(context).contactsRechercherPseudo,
              aide: AppTexts.of(context).contactsTrouverUtilisateurJelvo,
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(AppRoutes.addContact);
              },
            ),
            Divider(height: 1, indent: 64, color: context.couleurs.border),
            _Choix(
              icone: Icons.mail_outline_rounded,
              couleur: context.couleurs.warning,
              titre: AppTexts.of(context).contactsInviterAmi,
              aide: AppTexts.of(context).contactsEnvoyerInvitationJelvo,
              onTap: () => _inviter(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// **On partage son pseudo, pas un lien d'inscription.** Jelvo n'a pas
  /// d'adresse publique de profil, et inventer un lien qui n'ouvrirait rien
  /// serait pire que de donner le pseudo, avec lequel on se retrouve par la
  /// recherche. Même arbitrage que « Partager profil ».
  Future<void> _inviter(BuildContext context, WidgetRef ref) async {
    final AppTexts t = AppTexts.of(context);
    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final Profile? profil = ref.read(currentProfileProvider).value;
    navigateur.pop();

    final String pseudo = profil?.pseudoHandle ?? '';
    final String texte =
        t.contactsRejoignezMoi(AppConfig.webBaseUrl) +
        (pseudo.isEmpty ? '' : t.contactsMonPseudoLigne(pseudo));
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: texte,
          subject: AppTexts.of(context).contactsRejoignezMoiJelvo,
        ),
      );
    } catch (_) {
      messager.showSnackBar(SnackBar(content: Text(texte)));
    }
  }
}

/// Ce qu'on peut faire d'un contact, une fois sa ligne touchée.
///
/// L'écran n'ouvrait rien jusqu'ici, et `remove` n'était appelé de nulle
/// part : retirer quelqu'un de son carnet existait en base sans être
/// atteignable. Le chevron de la maquette mène donc ici.
class ContactActionsSheet extends ConsumerWidget {
  const ContactActionsSheet({super.key, required this.contact});

  final Contact contact;

  static Future<void> ouvrir(BuildContext context, Contact contact) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ContactActionsSheet(contact: contact),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AvatarImage(
                  data: AvatarData(
                    name: contact.fullName,
                    imageUrl: contact.avatarUrl,
                  ),
                  size: 44,
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        contact.fullName,
                        style: context.typo.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        contact.sharedGroupsLabel(AppTexts.of(context)),
                        style: context.typo.caption,
                      ),
                      // L'anniversaire, **quand il y en a un**. C'est la seule
                      // fiche d'autrui que Jelvo possède : il n'existe pas
                      // d'écran de profil d'une autre personne, et inventer
                      // une ligne « non précisé » ferait passer une absence
                      // pour une donnée manquante.
                      if (ref
                              .watch(contactBirthdayProvider)(contact.id)
                              ?.anniversaire
                          case final Anniversaire date)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.cake_outlined,
                                size: 14,
                                color: context.couleurs.warningInk,
                              ),
                              AppSpacing.hGapXs,
                              Text(
                                date.libelle(AppTexts.of(context)),
                                style: context.typo.caption.copyWith(
                                  color: context.couleurs.warningInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapLg,

            _Choix(
              icone: contact.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              couleur: context.couleurs.primary,
              titre: contact.isFavorite
                  ? AppTexts.of(context).contactsRetirerFavoris
                  : AppTexts.of(context).contactsAjouterFavoris,
              aide: AppTexts.of(context).contactsFavorisTeteCarnet,
              onTap: () async {
                final NavigatorState navigateur = Navigator.of(context);
                await ref.read(contactActionsProvider).toggleFavorite(contact);
                navigateur.pop();
              },
            ),
            Divider(height: 1, indent: 64, color: context.couleurs.border),
            _Choix(
              icone: Icons.person_remove_outlined,
              couleur: context.couleurs.danger,
              titre: AppTexts.of(context).contactsRetirerContacts,
              aide: AppTexts.of(context).contactsRelationSupprimeeDeuxCotes,
              onTap: () => _retirer(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retirer(BuildContext context, WidgetRef ref) async {
    // Lu **avant** l’attente : le contexte peut avoir disparu après.
    final AppTexts t = AppTexts.of(context);
    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final bool? confirme = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogue) => AlertDialog(
        title: Text(AppTexts.of(context).contactsRetirerContact),
        content: Text(
          AppTexts.of(context).contactsRetraitConfirmation(contact.fullName),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.couleurs.danger,
            ),
            child: Text(t.coreRetirer),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await ref.read(contactActionsProvider).remove(contact.id);
      navigateur.pop();
      messager.showSnackBar(
        SnackBar(content: Text(t.contactsAEteRetire(contact.shortName))),
      );
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message(t))),
      );
    }
  }
}

/// « Gérer » : épingler et désépingler à la chaîne.
///
/// C'est ce que le lien de la maquette doit ouvrir. Sur la liste, l'étoile est
/// à côté de chaque nom, mais il faut la chercher ligne à ligne ; ici, tout le
/// carnet est là, chaque nom porte son interrupteur, et la bande du haut suit
/// à chaque touche.
class ManageFavoritesSheet extends ConsumerWidget {
  const ManageFavoritesSheet({super.key});

  static Future<void> ouvrir(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const ManageFavoritesSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Contact> contacts = ref.watch(acceptedContactsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTexts.of(context).contactsGererFavoris,
              style: context.typo.h2,
            ),
            const SizedBox(height: 2),
            Text(
              AppTexts.of(context).contactsFavoriPersonnelAutreSait,
              style: context.typo.caption,
            ),
            AppSpacing.gapLg,

            if (contacts.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title: AppTexts.of(context).contactsCarnetVide,
                  message: AppTexts.of(
                    context,
                  ).contactsAjoutezAbordContactsEpingler,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: contacts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Contact contact = contacts[index];
                    return SwitchListTile(
                      value: contact.isFavorite,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (_) => ref
                          .read(contactActionsProvider)
                          .toggleFavorite(contact),
                      secondary: AvatarImage(
                        data: AvatarData(
                          name: contact.fullName,
                          imageUrl: contact.avatarUrl,
                        ),
                        size: 36,
                      ),
                      title: Text(
                        contact.fullName,
                        style: context.typo.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: contact.pseudo == null
                          ? null
                          : Text(
                              contact.pseudoHandle,
                              style: context.typo.caption,
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une entrée de feuille : pastille colorée, titre, aide, chevron.
class _Choix extends StatelessWidget {
  const _Choix({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.aide,
    required this.onTap,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String aide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Icon(icone, size: 20, color: couleur),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    titre,
                    style: context.typo.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(aide, style: context.typo.caption),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.couleurs.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
