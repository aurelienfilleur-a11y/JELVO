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
          Text('Inviter par lien', style: AppTypography.h2),
          AppSpacing.gapSm,
          Text(
            'Partagez ce lien par SMS, messagerie ou e-mail. La personne '
            'pourra créer son compte puis rejoindre « ${widget.group.name} ».',
            style: AppTypography.bodyMuted,
          ),

          if (_errorMessage != null) ...<Widget>[
            AppSpacing.gapLg,
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Text(
                _errorMessage!,
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          ],

          AppSpacing.gapXl,
          if (linksAsync.isLoading && links.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (active.isEmpty)
            Text(
              'Aucun lien actif pour le moment.',
              style: AppTypography.caption,
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

          AppSpacing.gapMd,
          PrimaryButton(
            label: active.isEmpty ? 'Générer un lien' : 'Générer un autre lien',
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
          .createInviteLink(groupId: widget.group.id);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = AuthFailure.from(error).message);
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
        setState(() => _errorMessage = AuthFailure.from(error).message);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share(GroupInviteLink link) async {
    final String url = AppConfig.inviteUrl(link.token);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Rejoins « ${widget.group.name} » sur Jelvo : $url',
          subject: 'Invitation à rejoindre ${widget.group.name}',
        ),
      );
    } catch (_) {
      // Pas de feuille de partage disponible (certains navigateurs) : le lien
      // reste copiable, ce qui couvre le même besoin.
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        const SnackBar(content: Text('Lien copié dans le presse-papiers.')),
      );
    }
  }

  Future<void> _copy(GroupInviteLink link) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: AppConfig.inviteUrl(link.token)),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Lien copié dans le presse-papiers.')),
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppConfig.inviteUrl(link.token),
            style: AppTypography.caption.copyWith(color: AppColors.primary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapSm,
          Text(
            '${link.usesLabel} · expire le '
            '${AppDates.shortDate(link.expiresAt)}',
            style: AppTypography.caption,
          ),
          AppSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: 'Partager',
                  icon: Icons.ios_share_rounded,
                  onPressed: onShare,
                ),
              ),
              AppSpacing.hGapSm,
              IconButton(
                onPressed: onCopy,
                tooltip: 'Copier le lien',
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
              IconButton(
                onPressed: onRevoke,
                tooltip: 'Révoquer le lien',
                icon: const Icon(
                  Icons.link_off_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
