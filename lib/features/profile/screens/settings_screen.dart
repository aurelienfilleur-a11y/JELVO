import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';

/// Écran Paramètres : compte, préférences à venir et déconnexion.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final Profile? profile = ref.watch(currentProfileProvider).value;
    final String? email = ref.watch(currentEmailProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
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
            const SectionHeader(title: 'Compte'),
            AppSpacing.gapMd,
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Nom',
                    value: profile?.displayName ?? '—',
                  ),
                  const Divider(height: AppSpacing.xl),
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Pseudo',
                    value: profile?.pseudoHandle ?? '—',
                  ),
                  const Divider(height: AppSpacing.xl),
                  _InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Adresse e-mail',
                    value: email ?? '—',
                  ),
                ],
              ),
            ),

            AppSpacing.gapXl,
            const SectionHeader(
              title: 'Préférences',
              subtitle: 'Notifications et thème arriveront prochainement',
            ),
            AppSpacing.gapMd,
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Text(
                      'Le réglage des notifications et le mode sombre ne sont '
                      'pas encore disponibles.',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.gapXxl,
            SecondaryButton(
              label: 'Se déconnecter',
              icon: Icons.logout_rounded,
              isDestructive: true,
              onPressed: _signingOut ? null : _confirmSignOut,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Se déconnecter'),
            content: const Text(
              'Vous devrez saisir à nouveau vos identifiants pour revenir.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      // La garde du routeur ramène à la connexion dès la session fermée.
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthFailure.from(error).message)));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.textSecondary),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
