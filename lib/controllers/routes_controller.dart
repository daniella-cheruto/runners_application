// lib/controllers/routes_controller.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/route_model.dart';

class RoutesController {
  final SupabaseClient _client = Supabase.instance.client;

  /// Normal: fetch routes with optional filters
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

      final resp = await query.order('name', ascending: true);
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

  /// Normal: look up a route by exact (case-insensitive) name match.
  /// Used to warn users before creating a likely duplicate. Returns the
  /// first match, or null if none exists. Fails open (returns null) on
  /// error so a broken check never blocks route creation.
  Future<RouteModel?> findRouteByName(String name) async {
    try {
      final resp = await _client
          .from('routes')
          .select()
          .ilike('name', name.trim())
          .limit(1)
          .maybeSingle();

      if (resp == null) return null;
      return RouteModel.fromJson(resp);
    } catch (e, st) {
      debugPrint('findRouteByName error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Normal: check whether a route has any community data attached
  /// (feedback, photos, or incident reports) from anyone. Deleting a route
  /// cascades to delete route_feedback, route_photos, and incident_report
  /// (all ON DELETE CASCADE) — so this guards against a route's creator
  /// silently destroying other users' contributions. Fails closed (returns
  /// true) on error, since blocking a delete is safer than risking one
  /// that destroys data we couldn't verify.
  Future<bool> routeHasCommunityData(int routeId) async {
    try {
      final results = await Future.wait([
        _client
            .from('route_feedback')
            .select('id')
            .eq('route_id', routeId)
            .limit(1),
        _client
            .from('route_photos')
            .select('id')
            .eq('route_id', routeId)
            .limit(1),
        _client
            .from('incident_report')
            .select('incident_id')
            .eq('route_id', routeId)
            .limit(1),
      ]);

      return results.any((r) => (r as List).isNotEmpty);
    } catch (e, st) {
      debugPrint('routeHasCommunityData error: $e');
      debugPrint('$st');
      return true;
    }
  }

  /// Normal: delete a route the current user owns, but only if it has no
  /// community data attached (see routeHasCommunityData). Relies on RLS
  /// ("Allow users to delete their own routes") to enforce ownership.
  /// Returns null on success, or an error message on failure.
  Future<String?> deleteRoute(int routeId) async {
    final hasData = await routeHasCommunityData(routeId);
    if (hasData) {
      return "This route has feedback, photos, or incident reports from "
          "the community and can't be deleted.";
    }

    try {
      final deleted = await _client
          .from('routes')
          .delete()
          .eq('route_id', routeId)
          .select('route_id');

      final list = deleted as List<dynamic>;
      if (list.isEmpty) {
        return "Couldn't delete this route.";
      }
      return null;
    } catch (e, st) {
      debugPrint('deleteRoute error: $e');
      debugPrint('$st');
      return 'Failed to delete route.';
    }
  }

  /// Normal: search routes by name/description
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
          .or('name.ilike.%$t%,description.ilike.%$t%')
          .order('name', ascending: true);

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

  /// Normal: add a new route
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

  // ===================== ADMIN METHODS  =====================

  /// ADMIN: fetch all routes (no filters)
  Future<List<RouteModel>> adminFetchAllRoutes({int? limit}) async {
    try {
      final resp = await _client
          .from('routes')
          .select()
          .order('name')
          .limit(limit ?? 200);

      final list = resp as List<dynamic>;
      debugPrint('adminFetchAllRoutes returned ${list.length} rows');

      return list
          .map((row) => RouteModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('adminFetchAllRoutes error: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// ADMIN: update route name + description by route_id
  Future<String?> adminUpdateRoute({
    required int routeId,
    required String name,
    required String description,
  }) async {
    try {
      await _client
          .from('routes')
          .update({'name': name, 'description': description})
          .eq('route_id', routeId); //  matches the DB column

      return null;
    } catch (e, st) {
      debugPrint('adminUpdateRoute error: $e');
      debugPrint('$st');
      return 'Failed to update route.';
    }
  }

  /// ADMIN: delete a route by route_id
  Future<String?> adminDeleteRoute(int routeId) async {
    try {
      await _client.from('routes').delete().eq('route_id', routeId);
      return null;
    } catch (e, st) {
      debugPrint('adminDeleteRoute error: $e');
      debugPrint('$st');
      return 'Failed to delete route.';
    }
  }
}
