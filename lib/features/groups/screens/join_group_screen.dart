import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/group_invite.dart';
import '../providers/group_providers.dart';
import '../widgets/group_banner.dart';

/// Page publique d'un lien de partage : `/rejoindre/<jeton>`.
///
/// Accessible sans session — c'est tout l'intérêt du lien. Sans compte, le
/// jeton est mis de côté et l'inscription prend le relais ; le groupe est
/// rejoint automatiquement une fois le compte créé.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool _working = false;
  String? _resultMessage;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<GroupInvitePreview> previewAsync = ref.watch(
      groupInvitePreviewProvider(widget.token),
    );
    final bool signedIn = ref.watch(authStatusProvider) == AuthStatus.signedIn;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: previewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Invitation indisponible',
            message: AuthFailure.from(error).message,
            actionLabel: 'Réessayer',
            onActionPressed: () =>
                ref.invalidate(groupInvitePreviewProvider(widget.token)),
          ),
          data: (GroupInvitePreview preview) =>
              _content(preview, signedIn: signedIn),
        ),
      ),
    );
  }

  Widget _content(GroupInvitePreview preview, {required bool signedIn}) {
    if (!preview.isJoinable) {
      return EmptyState(
        icon: Icons.link_off_rounded,
        title: 'Lien inutilisable',
        message: preview.status.message,
        actionLabel: signedIn ? "Revenir à l'accueil" : 'Se connecter',
        onActionPressed: () =>
            context.goNamed(signedIn ? AppRoutes.home : AppRoutes.login),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.lg),
          ),
          child: GroupBanner(
            name: preview.name ?? 'Groupe',
            subtitle:
                '${preview.memberCount} membre'
                '${preview.memberCount > 1 ? 's' : ''}',
            accentColor: AppColors.primary,
            icon: Icons.groups_rounded,
            photoUrl: preview.photoUrl,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Vous êtes invité à rejoindre ce groupe sur Jelvo.',
                style: AppTypography.h3,
              ),
              if (preview.description != null &&
                  preview.description!.isNotEmpty) ...<Widget>[
                AppSpacing.gapMd,
                Text(preview.description!, style: AppTypography.bodyMuted),
              ],

              // Une adhésion qui s'arrête n'est pas la même offre qu'une
              // adhésion sans fin : elle se dit **avant** d'accepter, pas
              // après.
              if (preview.membershipExpiresAt != null) ...<Widget>[
                AppSpacing.gapMd,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: AppRadii.fieldRadius,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          'Adhésion temporaire : vous ferez partie du groupe '
                          'jusqu’au '
                          '${AppDates.fullDate(preview.membershipExpiresAt!)}.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.midnight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_resultMessage != null) ...<Widget>[
                AppSpacing.gapLg,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: AppRadii.fieldRadius,
                  ),
                  child: Text(
                    _resultMessage!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],

              AppSpacing.gapXxl,
              if (signedIn)
                PrimaryButton(
                  label: 'Rejoindre le groupe',
                  icon: Icons.group_add_rounded,
                  isLoading: _working,
                  onPressed: _join,
                )
              else ...<Widget>[
                PrimaryButton(
                  label: 'Créer un compte pour rejoindre',
                  icon: Icons.person_add_alt_rounded,
                  onPressed: () => _rememberThen(AppRoutes.signUp),
                ),
                AppSpacing.gapMd,
                SecondaryButton(
                  label: "J'ai déjà un compte",
                  onPressed: () => _rememberThen(AppRoutes.login),
                ),
                AppSpacing.gapMd,
                Text(
                  'Le groupe sera rejoint automatiquement une fois votre '
                  'compte créé.',
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Met le jeton de côté puis part vers l'authentification.
  void _rememberThen(String routeName) {
    ref.read(pendingInviteTokenProvider.notifier).remember(widget.token);
    context.goNamed(routeName);
  }

  Future<void> _join() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GoRouter router = GoRouter.of(context);

    setState(() {
      _working = true;
      _resultMessage = null;
    });
    try {
      final JoinOutcome outcome = await ref
          .read(groupActionsProvider)
          .joinByToken(widget.token);

      if (!outcome.isSuccess) {
        if (mounted) setState(() => _resultMessage = outcome.message);
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
      final String? groupId = ref
          .read(groupInvitePreviewProvider(widget.token))
          .value
          ?.groupId;
      if (groupId == null) {
        router.goNamed(AppRoutes.groups);
      } else {
        router.goNamed(
          AppRoutes.groupDetail,
          pathParameters: <String, String>{'id': groupId},
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _resultMessage = AuthFailure.from(error).message);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
