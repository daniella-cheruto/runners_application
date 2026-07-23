// lib/controllers/admin_feedback_controller.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/route_feedback_model.dart';
import '/controllers/profile_lookup.dart';

class AdminFeedbackController {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<RouteFeedback>> fetchAllFeedback() async {
    try {
      final resp = await _client
          .from('route_feedback')
          .select(
            'id, route_id, user_id, rating, comment, created_at, routes(name)',
          )
          .order('created_at', ascending: false);

      final list = resp as List<dynamic>;
      final userIds = list.map((row) => row['user_id'] as String);
      final names = await fetchFullNames(_client, userIds);

      return list.map((row) {
        final map = row as Map<String, dynamic>;
        map['profiles'] = {'full_name': names[map['user_id']]};
        return RouteFeedback.fromJson(map);
      }).toList();
    } catch (e, st) {
      debugPrint('fetchAllFeedback error: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// ADMIN: delete feedback. average_rating/popularity on routes are
  /// recomputed automatically by a database trigger on route_feedback.
  Future<String?> adminDeleteFeedback({required int feedbackId}) async {
    try {
      await _client.from('route_feedback').delete().eq('id', feedbackId);
      return null;
    } catch (e, st) {
      debugPrint('adminDeleteFeedback error: $e');
      debugPrint('$st');
      return 'Failed to delete feedback.';
    }
  }
}
