import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
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
            Text('Ajouter un contact', style: AppTypography.h2),
            AppSpacing.gapLg,

            _Choix(
              icone: Icons.qr_code_scanner_rounded,
              couleur: AppColors.primary,
              titre: 'Scanner un QR Code',
              aide: 'Ajouter un contact avec son QR Code',
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(AppRoutes.scanContact);
              },
            ),
            const Divider(height: 1, indent: 64, color: AppColors.border),
            _Choix(
              icone: Icons.search_rounded,
              couleur: AppColors.success,
              titre: 'Rechercher un pseudo',
              aide: 'Trouver un utilisateur Jelvo',
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed(AppRoutes.addContact);
              },
            ),
            const Divider(height: 1, indent: 64, color: AppColors.border),
            _Choix(
              icone: Icons.mail_outline_rounded,
              couleur: AppColors.warning,
              titre: 'Inviter un ami',
              aide: 'Envoyer une invitation Jelvo',
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
    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final Profile? profil = ref.read(currentProfileProvider).value;
    navigateur.pop();

    final String pseudo = profil?.pseudoHandle ?? '';
    final String texte =
        'Rejoignez-moi sur Jelvo pour organiser nos sorties : '
        '${AppConfig.webBaseUrl}'
        '${pseudo.isEmpty ? '' : '\nMon pseudo : $pseudo'}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: texte, subject: 'Rejoignez-moi sur Jelvo'),
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
                        style: AppTypography.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        contact.sharedGroupsLabel,
                        style: AppTypography.caption,
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
              couleur: AppColors.primary,
              titre: contact.isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              aide: 'Les favoris sont en tête de votre carnet',
              onTap: () async {
                final NavigatorState navigateur = Navigator.of(context);
                await ref.read(contactActionsProvider).toggleFavorite(contact);
                navigateur.pop();
              },
            ),
            const Divider(height: 1, indent: 64, color: AppColors.border),
            _Choix(
              icone: Icons.person_remove_outlined,
              couleur: AppColors.danger,
              titre: 'Retirer de mes contacts',
              aide: 'La relation est supprimée des deux côtés',
              onTap: () => _retirer(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retirer(BuildContext context, WidgetRef ref) async {
    final NavigatorState navigateur = Navigator.of(context);
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final bool? confirme = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogue) => AlertDialog(
        title: const Text('Retirer ce contact'),
        content: Text(
          '${contact.fullName} ne fera plus partie de vos contacts, et vous '
          'ne ferez plus partie des siens.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await ref.read(contactActionsProvider).remove(contact.id);
      navigateur.pop();
      messager.showSnackBar(
        SnackBar(content: Text('${contact.shortName} a été retiré.')),
      );
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
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
            Text('Gérer les favoris', style: AppTypography.h2),
            const SizedBox(height: 2),
            Text(
              'Le favori est personnel : l’autre n’en sait rien.',
              style: AppTypography.caption,
            ),
            AppSpacing.gapLg,

            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'Carnet vide',
                  message: 'Ajoutez d’abord des contacts à épingler.',
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
                        style: AppTypography.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: contact.pseudo == null
                          ? null
                          : Text(
                              contact.pseudoHandle,
                              style: AppTypography.caption,
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
                    style: AppTypography.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(aide, style: AppTypography.caption),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
