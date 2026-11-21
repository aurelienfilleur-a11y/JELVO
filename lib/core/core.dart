/// Point d'entrée unique du noyau : thème + design system.
///
/// Les écrans importent `package:jelvo/core/core.dart` plutôt que chaque
/// fichier individuellement.
library;

// `AppTexts` est exporté ici pour la même raison que la palette : un écran
// lit ses mots au contexte comme il y lit ses couleurs, et un seul import
// doit suffire. `core/utils/date_formatting.dart` en dépend déjà.
export '../l10n/app_localizations.dart';

export 'theme/jelvo_colors.dart';
export 'theme/app_radii.dart';
export 'theme/app_shadows.dart';
export 'theme/app_spacing.dart';
export 'theme/app_theme.dart';
export 'theme/app_typography.dart';
export 'theme/emoji_runs.dart';
export 'theme/speaker_accent.dart';
export 'utils/date_formatting.dart';
export 'widgets/app_card.dart';
export 'widgets/app_screen.dart';
export 'widgets/app_text_field.dart';
export 'widgets/cover_banner.dart';
export 'widgets/avatar_stack.dart';
export 'widgets/emoji_text.dart';
export 'widgets/empty_state.dart';
export 'widgets/event_card.dart';
export 'widgets/group_card.dart';
export 'widgets/invitation_header.dart';
export 'widgets/nav_badge.dart';
export 'widgets/option_row.dart';
export 'widgets/person_picker.dart';
export 'widgets/primary_button.dart';
export 'widgets/secondary_button.dart';
export 'widgets/section_header.dart';
export 'widgets/status_dot.dart';
export 'widgets/task_row.dart';
