// lib/controllers/route_feedback_controller.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/route_feedback_model.dart';

class RouteFeedbackController {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all feedback for a route, including the user's name from profiles
  Future<List<RouteFeedback>> fetchForRoute(int routeId) async {
    try {
      final data = await _client
          .from('route_feedback')
          .select(
            'id, route_id, user_id, rating, comment, created_at, profiles(full_name)',
          )
          .eq('route_id', routeId)
          .order('created_at', ascending: false);

      final list = data as List<dynamic>;
      return list
          .map((row) => RouteFeedback.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('fetchForRoute error: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Optional helper – read the current average_rating from routes
  Future<double> averageForRoute(int routeId) async {
    try {
      final resp = await _client
          .from('routes')
          .select('average_rating')
          .eq('route_id', routeId) // your PK is route_id
          .maybeSingle();

      if (resp == null) return 0.0;
      final val = resp['average_rating'];
      return (val as num?)?.toDouble() ?? 0.0;
    } catch (e, st) {
      debugPrint('averageForRoute error: $e');
      debugPrint('$st');
      return 0.0;
    }
  }

  /// Add feedback. Returns null on success, or an error message on failure.
  Future<String?> addFeedback({
    required int routeId,
    required int rating,
    required String comment,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return 'You must be logged in to leave feedback.';
    }

    try {
      await _client.from('route_feedback').insert({
        'route_id': routeId,
        'user_id': user.id,
        'rating': rating,
        'comment': comment,
      });
    } catch (e, st) {
      debugPrint('addFeedback insert error: $e');
      debugPrint('$st');
      return 'Failed to submit feedback. Please try again.';
    }

    // average_rating/popularity on routes are recomputed automatically by
    // a database trigger on route_feedback — no client-side update needed.
    return null; // success
  }

  /// Delete feedback (only if owned by the current user).
  /// Returns null on success, or an error message on failure.
  Future<String?> deleteFeedback(int feedbackId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return 'You must be logged in.';
    }

    try {
      await _client
          .from('route_feedback')
          .delete()
          .eq('id', feedbackId)
          .eq('user_id', user.id);
    } catch (e, st) {
      debugPrint('deleteFeedback error: $e');
      debugPrint('$st');
      return 'Failed to delete feedback.';
    }

    // average_rating/popularity on routes are recomputed automatically by
    // a database trigger on route_feedback — no client-side update needed.
    return null;
  }
}
