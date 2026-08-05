import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase de l'application.
///
/// Exposé par un provider plutôt que via le singleton `Supabase.instance` :
/// les tests peuvent ainsi surcharger toute la couche d'accès sans que
/// `Supabase.initialize` ait été appelé.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);
