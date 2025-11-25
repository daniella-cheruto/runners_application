// lib/views/incident/report_incident_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '/models/route_model.dart';
import '/controllers/incident_report_controller.dart';
import '/widgets/custom_button.dart';
import '/widgets/custom_textfield.dart';
import '/views/incident/my_incidents_screen.dart';
import '/views/incident/fullscreen_image_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  final RouteModel route;

  const ReportIncidentScreen({super.key, required this.route});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  final _ctrl = IncidentReportController();
  final ImagePicker _picker = ImagePicker();

  // incident fields
  String _incidentType = 'Lighting';
  String _severity = 'Medium';
  bool _submitting = false;
  String? _statusMessage;

  // location fields
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;

  // photo fields (multi-photo)
  final int _maxPhotos = 3;
  final List<String> _photoUrls = [];
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------------- PHOTO ----------------

  Future<void> _pickAndUploadPhoto() async {
    FocusScope.of(context).unfocus();

    if (_photoUrls.length >= _maxPhotos) {
      setState(() {
        _statusMessage = 'You can attach at most $_maxPhotos photos.';
      });
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      _uploadingPhoto = true;
      _statusMessage = null;
    });

    try {
      final url = await _ctrl.uploadIncidentPhoto(image.path);
      if (!mounted) return;

      setState(() {
        _photoUrls.add(url);
        _statusMessage = 'Photo attached.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to upload photo.';
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  // ---------------- LOCATION ----------------

  Future<void> _getCurrentLocation() async {
    setState(() {
      _gettingLocation = true;
      _statusMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = 'Please enable location services.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Location permission denied.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage =
              'Location permission permanently denied. Enable it in Settings.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _statusMessage = 'Location attached.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to get location: $e';
      });
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  Future<void> _openInMaps() async {
    if (_latitude == null || _longitude == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_latitude!},${_longitude!}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      setState(() {
        _statusMessage = 'Could not open Google Maps.';
      });
    }
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    final err = await _ctrl.addIncident(
      routeId: widget.route.routeId,
      incidentType: _incidentType,
      severity: _severity,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      photoUrls: _photoUrls, // send list of URLs
    );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _submitting = false;
        _statusMessage = err;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _statusMessage = 'Incident reported successfully!';
    });

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9C27B0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Incident – ${widget.route.name}'),
        backgroundColor: purple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F3FF), Color(0xFFFDFBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 6,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // View My Reports (for this route)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MyIncidentsScreen(
                                    routeId: widget.route.routeId,
                                    routeName: widget.route.name,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('View My Reports'),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFE1BEE7),
                              ),
                              child: const Icon(
                                Icons.report_problem_outlined,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Report an Incident',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Incident type
                        const Text(
                          'Incident Type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _incidentType,
                          items:
                              const [
                                    'Lighting',
                                    'Harassment',
                                    'Traffic',
                                    'Crowded',
                                    'Poor Path Condition',
                                    'Other',
                                  ]
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _incidentType = val);
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Severity
                        const Text(
                          'Severity',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _severity,
                          items: const ['High', 'Medium', 'Low']
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _severity = val);
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        CustomTextField(
                          controller: _descriptionController,
                          hint:
                              'Describe what happened (e.g. dark area, suspicious people, stray dogs, traffic, etc.)',
                          maxLines: 4,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please describe the incident.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Photos (multi)
                        const Text(
                          'Photos (max 3, optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (int i = 0; i < _photoUrls.length; i++)
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FullscreenImageScreen(
                                            imageUrl: _photoUrls[i],
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        _photoUrls[i],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _photoUrls.removeAt(i);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            if (_photoUrls.length < _maxPhotos)
                              InkWell(
                                onTap: _uploadingPhoto
                                    ? null
                                    : _pickAndUploadPhoto,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.purple.shade50,
                                    border: Border.all(
                                      color: Colors.purple.shade200,
                                    ),
                                  ),
                                  child: _uploadingPhoto
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: Colors.purple,
                                        ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Location
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _latitude != null && _longitude != null
                                    ? 'Location attached: '
                                          '${_latitude!.toStringAsFixed(5)}, '
                                          '${_longitude!.toStringAsFixed(5)}'
                                    : 'No location attached (optional).',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomButton(
                          label: _gettingLocation
                              ? 'Getting location...'
                              : 'Use current location',
                          loading: _gettingLocation,
                          color: Colors.purple.shade200,
                          onPressed: _gettingLocation
                              ? null
                              : _getCurrentLocation,
                        ),
                        const SizedBox(height: 8),

                        if (_latitude != null && _longitude != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _openInMaps,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Open in Google Maps'),
                            ),
                          ),

                        const SizedBox(height: 8),

                        if (_statusMessage != null) ...[
                          Text(
                            _statusMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _statusMessage!.startsWith('Failed')
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        CustomButton(
                          label: _submitting ? 'Submitting...' : 'Submit',
                          loading: _submitting,
                          color: Colors.purple,
                          onPressed: _submitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
