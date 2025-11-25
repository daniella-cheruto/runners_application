// lib/views/profile/profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/controllers/profile_controller.dart';
import '/widgets/custom_textfield.dart';
import '/widgets/custom_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _controller = ProfileController();

  // Validators
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _preferredTimeController =
      TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;

  String _statusMessage = '';
  Color _statusColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await _controller.fetchUserProfile(user.id);
    if (profile != null) {
      setState(() {
        _nameController.text = profile.fullName;
        _dobController.text = profile.dob ?? '';
        _genderController.text = profile.gender ?? '';
        _locationController.text = profile.location ?? '';
        _experienceController.text = profile.experience ?? '';
        _preferredTimeController.text = profile.preferredTime ?? '';
        _emergencyContactController.text = profile.emergencyContact ?? '';
        _profileImageUrl = profile.profileImageUrl;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _controller.pickProfileImage();
    if (picked != null) setState(() => _profileImage = picked);
  }

  String? _requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _statusMessage = '');

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _statusMessage = 'Please fill in all required fields.';
        _statusColor = Colors.red;
      });
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String? uploadedUrl = _profileImageUrl;

    if (_profileImage != null) {
      final url = await _controller.uploadProfileImage(_profileImage!, user.id);
      if (url != null) uploadedUrl = url;
    }

    final success = await _controller.updateProfile(
      uid: user.id,
      fullName: _nameController.text.trim(),
      dob: _dobController.text.trim(),
      gender: _genderController.text.trim(),
      location: _locationController.text.trim(),
      experience: _experienceController.text.trim(),
      preferredTime: _preferredTimeController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim(),
      profileImageUrl: uploadedUrl,
    );

    if (success) {
      _profileImageUrl = uploadedUrl;
      await _loadUserProfile();
    }

    setState(() {
      _statusMessage = success
          ? 'Profile updated successfully!'
          : 'Failed to update profile';
      _statusColor = success ? Colors.green : Colors.red;
    });
  }

  Future<void> _pickDob() async {
    DateTime? initial;

    if (_dobController.text.trim().isNotEmpty) {
      try {
        initial = DateTime.parse(_dobController.text.trim());
      } catch (_) {}
    }

    initial ??= DateTime(2000, 1, 1);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _preferredTimeController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), backgroundColor: purple),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Profile Image
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (_profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : null),
                  backgroundColor: purple.withValues(alpha: 0.30),
                  child: _profileImage == null && _profileImageUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 16),

              /// Form Fields
              CustomTextField(
                controller: _nameController,
                label: 'Full Name',
                validator: (v) => _requiredField(v, 'Full Name'),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _dobController,
                label: 'Date of Birth',
                readOnly: true,
                onTap: _pickDob,
                validator: (v) => _requiredField(v, 'Date of Birth'),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _genderController,
                label: 'Gender',
                validator: (v) => _requiredField(v, 'Gender'),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _locationController,
                label: 'Neighborhood (Nairobi)',
                validator: (v) => _requiredField(v, 'Neighborhood'),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _experienceController,
                label: 'Running Experience',
                validator: (v) => _requiredField(v, 'Running Experience'),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _preferredTimeController,
                label: 'Preferred Running Time',
                validator: (v) => _requiredField(v, 'Preferred Running Time'),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _emergencyContactController,
                label: 'Emergency Contact',
                keyboardType: TextInputType.phone,
                validator: (v) => _requiredField(v, 'Emergency Contact'),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: 'Save Profile',
                  color: purple,
                  onPressed: _saveProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
