import 'package:supabase_flutter/supabase_flutter.dart';

/// Looks up display names for a set of user IDs via the public_profiles
/// view (safe columns only — id, full_name, profile_image_url). Used to
/// attach commenter/reporter names to feedback and incident rows without
/// relying on PostgREST embedding, since public_profiles is a view (no
/// foreign key) and can't be auto-embedded the way the base profiles
/// table could.
Future<Map<String, String>> fetchFullNames(
  SupabaseClient client,
  Iterable<String> userIds,
) async {
  final ids = userIds.toSet().toList();
  if (ids.isEmpty) return {};

  final resp = await client
      .from('public_profiles')
      .select('id, full_name')
      .inFilter('id', ids);

  final list = resp as List<dynamic>;
  final map = <String, String>{};
  for (final row in list) {
    final id = row['id'] as String?;
    final name = row['full_name'] as String?;
    if (id != null && name != null) {
      map[id] = name;
    }
  }
  return map;
}
