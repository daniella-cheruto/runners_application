// lib/controllers/profile_controller.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '/models/user_model.dart';
import 'package:flutter/material.dart';

class ProfileController {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch full user profile from Supabase "profiles" table
  Future<UserModel?> fetchUserProfile(String uid) async {
    try {
      final data = await _client
          .from('profiles')
          .select('*')
          .eq('id', uid)
          .maybeSingle(); // returns Map<String, dynamic>? or null

      if (data != null) return UserModel.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
    return null;
  }

  /// Validate profile fields
  String? validateProfile({required String fullName}) {
    if (fullName.trim().isEmpty) return 'Full Name is required';
    return null;
  }

  /// Update or create user profile in Supabase
  Future<bool> updateProfile({
    required String uid,
    required String fullName,
    String? dob,
    String? gender,
    String? location,
    String? experience,
    String? preferredTime,
    String? emergencyContact,
    String? profileImageUrl,
  }) async {
    try {
      final profileData = {
        'id': uid,
        'full_name': fullName,
        'dob': dob,
        'gender': gender,
        'location': location,
        'experience': experience,
        'preferred_time': preferredTime,
        'emergency_contact': emergencyContact,
        'profile_image_url': profileImageUrl,
      };

      await _client.from('profiles').upsert(profileData, onConflict: 'id');

      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Pick image from gallery
  Future<File?> pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) return File(pickedFile.path);
    return null;
  }

  /// Upload profile image to Supabase storage
  Future<String?> uploadProfileImage(File imageFile, String uid) async {
    try {
      final filePath = 'profile_images/$uid.jpg';
      final storage = _client.storage.from('profile-images');

      await storage.upload(filePath, imageFile,
          fileOptions: const FileOptions(upsert: true));

      final url = storage.getPublicUrl(filePath);
      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
}
