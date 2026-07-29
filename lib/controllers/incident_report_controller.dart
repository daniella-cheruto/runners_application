import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/models/incident_report_model.dart';
import '/controllers/profile_lookup.dart';

class IncidentReportController {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _bucket = 'incident-photos';

  /// Upload a photo file to Supabase Storage and return its public URL.
  Future<String> uploadIncidentPhoto(String filePath) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist.');
    }

    final fileName =
        'incident_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final bytes = await file.readAsBytes();

      await _client.storage
          .from(_bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(fileName);
      return publicUrl;
    } catch (e, st) {
      debugPrint('uploadIncidentPhoto error: $e');
      debugPrint('$st');
      throw Exception('Failed to upload photo.');
    }
  }

  /// Fetch all incidents for a given route.
  /// Joins with profiles to show reporter name.
  Future<List<IncidentReport>> fetchForRoute(int routeId) async {
    try {
      final resp = await _client
          .from('incident_report')
          .select(
            'incident_id, route_id, user_id, incident_type, severity, '
            'description, latitude, longitude, created_at, photo_urls',
          )
          .eq('route_id', routeId)
          .order('created_at', ascending: false);

      final list = resp as List<dynamic>;
      final userIds = list.map((row) => row['user_id'] as String);
      final names = await fetchFullNames(_client, userIds);

      return list.map((row) {
        final map = row as Map<String, dynamic>;
        map['profiles'] = {'full_name': names[map['user_id']]};
        return IncidentReport.fromJson(map);
      }).toList();
    } catch (e, st) {
      debugPrint('fetchForRoute (incident_report) error: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Add a new incident report.
  /// Returns `null` on success, or an error message on failure.
  Future<String?> addIncident({
    required int routeId,
    required String incidentType,
    required String severity,
    String? description,
    double? latitude,
    double? longitude,
    List<String>? photoUrls, // NEW
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return 'You must be logged in to report an incident.';
    }

    try {
      await _client.from('incident_report').insert({
        'route_id': routeId,
        'user_id': user.id,
        'incident_type': incidentType,
        'severity': severity,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'photo_urls': photoUrls, // NEW
      });

      return null;
    } catch (e, st) {
      debugPrint('addIncident error: $e');
      debugPrint('$st');
      return 'Failed to submit incident. Please try again.';
    }
  }

  /// Delete an incident (only if owned by the current user). Also removes
  /// any photos the incident had from storage.
  /// Returns `null` on success, or an error message on failure.
  Future<String?> deleteIncident(int incidentId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return 'You must be logged in.';
    }

    try {
      final existing = await _client
          .from('incident_report')
          .select('photo_urls')
          .eq('incident_id', incidentId)
          .eq('user_id', user.id)
          .maybeSingle();

      await _client
          .from('incident_report')
          .delete()
          .eq('incident_id', incidentId)
          .eq('user_id', user.id);

      await _deletePhotosForUrls(existing?['photo_urls']);

      return null;
    } catch (e, st) {
      debugPrint('deleteIncident error: $e');
      debugPrint('$st');
      return 'Failed to delete incident.';
    }
  }

  //  ADMIN METHODS BELOW

  /// ADMIN: fetch all incidents across all routes (no route/user filter).
  Future<List<IncidentReport>> fetchAllIncidents({int? limit}) async {
    try {
      final resp = await _client
          .from('incident_report')
          .select(
            'incident_id, route_id, user_id, incident_type, severity, '
            'description, latitude, longitude, created_at, photo_urls, '
            'routes(name)',
          )
          .order('created_at', ascending: false)
          .limit(limit ?? 200);

      final list = resp as List<dynamic>;
      final userIds = list.map((row) => row['user_id'] as String);
      final names = await fetchFullNames(_client, userIds);

      return list.map((row) {
        final map = row as Map<String, dynamic>;
        map['profiles'] = {'full_name': names[map['user_id']]};
        return IncidentReport.fromJson(map);
      }).toList();
    } catch (e, st) {
      debugPrint('fetchAllIncidents error: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// ADMIN: delete any incident (RLS will allow only admins to succeed).
  /// Also removes any photos the incident had from storage.
  Future<String?> adminDeleteIncident(int incidentId) async {
    try {
      final existing = await _client
          .from('incident_report')
          .select('photo_urls')
          .eq('incident_id', incidentId)
          .maybeSingle();

      await _client
          .from('incident_report')
          .delete()
          .eq('incident_id', incidentId);

      await _deletePhotosForUrls(existing?['photo_urls']);

      return null;
    } catch (e, st) {
      debugPrint('adminDeleteIncident error: $e');
      debugPrint('$st');
      return 'Failed to delete incident.';
    }
  }

  /// Delete the storage files for a set of public photo URLs (best-effort
  /// — failure here shouldn't block deleting the report itself).
  Future<void> _deletePhotosForUrls(dynamic photoUrls) async {
    if (photoUrls is! List || photoUrls.isEmpty) return;
    try {
      final paths = photoUrls
          .whereType<String>()
          .map(_extractStoragePath)
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        await _client.storage.from(_bucket).remove(paths);
      }
    } catch (e, st) {
      debugPrint('incident photo cleanup error (ignored): $e');
      debugPrint('$st');
    }
  }

  /// Extract the storage object path from a public URL like
  /// https://xxx.supabase.co/storage/v1/object/public/incident-photos/foo.jpg
  String? _extractStoragePath(String url) {
    final marker = '/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }
}
