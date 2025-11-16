import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/route_model.dart';

class RoutesController {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<RouteModel>> fetchRoutes({
    double? maxDistance, // meters
    double? minRating,
    int? minPopularity,
  }) async {
    try {
      var query = _client.from('routes').select();

      if (maxDistance != null) {
        final intMax = maxDistance.toInt();
        debugPrint('Applying maxDistance <= $intMax');
        query = query.lte('distance_m', intMax);
      }
      if (minRating != null) {
        debugPrint('Applying minRating >= $minRating');
        query = query.gte('average_rating', minRating);
      }
      if (minPopularity != null) {
        debugPrint('Applying minPopularity >= $minPopularity');
        query = query.gte('popularity', minPopularity);
      }

      final resp = await query;
      final list = resp as List<dynamic>;

      debugPrint('fetchRoutes returned ${list.length} rows');

      return list
          .map((row) => RouteModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('fetchRoutes error: $e');
      debugPrint('$st');
      // Return empty so UI shows "No routes found" instead of crashing
      return [];
    }
  }

  Future<List<RouteModel>> searchRoutes(String term) async {
    final t = term.trim();
    if (t.isEmpty) {
      return fetchRoutes();
    }

    try {
      debugPrint('Searching for "$t"...');
      final resp = await _client
          .from('routes')
          .select()
          .or('name.ilike.%$t%,description.ilike.%$t%');

      final list = resp as List<dynamic>;
      debugPrint('searchRoutes returned ${list.length} rows');

      return list
          .map((row) => RouteModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('searchRoutes error: $e');
      debugPrint('$st');
      return [];
    }
  }

  Future<bool> addRoute({
    required String name,
    required String description,
    required int distanceM,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final uid = _client.auth.currentUser!.id;

      await _client.from('routes').insert({
        'name': name,
        'description': description,
        'distance_m': distanceM,
        'start_latitude': startLat,
        'start_longitude': startLng,
        'end_latitude': endLat,
        'end_longitude': endLng,
        'average_rating': 0,
        'popularity': 0,
        'user_id': uid,
      });

      return true;
    } catch (e, st) {
      debugPrint('addRoute error: $e');
      debugPrint('$st');
      return false;
    }
  }
}
