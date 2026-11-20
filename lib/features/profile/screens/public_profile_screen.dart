import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../contacts/models/contact.dart';
import '../../contacts/providers/contact_providers.dart';
import '../models/profil_consultable.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_action_row.dart';
import '../widgets/public_profile_cards.dart';

/// Le profil de quelqu'un d'autre.
///
/// Jelvo n'en avait aucun : on ne voyait qu'une fiche de contact, et rien du
/// tout d'une personne absente du carnet. C'est pourtant l'écran qu'on cherche
/// en touchant un avatar dans une conversation.
///
/// **Rien n'est filtré ici.** Les statistiques et la disponibilité arrivent à
/// `null` quand on n'est pas un contact accepté, et c'est
/// `profil_consultable` qui en décide : un appel direct à PostgREST obtient
/// les mêmes `null`. Cet écran ne fait qu'afficher ce qu'il reçoit — un écran
/// ne peut rien réserver.
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfilConsultable?> lecture = ref.watch(
      profilConsultableProvider(widget.userId),
    );

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (lecture) {
          AsyncValue<ProfilConsultable?>(hasError: true) => _Message(
            icon: Icons.cloud_off_rounded,
            titre: 'Profil indisponible',
            message: 'La lecture n’a pas abouti. Réessayez dans un instant.',
          ),
          // Zéro ligne : l'identifiant n'existe pas. C'est le seul état
          // dégradé d'un profil — contrairement à une invitation, qui en a
          // quatre et porte donc un mot d'état.
          AsyncValue<ProfilConsultable?>(value: null, isLoading: false) =>
            const _Message(
              icon: Icons.person_off_outlined,
              titre: 'Profil introuvable',
              message: 'Cette personne n’a plus de compte Jelvo.',
            ),
          AsyncValue<ProfilConsultable?>(value: final ProfilConsultable p) =>
            _Contenu(
              profil: p,
              actions: _actions(p),
              enCours: _enCours,
              onOuvrirGroupe: (String id) => context.pushNamed(
                AppRoutes.groupDetail,
                pathParameters: <String, String>{'id': id},
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// Les actions dépendent de la relation, et **aucune n'est inerte** : un
  /// bouton grisé annoncerait une capacité que la base refuse.
  List<ProfileAction> _actions(ProfilConsultable p) {
    if (_enCours) return const <ProfileAction>[];

    // Son propre profil, ouvert en touchant son avatar dans une conversation.
    // Pas d'action de relation — on ne s'ajoute pas soi-même — et un chemin
    // vers l'écran qui, lui, se modifie.
    if (p.cestMoi) {
      return <ProfileAction>[
        ProfileAction(
          icon: Icons.person_outline_rounded,
          label: 'Mon profil',
          accented: true,
          onTap: () => context.goNamed(AppRoutes.profile),
        ),
      ];
    }

    if (p.demandeRecue) {
      return <ProfileAction>[
        ProfileAction(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Accepter',
          accented: true,
          onTap: () => _agir(() => _actionsContact.accept(widget.userId)),
        ),
        ProfileAction(
          icon: Icons.close_rounded,
          label: 'Refuser',
          destructive: true,
          onTap: () => _agir(() => _actionsContact.decline(widget.userId)),
        ),
      ];
    }

    if (p.demandeEnvoyee) {
      // « Annuler la demande » passe par `remove`, qui supprime la ligne :
      // `contact_status` ne connaît pas de `declined`, et c'est la suppression
      // qui tient le refus comme l'annulation.
      return <ProfileAction>[
        ProfileAction(
          icon: Icons.schedule_rounded,
          label: 'Annuler la demande',
          onTap: () => _agir(() => _actionsContact.remove(widget.userId)),
        ),
      ];
    }

    final Contact? relation = p.relation;
    if (p.estContact && relation != null) {
      return <ProfileAction>[
        ProfileAction(
          icon: relation.isFavorite
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          label: relation.isFavorite ? 'Épinglé' : 'Épingler',
          accented: relation.isFavorite,
          onTap: () => _agir(() => _actionsContact.toggleFavorite(relation)),
        ),
        ProfileAction(
          icon: Icons.person_remove_outlined,
          label: 'Retirer',
          destructive: true,
          onTap: () => _retirer(p),
        ),
      ];
    }

    return <ProfileAction>[
      ProfileAction(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Ajouter en contact',
        accented: true,
        onTap: () => _agir(() => _actionsContact.sendRequest(widget.userId)),
      ),
    ];
  }

  ContactActions get _actionsContact => ref.read(contactActionsProvider);

  /// Retirer quelqu'un se confirme : c'est la seule action de cet écran qui
  /// défait quelque chose sans moyen de le refaire d'un geste.
  Future<void> _retirer(ProfilConsultable p) async {
    final bool confirme =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext c) => AlertDialog(
            title: const Text('Retirer ce contact ?'),
            content: Text(
              '${p.profil.displayName} ne figurera plus dans votre carnet. '
              'Vos groupes communs ne changent pas.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: Text(
                  'Retirer',
                  style: TextStyle(color: context.couleurs.dangerInk),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirme) return;
    await _agir(() => _actionsContact.remove(widget.userId));
  }

  /// Exécute l'action, puis **relit le profil**.
  ///
  /// La relecture n'est pas du confort : la relation vient de la base, et sans
  /// elle l'écran continuerait d'offrir « Ajouter en contact » à quelqu'un
  /// qu'on vient d'ajouter.
  Future<void> _agir(Future<void> Function() action) async {
    if (_enCours) return;
    setState(() => _enCours = true);
    // Capturé avant l'`await` : la garde du routeur peut avoir quitté l'écran
    // au moment d'afficher le message.
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(profilConsultableProvider(widget.userId));
    } catch (error) {
      messager.showSnackBar(
        const SnackBar(content: Text('L’action n’a pas abouti.')),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.profil,
    required this.actions,
    required this.enCours,
    required this.onOuvrirGroupe,
  });

  final ProfilConsultable profil;
  final List<ProfileAction> actions;
  final bool enCours;
  final void Function(String groupeId) onOuvrirGroupe;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        PublicProfileHeaderCard(profil: profil, actions: actions),
        if (enCours) ...<Widget>[
          AppSpacing.gapMd,
          const Center(child: CircularProgressIndicator()),
        ],

        AppSpacing.gapMd,
        PublicAboutCard(profil: profil),

        // **Pas de carte de statistiques ici**, et plus de phrase pour
        // expliquer son absence. Les deux sont partis ensemble, et c'est
        // cohérent : la phrase existait parce qu'une carte manquait à un
        // non-contact, ce qui laissait un trou indiscernable d'un chargement
        // raté. Sans carte pour personne, il n'y a plus de trou à expliquer —
        // et annoncer qu'une donnée est retenue en dirait plus sur la personne
        // consultée que son absence.
        //
        // Ne subsiste comme champ réservé que la pastille de disponibilité, et
        // son absence est muette par construction : un contact qui n'a rien
        // déclaré n'en a pas non plus.
        AppSpacing.gapMd,
        CommonGroupsCard(
          groupes: profil.groupesCommuns,
          onOuvrir: onOuvrirGroupe,
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.titre,
    required this.message,
  });

  final IconData icon;
  final String titre;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.screenMargin),
    child: EmptyState(icon: icon, title: titre, message: message),
  );
}
