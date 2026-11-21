import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../../../data/data_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../providers/group_providers.dart';
import 'membership_term_picker.dart';

/// Feuille de génération et de partage d'un lien d'invitation.
///
/// Le lien s'adresse à quelqu'un qui n'a pas encore de compte : il ouvre une
/// page publique, contrairement à l'invitation nominative qui suppose un compte
/// existant.
class InviteLinkSheet extends ConsumerStatefulWidget {
  const InviteLinkSheet({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<InviteLinkSheet> createState() => _InviteLinkSheetState();
}

class _InviteLinkSheetState extends ConsumerState<InviteLinkSheet> {
  bool _working = false;
  String? _errorMessage;

  /// Terme de l'adhésion accordée par le **prochain** lien généré.
  ///
  /// Les liens déjà créés gardent le leur : leur durée est partie avec eux,
  /// et la modifier après coup changerait une offre déjà envoyée.
  DateTime? _terme;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<GroupInviteLink>> linksAsync = ref.watch(
      groupInviteLinksProvider(widget.group.id),
    );
    final DateTime now = ref.watch(nowProvider);

    final List<GroupInviteLink> links =
        linksAsync.value ?? const <GroupInviteLink>[];
    final List<GroupInviteLink> active = links
        .where((GroupInviteLink l) => l.isActive(now))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppTexts.of(context).groupsInviterLien, style: context.typo.h2),
          AppSpacing.gapSm,
          Text(
            AppTexts.of(context).groupsPartagezCeLien(widget.group.name),
            style: context.typo.bodyMuted,
          ),

          if (_errorMessage != null) ...<Widget>[
            AppSpacing.gapLg,
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.couleurs.dangerSoft,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Text(
                _errorMessage!,
                style: context.typo.caption.copyWith(
                  color: context.couleurs.danger,
                ),
              ),
            ),
          ],

          AppSpacing.gapXl,
          if (linksAsync.isLoading && links.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (active.isEmpty)
            Text(
              AppTexts.of(context).groupsAucunLienActifMoment,
              style: context.typo.caption,
            )
          else
            for (final GroupInviteLink link in active) ...<Widget>[
              _LinkCard(
                link: link,
                now: now,
                onShare: () => _share(link),
                onCopy: () => _copy(link),
                onRevoke: _working ? null : () => _revoke(link),
              ),
              AppSpacing.gapMd,
            ],

          if (widget.group.isAdmin) ...<Widget>[
            AppSpacing.gapMd,
            MembershipTermPicker(
              now: now,
              value: _terme,
              enabled: !_working,
              label: AppTexts.of(context).groupsDureeAccordeeProchainLien,
              onChanged: (DateTime? valeur) => setState(() => _terme = valeur),
            ),
          ],

          AppSpacing.gapMd,
          PrimaryButton(
            label: active.isEmpty
                ? AppTexts.of(context).groupsGenererLien
                : AppTexts.of(context).groupsGenererAutreLien,
            icon: Icons.link_rounded,
            isLoading: _working,
            onPressed: _create,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      _working = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(groupActionsProvider)
          .createInviteLink(
            groupId: widget.group.id,
            membershipExpiresAt: _terme,
          );
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = AuthFailure.from(
            error,
          ).message(AppTexts.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _revoke(GroupInviteLink link) async {
    setState(() {
      _working = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(groupActionsProvider)
          .revokeInviteLink(groupId: widget.group.id, linkId: link.id);
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = AuthFailure.from(
            error,
          ).message(AppTexts.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share(GroupInviteLink link) async {
    // Lu **avant** l’attente : le contexte peut avoir disparu après.
    final AppTexts t = AppTexts.of(context);
    final String url = AppConfig.inviteUrl(link.token);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: t.groupsRejoinsSurJelvo(widget.group.name, url),
          subject: t.groupsInvitationARejoindre(widget.group.name),
        ),
      );
    } catch (_) {
      // Pas de feuille de partage disponible (certains navigateurs) : le lien
      // reste copiable, ce qui couvre le même besoin.
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        SnackBar(content: Text(t.groupsLienCopiePressePapiers)),
      );
    }
  }

  Future<void> _copy(GroupInviteLink link) async {
    // Lu **avant** l’attente : le contexte peut avoir disparu après.
    final AppTexts t = AppTexts.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: AppConfig.inviteUrl(link.token)),
    );
    messenger.showSnackBar(
      SnackBar(content: Text(t.groupsLienCopiePressePapiers)),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.now,
    required this.onShare,
    required this.onCopy,
    required this.onRevoke,
  });

  final GroupInviteLink link;
  final DateTime now;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppConfig.inviteUrl(link.token),
            style: context.typo.caption.copyWith(
              color: context.couleurs.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapSm,
          Text(
            t.groupsUtilisationsExpireLe(
              link.usesLabel(t),
              AppDates.shortDate(link.expiresAt, t),
            ),
            style: context.typo.caption,
          ),
          // Deux dates que rien ne rapproche : celle du dessus dit jusqu'à
          // quand le lien sert, celle-ci ce qu'il accorde. Un lien valable
          // trente jours peut n'ouvrir qu'une adhésion d'une semaine.
          if (link.isTemporaryMembership) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              t.groupsAdhesionJusquAu(
                AppDates.shortDate(link.membershipExpiresAt!, t),
              ),
              style: context.typo.caption.copyWith(
                color: context.couleurs.warning,
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ],
          AppSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: t.corePartager,
                  icon: Icons.ios_share_rounded,
                  onPressed: onShare,
                ),
              ),
              AppSpacing.hGapSm,
              IconButton(
                onPressed: onCopy,
                tooltip: AppTexts.of(context).groupsCopierLien,
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
              IconButton(
                onPressed: onRevoke,
                tooltip: AppTexts.of(context).groupsRevoquerLien,
                icon: Icon(
                  Icons.link_off_rounded,
                  size: 20,
                  color: context.couleurs.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
