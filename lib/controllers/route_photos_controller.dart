// lib/controllers/route_photos_controller.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/route_photo_model.dart';

class RoutePhotosController {
  final _client = Supabase.instance.client;
  static const bucket = 'route-photos'; // Public bucket

  /// List photos for a route (newest first).
  Future<List<RoutePhoto>> list(int routeId, {int limit = 24}) async {
    final res = await _client
        .from('route_photos')
        .select('id, route_id, user_id, storage_path, url, caption, created_at')
        .eq('route_id', routeId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (res as List)
        .map((m) => RoutePhoto.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Pick image -> upload to Storage -> insert DB row.
  Future<bool> pickAndUpload({required int routeId, String? caption}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final file = File(picked.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.id}.jpg';

    // Clean object path (NO bucket prefix)
    final objectPath = 'route_$routeId/$fileName';

    // 1) Upload to Storage
    await _client.storage.from(bucket).upload(objectPath, file);

    // 2) Build a PUBLIC URL (bucket is public)
    final publicUrl = _client.storage.from(bucket).getPublicUrl(objectPath);

    // 3) Insert DB row (RLS requires user_id == auth.uid())
    await _client.from('route_photos').insert({
      'route_id': routeId,
      'user_id': user.id,
      'storage_path': objectPath, // e.g., route_9/xxx.jpg
      'url': publicUrl, // full https URL (handy for rendering)
      'caption': caption,
      'is_public': true,
      'is_approved': true,
    });

    return true;
  }

  /// Delete a photo (only if it belongs to the current user).
  /// Returns null on success, or an error message.
  Future<String?> deletePhoto(RoutePhoto photo) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'You must be logged in';

    // Must match RLS on route_photos and storage.objects
    if (photo.userId != user.id) {
      return 'You can only delete your own photo';
    }

    try {
      // Derive the storage object path (handles with/without bucket prefix)
      final parts = photo.storagePath.split('/');
      final hasBucketPrefix = parts.isNotEmpty && parts.first == bucket;
      final objectPath = hasBucketPrefix
          ? parts.sublist(1).join('/')
          : photo.storagePath;

      // 1) Delete from Storage bucket
      await _client.storage.from(bucket).remove([objectPath]);

      // 2) Delete from DB table
      await _client
          .from('route_photos')
          .delete()
          .eq('id', photo.id)
          .eq('user_id', user.id);

      return null; // success
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  /// Public URL when you stored ONLY the object path (recommended).
  String getPublicUrlFromObjectPath(String objectPath) {
    return _client.storage.from(bucket).getPublicUrl(objectPath);
  }

  /// Back-compat: works whether storagePath includes the bucket or not.
  String getPublicUrl(String storagePath) {
    final parts = storagePath.split('/');
    if (parts.isNotEmpty && parts.first == bucket) {
      final path = parts.sublist(1).join('/');
      return _client.storage.from(bucket).getPublicUrl(path);
    }
    return _client.storage.from(bucket).getPublicUrl(storagePath);
  }

  /// Signed URL helper (useful if you later switch bucket to PRIVATE).
  Future<String> getSignedUrl(
    String storagePath, {
    int expiresInSec = 3600,
  }) async {
    final parts = storagePath.split('/');
    final hasBucketPrefix = parts.isNotEmpty && parts.first == bucket;
    final objectPath = hasBucketPrefix
        ? parts.sublist(1).join('/')
        : storagePath;
    return _client.storage
        .from(bucket)
        .createSignedUrl(objectPath, expiresInSec);
  }
}
