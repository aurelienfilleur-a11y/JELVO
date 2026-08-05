import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';
import '../repository/contact_repository.dart';
import '../widgets/qr_support.dart';

/// Ajout d'un contact : recherche par pseudo, QR personnel et scanner.
class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final TextEditingController _controller = TextEditingController();
  String _term = '';
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ajouter un contact'),
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
            AppTextField(
              label: 'Pseudo',
              hint: 'camille.rousseau',
              controller: _controller,
              prefixIcon: Icons.alternate_email_rounded,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (String value) => setState(() {
                _term = value;
                _message = null;
              }),
            ),
            AppSpacing.gapMd,

            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: 'Mon QR code',
                    icon: Icons.qr_code_rounded,
                    onPressed: () => context.pushNamed(AppRoutes.myQrCode),
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: SecondaryButton(
                    label: 'Scanner',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: QrScanSupport.isAvailable
                        ? () => context.pushNamed(AppRoutes.scanContact)
                        : null,
                  ),
                ),
              ],
            ),
            if (!QrScanSupport.isAvailable) ...<Widget>[
              AppSpacing.gapSm,
              Text(
                QrScanSupport.unavailableMessage,
                style: AppTypography.caption,
              ),
            ],

            if (_message != null) ...<Widget>[
              AppSpacing.gapLg,
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Text(
                  _message!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],

            AppSpacing.gapXl,
            const SectionHeader(title: 'Résultats'),
            AppSpacing.gapMd,
            _Results(term: _term, onPick: sendRequest),
          ],
        ),
      ),
    );
  }

  Future<void> sendRequest(ProfileSummary profile) async {
    try {
      final ContactRequestOutcome outcome = await ref
          .read(contactActionsProvider)
          .sendRequest(profile.id);
      if (!mounted) return;
      setState(() => _message = outcome.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = AuthFailure.from(error).message);
    }
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.term, required this.onPick});

  final String term;
  final Future<void> Function(ProfileSummary profile) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (term.trim().length < 2) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Cherchez un pseudo',
        message:
            'Saisissez au moins deux caractères pour trouver quelqu’un, ou '
            'scannez son QR code.',
      );
    }

    final AsyncValue<List<ProfileSummary>> results = ref.watch(
      pseudoSearchProvider(term),
    );
    final List<Contact> known =
        ref.watch(contactsProvider).value ?? const <Contact>[];
    final Set<String> knownIds = <String>{for (final Contact c in known) c.id};

    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Recherche indisponible',
        message: AuthFailure.from(error).message,
      ),
      data: (List<ProfileSummary> profiles) {
        if (profiles.isEmpty) {
          return EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Aucun résultat',
            message: 'Aucun pseudo ne commence par « $term ».',
          );
        }

        return Column(
          children: <Widget>[
            for (final ProfileSummary profile in profiles) ...<Widget>[
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    AvatarStack(
                      avatars: <AvatarData>[
                        AvatarData(
                          name: profile.fullName,
                          imageUrl: profile.avatarUrl,
                        ),
                      ],
                      size: 40,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile.fullName,
                            style: AppTypography.body.copyWith(
                              fontWeight: AppTypography.semiBold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            profile.pseudoHandle,
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (knownIds.contains(profile.id))
                      Text('Déjà dans le carnet', style: AppTypography.caption)
                    else
                      TextButton(
                        onPressed: () => onPick(profile),
                        child: const Text('Ajouter'),
                      ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
            ],
          ],
        );
      },
    );
  }
}
